import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../utils/platform_utils.dart';

/// 供应商配置切换服务
///
/// 管理 Claude Code 和 Codex 的供应商（API 代理/中转站）配置，
/// 支持多配置方案保存和一键切换激活。
class ProviderSwitchService extends ChangeNotifier {
  final AppDatabase _db;
  bool _isInitialized = false;

  // 内存缓存
  List<ProviderProfile> _claudeProfiles = [];
  List<ProviderProfile> _codexProfiles = [];
  List<String>? _cachedCodexModels;
  DateTime? _cachedCodexModelsAt;
  Future<List<String>>? _codexModelsFetchFuture;

  List<ProviderProfile> get claudeProfiles => _claudeProfiles;
  List<ProviderProfile> get codexProfiles => _codexProfiles;

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
    _isInitialized = true;
    notifyListeners();
  }

  /// 每次启动都读取实际配置文件，upsert 更新到数据库
  Future<void> _seedOfficialProfiles() async {
    await _syncClaudeOfficial();
    await _syncCodexOfficial();
    // 根据配置文件实际内容，校正激活状态
    await _reconcileActiveFromConfig('claude');
    await _reconcileActiveFromConfig('codex');
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
          // 如果是 custom，提取 [model_providers.custom] 中的 base_url
          if (fileModelProvider == 'custom') {
            final range = _findSectionRange(lines, 'model_providers.custom');
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
        final authPath =
            PlatformUtils.joinPath(home, '.codex', 'auth.json');
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

        // 非 custom provider → 官方配置，清空 baseUrl
        if (fileModelProvider != 'custom') {
          fileBaseUrl = null;
        }
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
  }

  /// 手动刷新：重新读取配置文件，校正 DB 激活状态
  Future<void> refreshFromConfig() async {
    await _seedOfficialProfiles();
    notifyListeners();
  }

  /// 获取指定编辑器的配置列表
  List<ProviderProfile> getProfiles(String editorType) {
    return editorType == 'claude' ? _claudeProfiles : _codexProfiles;
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
  }) async {
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
      updatedAt: Value(DateTime.now()),
    );
    await _db.updateProfile(entry);
    await _loadProfiles();

    // 如果当前 profile 处于激活状态，同步写入配置文件
    final updated = getProfiles(editorType).where((p) => p.id == id);
    if (updated.isNotEmpty && updated.first.isActive) {
      await _writeConfigFile(editorType, updated.first);
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
      } else if (editorType == 'codex') {
        await _writeCodexConfig(profile);
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
      } else if (editorType == 'codex') {
        await _clearCodexConfig();
      }
    } catch (e) {
      print('Error clearing config file: $e');
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

  /// 写入 Claude Code 配置 (~/.claude/settings.json)
  Future<void> _writeClaudeSettings(ProviderProfile profile) async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude', 'settings.json');
    final file = File(path);

    Map<String, dynamic> config = {};
    if (await file.exists()) {
      try {
        config = jsonDecode(await file.readAsString());
      } catch (_) {}
    }

    // 确保 env 对象存在
    if (config['env'] is! Map) {
      config['env'] = <String, dynamic>{};
    }
    final env = config['env'] as Map<String, dynamic>;

    // 更新供应商相关字段
    if (profile.apiToken != null && profile.apiToken!.isNotEmpty) {
      env['ANTHROPIC_AUTH_TOKEN'] = profile.apiToken;
    } else {
      env.remove('ANTHROPIC_AUTH_TOKEN');
    }

    if (profile.baseUrl != null && profile.baseUrl!.isNotEmpty) {
      env['ANTHROPIC_BASE_URL'] = profile.baseUrl;
    } else {
      env.remove('ANTHROPIC_BASE_URL');
    }

    if (profile.maxOutputTokens != null &&
        profile.maxOutputTokens!.isNotEmpty) {
      env['CLAUDE_CODE_MAX__OUTPUT_TOKENS'] = profile.maxOutputTokens;
    } else {
      env.remove('CLAUDE_CODE_MAX__OUTPUT_TOKENS');
    }

    if (profile.maxThinkingTokens != null &&
        profile.maxThinkingTokens!.isNotEmpty) {
      env['MAX_THINKING_TOKENS'] = profile.maxThinkingTokens;
    } else {
      env.remove('MAX_THINKING_TOKENS');
    }

    // model 放在顶层
    if (profile.model != null && profile.model!.isNotEmpty) {
      config['model'] = profile.model;
    } else {
      config.remove('model');
    }

    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(config));
  }

  /// 写入 Codex 配置 (~/.codex/config.toml + ~/.codex/auth.json)
  ///
  /// TOML 规则：顶级键值对必须在所有 [section] 之前，
  /// 否则会被解析为 section 的子属性。
  Future<void> _writeCodexConfig(ProviderProfile profile) async {
    final home = PlatformUtils.userHome;
    final codexDir = PlatformUtils.joinPath(home, '.codex');
    final dir = Directory(codexDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 写入 config.toml
    final tomlPath = PlatformUtils.joinPath(codexDir, 'config.toml');
    final tomlFile = File(tomlPath);
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

    // 写入 auth.json
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
      await authFile.writeAsString(
        encoder.convert({'OPENAI_API_KEY': apiKey}),
      );
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

    // 清理历史残留的非法字段
    _removeTopLevelKey(lines, 'disable_response_storage');

    if (profile == null) {
      _removeTopLevelKey(lines, 'model');
      _removeTopLevelKey(lines, 'model_reasoning_effort');
      _removeTopLevelKey(lines, 'personality');
      _removeTopLevelKey(lines, 'model_provider');
      _removeCustomProviderSection(lines);
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
      _upsertTopLevelKey(lines, 'model_provider', '"custom"');
      _upsertCustomProviderSection(lines, customBaseUrl);
    } else {
      _removeTopLevelKey(lines, 'model_provider');
      _removeCustomProviderSection(lines);
    }

    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
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

  void _upsertCustomProviderSection(List<String> lines, String baseUrl) {
    final range = _findSectionRange(lines, 'model_providers.custom');
    final body = range == null
        ? <String>[]
        : lines.sublist(range.start + 1, range.endExclusive).toList();
    _upsertSectionKey(body, 'name', '"custom"');
    _upsertSectionKey(body, 'wire_api', '"responses"');
    _upsertSectionKey(body, 'requires_openai_auth', 'true');
    _upsertSectionKey(body, 'base_url', '"$baseUrl"');

    final sectionLines = <String>['[model_providers.custom]', ...body];
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

  void _removeCustomProviderSection(List<String> lines) {
    final range = _findSectionRange(lines, 'model_providers.custom');
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
