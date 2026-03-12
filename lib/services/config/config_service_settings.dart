part of 'config_service.dart';

/// App 偏好设置 Mixin
///
/// 包含主题、托盘、自启动、API Key、模型选择、
/// Remote Claw、Proxy 等所有用户偏好设置的字段与方法。
mixin _SettingsMixin on ChangeNotifier {
  // ── Theme ──────────────────────────────────────────────────────────
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

  // ── Log Level ──────────────────────────────────────────────────────
  final ValueNotifier<int> logLevelNotifier = ValueNotifier(0);

  // ── API Keys & Model ───────────────────────────────────────────────
  String? _deeplApiKey;
  String? get deeplApiKey => _deeplApiKey;

  String? _claudeApiKey;
  String? get claudeApiKey => _claudeApiKey;

  String? _claudeApiBaseUrl;
  String? get claudeApiBaseUrl => _claudeApiBaseUrl;

  String _claudeModel = 'claude-sonnet-4-20250514';
  String get claudeModel => _claudeModel;

  bool _showChatbotIcon = true;
  bool get showChatbotIcon => _showChatbotIcon;

  String? _windowsShell;
  String? get windowsShell => _windowsShell;
  bool get hasWindowsShellPreference => _windowsShell != null;

  String _terminalAiModelId = 'claude-opus-4-5-20251101';
  String get terminalAiModelId => _terminalAiModelId;

  String _chatAiModelId = 'claude-sonnet-4-5-20250929';
  String get chatAiModelId => _chatAiModelId;

  // ── Remote Claw ────────────────────────────────────────────────────
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

  // ── Proxy ──────────────────────────────────────────────────────────
  String _proxyUrl = '';
  String _proxyUsername = '';
  String _proxyPassword = '';

  String get proxyUrl => _proxyUrl;
  String get proxyUsername => _proxyUsername;
  String get proxyPassword => _proxyPassword;
  bool get hasProxy => _proxyUrl.isNotEmpty;

  // ═══════════════════════════════════════════════════════════════════
  // 加载 / 刷新
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _loadAppSettings({
    bool forceSyncFromConfigFiles = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final themeIndex = prefs.getInt('theme_mode');
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      themeModeNotifier.value = ThemeMode.values[themeIndex];
    }

    _minimizeToTray = prefs.getBool('minimize_to_tray') ?? true;
    _launchAtStartup = prefs.getBool('launch_at_startup') ?? false;

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

    final logLevel = prefs.getInt('log_level') ?? 0;
    logLevelNotifier.value = logLevel;
    LoggerService.setReleaseLogLevel(logLevel);

    _deeplApiKey = prefs.getString('deepl_api_key');
    _claudeApiKey = prefs.getString('claude_api_key');
    _claudeApiBaseUrl = prefs.getString('claude_api_base_url');
    _claudeModel =
        prefs.getString('claude_model') ?? 'claude-sonnet-4-20250514';
    _showChatbotIcon = prefs.getBool('show_chatbot_icon') ?? true;
    _windowsShell = prefs.getString('windows_shell');
    _terminalAiModelId =
        prefs.getString('terminal_ai_model_id') ?? 'claude-opus-4-5-20251101';
    _chatAiModelId =
        prefs.getString('chat_ai_model_id') ?? 'claude-sonnet-4-5-20250929';

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

    _proxyUrl = prefs.getString('proxy_url') ?? '';
    _proxyUsername = prefs.getString('proxy_username') ?? '';
    _proxyPassword = prefs.getString('proxy_password') ?? '';
  }

  Future<void> refreshSettingsForSettingsScreen() async {
    final self = this as ConfigService;
    await self._loadCoreState();
    await _loadAppSettings(forceSyncFromConfigFiles: true);
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

  // ═══════════════════════════════════════════════════════════════════
  // Setter 方法
  // ═══════════════════════════════════════════════════════════════════

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> setLogLevel(int level) async {
    logLevelNotifier.value = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('log_level', level);
    LoggerService.setReleaseLogLevel(level);
    notifyListeners();
  }

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

  Future<void> setClaudeModel(String model) async {
    _claudeModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('claude_model', model);
    notifyListeners();
  }

  Future<void> setShowChatbotIcon(bool show) async {
    _showChatbotIcon = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_chatbot_icon', show);
    notifyListeners();
  }

  Future<void> setWindowsShell(String shell) async {
    _windowsShell = shell;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('windows_shell', shell);
    notifyListeners();
  }

  Future<void> setTerminalAiModelId(String modelId) async {
    _terminalAiModelId = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('terminal_ai_model_id', modelId);
    notifyListeners();
  }

  Future<void> setChatAiModelId(String modelId) async {
    _chatAiModelId = modelId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_ai_model_id', modelId);
    notifyListeners();
  }

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

  // ── Remote Claw ────────────────────────────────────────────────────

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

  // ── Proxy ──────────────────────────────────────────────────────────

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

  // ═══════════════════════════════════════════════════════════════════
  // 配置文件检测 helpers
  // ═══════════════════════════════════════════════════════════════════

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
      return key.toString().trim().isNotEmpty;
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
      if (value is bool) return value;
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
}
