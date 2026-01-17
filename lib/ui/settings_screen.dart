import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/version.dart';
import '../../models/editor_type.dart';
import '../../services/config_service.dart';
import '../../services/ai_chat_service.dart';
import '../l10n/s.dart';
import 'components/styled_popup_menu.dart';
import 'components/styled_dropdown.dart';
import 'components/custom_toast.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<EditorType, TextEditingController> _pathControllers = {};
  final Map<String, bool> _installedApps = {}; // Cache for installed apps

  // Mock Settings State for UI Demo

  int _selectedThemeIndex = 2; // 2: System
  bool _launchAtStartup = false;
  bool _minimizeToTray = true;
  int _logLevel = 2; // Info by default

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPaths();
    _checkInstalledApps();
  }

  Future<void> _checkInstalledApps() async {
    // Basic detection for macOS apps
    final apps = {
      'vscode': '/Applications/Visual Studio Code.app',
      'cursor': '/Applications/Cursor.app',
      'windsurf': '/Applications/Windsurf.app',
    };

    for (final entry in apps.entries) {
      final exists = await Directory(entry.value).exists();
      _installedApps[entry.key] = exists;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadPaths() async {
    final configService = Provider.of<ConfigService>(context, listen: false);

    // Theme mapping
    int themeIndex = 2; // System default
    final mode = configService.themeModeNotifier.value;
    if (mode == ThemeMode.light) {
      themeIndex = 0;
    } else if (mode == ThemeMode.dark) {
      themeIndex = 1;
    }

    setState(() {
      _selectedThemeIndex = themeIndex;
      _launchAtStartup = configService.launchAtStartup;
      _minimizeToTray = configService.minimizeToTray;
      _logLevel = configService.logLevelNotifier.value;
      for (var type in EditorType.values) {
        _pathControllers[type] = TextEditingController(
          text: configService.getConfigPath(type),
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 从 ~/.claude/settings.json 读取配置
  Future<void> _loadFromClaudeSettings(
    TextEditingController apiKeyController,
    TextEditingController baseUrlController,
    ConfigService configService,
    AiChatService aiService,
  ) async {
    try {
      final home = Platform.environment['HOME'];
      final settingsFile = File('$home/.claude/settings.json');

      if (!await settingsFile.exists()) {
        if (mounted) {
          Toast.show(
            context,
            message: S.get('claude_settings_not_found'),
            type: ToastType.warning,
          );
        }
        return;
      }

      final content = await settingsFile.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      final env = data['env'] as Map<String, dynamic>?;

      if (env == null) {
        if (mounted) {
          Toast.show(
            context,
            message: S.get('claude_settings_no_env'),
            type: ToastType.warning,
          );
        }
        return;
      }

      // 读取 API Token 和 Base URL
      final authToken = env['ANTHROPIC_AUTH_TOKEN'] as String?;
      final baseUrl = env['ANTHROPIC_BASE_URL'] as String?;

      bool hasChanges = false;

      if (authToken != null && authToken.isNotEmpty) {
        apiKeyController.text = authToken;
        await configService.setClaudeApiKey(authToken);
        hasChanges = true;
      }

      if (baseUrl != null && baseUrl.isNotEmpty) {
        baseUrlController.text = baseUrl;
        await configService.setClaudeApiBaseUrl(baseUrl);
        hasChanges = true;
      }

      if (hasChanges) {
        await aiService.updateApiConfig(
          configService.claudeApiKey,
          baseUrl: configService.claudeApiBaseUrl,
        );
        if (mounted) {
          Toast.show(
            context,
            message: S.get('claude_settings_loaded'),
            type: ToastType.success,
          );
        }
      } else {
        if (mounted) {
          Toast.show(
            context,
            message: S.get('claude_settings_empty'),
            type: ToastType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('claude_settings_error')}: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/lovelyJason/mcp-switch/releases/latest',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String;
        // GitHub release 'assets' array
        final assets = data['assets'] as List;
        // Find zip asset for macOS
        String? downloadUrl;
        for (var asset in assets) {
          final name = asset['name'].toString().toLowerCase();
          if (name.endsWith('.zip') && name.contains('macos')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        final releaseUrl = data['html_url'] as String;
        final body = data['body'] as String;

        final packageInfo = await PackageInfo.fromPlatform();
        String normalize(String v) => v.replaceAll('v', '').split('+')[0];
        final current = normalize(packageInfo.version);
        final latest = normalize(latestVersion);

        if (latest != current) {
          if (mounted) {
            // If we found a zip, we can offer auto-update
            if (downloadUrl != null) {
              _showUpdateDialog(latestVersion, body, downloadUrl, isAuto: true);
            } else {
              // Fallback to browser
              _showUpdateDialog(latestVersion, body, releaseUrl, isAuto: false);
            }
          }
        } else {
          if (mounted) {
            Toast.show(
              context,
              message: S.get('current_latest'),
              type: ToastType.success,
            );
          }
        }
      } else {
        throw Exception('Failed to fetch releases');
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, message: 'Check failed: $e', type: ToastType.error);
      }
    }
  }

  void _showUpdateDialog(
    String version,
    String notes,
    String url, {
    required bool isAuto,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          S.get('new_version_available').replaceAll('{version}', version),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(notes, style: const TextStyle(fontSize: 12))],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.get('later')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (isAuto) {
                _startAutoUpdate(url);
              } else {
                launchUrl(Uri.parse(url));
              }
            },
            child: Text(isAuto ? S.get('install_restart') : 'Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _startAutoUpdate(String zipUrl) async {
    // Show progress (simplified for now as indefinite)
    Toast.show(
      context,
      message: S.get('downloading_update'),
      type: ToastType.info,
    );

    try {
      // 1. Download
      final response = await http.get(Uri.parse(zipUrl));
      if (response.statusCode != 200) {
        throw Exception('Download failed code ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/update.zip');
      await zipFile.writeAsBytes(response.bodyBytes);

      // 2. Unzip
      final extractDir = Directory('${tempDir.path}/update_extract');
      if (await extractDir.exists()) await extractDir.delete(recursive: true);
      await extractDir.create();

      final result = await Process.run('unzip', [
        '-o',
        zipFile.path,
        '-d',
        extractDir.path,
      ]);
      if (result.exitCode != 0) throw Exception('Unzip failed');

      // 3. Find .app
      final appName = 'MCP Switch.app';
      final newAppPath = '${extractDir.path}/$appName';
      if (!await Directory(newAppPath).exists()) {
        throw Exception('App bundle not found in update');
      }

      // 4. Create Swap Script
      // Get current executable path and deduce .app path
      // Platform.resolvedExecutable -> .../MCP Switch.app/Contents/MacOS/MCP Switch
      final currentExe = Platform.resolvedExecutable;
      // We assume standard structure: Remove last 3 segments to get .app
      // But safer to just find the .app extension
      String currentAppPath = currentExe;
      while (currentAppPath.isNotEmpty && !currentAppPath.endsWith('.app')) {
        currentAppPath = Directory(currentAppPath).parent.path;
      }

      if (currentAppPath.isEmpty || !currentAppPath.endsWith('.app')) {
        // Fallback if we can't determine current path (e.g. running from build)
        throw Exception('Could not determine current app path');
      }

      final scriptFile = File('${tempDir.path}/update_script.sh');
      // Script logic:
      // 1. Wait a bit
      // 2. Remove old app (rm -rf)
      // 3. Move new app to old location (mv)
      // 4. Open new app (open)
      // Using 'nohup' or just simpler detached process usually works if app exits immediately.
      await scriptFile.writeAsString('''
#!/bin/bash
sleep 2
rm -rf "$currentAppPath"
mv "$newAppPath" "$currentAppPath"
open "$currentAppPath"
''');

      // 5. Run Script & Exit
      await Process.run('chmod', ['+x', scriptFile.path]);

      // We must launch detached so it survives our exit
      await Process.start('sh', [
        scriptFile.path,
      ], mode: ProcessStartMode.detached);

      // 6. Quit App
      exit(0);
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get("update_failed")}: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _savePath(EditorType type, String value) async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    await configService.setConfigPath(type, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),
            const SizedBox(height: 16),
            _buildTabBar(),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics:
                    const NeverScrollableScrollPhysics(), // Disable swipe to match desktop feel
                children: [
                  _buildGeneralTab(),
                  _buildAiTab(),
                  _buildAdvancedTab(),
                  _buildAboutTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 16, right: 16, bottom: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: '返回',
            ),
          ),
          const SizedBox(width: 16),
          Text(
            S.get('settings'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFF767680).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF636366) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: isDark ? Colors.white : Colors.black,
        unselectedLabelColor: isDark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        padding: const EdgeInsets.all(2),
        splashFactory: NoSplash.splashFactory,
        overlayColor: MaterialStateProperty.resolveWith<Color?>(
          (states) => Colors.transparent,
        ),
        tabs: [
          Tab(text: S.get('general')),
          Tab(text: S.get('ai_settings')),
          Tab(text: S.get('advanced')),
          Tab(text: S.get('about')),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle(S.get('interface_language')),
        Text(
          S.get('interface_language_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildLanguageOption('中文', const Locale('zh')),
            const SizedBox(width: 16),
            _buildLanguageOption('English', const Locale('en')),
          ],
        ),

        const SizedBox(height: 32),

        _buildSectionTitle(S.get('appearance_theme')),
        Text(
          S.get('appearance_theme_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildSegmentedControl(
          [
            '☀ ${S.get('theme_light')}',
            '☾ ${S.get('theme_dark')}',
            '🖥 ${S.get('theme_system')}',
          ],
          _selectedThemeIndex,
          (index) {
            setState(() => _selectedThemeIndex = index);
            final configService = Provider.of<ConfigService>(
              context,
              listen: false,
            );
            ThemeMode mode = ThemeMode.system;
            if (index == 0) {
              mode = ThemeMode.light;
            } else if (index == 1) {
              mode = ThemeMode.dark;
            }
            configService.setThemeMode(mode);
          },
        ),

        const SizedBox(height: 32),

        _buildSectionTitle(S.get('window_behavior')),
        Text(
          S.get('window_behavior_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        _buildSwitchTile(
          S.get('launch_at_startup'),
          S.isEn
              ? 'Automatically start MCP Switch at login'
              : '随系统启动自动运行 MCP Switch',
          _launchAtStartup,
          (v) {
            setState(() => _launchAtStartup = v);
            Provider.of<ConfigService>(
              context,
              listen: false,
            ).setLaunchAtStartup(v);
          },
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          S.get('minimize_to_tray'),
          S.get('minimize_to_tray_desc'),
          _minimizeToTray,
          (v) {
            setState(() => _minimizeToTray = v);
            Provider.of<ConfigService>(
              context,
              listen: false,
            ).setMinimizeToTray(v);
          },
        ),
        
        _buildDropdownTile(
          S.get('log_level'),
          S.get('log_level_desc'),
          _logLevel > 1
              ? 0
              : _logLevel, // Safety clamp: Invalid levels fallback to Error (0)
          {
            0: S.get('log_error'),
            1: S.get('log_warning'),
            // Removed Info and Verbose as per request
          },
          (int newValue) {
            setState(() => _logLevel = newValue);
            Provider.of<ConfigService>(
              context,
              listen: false,
            ).setLogLevel(newValue);
          },
        ),
      ],
    );
  }

  Widget _buildAiTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final configService = Provider.of<ConfigService>(context, listen: false);
    final aiService = Provider.of<AiChatService>(context, listen: false);
    final apiKeyController = TextEditingController(text: configService.claudeApiKey ?? '');
    final baseUrlController = TextEditingController(text: configService.claudeApiBaseUrl ?? '');

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Claude API Key 配置
        _buildSectionTitle(S.get('ai_chatbot_section')),
        Text(
          S.get('ai_chatbot_section_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // API Key 输入
        _buildSectionTitle(S.get('claude_api_key')),
        Text(
          S.get('claude_api_key_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Focus(
                onFocusChange: (hasFocus) async {
                  // 失去焦点时保存
                  if (!hasFocus) {
                    final value = apiKeyController.text;
                    await configService.setClaudeApiKey(value.isEmpty ? null : value);
                    await aiService.updateApiConfig(
                      value.isEmpty ? null : value,
                      baseUrl: configService.claudeApiBaseUrl,
                    );
                  }
                },
                child: TextField(
                  controller: apiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: S.get('claude_api_key_hint'),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.key, size: 18, color: Colors.deepPurple),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                launchUrl(Uri.parse('https://console.anthropic.com/'));
              },
              icon: const Icon(Icons.open_in_new, size: 14, color: Colors.deepPurple),
              label: Text(S.get('get_api_key')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _loadFromClaudeSettings(
                apiKeyController,
                baseUrlController,
                configService,
                aiService,
              ),
              icon: const Icon(Icons.download, size: 14, color: Colors.deepPurple),
              label: Text(S.get('load_from_claude')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepPurple,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // API Base URL 输入（第三方代理）
        _buildSectionTitle(S.get('claude_api_base_url')),
        Text(
          S.get('claude_api_base_url_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Focus(
                onFocusChange: (hasFocus) async {
                  // 失去焦点时保存
                  if (!hasFocus) {
                    final value = baseUrlController.text;
                    await configService.setClaudeApiBaseUrl(value.isEmpty ? null : value);
                    await aiService.updateApiConfig(
                      configService.claudeApiKey,
                      baseUrl: value.isEmpty ? null : value,
                    );
                  }
                },
                child: TextField(
                  controller: baseUrlController,
                  decoration: InputDecoration(
                    hintText: S.get('claude_api_base_url_hint'),
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.link, size: 18, color: Colors.deepPurple),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _TestConnectionButton(
              onTest: () async {
                // 先保存当前输入
                final value = baseUrlController.text;
                await configService.setClaudeApiBaseUrl(value.isEmpty ? null : value);
                await aiService.updateApiConfig(
                  configService.claudeApiKey,
                  baseUrl: value.isEmpty ? null : value,
                );
                // 测试连接
                return aiService.testConnection();
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 模型选择
        _buildSectionTitle(S.get('claude_model')),
        Text(
          S.get('claude_model_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: StyledDropdown<String>(
            value: configService.claudeModel,
            dense: true,
            items: ConfigService.availableModels.map((model) {
              return StyledDropdownItem<String>(
                value: model,
                label: model,
              );
            }).toList(),
            onChanged: (v) async {
              await configService.setClaudeModel(v);
              await aiService.updateApiConfig(
                configService.claudeApiKey,
                baseUrl: configService.claudeApiBaseUrl,
                model: v,
              );
              setState(() {});
            },
          ),
        ),

        const SizedBox(height: 32),

        // 悬浮图标开关
        _buildSwitchTile(
          S.get('enable_chatbot'),
          S.get('enable_chatbot_desc'),
          configService.showChatbotIcon,
          (v) async {
            await configService.setShowChatbotIcon(v);
            setState(() {});
          },
        ),

        const SizedBox(height: 32),

        // 聊天历史管理
        _buildSectionTitle(S.get('chat_history_section')),
        Text(
          S.get('chat_history_section_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(S.get('clear_history')),
                    content: Text(S.get('clear_history_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(S.get('cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: Text(S.get('clear_history')),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await aiService.clearHistory();
                  if (mounted) {
                    Toast.show(
                      context,
                      message: S.get('history_cleared'),
                      type: ToastType.success,
                    );
                  }
                }
              },
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text(S.get('clear_history')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    int value,
    Map<int, String> options,
    ValueChanged<int> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isDense: true,
                dropdownColor: isDark ? const Color(0xFF3C3C3E) : Colors.white,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                  fontFamily: 'Menlo',
                ),
                items: options.entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle(S.get('mcp_switch_config_file')),
        Text(
          S.get('mcp_switch_config_description'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildPathField(
          S.get('config_dir'),
          TextEditingController(
            text: '${Platform.environment['HOME']}/.mcp-switch',
          ),
          customTrailing: _buildFinderButton(
            '${Platform.environment['HOME']}/.mcp-switch',
          ),
          type: null, // Global config, no specific editor preference
        ),

        const SizedBox(height: 32),

        _buildSectionTitle(S.get('config_override_advanced')),
        Text(
          S.get('config_override_description'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),

        ...EditorType.values.map((type) {
          final controller = _pathControllers[type];
          if (controller == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == EditorType.claude
                      ? S.get('claude_code_config_file')
                      : '${type.label} ${S.get('config_file')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                _buildPathField(
                  type.label,
                  controller,
                  onChanged: (v) => _savePath(type, v),
                  type: type,
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 32),

        // DeepL API Key 配置
        _buildSectionTitle(S.get('deepl_api_key_title')),
        Text(
          S.get('deepl_api_key_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        _buildDeepLApiKeyField(),
      ],
    );
  }

  Widget _buildDeepLApiKeyField() {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final controller = TextEditingController(text: configService.deeplApiKey ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(
              hintText: S.get('deepl_api_key_hint'),
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                fontSize: 13,
              ),
              filled: true,
              fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.key, size: 18, color: Colors.deepPurple),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (value) async {
              await configService.setDeepLApiKey(value.isEmpty ? null : value);
            },
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () {
            launchUrl(Uri.parse('https://www.deepl.com/pro-api'));
          },
          icon: const Icon(Icons.open_in_new, size: 14),
          label: Text(S.get('get_api_key')),
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildAboutTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              // color: Colors.blueAccent, // Removed background color as image handles it
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/images/cat.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'MCP Switch',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            appVersion,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Text(
            'Designed by jasonhuang',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _checkForUpdates,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(S.get('check_for_updates')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
    );
  }

  Widget _buildSegmentedControl(
    List<String> labels,
    int selectedIndex,
    ValueChanged<int> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return Row(
      children: List.generate(labels.length, (index) {
        final isSelected = selectedIndex == index;
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: InkWell(
            onTap: () => onChanged(index),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.blue : borderColor,
                ),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenAction(String path, String action) async {
    if (path.isEmpty) return;
    try {
      List<String> args = [];
      switch (action) {
        case 'vscode':
          args = ['-a', 'Visual Studio Code', path];
          break;
        case 'cursor':
          args = ['-a', 'Cursor', path];
          break;
        case 'windsurf':
          args = ['-a', 'Windsurf', path];
          break;
        case 'textedit':
          args = ['-a', 'TextEdit', path];
          break;
        case 'finder':
          args = ['-R', path];
          break;
        case 'default':
        default:
          args = [path];
          break;
      }
      await Process.run('open', args);
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: 'Action failed: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Widget _buildPathField(
    String label,
    TextEditingController controller, {
    ValueChanged<String>? onChanged,
    Widget? customTrailing,
    EditorType? type,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48, // Fixed height for alignment
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Select or type path...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey,
                ),
              ),
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'Menlo',
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        customTrailing ?? _buildOpenMenu(controller.text, type: type),
      ],
    );
  }

  Widget _buildOpenMenu(String path, {EditorType? type}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    // Define all available editors
    final allEditors = [
      StyledPopupMenuItem(
        value: 'cursor',
        label: 'Cursor',
        icon: Icons.terminal,
      ),
      StyledPopupMenuItem(
        value: 'windsurf',
        label: 'Windsurf',
        icon: Icons.waves,
      ),
      StyledPopupMenuItem(
        value: 'vscode',
        label: 'Visual Studio Code',
        icon: Icons.code,
      ),
    ];

    // Determine installed editors
    final installedEditors = allEditors
        .where((item) => _installedApps[item.value] == true)
        .toList();
    final List<StyledPopupMenuItem<String>> builtInItems = [
      StyledPopupMenuItem(
        value: 'textedit',
        label: 'TextEdit (文本编辑)',
        icon: Icons.text_snippet,
      ),
      StyledPopupMenuItem.divider(),
      StyledPopupMenuItem(
        value: 'default',
        label: '默认应用打开',
        icon: Icons.open_in_new,
      ),
      StyledPopupMenuItem(
        value: 'finder',
        label: '在 Finder 中显示',
        icon: Icons.folder_open,
      ),
    ];

    // Construct the list based on priority
    List<StyledPopupMenuItem<String>> finalItems = [];

    // 1. Preferred Editor (Top priority if installed)
    String? preferredKey;
    if (type == EditorType.cursor)
      preferredKey = 'cursor';
    else if (type == EditorType.windsurf)
      preferredKey = 'windsurf';
    // Claude/Antigravity/Codex usually default to VSCode or Cursor generically,
    // but if we want to be smart:
    // If user has Cursor, maybe they prefer Cursor for everything? Or VSCode?
    // Let's default to VSCode as primary fallback, unless Cursor is specifically the type.

    // Actually, user said: "If installed Cursor, first is Cursor" (implied for Cursor config).
    // "If installed Windsurf, first is Windsurf" (implied for Windsurf config).
    // For general ones, let's put configured editors first.

    if (preferredKey != null && _installedApps[preferredKey] == true) {
      final item = installedEditors.firstWhere((e) => e.value == preferredKey);
      finalItems.add(item);
    }

    // 2. Other Installed Editors (excluding the one added above)
    // Priority order: Cursor > Windsurf > VSCode (Just an arbitrary choice or installed order)
    // Actually common popularity: VSCode > Cursor > Windsurf
    // Let's sort installed editors by a standard rank if they are not the preferred one.
    // Rank: VSCode, Cursor, Windsurf
    final rank = {'vscode': 1, 'cursor': 2, 'windsurf': 3};
    installedEditors.sort(
      (a, b) => (rank[a.value] ?? 99).compareTo(rank[b.value] ?? 99),
    );

    for (var item in installedEditors) {
      if (item.value != preferredKey) {
        // Avoid duplicate
        finalItems.add(item);
      }
    }

    // 3. If no editors installed at all, maybe show generic ones?
    // We already added installed ones.

    // 4. Fallback: If preferred was NOT installed, we haven't added it yet.
    // Should we show it disabled? Or just not show it?
    // User request: "If installed... first option is cursor". Implies if not installed, don't show or prioritize others.
    // I will only show INSTALLED editors to avoid cluttering with broken options.

    // 5. Add built-in items
    finalItems.addAll(builtInItems);

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
        color: cardColor,
      ),
      child: Center(
        child: StyledPopupMenu<String>(
          icon: Icons.edit_note,
          tooltip: 'Open with...',
          onSelected: (value) => _handleOpenAction(path, value),
          items: finalItems,
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String label, Locale locale) {
    final isSelected = S.localeNotifier.value == locale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return InkWell(
      onTap: () {
        S.setLocale(locale);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.blue : borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : Colors.black87),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  Widget _buildFinderButton(String path) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.shade300;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
        color: cardColor,
      ),
      child: IconButton(
        icon: const Icon(Icons.folder_open, size: 20),
        tooltip: S.get('open_in_finder'),
        onPressed: () => _handleOpenAction(path, 'finder'),
        color: isDark ? Colors.white : Colors.black54,
      ),
    );
  }
}

/// 测速按钮组件
class _TestConnectionButton extends StatefulWidget {
  final Future<({int? latency, String? error})> Function() onTest;

  const _TestConnectionButton({required this.onTest});

  @override
  State<_TestConnectionButton> createState() => _TestConnectionButtonState();
}

class _TestConnectionButtonState extends State<_TestConnectionButton> {
  bool _isTesting = false;
  int? _lastLatency; // 上次测速结果

  Future<void> _handleTest() async {
    setState(() {
      _isTesting = true;
      _lastLatency = null;
    });
    final result = await widget.onTest();
    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _lastLatency = result.latency;
    });

    if (result.latency != null) {
      Toast.show(
        context,
        message: S.get('connection_success').replaceAll('{ms}', result.latency.toString()),
        type: ToastType.success,
      );
    } else {
      Toast.show(
        context,
        message: S.get('connection_failed').replaceAll('{error}', result.error ?? 'Unknown'),
        type: ToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 构建标签文本
    String labelText;
    if (_isTesting) {
      labelText = S.get('testing_connection');
    } else if (_lastLatency != null) {
      labelText = '${S.get('test_connection')} (${_lastLatency}ms)';
    } else {
      labelText = S.get('test_connection');
    }

    return TextButton.icon(
      onPressed: _isTesting ? null : _handleTest,
      icon: _isTesting
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.deepPurple.shade300,
              ),
            )
          : Icon(
              _lastLatency != null ? Icons.check_circle : Icons.speed,
              size: 14,
              color: _lastLatency != null ? Colors.green : Colors.deepPurple,
            ),
      label: Text(
        labelText,
        style: TextStyle(
          color: _lastLatency != null ? Colors.green : Colors.deepPurple,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: _lastLatency != null ? Colors.green : Colors.deepPurple,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }
}
