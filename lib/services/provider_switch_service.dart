import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import 'claude_plugin_integration_service.dart';
import '../utils/platform_utils.dart';

/// 供应商配置切换服务
///
/// 管理 Claude Code、Codex 和 Gemini 的供应商（API 代理/中转站）配置，
/// 支持多配置方案保存和一键切换激活。
class ProviderSwitchService extends ChangeNotifier {
  final AppDatabase _db;
  bool _isInitialized = false;

  // 内存缓存
  List<ProviderProfile> _claudeProfiles = [];
  List<ProviderProfile> _codexProfiles = [];
  List<ProviderProfile> _geminiProfiles = [];
  List<String>? _cachedCodexModels;
  DateTime? _cachedCodexModelsAt;
  Future<List<String>>? _codexModelsFetchFuture;

  List<ProviderProfile> get claudeProfiles => _claudeProfiles;
  List<ProviderProfile> get codexProfiles => _codexProfiles;
  List<ProviderProfile> get geminiProfiles => _geminiProfiles;

  /// 官方配置的固定 ID 前缀
  static const String officialIdPrefix = 'official-';
  static const Duration _codexModelsCacheTtl = Duration(hours: 6);
  static const String _codexModelsCacheFileName = 'codex_models.json';

  /// 判断是否为官方预置配置
  static bool isOfficialProfile(ProviderProfile profile) {
    return profile.id.startsWith(officialIdPrefix);
  }

  ProviderSwitchService(this._db);

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadProfiles();
    await _seedOfficialProfiles();
    await _migrateConfigContent();
    await _loadProfiles();
    _isInitialized = true;
    notifyListeners();
  }

  /// 每次启动都读取实际配置文件，upsert 更新到数据库
  Future<void> _seedOfficialProfiles() async {
    await _syncClaudeOfficial();
    await _syncCodexOfficial();
    await _syncGeminiOfficial();
    // 根据配置文件实际内容，校正激活状态
    await _reconcileActiveFromConfig('claude');
    await _reconcileActiveFromConfig('codex');
    await _reconcileActiveFromConfig('gemini');
    await _loadProfiles();
  }

  /// 以配置文件为 source of truth，校正 DB 中的激活状态
  ///
  /// 逻辑：读取配置文件里的 baseUrl/apiToken，和 DB 中所有 profile
  /// 做匹配。匹配上的激活，其余全部取消。
  Future<void> _reconcileActiveFromConfig(String editorType) async {
    final all = await _db.getProfilesByEditor(editorType);
    if (all.isEmpty) return;

    String? fileBaseUrl;
    String? fileApiToken;

    try {
      if (editorType == 'claude') {
        final home = PlatformUtils.userHome;
        final path = PlatformUtils.joinPath(home, '.claude', 'settings.json');
        final file = File(path);
        if (await file.exists()) {
          final config = jsonDecode(await file.readAsString());
          if (config is Map<String, dynamic>) {
            final env = config['env'];
            if (env is Map<String, dynamic>) {
              fileBaseUrl = env['ANTHROPIC_BASE_URL'] as String?;
              fileApiToken = env['ANTHROPIC_AUTH_TOKEN'] as String?;
            }
          }
        }
      } else if (editorType == 'gemini') {
        // Gemini：读取 ~/.gemini/.env
        final home = PlatformUtils.userHome;
        final envPath = PlatformUtils.joinPath(home, '.gemini', '.env');
        final envFile = File(envPath);
        if (await envFile.exists()) {
          final lines = await envFile.readAsLines();
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('GEMINI_API_KEY=')) {
              fileApiToken = trimmed.substring('GEMINI_API_KEY='.length).trim();
            } else if (trimmed.startsWith('GOOGLE_GEMINI_BASE_URL=')) {
              fileBaseUrl = trimmed
                  .substring('GOOGLE_GEMINI_BASE_URL='.length)
                  .trim();
            }
          }
          if (fileApiToken?.isEmpty == true) fileApiToken = null;
          if (fileBaseUrl?.isEmpty == true) fileBaseUrl = null;
        }
      } else {
        // Codex：读取 config.toml + auth.json，匹配 DB 中的 profile
        final home = PlatformUtils.userHome;
        final tomlPath = PlatformUtils.joinPath(home, '.codex', 'config.toml');
        final tomlFile = File(tomlPath);
        String? fileModelProvider;

        if (await tomlFile.exists()) {
          final lines = await tomlFile.readAsLines();
          // 提取顶级 model_provider
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('model_provider')) {
              fileModelProvider = _extractTomlValue(trimmed);
              break;
            }
          }
          // 从 [model_providers.{provider}] 中提取 base_url
          if (fileModelProvider != null && fileModelProvider.isNotEmpty) {
            final section = 'model_providers.$fileModelProvider';
            final range = _findSectionRange(lines, section);
            if (range != null) {
              for (var i = range.start + 1; i < range.endExclusive; i++) {
                final trimmed = lines[i].trim();
                if (trimmed.startsWith('base_url')) {
                  fileBaseUrl = _extractTomlValue(trimmed);
                  break;
                }
              }
            }
          }
        }

        // 读取 auth.json 中的 OPENAI_API_KEY
        final authPath = PlatformUtils.joinPath(home, '.codex', 'auth.json');
        final authFile = File(authPath);
        if (await authFile.exists()) {
          try {
            final raw = await authFile.readAsString();
            final decoded = jsonDecode(raw.trim());
            if (decoded is Map<String, dynamic>) {
              fileApiToken = decoded['OPENAI_API_KEY'] as String?;
            }
          } catch (_) {}
        }

        // 如果没有找到 base_url（无 section 或 section 内无 base_url），
        // fileBaseUrl 自然为 null，无需额外清空。
        // 不再硬编码 model_provider == 'custom' 判断，
        // 因为用户可能用 "OpenAI" 等 provider name 搭配自定义 base_url。
      }
    } catch (_) {
      return;
    }

    // 根据 baseUrl + apiToken 找到匹配的 profile
    ProviderProfile? matched;
    for (final p in all) {
      final pBase = p.baseUrl ?? '';
      final fBase = fileBaseUrl ?? '';
      final pToken = p.apiToken ?? '';
      final fToken = fileApiToken ?? '';
      if (pBase == fBase && pToken == fToken) {
        matched = p;
        break;
      }
    }

    // 没有精确匹配时，用 baseUrl 模糊匹配
    if (matched == null && fileBaseUrl != null && fileBaseUrl.isNotEmpty) {
      for (final p in all) {
        if (p.baseUrl == fileBaseUrl) {
          matched = p;
          break;
        }
      }
    }

    // 还是没匹配上：如果 baseUrl 为空，匹配官方配置
    if (matched == null && (fileBaseUrl == null || fileBaseUrl.isEmpty)) {
      matched = all.where((p) => isOfficialProfile(p)).firstOrNull;
    }

    if (matched != null) {
      // 激活匹配的，取消其余
      await _db.activateProfile(editorType, matched.id);
    } else {
      // 兜底：确保不出现多个 active
      final actives = all.where((p) => p.isActive).toList();
      if (actives.length > 1) {
        actives.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        for (var i = 1; i < actives.length; i++) {
          await _db.updateProfile(
            ProviderProfilesCompanion(
              id: Value(actives[i].id),
              isActive: const Value(false),
            ),
          );
        }
      }
    }
  }

  Future<void> _syncClaudeOfficial() async {
    final officialId = '${officialIdPrefix}claude';
    final existing = await _db.getProfileById(officialId);
    final now = DateTime.now();

    if (existing != null) {
      // 已存在：不动任何字段，保持原样
      return;
    }

    // 首次创建：官方配置，字段为空，默认激活
    await _db.insertProfile(
      ProviderProfilesCompanion.insert(
        id: officialId,
        editorType: 'claude',
        name: 'Official',
        description: const Value('Anthropic Official'),
        isActive: const Value(true),
        apiToken: const Value(null),
        baseUrl: const Value(null),
        model: const Value(null),
        maxOutputTokens: const Value(null),
        maxThinkingTokens: const Value(null),
        website: const Value('https://www.anthropic.com'),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _syncCodexOfficial() async {
    String? model;
    String? reasoningEffort;
    String? personality;
    String? apiToken;
    String? oauthData;
    try {
      final home = PlatformUtils.userHome;
      final path = PlatformUtils.joinPath(home, '.codex', 'config.toml');
      final file = File(path);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('model ') || trimmed.startsWith('model=')) {
            model = _extractTomlValue(trimmed);
          } else if (trimmed.startsWith('model_reasoning_effort')) {
            reasoningEffort = _extractTomlValue(trimmed);
          } else if (trimmed.startsWith('personality')) {
            personality = _extractTomlValue(trimmed);
          }
        }
      }
    } catch (_) {}

    // 读取 auth.json：提取 OPENAI_API_KEY + OAuth 数据
    try {
      final home = PlatformUtils.userHome;
      final authPath = PlatformUtils.joinPath(home, '.codex', 'auth.json');
      final authFile = File(authPath);
      if (await authFile.exists()) {
        final raw = await authFile.readAsString();
        final decoded = jsonDecode(raw.trim());
        if (decoded is Map<String, dynamic>) {
          apiToken = decoded['OPENAI_API_KEY'] as String?;
          // 提取 OAuth 字段（tokens、last_refresh 等），存入 DB
          final oauth = Map<String, dynamic>.from(decoded);
          oauth.remove('OPENAI_API_KEY');
          if (oauth.isNotEmpty) {
            oauthData = jsonEncode(oauth);
          }
        }
      }
    } catch (_) {}

    final officialId = '${officialIdPrefix}codex';
    final existing = await _db.getProfileById(officialId);
    final now = DateTime.now();

    if (existing != null) {
      await _db.updateProfile(
        ProviderProfilesCompanion(
          id: Value(officialId),
          editorType: const Value('codex'),
          name: const Value('Official'),
          description: const Value('OpenAI Official'),
          apiToken: Value(apiToken),
          model: Value(model ?? codexModels.first),
          modelReasoningEffort: Value(reasoningEffort ?? 'high'),
          personality: Value(personality ?? 'pragmatic'),
          oauthData: Value(oauthData),
          updatedAt: Value(now),
        ),
      );
    } else {
      await _db.insertProfile(
        ProviderProfilesCompanion.insert(
          id: officialId,
          editorType: 'codex',
          name: 'Official',
          description: const Value('OpenAI Official'),
          isActive: const Value(true),
          apiToken: Value(apiToken),
          model: Value(model ?? codexModels.first),
          modelReasoningEffort: Value(reasoningEffort ?? 'high'),
          personality: Value(personality ?? 'pragmatic'),
          oauthData: Value(oauthData),
          website: const Value('https://openai.com'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  Future<void> _syncGeminiOfficial() async {
    final officialId = '${officialIdPrefix}gemini';
    final existing = await _db.getProfileById(officialId);
    final now = DateTime.now();

    if (existing != null) return;

    await _db.insertProfile(
      ProviderProfilesCompanion.insert(
        id: officialId,
        editorType: 'gemini',
        name: 'Official',
        description: const Value('Google Official'),
        isActive: const Value(true),
        apiToken: const Value(null),
        baseUrl: const Value(null),
        model: const Value(null),
        maxOutputTokens: const Value(null),
        maxThinkingTokens: const Value(null),
        website: const Value('https://gemini.google.com'),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// 从 TOML 行中提取值，如 'model = "gpt-4o"' → 'gpt-4o'
  static String? _extractTomlValue(String line) {
    final idx = line.indexOf('=');
    if (idx < 0) return null;
    var val = line.substring(idx + 1).trim();
    if (val.startsWith('"') && val.endsWith('"')) {
      val = val.substring(1, val.length - 1);
    }
    return val.isEmpty ? null : val;
  }

  Future<void> _loadProfiles() async {
    _claudeProfiles = await _db.getProfilesByEditor('claude');
    _codexProfiles = await _db.getProfilesByEditor('codex');
    _geminiProfiles = await _db.getProfilesByEditor('gemini');
  }

  /// 手动刷新：重新读取配置文件，校正 DB 激活状态
  Future<void> refreshFromConfig() async {
    await _seedOfficialProfiles();
    notifyListeners();
  }

  /// 获取指定编辑器的配置列表
  List<ProviderProfile> getProfiles(String editorType) {
    if (editorType == 'claude') return _claudeProfiles;
    if (editorType == 'gemini') return _geminiProfiles;
    return _codexProfiles;
  }

  /// 获取激活的配置
  ProviderProfile? getActiveProfile(String editorType) {
    final profiles = getProfiles(editorType);
    try {
      return profiles.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  /// 添加新配置
  Future<void> addProfile({
    required String editorType,
    required String name,
    String? description,
    String? apiToken,
    String? baseUrl,
    String? model,
    String? maxOutputTokens,
    String? maxThinkingTokens,
    String? modelReasoningEffort,
    String? personality,
    String? website,
    String? configContent,
  }) async {
    final now = DateTime.now();
    final entry = ProviderProfilesCompanion.insert(
      id: const Uuid().v4(),
      editorType: editorType,
      name: name,
      description: Value(description),
      apiToken: Value(apiToken),
      baseUrl: Value(baseUrl),
      model: Value(model),
      maxOutputTokens: Value(maxOutputTokens),
      maxThinkingTokens: Value(maxThinkingTokens),
      modelReasoningEffort: Value(modelReasoningEffort),
      personality: Value(personality),
      website: Value(website),
      configContent: Value(configContent),
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertProfile(entry);
    await _loadProfiles();
    notifyListeners();
  }

  /// 更新配置
  Future<void> updateProfile({
    required String id,
    required String editorType,
    required String name,
    String? description,
    String? apiToken,
    String? baseUrl,
    String? model,
    String? maxOutputTokens,
    String? maxThinkingTokens,
    String? modelReasoningEffort,
    String? personality,
    String? website,
    String? configContent,
  }) async {
    final existingProfile = await _db.getProfileById(id);
    final wasActive = existingProfile?.isActive ?? false;

    final entry = ProviderProfilesCompanion(
      id: Value(id),
      editorType: Value(editorType),
      name: Value(name),
      description: Value(description),
      apiToken: Value(apiToken),
      baseUrl: Value(baseUrl),
      model: Value(model),
      maxOutputTokens: Value(maxOutputTokens),
      maxThinkingTokens: Value(maxThinkingTokens),
      modelReasoningEffort: Value(modelReasoningEffort),
      personality: Value(personality),
      website: Value(website),
      configContent: Value(configContent),
      updatedAt: Value(DateTime.now()),
    );
    await _db.updateProfile(entry);
    await _loadProfiles();

    final updatedProfile = await _db.getProfileById(id);
    if (updatedProfile != null && (wasActive || updatedProfile.isActive)) {
      await _writeConfigFile(editorType, updatedProfile);
    }

    notifyListeners();
  }

  /// 删除配置
  Future<void> deleteProfile(String id, String editorType) async {
    await _db.deleteProfile(id);
    await _loadProfiles();
    notifyListeners();
  }

  /// 切换激活状态
  Future<void> toggleActive(String id, String editorType, bool activate) async {
    if (activate) {
      await _db.activateProfile(editorType, id);
      await _loadProfiles();
      // 从刷新后的缓存中获取配置
      final profile = getProfiles(editorType).firstWhere((p) => p.id == id);
      await _writeConfigFile(editorType, profile);
    } else {
      // 取消激活：更新 DB 并清理配置文件中的供应商字段
      await _db.deactivateAll(editorType);
      await _clearConfigFile(editorType);
      await _loadProfiles();
    }
    notifyListeners();
  }

  /// 将激活配置写入对应的配置文件
  Future<void> _writeConfigFile(
    String editorType,
    ProviderProfile profile,
  ) async {
    try {
      if (editorType == 'claude') {
        await _writeClaudeSettings(profile);
        await _syncClaudePluginIntegration(profile);
      } else if (editorType == 'codex') {
        await _writeCodexConfig(profile);
      } else if (editorType == 'gemini') {
        await _writeGeminiEnv(profile);
      }
    } catch (e) {
      // 写入失败时回滚 DB 激活状态
      await _db.deactivateAll(editorType);
      await _loadProfiles();
      notifyListeners();
      rethrow;
    }
  }

  /// 取消激活时清理配置文件中的供应商字段
  Future<void> _clearConfigFile(String editorType) async {
    try {
      if (editorType == 'claude') {
        await _clearClaudeSettings();
        await _syncClaudePluginWhenDisabledOrOfficial();
      } else if (editorType == 'codex') {
        await _clearCodexConfig();
      } else if (editorType == 'gemini') {
        await _clearGeminiEnv();
      }
    } catch (e) {
      print('Error clearing config file: $e');
    }
  }

  Future<void> _syncClaudePluginIntegration(ProviderProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('enable_claude_plugin_integration') ?? false;
    if (!enabled) return;

    try {
      if (isOfficialProfile(profile)) {
        await ClaudePluginIntegrationService.clearPrimaryApiKey();
      } else {
        await ClaudePluginIntegrationService.writeManagedConfig();
      }
    } catch (e) {
      // 插件联动失败不应影响主供应商切换流程
      debugPrint('Claude plugin integration sync failed: $e');
    }
  }

  Future<void> _syncClaudePluginWhenDisabledOrOfficial() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('enable_claude_plugin_integration') ?? false;
    if (!enabled) return;

    try {
      await ClaudePluginIntegrationService.clearPrimaryApiKey();
    } catch (e) {
      // 插件联动失败不应影响主供应商切换流程
      debugPrint('Claude plugin integration clear failed: $e');
    }
  }

  /// 清理 Claude settings.json 中的供应商字段
  Future<void> _clearClaudeSettings() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude', 'settings.json');
    final file = File(path);
    if (!await file.exists()) return;

    try {
      final config =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final env = config['env'];
      if (env is Map<String, dynamic>) {
        env.remove('ANTHROPIC_AUTH_TOKEN');
        env.remove('ANTHROPIC_BASE_URL');
        env.remove('CLAUDE_CODE_MAX__OUTPUT_TOKENS');
        env.remove('MAX_THINKING_TOKENS');
      }
      config.remove('model');

      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(config));
    } catch (_) {}
  }

  /// 清理 Codex config.toml + auth.json 中的供应商字段
  Future<void> _clearCodexConfig() async {
    final home = PlatformUtils.userHome;

    // 清理 config.toml
    final tomlPath = PlatformUtils.joinPath(home, '.codex', 'config.toml');
    final tomlFile = File(tomlPath);
    if (await tomlFile.exists()) {
      try {
        final content = await tomlFile.readAsString();
        final merged = _mergeCodexConfig(
          existingContent: content,
          profile: null,
        );
        await tomlFile.writeAsString(merged.isEmpty ? '' : '$merged\n');
      } catch (_) {}
    }

    // 清理 auth.json 中的 OPENAI_API_KEY
    final authPath = PlatformUtils.joinPath(home, '.codex', 'auth.json');
    final authFile = File(authPath);
    if (await authFile.exists()) {
      try {
        final raw = await authFile.readAsString();
        final decoded = jsonDecode(raw.trim());
        if (decoded is Map<String, dynamic>) {
          decoded.remove('OPENAI_API_KEY');
          const encoder = JsonEncoder.withIndent('  ');
          await authFile.writeAsString(encoder.convert(decoded));
        }
      } catch (_) {}
    }
  }

  /// 写入 Gemini 配置 (~/.gemini/.env)
  ///
  /// 优先使用 profile.configContent 直接写入；
  /// configContent 为空时回退到字段合并逻辑（迁移兼容）。
  Future<void> _writeGeminiEnv(ProviderProfile profile) async {
    final home = PlatformUtils.userHome;
    final geminiDir = PlatformUtils.joinPath(home, '.gemini');
    final dir = Directory(geminiDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final envPath = PlatformUtils.joinPath(geminiDir, '.env');
    final envFile = File(envPath);

    final content = profile.configContent;
    if (content != null && content.trim().isNotEmpty) {
      await envFile.writeAsString('${content.trim()}\n');
      return;
    }

    final Map<String, String> envMap = {};
    final List<String> keyOrder = [];
    if (await envFile.exists()) {
      final lines = await envFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx < 0) continue;
        final key = trimmed.substring(0, eqIdx).trim();
        final value = trimmed.substring(eqIdx + 1).trim();
        if (!keyOrder.contains(key)) keyOrder.add(key);
        envMap[key] = value;
      }
    }

    void setOrRemove(String key, String? value) {
      if (value != null && value.isNotEmpty) {
        if (!keyOrder.contains(key)) keyOrder.add(key);
        envMap[key] = value;
      } else {
        keyOrder.remove(key);
        envMap.remove(key);
      }
    }

    setOrRemove('GEMINI_API_KEY', profile.apiToken);
    setOrRemove('GOOGLE_GEMINI_BASE_URL', profile.baseUrl);
    setOrRemove('GEMINI_MODEL', profile.model);

    final output = keyOrder.map((k) => '$k=${envMap[k]}').join('\n');
    await envFile.writeAsString(output.isEmpty ? '' : '$output\n');
  }

  /// 清理 Gemini .env 中的供应商字段
  Future<void> _clearGeminiEnv() async {
    final home = PlatformUtils.userHome;
    final envPath = PlatformUtils.joinPath(home, '.gemini', '.env');
    final envFile = File(envPath);
    if (!await envFile.exists()) return;

    try {
      final lines = await envFile.readAsLines();
      final keysToRemove = {
        'GEMINI_API_KEY',
        'GOOGLE_GEMINI_BASE_URL',
        'GEMINI_MODEL',
      };
      final remaining = lines.where((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) return true;
        final key = trimmed.split('=').first.trim();
        return !keysToRemove.contains(key);
      }).toList();
      final output = remaining.join('\n');
      await envFile.writeAsString(output.isEmpty ? '' : '$output\n');
    } catch (_) {}
  }

  /// 写入 Claude Code 配置 (~/.claude/settings.json)
  ///
  /// 优先使用 profile.configContent 直接写入；
  /// configContent 为空时回退到字段合并逻辑（迁移兼容）。
  Future<void> _writeClaudeSettings(ProviderProfile profile) async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude', 'settings.json');
    final file = File(path);

    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');

    final content = profile.configContent;
    if (content != null && content.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(content);
        await file.writeAsString(encoder.convert(parsed));
      } catch (_) {
        await file.writeAsString(content);
      }
      return;
    }

    Map<String, dynamic> config = {};
    if (await file.exists()) {
      try {
        config = jsonDecode(await file.readAsString());
      } catch (_) {}
    }

    if (config['env'] is! Map) {
      config['env'] = <String, dynamic>{};
    }
    final env = config['env'] as Map<String, dynamic>;

    setOrRemove(env, 'ANTHROPIC_AUTH_TOKEN', profile.apiToken);
    setOrRemove(env, 'ANTHROPIC_BASE_URL', profile.baseUrl);
    setOrRemove(env, 'CLAUDE_CODE_MAX__OUTPUT_TOKENS', profile.maxOutputTokens);
    setOrRemove(env, 'MAX_THINKING_TOKENS', profile.maxThinkingTokens);

    if (profile.model != null && profile.model!.isNotEmpty) {
      config['model'] = profile.model;
    } else {
      config.remove('model');
    }

    await file.writeAsString(encoder.convert(config));
  }

  static void setOrRemove(Map<String, dynamic> map, String key, String? value) {
    if (value != null && value.isNotEmpty) {
      map[key] = value;
    } else {
      map.remove(key);
    }
  }

  /// 写入 Codex 配置 (~/.codex/config.toml + ~/.codex/auth.json)
  ///
  /// 优先使用 profile.configContent 直接写入；
  /// configContent 为空时回退到字段合并逻辑（迁移兼容）。
  Future<void> _writeCodexConfig(ProviderProfile profile) async {
    final home = PlatformUtils.userHome;
    final codexDir = PlatformUtils.joinPath(home, '.codex');
    final dir = Directory(codexDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tomlPath = PlatformUtils.joinPath(codexDir, 'config.toml');
    final tomlFile = File(tomlPath);

    final content = profile.configContent;
    if (content != null && content.trim().isNotEmpty) {
      await tomlFile.writeAsString('${content.trim()}\n');
    } else {
      String existingContent = '';
      if (await tomlFile.exists()) {
        try {
          existingContent = await tomlFile.readAsString();
        } catch (_) {}
      }
      final generated = generateCodexPreview(
        profile,
        existingConfigContent: existingContent,
      );
      await tomlFile.writeAsString(generated.isEmpty ? '' : '$generated\n');
    }

    await _writeCodexAuth(profile.apiToken);
  }

  /// 写入 Codex 认证文件 (~/.codex/auth.json)
  ///
  /// - 有 apiKey（第三方）→ 只写 {"OPENAI_API_KEY": "sk-xxx"}，清除 OAuth 字段
  /// - 无 apiKey（官方）→ 从 DB 恢复 OAuth tokens，OPENAI_API_KEY 设为 null
  Future<void> _writeCodexAuth(String? apiKey) async {
    final home = PlatformUtils.userHome;
    final authPath = PlatformUtils.joinPath(home, '.codex', 'auth.json');
    final authFile = File(authPath);
    final authDir = authFile.parent;
    if (!await authDir.exists()) {
      await authDir.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    final hasKey = apiKey != null && apiKey.isNotEmpty;

    if (hasKey) {
      // 第三方：只写 OPENAI_API_KEY，清除 OAuth 字段
      await authFile.writeAsString(encoder.convert({'OPENAI_API_KEY': apiKey}));
    } else {
      // 官方：从 DB 恢复 OAuth tokens + OPENAI_API_KEY 设为 null
      final officialId = '${officialIdPrefix}codex';
      final profile = await _db.getProfileById(officialId);
      final Map<String, dynamic> authMap = {'OPENAI_API_KEY': null};
      if (profile?.oauthData != null) {
        try {
          final oauth = jsonDecode(profile!.oauthData!);
          if (oauth is Map<String, dynamic>) {
            authMap.addAll(oauth);
          }
        } catch (_) {}
      }
      await authFile.writeAsString(encoder.convert(authMap));
    }
  }

  /// 检查已选中供应商的 configContent 与配置文件是否一致
  Future<bool> checkConfigSync(String editorType) async {
    final active = getActiveProfile(editorType);
    if (active == null) return true;

    final dbContent = active.configContent;
    if (dbContent == null) return false;

    try {
      if (editorType == 'claude') {
        final fileContent = await readClaudeConfigFile();
        return jsonEquals(dbContent, fileContent);
      } else if (editorType == 'codex') {
        final fileContent = await readCodexConfigFile();
        return normalizedEquals(dbContent, fileContent);
      } else if (editorType == 'gemini') {
        final fileContent = await readGeminiEnvFile();
        return envEquals(dbContent, fileContent);
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  static bool jsonEquals(String a, String b) {
    try {
      final objA = jsonDecode(a.trim());
      final objB = jsonDecode(b.trim());
      return deepEquals(objA, objB);
    } catch (_) {
      return normalizedEquals(a, b);
    }
  }

  static bool deepEquals(dynamic a, dynamic b) {
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  static bool normalizedEquals(String a, String b) {
    return a.trim().replaceAll('\r\n', '\n') ==
        b.trim().replaceAll('\r\n', '\n');
  }

  static bool envEquals(String a, String b) {
    Map<String, String> parse(String content) {
      final map = <String, String>{};
      for (final line in const LineSplitter().convert(content)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx < 0) continue;
        map[trimmed.substring(0, eqIdx).trim()] =
            trimmed.substring(eqIdx + 1).trim();
      }
      return map;
    }
    return deepEquals(parse(a), parse(b));
  }

  /// 启动时对已激活且 configContent 为空的 profile，从配置文件补充
  Future<void> _migrateConfigContent() async {
    for (final editorType in ['claude', 'codex', 'gemini']) {
      final active = await _db.getActiveProfile(editorType);
      if (active == null || active.configContent != null) continue;

      String fileContent;
      try {
        if (editorType == 'claude') {
          fileContent = await readClaudeConfigFile();
        } else if (editorType == 'codex') {
          fileContent = await readCodexConfigFile();
        } else {
          fileContent = await readGeminiEnvFile();
        }
      } catch (_) {
        continue;
      }

      if (fileContent.trim().isNotEmpty) {
        await _db.updateProfile(
          ProviderProfilesCompanion(
            id: Value(active.id),
            configContent: Value(fileContent),
          ),
        );
      }
    }
  }

  /// 获取 Claude 可用模型列表
  static const List<String> claudeModels = [
    'opus',
    'sonnet',
    'haiku',
    'claude-opus-4-5-20251101',
    'claude-sonnet-4-5-20250929',
    'claude-sonnet-4-20250514',
    'claude-haiku-4-5-20251001',
    'claude-3-5-sonnet-20241022',
    'claude-3-5-haiku-20241022',
    'claude-3-opus-20240229',
  ];

  /// CLI 模型精简版（仅 opus/sonnet/haiku）
  static const List<String> claudeModelsSimple = ['opus', 'sonnet', 'haiku'];

  /// 获取 Codex 可用模型列表
  static const List<String> codexModels = [
    'gpt-5.3-codex',
    'o4-mini',
    'o3',
    'o3-mini',
    'gpt-4.1',
    'gpt-4.1-mini',
    'gpt-4.1-nano',
    'gpt-4o',
    'gpt-4o-mini',
  ];

  /// 获取 Gemini 可用模型列表
  static const List<String> geminiModels = [
    'gemini-3.1-pro-preview',
    'gemini-3-flash',
    'gemini-2.5-pro',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite-preview-06-17',
  ];

  /// Codex reasoning effort 选项
  static const List<String> reasoningEfforts = [
    'high',
    'medium',
    'low',
    'minimal',
    'xhigh',
  ];

  /// Codex personality 选项（官方仅支持 none / friendly / pragmatic）
  static const List<String> personalities = ['pragmatic', 'friendly', 'none'];

  /// 动态获取 Codex 模型列表（优先缓存，失败回退静态列表）
  Future<List<String>> getCodexModels({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final memoryCached = _getFreshInMemoryCodexModels();
      if (memoryCached != null) return memoryCached;

      final diskCached = await _readCodexModelsCache();
      if (diskCached != null &&
          _isCodexModelsCacheFresh(diskCached.fetchedAt)) {
        _cachedCodexModels = diskCached.models;
        _cachedCodexModelsAt = diskCached.fetchedAt;
        return diskCached.models;
      }
    }

    final inflight = _codexModelsFetchFuture;
    if (inflight != null) return inflight;

    final fetchFuture = _fetchCodexModelsFromAppServer().then((models) async {
      if (models.isEmpty) return codexModels;

      final fetchedAt = DateTime.now().toUtc();
      _cachedCodexModels = models;
      _cachedCodexModelsAt = fetchedAt;
      await _writeCodexModelsCache(models, fetchedAt);
      return models;
    });

    _codexModelsFetchFuture = fetchFuture;
    try {
      return await fetchFuture;
    } catch (_) {
      final diskCached = await _readCodexModelsCache();
      if (diskCached != null && diskCached.models.isNotEmpty) {
        _cachedCodexModels = diskCached.models;
        _cachedCodexModelsAt = diskCached.fetchedAt;
        return diskCached.models;
      }
      return codexModels;
    } finally {
      _codexModelsFetchFuture = null;
    }
  }

  List<String>? _getFreshInMemoryCodexModels() {
    final models = _cachedCodexModels;
    final fetchedAt = _cachedCodexModelsAt;
    if (models == null || fetchedAt == null) return null;
    if (models.isEmpty) return null;
    if (!_isCodexModelsCacheFresh(fetchedAt)) return null;
    return models;
  }

  bool _isCodexModelsCacheFresh(DateTime fetchedAt) {
    final elapsed = DateTime.now().toUtc().difference(fetchedAt.toUtc());
    return elapsed <= _codexModelsCacheTtl;
  }

  String get _codexModelsCachePath => PlatformUtils.joinPath(
    PlatformUtils.appDataDir,
    'cache',
    _codexModelsCacheFileName,
  );

  Future<void> _writeCodexModelsCache(
    List<String> models,
    DateTime fetchedAt,
  ) async {
    try {
      final file = File(_codexModelsCachePath);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        encoder.convert({
          'fetchedAt': fetchedAt.toUtc().toIso8601String(),
          'models': models,
        }),
      );
    } catch (_) {}
  }

  Future<_CodexModelsCacheData?> _readCodexModelsCache() async {
    try {
      final file = File(_codexModelsCachePath);
      if (!await file.exists()) return null;

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;

      final fetchedAtStr = decoded['fetchedAt']?.toString();
      if (fetchedAtStr == null || fetchedAtStr.isEmpty) return null;
      final fetchedAt = DateTime.tryParse(fetchedAtStr);
      if (fetchedAt == null) return null;

      final rawModels = decoded['models'];
      if (rawModels is! List) return null;

      final models = <String>[];
      for (final item in rawModels) {
        final model = item.toString().trim();
        if (model.isEmpty || models.contains(model)) continue;
        models.add(model);
      }
      if (models.isEmpty) return null;

      return _CodexModelsCacheData(models: models, fetchedAt: fetchedAt);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _fetchCodexModelsFromAppServer() async {
    final env = await PlatformUtils.getUpdatedEnvironment();
    final executable = await PlatformUtils.findCodexExePath() ?? 'codex';

    Process? process;
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    final completer = Completer<List<String>>();

    try {
      process = await Process.start(
        executable,
        const ['app-server'],
        runInShell: Platform.isWindows,
        environment: env,
      );

      stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            _handleCodexModelListLine(line, completer);
          });

      stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((_) {});

      unawaited(
        process.exitCode.then((code) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError(
                'codex app-server exited before model/list response: $code',
              ),
            );
          }
        }),
      );

      process.stdin.writeln(
        jsonEncode({
          'id': 0,
          'method': 'initialize',
          'params': {
            'clientInfo': {'name': 'mcp-switch', 'version': '1.0.0'},
          },
        }),
      );
      process.stdin.writeln(jsonEncode({'method': 'initialized'}));
      process.stdin.writeln(
        jsonEncode({
          'id': 1,
          'method': 'model/list',
          'params': {'limit': 100},
        }),
      );

      return await completer.future.timeout(const Duration(seconds: 10));
    } finally {
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      if (process != null) {
        await _terminateProcess(process);
      }
    }
  }

  void _handleCodexModelListLine(
    String line,
    Completer<List<String>> completer,
  ) {
    if (completer.isCompleted) return;
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return;
      if (decoded['id'] != 1) return;

      final error = decoded['error'];
      if (error != null) {
        completer.completeError(StateError('model/list failed: $error'));
        return;
      }

      final result = decoded['result'];
      if (result is! Map) return;
      final data = result['data'];
      if (data is! List) return;

      final models = <String>[];
      for (final item in data) {
        if (item is! Map || item['model'] == null) continue;
        final model = item['model'].toString().trim();
        if (model.isEmpty || models.contains(model)) continue;
        models.add(model);
      }
      if (models.isNotEmpty) {
        completer.complete(models);
      }
    } catch (_) {}
  }

  Future<void> _terminateProcess(Process process) async {
    try {
      await process.stdin.close();
    } catch (_) {}

    try {
      await process.exitCode.timeout(const Duration(milliseconds: 200));
      return;
    } catch (_) {}

    try {
      process.kill();
    } catch (_) {}

    try {
      await process.exitCode.timeout(const Duration(milliseconds: 500));
      return;
    } catch (_) {}

    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {}

    try {
      await process.exitCode.timeout(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  /// 读取完整的 Claude 配置文件内容（用于预览）
  static Future<String> readClaudeConfigFile() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude', 'settings.json');
    final file = File(path);
    if (!await file.exists()) return '{}';
    final raw = await file.readAsString();
    // 格式化 JSON
    try {
      final decoded = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  /// 读取完整的 Codex 配置文件内容（用于预览）
  static Future<String> readCodexConfigFile() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.codex', 'config.toml');
    final file = File(path);
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  /// 读取 Gemini .env 完整内容（用于预览）
  static Future<String> readGeminiEnvFile() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.gemini', '.env');
    final file = File(path);
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  /// 读取 Gemini settings.json 完整内容（用于预览）
  static Future<String> readGeminiSettingsFile() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.gemini', 'settings.json');
    final file = File(path);
    if (!await file.exists()) return '';
    final raw = await file.readAsString();
    try {
      final decoded = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  /// 读取 Codex auth.json 完整内容（用于预览）
  static Future<String> readCodexAuthFile() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.codex', 'auth.json');
    final file = File(path);
    if (!await file.exists()) return '';
    final raw = await file.readAsString();
    try {
      final decoded = jsonDecode(raw.trim());
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  /// 生成 Codex auth.json 预览内容
  static String generateCodexAuthPreview(String? apiKey) {
    if (apiKey == null || apiKey.trim().isEmpty) {
      return '{}';
    }
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({'OPENAI_API_KEY': apiKey.trim()});
  }

  /// 生成 Gemini 配置预览 dotenv（与实际写入逻辑保持一致）
  String generateGeminiPreview(
    ProviderProfile profile, {
    String? existingEnvContent,
  }) {
    final Map<String, String> envMap = {};
    final List<String> keyOrder = [];
    if (existingEnvContent != null && existingEnvContent.isNotEmpty) {
      for (final line in const LineSplitter().convert(existingEnvContent)) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eqIdx = trimmed.indexOf('=');
        if (eqIdx < 0) continue;
        final key = trimmed.substring(0, eqIdx).trim();
        final value = trimmed.substring(eqIdx + 1).trim();
        if (!keyOrder.contains(key)) keyOrder.add(key);
        envMap[key] = value;
      }
    }
    void setOrRemove(String key, String? value) {
      if (value != null && value.isNotEmpty) {
        if (!keyOrder.contains(key)) keyOrder.add(key);
        envMap[key] = value;
      } else {
        keyOrder.remove(key);
        envMap.remove(key);
      }
    }
    setOrRemove('GEMINI_API_KEY', profile.apiToken);
    setOrRemove('GOOGLE_GEMINI_BASE_URL', profile.baseUrl);
    setOrRemove('GEMINI_MODEL', profile.model);
    if (keyOrder.isEmpty) return '# (empty)';
    return keyOrder.map((k) => '$k=${envMap[k]}').join('\n');
  }

  /// 生成 Codex 配置预览 TOML（与实际写入逻辑保持一致）
  String generateCodexPreview(
    ProviderProfile profile, {
    String? existingConfigContent,
  }) {
    return _mergeCodexConfig(
      existingContent: existingConfigContent ?? '',
      profile: profile,
    );
  }

  String _mergeCodexConfig({
    required String existingContent,
    required ProviderProfile? profile,
  }) {
    final lines = existingContent.trim().isEmpty
        ? <String>[]
        : const LineSplitter().convert(existingContent).toList();
    final customBaseUrl = profile?.baseUrl?.trim() ?? '';
    final useCustomProvider = profile != null && customBaseUrl.isNotEmpty;

    // 检测已有的 model_provider 值（如 "OpenAI"、"custom" 等）
    final existingProvider = _extractTopLevelValue(lines, 'model_provider');

    if (profile == null) {
      _removeTopLevelKey(lines, 'model');
      _removeTopLevelKey(lines, 'model_reasoning_effort');
      _removeTopLevelKey(lines, 'personality');
      _removeTopLevelKey(lines, 'model_provider');
      _removeProviderSection(lines, existingProvider ?? 'custom');
      while (lines.isNotEmpty && lines.last.trim().isEmpty) {
        lines.removeLast();
      }
      return lines.join('\n');
    }

    final model = profile.model?.trim();
    if (model != null && model.isNotEmpty) {
      _upsertTopLevelKey(lines, 'model', '"$model"');
    }

    final reasoningEffort = profile.modelReasoningEffort?.trim();
    if (reasoningEffort != null && reasoningEffort.isNotEmpty) {
      _upsertTopLevelKey(lines, 'model_reasoning_effort', '"$reasoningEffort"');
    }

    final personality = profile.personality?.trim();
    if (personality != null && personality.isNotEmpty) {
      _upsertTopLevelKey(lines, 'personality', '"$personality"');
    }

    if (useCustomProvider) {
      // 尊重已有的 model_provider 值，没有时默认 "custom"
      final providerName = existingProvider ?? 'custom';
      _upsertTopLevelKey(lines, 'model_provider', '"$providerName"');
      _upsertProviderSection(lines, providerName, customBaseUrl);
    } else {
      _removeTopLevelKey(lines, 'model_provider');
      _removeProviderSection(lines, existingProvider ?? 'custom');
    }

    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }

  /// 从 lines 中提取顶级 key 的值（去引号）
  String? _extractTopLevelValue(List<String> lines, String key) {
    final regex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=\s*"?([^"]*)"?');
    final firstSection = _firstSectionIndex(lines);
    for (var i = 0; i < firstSection; i++) {
      final m = regex.firstMatch(lines[i]);
      if (m != null) return m.group(1)?.trim();
    }
    return null;
  }

  void _upsertTopLevelKey(List<String> lines, String key, String value) {
    final keyRegex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=');
    final firstSection = _firstSectionIndex(lines);
    final indexes = <int>[];
    for (var i = 0; i < firstSection; i++) {
      if (keyRegex.hasMatch(lines[i])) {
        indexes.add(i);
      }
    }

    final newLine = '$key = $value';
    if (indexes.isEmpty) {
      lines.insert(firstSection, newLine);
      return;
    }

    lines[indexes.first] = newLine;
    for (var i = indexes.length - 1; i >= 1; i--) {
      lines.removeAt(indexes[i]);
    }
  }

  void _removeTopLevelKey(List<String> lines, String key) {
    final keyRegex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=');
    final firstSection = _firstSectionIndex(lines);
    for (var i = firstSection - 1; i >= 0; i--) {
      if (keyRegex.hasMatch(lines[i])) {
        lines.removeAt(i);
      }
    }
  }

  int _firstSectionIndex(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      if (_parseSectionName(lines[i]) != null) {
        return i;
      }
    }
    return lines.length;
  }

  void _upsertProviderSection(
      List<String> lines, String providerName, String baseUrl) {
    final sectionName = 'model_providers.$providerName';
    final range = _findSectionRange(lines, sectionName);
    final body = range == null
        ? <String>[]
        : lines.sublist(range.start + 1, range.endExclusive).toList();
    _upsertSectionKey(body, 'name', '"$providerName"');
    _upsertSectionKey(body, 'wire_api', '"responses"');
    _upsertSectionKey(body, 'requires_openai_auth', 'true');
    _upsertSectionKey(body, 'base_url', '"$baseUrl"');

    final sectionLines = <String>['[$sectionName]', ...body];
    if (range != null) {
      lines.removeRange(range.start, range.endExclusive);
      lines.insertAll(range.start, sectionLines);
      return;
    }

    if (lines.isNotEmpty && lines.last.trim().isNotEmpty) {
      lines.add('');
    }
    lines.addAll(sectionLines);
  }

  void _upsertSectionKey(List<String> sectionBody, String key, String value) {
    final keyRegex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=');
    final indexes = <int>[];
    for (var i = 0; i < sectionBody.length; i++) {
      if (keyRegex.hasMatch(sectionBody[i])) {
        indexes.add(i);
      }
    }

    final newLine = '$key = $value';
    if (indexes.isEmpty) {
      var insertAt = sectionBody.length;
      while (insertAt > 0 && sectionBody[insertAt - 1].trim().isEmpty) {
        insertAt--;
      }
      sectionBody.insert(insertAt, newLine);
      return;
    }

    sectionBody[indexes.first] = newLine;
    for (var i = indexes.length - 1; i >= 1; i--) {
      sectionBody.removeAt(indexes[i]);
    }
  }

  void _removeProviderSection(List<String> lines, String providerName) {
    final range = _findSectionRange(lines, 'model_providers.$providerName');
    if (range == null) return;

    var start = range.start;
    var end = range.endExclusive;
    if (start > 0 && lines[start - 1].trim().isEmpty) {
      start -= 1;
    } else if (end < lines.length && lines[end].trim().isEmpty) {
      end += 1;
    }

    lines.removeRange(start, end);
  }

  _LineRange? _findSectionRange(List<String> lines, String sectionName) {
    for (var i = 0; i < lines.length; i++) {
      final name = _parseSectionName(lines[i]);
      if (name != sectionName) continue;

      var endExclusive = lines.length;
      for (var j = i + 1; j < lines.length; j++) {
        if (_parseSectionName(lines[j]) != null) {
          endExclusive = j;
          break;
        }
      }
      return _LineRange(start: i, endExclusive: endExclusive);
    }
    return null;
  }

  String? _parseSectionName(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return null;
    return trimmed.substring(1, trimmed.length - 1).trim();
  }
}

class _CodexModelsCacheData {
  final List<String> models;
  final DateTime fetchedAt;

  const _CodexModelsCacheData({required this.models, required this.fetchedAt});
}

class _LineRange {
  final int start;
  final int endExclusive;

  const _LineRange({required this.start, required this.endExclusive});
}
