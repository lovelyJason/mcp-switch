import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/editor_type.dart';
import '../models/mcp_profile.dart';
import 'package:uuid/uuid.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'logger_service.dart';
import 'cursor_workspace_service.dart';
import 'claude_plugin_integration_service.dart';
import '../utils/platform_utils.dart';

/// 配置服务类 (ConfigService)
///
/// 主要作用：
/// 1. 管理应用全局状态（如主题、最小化到托盘、开机自启等）。
/// 2. 管理各个编辑器（Cursor, Windsurf, Claude Code 等）的 MCP 配置文件路径和内容。
/// 3. 提供配置文件的读取、解析、保存和同步功能（支持 JSON 和 TOML 格式）。
/// 4. 维护当前选中的编辑器状态（Global Editor State），用于跨页面状态共享。
class ConfigService extends ChangeNotifier {
  // In-memory storage of profiles for each editor
  final Map<EditorType, List<McpProfile>> _profiles = {};
  final Map<EditorType, String?> _activeProfileIds = {};

  // Selected Editor (Redundant Global State)
  EditorType _selectedEditor = EditorType.cursor;
  EditorType get selectedEditor => _selectedEditor;

  // Theme
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.system,
  );

  bool _minimizeToTray = true;
  bool get minimizeToTray => _minimizeToTray;

  bool _launchAtStartup = false;
  bool get launchAtStartup => _launchAtStartup;

  bool _enableClaudePluginIntegration = false;
  bool get enableClaudePluginIntegration => _enableClaudePluginIntegration;

  bool _skipClaudeCodeOnboarding = false;
  bool get skipClaudeCodeOnboarding => _skipClaudeCodeOnboarding;

  // Custom paths for editors (configurable by user)
  final Map<EditorType, String> _editorConfigPaths = {};

  bool _isInitialized = false;

  ConfigService();

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadSettings();
    await _initStartup();
    await _loadProfiles();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadSettings({bool forceSyncFromConfigFiles = false}) async {
    final prefs = await SharedPreferences.getInstance();
    // Load custom paths
    for (var type in EditorType.values) {
      String? path = prefs.getString('path_${type.name}');
      if (path != null) {
        _editorConfigPaths[type] = path;
      } else {
        _editorConfigPaths[type] = _getDefaultPath(type);
      }

      String? activeId = prefs.getString('active_${type.name}');
      _activeProfileIds[type] = activeId;
    }

    // Load theme
    final themeIndex = prefs.getInt('theme_mode');
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      themeModeNotifier.value = ThemeMode.values[themeIndex];
    }

    _minimizeToTray = prefs.getBool('minimize_to_tray') ?? true;
    _launchAtStartup =
        prefs.getBool('launch_at_startup') ??
        false; // Actual check via package done in _initStartup
    if (forceSyncFromConfigFiles) {
      _enableClaudePluginIntegration =
          await _detectClaudePluginIntegrationFromConfig();
      await prefs.setBool(
        'enable_claude_plugin_integration',
        _enableClaudePluginIntegration,
      );
    } else if (prefs.containsKey('enable_claude_plugin_integration')) {
      _enableClaudePluginIntegration =
          prefs.getBool('enable_claude_plugin_integration') ?? false;
    } else {
      _enableClaudePluginIntegration =
          await _detectClaudePluginIntegrationFromConfig();
      await prefs.setBool(
        'enable_claude_plugin_integration',
        _enableClaudePluginIntegration,
      );
    }

    if (forceSyncFromConfigFiles) {
      _skipClaudeCodeOnboarding = await _detectClaudeOnboardingFromConfig();
      await prefs.setBool(
        'skip_claude_code_onboarding',
        _skipClaudeCodeOnboarding,
      );
    } else if (prefs.containsKey('skip_claude_code_onboarding')) {
      _skipClaudeCodeOnboarding =
          prefs.getBool('skip_claude_code_onboarding') ?? false;
    } else {
      _skipClaudeCodeOnboarding = await _detectClaudeOnboardingFromConfig();
      await prefs.setBool(
        'skip_claude_code_onboarding',
        _skipClaudeCodeOnboarding,
      );
    }

    // Load Log Level
    final logLevel = prefs.getInt('log_level') ?? 0; // Default Error
    logLevelNotifier.value = logLevel;
    LoggerService.setReleaseLogLevel(logLevel);

    // Load DeepL API Key
    _deeplApiKey = prefs.getString('deepl_api_key');

    // Load Claude API Key
    _claudeApiKey = prefs.getString('claude_api_key');

    // Load Claude API Base URL
    _claudeApiBaseUrl = prefs.getString('claude_api_base_url');

    // Load Claude Model
    _claudeModel =
        prefs.getString('claude_model') ?? 'claude-sonnet-4-20250514';

    // Load Chatbot Icon Setting
    _showChatbotIcon = prefs.getBool('show_chatbot_icon') ?? true;

    // Load Last Selected Editor
    final savedEditor = prefs.getString('selected_editor');
    if (savedEditor != null) {
      try {
        _selectedEditor = EditorType.values.firstWhere(
          (e) => e.name == savedEditor,
        );
      } catch (_) {}
    }

    // Load Windows Shell Preference
    _windowsShell = prefs.getString('windows_shell');

    // Load Terminal AI Model Preference
    _terminalAiModelId =
        prefs.getString('terminal_ai_model_id') ?? 'claude-opus-4-5-20251101';

    // Load Chat AI Model Preference
    _chatAiModelId =
        prefs.getString('chat_ai_model_id') ?? 'claude-sonnet-4-5-20250929';

    // Load Remote Claw config
    _remoteClawTelegramEnabled = prefs.getBool('rc_telegram_enabled') ?? false;
    _remoteClawTelegramBotToken =
        prefs.getString('rc_telegram_bot_token') ?? '';
    _remoteClawTelegramChatId = prefs.getString('rc_telegram_chat_id') ?? '';
    _remoteClawDingtalkEnabled = prefs.getBool('rc_dingtalk_enabled') ?? false;
    _remoteClawDingtalkWebhookUrl =
        prefs.getString('rc_dingtalk_webhook_url') ?? '';
    _remoteClawDingtalkSecret = prefs.getString('rc_dingtalk_secret') ?? '';
    _remoteClawPort = prefs.getInt('rc_port') ?? 8099;
    _remoteClawAutoStart = prefs.getBool('rc_auto_start') ?? false;
    _remoteClawCallbackHost = prefs.getString('rc_callback_host') ?? '';
    _remoteClawUseLocalCallback =
        prefs.getBool('rc_use_local_callback') ?? true;

    // Load Proxy config
    _proxyUrl = prefs.getString('proxy_url') ?? '';
    _proxyUsername = prefs.getString('proxy_username') ?? '';
    _proxyPassword = prefs.getString('proxy_password') ?? '';
  }

  /// 进入设置页时调用：从 prefs + 配置文件重新同步当前设置状态。
  Future<void> refreshSettingsForSettingsScreen() async {
    await _loadSettings(forceSyncFromConfigFiles: true);
    notifyListeners();
  }

  Future<bool> _detectClaudePluginIntegrationFromConfig() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude', 'config.json');
    final file = File(path);
    if (!await file.exists()) return false;

    try {
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      final key = decoded['primaryApiKey'];
      if (key == null) return false;
      final value = key.toString().trim();
      return value.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _detectClaudeOnboardingFromConfig() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude.json');
    final file = File(path);
    if (!await file.exists()) return false;

    try {
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return false;
      final value = decoded['hasCompletedOnboarding'];
      if (value is bool) {
        return value;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setClaudeOnboardingInConfig(bool value) async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude.json');
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    Map<String, dynamic> obj = <String, dynamic>{};
    if (await file.exists()) {
      try {
        final raw = (await file.readAsString()).trim();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            obj = decoded;
          }
        }
      } catch (_) {
        obj = <String, dynamic>{};
      }
    }

    obj['hasCompletedOnboarding'] = value;
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(obj)}\n');
  }

  String _getDefaultPath(EditorType type) {
    // 使用跨平台工具类获取用户目录
    // Windows: %USERPROFILE%, macOS/Linux: $HOME
    final home = PlatformUtils.userHome;
    switch (type) {
      case EditorType.cursor:
        return PlatformUtils.joinPath(home, '.cursor', 'mcp.json');
      case EditorType.windsurf:
        return PlatformUtils.joinPath(
          home,
          '.codeium',
          'windsurf',
          'mcp_config.json',
        );
      case EditorType.claude:
        return PlatformUtils.joinPath(home, '.claude.json');
      case EditorType.codex:
        return PlatformUtils.joinPath(home, '.codex', 'config.toml');
      case EditorType.antigravity:
        return PlatformUtils.joinPath(
          home,
          '.gemini',
          'antigravity',
          'mcp_config.json',
        );
      case EditorType.gemini:
        return PlatformUtils.joinPath(home, '.gemini', 'settings.json');
    }
  }

  Future<void> reloadProfiles() async {
    await _loadProfiles();
    notifyListeners();
  }

  Future<void> _loadProfiles() async {
    // 1. Load cached profiles first to preserve IDs and metadata (like descriptions)
    final prefs = await SharedPreferences.getInstance();
    final String? allProfilesJson = prefs.getString('mcp_profiles');

    if (allProfilesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(allProfilesJson);
        decoded.forEach((key, value) {
          final editor = EditorType.values.firstWhere(
            (e) => e.name == key,
            orElse: () => EditorType.cursor,
          );
          if (value is List) {
            _profiles[editor] = value
                .map((e) => McpProfile.fromJson(e))
                .toList();
          }
        });
      } catch (e) {
        print("Error loading profiles cache: $e");
      }
    }

    // 2. SYNC with actual config files (Source of Truth)
    for (var type in EditorType.values) {
      if (!_profiles.containsKey(type)) {
        _profiles[type] = [];
      }

      final path = getConfigPath(type);
      final file = File(path);

      // If Cursor/Gemini config file is missing, clear any cached profiles to show empty state
      if ((type == EditorType.cursor || type == EditorType.gemini) &&
          !await file.exists()) {
        _profiles[type] = [];
      }

      if (await file.exists()) {
        try {
          final text = await file.readAsString();

          if (type == EditorType.codex) {
            _profiles[type] = _parseCodexToml(text, _profiles[type] ?? []);
            // 异步补充 auth 状态（不阻塞加载）
            _enrichCodexAuthStatus(_profiles[type]!);
            continue;
          }

          if (text.trim().isEmpty) {
            _profiles[type] = [];
            continue;
          }

          if (type != EditorType.codex && text.trim().isNotEmpty) {
            final content = jsonDecode(text);

            if (type == EditorType.claude) {
              // --- CLAUDE CODE SPECIAL LOGIC (Nested Projects + Global) ---
              final List<McpProfile> syncedList = [];
              final List<McpProfile> cachedList = _profiles[type]!;
              final Map<String, McpProfile> existingMap = {
                for (var p in cachedList) p.name: p,
              };

              // 1. Global Config (Root mcpServers)
              if (content.containsKey('mcpServers') &&
                  content['mcpServers'] is Map) {
                final globalName = 'Global Configuration';
                final existingGlobal = cachedList
                    .cast<McpProfile?>()
                    .firstWhere(
                      (p) =>
                          p != null &&
                          (p.content['isGlobal'] == true ||
                              p.name == globalName),
                      orElse: () => null,
                    );

                syncedList.add(
                  McpProfile(
                    id: existingGlobal?.id ?? const Uuid().v4(),
                    name: globalName,
                    description: 'Global User Settings',
                    content: {
                      'mcpServers': content['mcpServers'],
                      'isGlobal': true,
                    },
                  ),
                );
              }

              // 2. Projects
              if (content['projects'] is Map<String, dynamic>) {
                final Map<String, dynamic> projects = content['projects'];
                projects.forEach((projectPath, projectConfig) {
                  if (projectConfig is Map<String, dynamic> &&
                      projectConfig.containsKey('mcpServers')) {
                    final mcpServers = projectConfig['mcpServers'];
                    // 读取 disabledMcpServers（项目级禁用继承的全局 MCP）
                    final disabledMcpServers =
                        projectConfig['disabledMcpServers'];

                    if (existingMap.containsKey(projectPath)) {
                      final existing = existingMap[projectPath]!;
                      syncedList.add(
                        McpProfile(
                          id: existing.id,
                          name: projectPath,
                          description: existing.description,
                          content: {
                            'mcpServers': mcpServers,
                            if (disabledMcpServers is List)
                              'disabledMcpServers': disabledMcpServers,
                          },
                        ),
                      );
                    } else {
                      syncedList.add(
                        McpProfile(
                          id: const Uuid().v4(),
                          name: projectPath, // Project Path is the Name
                          description: 'Project Config',
                          content: {
                            'mcpServers': mcpServers,
                            if (disabledMcpServers is List)
                              'disabledMcpServers': disabledMcpServers,
                          },
                        ),
                      );
                    }
                  }
                });
              }
              _profiles[type] = syncedList;
            } else {
              // --- STANDARD LOGIC (Root Impl) ---
              final List<McpProfile> syncedList = [];
              final mcpServers = content['mcpServers'];

              if (mcpServers is Map<String, dynamic>) {
                final List<McpProfile> cachedList = _profiles[type]!;
                final Map<String, McpProfile> existingMap = {
                  for (var p in cachedList) p.name: p,
                };

                mcpServers.forEach((key, value) {
                  if (existingMap.containsKey(key)) {
                    final existing = existingMap[key]!;
                    syncedList.add(
                      McpProfile(
                        id: existing.id,
                        name: key,
                        description: existing.description,
                        content: {
                          'mcpServers': {key: value},
                        },
                      ),
                    );
                  } else {
                    syncedList.add(
                      McpProfile(
                        id: const Uuid().v4(),
                        name: key,
                        description: 'Imported from config',
                        content: {
                          'mcpServers': {key: value},
                        },
                      ),
                    );
                  }
                });
              }
              _profiles[type] = syncedList;
            }
          }
        } catch (e) {
          print('Error reading/parsing config for $type: $e');
        }
      }
    }

    // 3. Persist the synchronized state
    await _persistProfiles();
  }

  Future<void> saveProfile(EditorType editor, McpProfile profile) async {
    if (_profiles[editor] == null) _profiles[editor] = [];

    final index = _profiles[editor]!.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      _profiles[editor]![index] = profile;
    } else {
      _profiles[editor]!.add(profile);
    }

    await _persistProfiles();
    await _syncCombinedConfig(editor);
    notifyListeners();
  }

  Future<void> deleteProfile(EditorType editor, String profileId) async {
    _profiles[editor]?.removeWhere((p) => p.id == profileId);
    if (_activeProfileIds[editor] == profileId) {
      _activeProfileIds[editor] = null;
    }
    await _persistProfiles();
    await _syncCombinedConfig(editor);
    notifyListeners();
  }

  Future<void> activateProfile(EditorType editor, String profileId) async {
    // In synced mode, 'active' mainly acts as a UI selection or "Edit Focus".
    // It doesn't exclusive-write to file anymore.
    final profile = _profiles[editor]?.firstWhere((p) => p.id == profileId);
    if (profile == null) return;

    _activeProfileIds[editor] = profileId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_${editor.name}', profileId);

    // We don't overwrite file with single profile here, ensuring aggregate view.
    notifyListeners();
  }

  Future<void> _writeToEditorConfig(
    EditorType editor,
    Map<String, dynamic> content,
  ) async {
    final path = _editorConfigPaths[editor];
    if (path == null) return;

    final file = File(path);
    // Don't create recursively if it doesn't exist for Claude (should exist?), but standard safe
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(content));
  }

  Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    _profiles.forEach((key, value) {
      data[key.name] = value.map((p) => p.toJson()).toList();
    });
    await prefs.setString('mcp_profiles', jsonEncode(data));
  }

  Future<void> _syncCombinedConfig(EditorType editor) async {
    final profiles = _profiles[editor] ?? [];

    if (editor == EditorType.claude) {
      // --- CLAUDE CODE SYNC (Root + Projects) ---
      final path = getConfigPath(editor);
      final file = File(path);
      Map<String, dynamic> fullConfig = {};

      if (await file.exists()) {
        try {
          fullConfig = jsonDecode(await file.readAsString());
        } catch (_) {}
      }

      // 1. Handle Global Config
      McpProfile? globalProfile;
      try {
        globalProfile = profiles.firstWhere(
          (p) => p.content['isGlobal'] == true,
        );
      } catch (_) {}

      if (globalProfile != null) {
        fullConfig['mcpServers'] = globalProfile.content['mcpServers'] ?? {};
      }

      // 2. Handle Projects
      if (!fullConfig.containsKey('projects')) {
        fullConfig['projects'] = {};
      }
      final Map<String, dynamic> projects = fullConfig['projects'];

      final activeProjectPaths = <String>{};

      for (final profile in profiles) {
        if (profile.content['isGlobal'] == true) continue;

        final projectPath = profile.name;
        activeProjectPaths.add(projectPath);

        if (!projects.containsKey(projectPath)) {
          projects[projectPath] = {};
        }
        projects[projectPath]['mcpServers'] =
            profile.content['mcpServers'] ?? {};

        // 保存 disabledMcpServers（项目级禁用继承的全局 MCP）
        final disabledMcpServers = profile.content['disabledMcpServers'];
        if (disabledMcpServers is List && disabledMcpServers.isNotEmpty) {
          projects[projectPath]['disabledMcpServers'] = disabledMcpServers;
        } else {
          // 清理空的 disabledMcpServers
          projects[projectPath].remove('disabledMcpServers');
        }
      }

      // 3. Remove mcpServers from projects that are NO LONGER in profiles
      projects.keys.toList().forEach((key) {
        if (!activeProjectPaths.contains(key)) {
          if (projects[key] is Map) {
            projects[key].remove('mcpServers');
          }
        }
      });

      await _writeToEditorConfig(editor, fullConfig);
    } else if (editor == EditorType.codex) {
      // --- CODEX TOML GENERATION WITH PRESERVATION ---
      final path = getConfigPath(editor);
      final file = File(path);

      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString('');
      }

      // Read existing to preserve non-mcp sections
      List<String> preservedLines = [];
      if (await file.exists()) {
        try {
          final lines = await file.readAsLines();
          String? currentSection;
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
              currentSection = trimmed;
            }

            // Skip mcp_servers sections
            if (currentSection != null &&
                currentSection.startsWith('[mcp_servers.')) {
              continue;
            }
            preservedLines.add(line);
          }
        } catch (_) {}
      }

      // Clean up trailing empty lines
      while (preservedLines.isNotEmpty && preservedLines.last.trim().isEmpty) {
        preservedLines.removeLast();
      }

      final newConfig = _generateCodexToml(profiles);
      final combined = '${preservedLines.join('\n')}\n\n$newConfig';
      await file.writeAsString(combined.trim() + '\n');
    } else {
      // --- STANDARD SYNC (Combined mcpServers) ---
      final Map<String, dynamic> combinedMcpServers = {};

      for (final profile in profiles) {
        final content = profile.content;
        if (content['mcpServers'] is Map) {
          combinedMcpServers.addAll(
            Map<String, dynamic>.from(content['mcpServers']),
          );
        }
      }
      final fullConfig = {'mcpServers': combinedMcpServers};
      await _writeToEditorConfig(editor, fullConfig);
    }
  }

  // Settings Updates
  Future<void> setConfigPath(EditorType type, String path) async {
    _editorConfigPaths[type] = path;
    final prefs = await SharedPreferences.getInstance();
    if (path.isEmpty) {
      await prefs.remove('path_${type.name}');
      _editorConfigPaths[type] = _getDefaultPath(type);
    } else {
      await prefs.setString('path_${type.name}', path);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  // Log Level: 0=Error, 1=Warning, 2=Info, 3=Verbose
  final ValueNotifier<int> logLevelNotifier = ValueNotifier(0); // Default Error

  Future<void> setLogLevel(int level) async {
    logLevelNotifier.value = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('log_level', level);
    LoggerService.setReleaseLogLevel(level);
    notifyListeners();
  }

  // DeepL API Key (可选翻译引擎)
  String? _deeplApiKey;
  String? get deeplApiKey => _deeplApiKey;

  Future<void> setDeepLApiKey(String? key) async {
    _deeplApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove('deepl_api_key');
    } else {
      await prefs.setString('deepl_api_key', key);
    }
    notifyListeners();
  }

  // Claude API Key (AI Chatbot)
  String? _claudeApiKey;
  String? get claudeApiKey => _claudeApiKey;

  Future<void> setClaudeApiKey(String? key) async {
    _claudeApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove('claude_api_key');
    } else {
      await prefs.setString('claude_api_key', key);
    }
    notifyListeners();
  }

  // Claude API Base URL (第三方代理)
  String? _claudeApiBaseUrl;
  String? get claudeApiBaseUrl => _claudeApiBaseUrl;

  Future<void> setClaudeApiBaseUrl(String? url) async {
    _claudeApiBaseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove('claude_api_base_url');
    } else {
      await prefs.setString('claude_api_base_url', url);
    }
    notifyListeners();
  }

  // Claude Model 选择
  // 注意：模型名称需要与 Anthropic API 实际支持的名称一致
  // 参考 Claude Code CLI 的 /model 命令
  static const List<String> availableModels = [
    'claude-opus-4-5-20251101', // Opus 4.5 (Most capable)
    'claude-sonnet-4-5-20250929', // Sonnet 4.5 (Recommended)
    'claude-sonnet-4-20250514', // Sonnet 4
    'claude-haiku-4-5-20251001', // Haiku 4.5 (Fastest)
    'claude-3-5-sonnet-20241022', // Claude 3.5 Sonnet
    'claude-3-5-haiku-20241022', // Claude 3.5 Haiku
    'claude-3-opus-20240229', // Claude 3 Opus
  ];

  String _claudeModel = 'claude-sonnet-4-20250514';
  String get claudeModel => _claudeModel;

  Future<void> setClaudeModel(String model) async {
    _claudeModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('claude_model', model);
    notifyListeners();
  }

  // AI Chatbot 悬浮图标显示
  bool _showChatbotIcon = true;
  bool get showChatbotIcon => _showChatbotIcon;

  Future<void> setShowChatbotIcon(bool show) async {
    _showChatbotIcon = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_chatbot_icon', show);
    notifyListeners();
  }

  // Windows Shell 偏好 (powershell | cmd)
  // null 表示首次启动，需要弹窗选择
  String? _windowsShell;
  String? get windowsShell => _windowsShell;
  bool get hasWindowsShellPreference => _windowsShell != null;

  Future<void> setWindowsShell(String shell) async {
    _windowsShell = shell;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('windows_shell', shell);
    notifyListeners();
  }

  // 终端 AI 输入框选中的模型 ID
  String _terminalAiModelId = 'claude-opus-4-5-20251101'; // 默认 Opus 4.5
  String get terminalAiModelId => _terminalAiModelId;

  Future<void> setTerminalAiModelId(String modelId) async {
    _terminalAiModelId = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('terminal_ai_model_id', modelId);
    notifyListeners();
  }

  // AI 助手聊天选中的模型 ID
  String _chatAiModelId = 'claude-sonnet-4-5-20250929'; // 默认 Sonnet 4.5
  String get chatAiModelId => _chatAiModelId;

  Future<void> setChatAiModelId(String modelId) async {
    _chatAiModelId = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_ai_model_id', modelId);
    notifyListeners();
  }

  // ──────────────────────────────────────────
  // Remote Claw 配置
  // ──────────────────────────────────────────

  bool _remoteClawTelegramEnabled = false;
  String _remoteClawTelegramBotToken = '';
  String _remoteClawTelegramChatId = '';
  bool _remoteClawDingtalkEnabled = false;
  String _remoteClawDingtalkWebhookUrl = '';
  String _remoteClawDingtalkSecret = '';
  int _remoteClawPort = 8099;
  bool _remoteClawAutoStart = false;
  String _remoteClawCallbackHost = '';
  bool _remoteClawUseLocalCallback = true;

  bool get remoteClawTelegramEnabled => _remoteClawTelegramEnabled;
  String get remoteClawTelegramBotToken => _remoteClawTelegramBotToken;
  String get remoteClawTelegramChatId => _remoteClawTelegramChatId;
  bool get remoteClawDingtalkEnabled => _remoteClawDingtalkEnabled;
  String get remoteClawDingtalkWebhookUrl => _remoteClawDingtalkWebhookUrl;
  String get remoteClawDingtalkSecret => _remoteClawDingtalkSecret;
  int get remoteClawPort => _remoteClawPort;
  bool get remoteClawAutoStart => _remoteClawAutoStart;
  String get remoteClawCallbackHost => _remoteClawCallbackHost;
  bool get remoteClawUseLocalCallback => _remoteClawUseLocalCallback;

  Future<void> saveRemoteClawConfig({
    required bool telegramEnabled,
    required String telegramBotToken,
    required String telegramChatId,
    required bool dingtalkEnabled,
    required String dingtalkWebhookUrl,
    required String dingtalkSecret,
    int port = 8099,
    bool? autoStart,
  }) async {
    _remoteClawTelegramEnabled = telegramEnabled;
    _remoteClawTelegramBotToken = telegramBotToken;
    _remoteClawTelegramChatId = telegramChatId;
    _remoteClawDingtalkEnabled = dingtalkEnabled;
    _remoteClawDingtalkWebhookUrl = dingtalkWebhookUrl;
    _remoteClawDingtalkSecret = dingtalkSecret;
    _remoteClawPort = port;
    if (autoStart != null) _remoteClawAutoStart = autoStart;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rc_telegram_enabled', telegramEnabled);
    await prefs.setString('rc_telegram_bot_token', telegramBotToken);
    await prefs.setString('rc_telegram_chat_id', telegramChatId);
    await prefs.setBool('rc_dingtalk_enabled', dingtalkEnabled);
    await prefs.setString('rc_dingtalk_webhook_url', dingtalkWebhookUrl);
    await prefs.setString('rc_dingtalk_secret', dingtalkSecret);
    await prefs.setInt('rc_port', port);
    if (autoStart != null) await prefs.setBool('rc_auto_start', autoStart);
    notifyListeners();
  }

  Future<void> saveRemoteClawCallbackHost(String host) async {
    _remoteClawCallbackHost = host;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rc_callback_host', host);
    notifyListeners();
  }

  Future<void> saveRemoteClawServerConfig({
    required int port,
    required String callbackHost,
    bool? useLocalCallback,
  }) async {
    _remoteClawPort = port;
    _remoteClawCallbackHost = callbackHost;
    if (useLocalCallback != null) {
      _remoteClawUseLocalCallback = useLocalCallback;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rc_port', port);
    await prefs.setString('rc_callback_host', callbackHost);
    if (useLocalCallback != null) {
      await prefs.setBool('rc_use_local_callback', useLocalCallback);
    }
    notifyListeners();
  }

  Future<void> saveRemoteClawAutoStart(bool autoStart) async {
    _remoteClawAutoStart = autoStart;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rc_auto_start', autoStart);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Proxy 出站代理配置
  // ═══════════════════════════════════════════════════════════════════════════

  String _proxyUrl = '';
  String _proxyUsername = '';
  String _proxyPassword = '';

  String get proxyUrl => _proxyUrl;
  String get proxyUsername => _proxyUsername;
  String get proxyPassword => _proxyPassword;
  bool get hasProxy => _proxyUrl.isNotEmpty;

  Future<void> saveProxyConfig({
    required String url,
    String username = '',
    String password = '',
  }) async {
    _proxyUrl = url;
    _proxyUsername = username;
    _proxyPassword = password;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('proxy_url', url);
    await prefs.setString('proxy_username', username);
    await prefs.setString('proxy_password', password);
    notifyListeners();
  }

  Future<void> clearProxyConfig() async {
    _proxyUrl = '';
    _proxyUsername = '';
    _proxyPassword = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('proxy_url');
    await prefs.remove('proxy_username');
    await prefs.remove('proxy_password');
    notifyListeners();
  }

  // Getters
  List<McpProfile> getProfiles(EditorType editor) => _profiles[editor] ?? [];
  String? getActiveProfileId(EditorType editor) => _activeProfileIds[editor];
  String getConfigPath(EditorType editor) =>
      _editorConfigPaths[editor] ?? _getDefaultPath(editor);

  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('minimize_to_tray', value);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool value) async {
    _launchAtStartup = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('launch_at_startup', value);

    try {
      if (value) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
    } catch (e) {
      // 开发模式下原生插件可能未加载，忽略错误
      LoggerService.error('Failed to set launch at startup: $e');
    }
    notifyListeners();
  }

  Future<void> setEnableClaudePluginIntegration(bool value) async {
    _enableClaudePluginIntegration = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enable_claude_plugin_integration', value);

    try {
      if (value) {
        await ClaudePluginIntegrationService.writeManagedConfig();
      } else {
        await ClaudePluginIntegrationService.clearPrimaryApiKey();
      }
    } catch (e) {
      LoggerService.error('Failed to sync Claude plugin integration', e);
    }

    notifyListeners();
  }

  Future<void> setSkipClaudeCodeOnboarding(bool value) async {
    _skipClaudeCodeOnboarding = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('skip_claude_code_onboarding', value);

    try {
      await _setClaudeOnboardingInConfig(value);
    } catch (e) {
      LoggerService.error('Failed to set Claude onboarding config', e);
    }

    notifyListeners();
  }

  Future<void> _initStartup() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      LaunchAtStartup.instance.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );
      _launchAtStartup = await LaunchAtStartup.instance.isEnabled();
    } catch (e) {
      print('Error initializing startup config: $e');
      _launchAtStartup = false;
    }
  }

  Future<void> setEditor(EditorType type) async {
    if (_selectedEditor == type) return;
    _selectedEditor = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_editor', type.name);
    notifyListeners();
  }

  Future<void> toggleServerStatus(EditorType editor, String profileId) async {
    final profiles = _profiles[editor];
    if (profiles == null) return;
    final index = profiles.indexWhere((p) => p.id == profileId);
    if (index == -1) return;

    final profile = profiles[index];
    final mcpServers = profile.content['mcpServers'];
    if (mcpServers is! Map) return;

    final name = profile.name;
    if (mcpServers.containsKey(name)) {
      final serverConfig = mcpServers[name];
      if (serverConfig is Map) {
        bool isEnabled = true;
        if (serverConfig.containsKey('disabled')) {
          isEnabled = serverConfig['disabled'] != true;
        } else if (serverConfig.containsKey('enabled')) {
          isEnabled = serverConfig['enabled'] == true;
        }

        final nowDisabled = isEnabled; // toggle: was enabled -> now disabled

        serverConfig['disabled'] = nowDisabled;
        serverConfig.remove('enabled');

        await saveProfile(editor, profile);

        // Cursor: 同步写入所有 workspace 的 SQLite 数据库
        if (editor == EditorType.cursor) {
          final cursorWs = CursorWorkspaceService.instance;
          if (cursorWs.shouldUseSqlite) {
            await cursorWs.toggleServerInAllWorkspaces(name, nowDisabled);
          }
        }
      }
    }
  }
  // --- HELPERS for Codex CLI / TOML ---

  /// 异步执行 `codex mcp list`，从输出中提取 auth 状态并合并到已有 profiles
  Future<void> _enrichCodexAuthStatus(List<McpProfile> profiles) async {
    try {
      final result = await PlatformUtils.runCommand('codex mcp list')
          .timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) return;
      final output = (result.stdout as String).trim();
      if (output.isEmpty) return;

      final authMap = _parseCodexMcpListAuth(output);
      if (authMap.isEmpty) return;

      bool changed = false;
      for (final profile in profiles) {
        final auth = authMap[profile.name];
        if (auth == null || auth.isEmpty) continue;
        final mcpServers = profile.content['mcpServers'];
        if (mcpServers is Map && mcpServers.containsKey(profile.name)) {
          final server = mcpServers[profile.name];
          if (server is Map<String, dynamic>) {
            server['auth'] = auth;
            changed = true;
          }
        }
      }
      if (changed) notifyListeners();
    } catch (_) {
      // CLI 不可用时静默忽略
    }
  }

  /// 从 `codex mcp list` 输出提取 name -> auth 映射
  Map<String, String> _parseCodexMcpListAuth(String output) {
    final authMap = <String, String>{};
    final lines = output.split('\n');

    int i = 0;
    while (i < lines.length) {
      final headerLine = lines[i];
      if (headerLine.trim().isEmpty) { i++; continue; }

      final isStdioTable = headerLine.trimLeft().startsWith('Name') && headerLine.contains('Command');
      final isHttpTable = headerLine.trimLeft().startsWith('Name') && headerLine.contains('Url');
      if (!isStdioTable && !isHttpTable) { i++; continue; }

      final colStarts = _detectColumnStarts(headerLine);
      final authIdx = isStdioTable ? 6 : 4;
      i++;

      while (i < lines.length) {
        final line = lines[i];
        if (line.trim().isEmpty) { i++; break; }
        final cols = _splitByColumns(line, colStarts);
        if (cols.isEmpty || cols[0].isEmpty) { i++; continue; }
        final name = cols[0];
        final auth = authIdx < cols.length ? cols[authIdx] : '';
        if (auth.isNotEmpty) authMap[name] = auth;
        i++;
      }
    }
    return authMap;
  }

  /// 从 header 行检测各列的起始字符位置
  List<int> _detectColumnStarts(String headerLine) {
    final starts = <int>[0];
    bool inSpace = false;
    for (var i = 0; i < headerLine.length; i++) {
      if (headerLine[i] == ' ') {
        inSpace = true;
      } else if (inSpace) {
        // 连续空格后遇到非空格 = 新列开始
        // 但至少要有 2 个空格才算列分隔
        if (i >= 2 && headerLine[i - 1] == ' ' && headerLine[i - 2] == ' ') {
          starts.add(i);
        }
        inSpace = false;
      }
    }
    return starts;
  }

  /// 按列位置拆分行内容
  List<String> _splitByColumns(String line, List<int> colStarts) {
    final result = <String>[];
    for (var c = 0; c < colStarts.length; c++) {
      final start = colStarts[c];
      final end = (c + 1 < colStarts.length) ? colStarts[c + 1] : line.length;
      if (start >= line.length) {
        result.add('');
      } else {
        result.add(line.substring(start, end.clamp(start, line.length)).trim());
      }
    }
    return result;
  }

  List<McpProfile> _parseCodexToml(
    String content,
    List<McpProfile> cachedProfiles,
  ) {
    final List<McpProfile> profiles = [];
    final lines = content.split('\n');
    String? currentServerName;
    String? currentCommand;
    String? currentUrl;
    List<String> currentArgs = [];
    Map<String, String> currentHttpHeaders = {};
    bool inArgs = false;
    bool currentDisabled = false;

    // Map for ID preservation
    final Map<String, String> nameToId = {
      for (var p in cachedProfiles) p.name: p.id,
    };

    void saveCurrent() {
      if (currentServerName != null) {
        final serverConfig = <String, dynamic>{};
        if (currentUrl != null && currentUrl!.isNotEmpty) {
          serverConfig['url'] = currentUrl!;
          if (currentHttpHeaders.isNotEmpty) {
            serverConfig['http_headers'] = Map<String, String>.from(
              currentHttpHeaders,
            );
          }
        } else {
          serverConfig['command'] = currentCommand ?? '';
          serverConfig['args'] = currentArgs;
        }
        if (currentDisabled) {
          serverConfig['disabled'] = true;
        }
        profiles.add(
          McpProfile(
            id: nameToId[currentServerName] ?? const Uuid().v4(),
            name: currentServerName!,
            description: 'Codex Server configuration',
            content: {
              'mcpServers': {currentServerName: serverConfig},
            },
          ),
        );
      }
      currentServerName = null;
      currentCommand = null;
      currentUrl = null;
      currentArgs = [];
      currentHttpHeaders = {};
      inArgs = false;
      currentDisabled = false;
    }

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('[mcp_servers.') && line.endsWith(']')) {
        saveCurrent();
        currentServerName = line.substring(13, line.length - 1).trim();
        continue;
      }

      if (line.startsWith('enabled')) {
        final match = RegExp(r'enabled\s*=\s*(\w+)').firstMatch(line);
        if (match != null && match.group(1) == 'false') {
          currentDisabled = true;
        }
        continue;
      }

      if (line.startsWith('command')) {
        final match = RegExp(r'command\s*=\s*"(.*)"').firstMatch(line);
        if (match != null) currentCommand = match.group(1);
        continue;
      }

      if (line.startsWith('url')) {
        final match = RegExp(r'url\s*=\s*"(.*)"').firstMatch(line);
        if (match != null) currentUrl = match.group(1);
        continue;
      }

      if (line.startsWith('http_headers')) {
        final match = RegExp(r'http_headers\s*=\s*\{(.*)\}').firstMatch(line);
        if (match != null) {
          currentHttpHeaders = _parseCodexInlineTable(match.group(1)!);
        }
        continue;
      }

      if (line.startsWith('args')) {
        if (line.contains('[')) {
          // check for inline empty or inline content
          final inlineMatch = RegExp(r'\[(.*)\]').firstMatch(line);
          if (inlineMatch != null && !line.endsWith('[')) {
            // inline
            final raw = inlineMatch.group(1)!;
            if (raw.trim().isNotEmpty) {
              currentArgs = raw
                  .split(',')
                  .map((e) => e.trim().replaceAll('"', ''))
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          } else {
            inArgs = true;
          }
        }
        continue;
      }

      if (inArgs) {
        if (line.trim() == ']') {
          inArgs = false;
          continue;
        }
        final match = RegExp(r'"(.*)"').firstMatch(line);
        if (match != null) {
          currentArgs.add(match.group(1)!);
        }
      }
    }
    saveCurrent();
    return profiles;
  }

  String _generateCodexToml(List<McpProfile> profiles) {
    final buffer = StringBuffer();
    for (var profile in profiles) {
      final content = profile.content;
      if (content['mcpServers'] is! Map) continue;
      final servers = Map<String, dynamic>.from(content['mcpServers'] as Map);

      for (var entry in servers.entries) {
        final name = entry.key;
        final config = entry.value;
        if (config is! Map) continue;

        // Quote name if it contains spaces or non-alphanumeric chars
        final safeName = name.contains(RegExp(r'[^a-zA-Z0-9_\-]'))
            ? '"$name"'
            : name;
        buffer.writeln('[mcp_servers.$safeName]');

        if (config['disabled'] == true) {
          buffer.writeln('enabled = false');
        }

        final url = config['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          buffer.writeln('url = "${_escapeTomlString(url)}"');

          final headers = _stringMapFrom(config['http_headers']);
          if (headers.isNotEmpty) {
            final headerStr = headers.entries
                .map(
                  (entry) =>
                      '"${_escapeTomlString(entry.key)}" = "${_escapeTomlString(entry.value)}"',
                )
                .join(', ');
            buffer.writeln('http_headers = { $headerStr }');
          }
        } else {
          buffer.writeln(
            'command = "${_escapeTomlString(config['command']?.toString() ?? '')}"',
          );
          final args = config['args'];
          if (args is List && args.isNotEmpty) {
            buffer.writeln('args = [');
            for (var i = 0; i < args.length; i++) {
              final arg = args[i];
              final suffix = (i == args.length - 1) ? '' : ',';
              buffer.writeln('  "${_escapeTomlString(arg.toString())}"$suffix');
            }
            buffer.writeln(']');
          } else {
            buffer.writeln('args = []');
          }
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  Map<String, String> _parseCodexInlineTable(String raw) {
    final result = <String, String>{};
    final pairRegex = RegExp(r'"([^"]+)"\s*=\s*"([^"]*)"');
    for (final match in pairRegex.allMatches(raw)) {
      result[match.group(1)!] = match.group(2)!;
    }
    return result;
  }

  Map<String, String> _stringMapFrom(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue.toString()),
      );
    }
    return {};
  }

  String _escapeTomlString(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
