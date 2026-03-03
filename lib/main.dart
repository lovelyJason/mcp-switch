
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'services/config_service.dart';
import 'services/prompt_service.dart';
import 'services/terminal_service.dart';
import 'services/ai_chat_service.dart';
import 'services/mcp_health_check_service.dart';
import 'services/update_service.dart';
import 'ui/main_window.dart';
import 'ui/components/floating_terminal_icon.dart';
import 'ui/components/global_terminal_panel.dart';
import 'ui/components/floating_chatbot_icon.dart';
import 'ui/components/global_chatbot_panel.dart';
import 'ui/components/floating_debug_button.dart';
import 'ui/components/windows_shell_selector_dialog.dart';
import 'utils/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'l10n/s.dart';
import 'services/logger_service.dart';
import 'utils/platform_utils.dart';
import 'config/platform_commands_config.dart';
import 'config/mcp_presets_config.dart';
import 'constants/editor_features.dart';
import 'services/cursor_workspace_service.dart';
import 'utils/global_keys.dart';
import 'data/database.dart';
import 'services/provider_switch_service.dart';
import 'services/remote_claw_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Logger
  await LoggerService.init();

  // Setup Global Error Handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    LoggerService.error('Flutter Error', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    LoggerService.error('Async Error', error, stack);
    return true;
  };
  
  // Initialize Window Manager
  await windowManager.ensureInitialized();
  
  // Windows 使用原生标题栏，macOS 隐藏标题栏内容但保留红绿灯
  final titleBarStyle = Platform.isWindows
      ? TitleBarStyle.normal
      : TitleBarStyle.hidden;

  WindowOptions windowOptions = WindowOptions(
    size: const Size(900, 600),
    minimumSize: const Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: titleBarStyle,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.show();
    await windowManager.focus();
  });

  // Initialize Services
  final configService = ConfigService();
  await configService.init();
  await S.init();
  await PlatformCommandsConfig.init(); // 加载平台命令配置
  await McpPresetsConfig.init(); // 加载 MCP 预设配置
  await EditorFeatures.init(); // 加载编辑器功能版本兼容配置
  await CursorWorkspaceService.instance.init(); // 检测 Cursor 版本

  final dbPath = await AppDatabase.getDatabasePath();
  final configPath = '${PlatformUtils.userHome}/.mcp-switch/config.json';
  final prefsPath = Platform.isMacOS
      ? '~/Library/Preferences/com.jason.mcpSwitch.plist'
      : Platform.isWindows
          ? r'%APPDATA%\com.jason\mcpSwitch\shared_preferences.json'
          : '~/.local/share/mcpSwitch/shared_preferences.json';
  LoggerService.info('''
  ════════════════════════════════════════════
     🚀 MCP Switch Initialized Successfully 🚀
     ----------------------------------------
     📁 Home:              ${PlatformUtils.userHome}
     🌏 Locale:            ${S.localeNotifier.value}
     🔧 Mode:              ${kReleaseMode ? 'Release' : 'Debug'}
     💾 DB:                $dbPath
     📄 Config:            $configPath
     📦 SharedPreferences: $prefsPath
  ════════════════════════════════════════════
  ''');

  // Initialize Terminal Service first
  final terminalService = TerminalService();

  // Initialize AI Chat Service and inject Terminal Service
  final aiChatService = AiChatService();
  aiChatService.setTerminalService(terminalService); // 关键：注入终端服务
  await aiChatService.init(
    configService.claudeApiKey,
    baseUrl: configService.claudeApiBaseUrl,
    model: configService.claudeModel,
  );

  // Initialize MCP Health Check Service
  final mcpHealthCheckService = McpHealthCheckService();
  // 延迟 2 秒后执行首次检测（避免启动卡顿）
  Future.delayed(const Duration(seconds: 2), () {
    mcpHealthCheckService.checkAllServers();
  });

  // Initialize Provider Switch Service（供应商配置切换）
  final db = AppDatabase();
  final providerSwitchService = ProviderSwitchService(db);
  await providerSwitchService.init();

  // Initialize Update Service（自动检测更新）
  final updateService = UpdateService();
  updateService.init();

  // Initialize Remote Claw Service（远程审批服务）
  final remoteClawService = RemoteClawService();
  remoteClawService.loadConfig(
    telegramEnabled: configService.remoteClawTelegramEnabled,
    telegramBotToken: configService.remoteClawTelegramBotToken,
    telegramChatId: configService.remoteClawTelegramChatId,
    dingtalkEnabled: configService.remoteClawDingtalkEnabled,
    dingtalkWebhookUrl: configService.remoteClawDingtalkWebhookUrl,
    dingtalkSecret: configService.remoteClawDingtalkSecret,
    callbackHost: configService.remoteClawCallbackHost,
  );
  if (configService.remoteClawAutoStart) {
    remoteClawService.start();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider(create: (_) => PromptService()..init()),
        ChangeNotifierProvider.value(value: terminalService),
        ChangeNotifierProvider.value(value: aiChatService),
        ChangeNotifierProvider.value(value: mcpHealthCheckService),
        ChangeNotifierProvider.value(value: updateService),
        ChangeNotifierProvider.value(value: providerSwitchService),
        ChangeNotifierProvider.value(value: remoteClawService),
      ],
      child: const McpSwitchApp(),
    ),
  );
}

class McpSwitchApp extends StatelessWidget {
  const McpSwitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final configService = Provider.of<ConfigService>(context, listen: false);

    return ValueListenableBuilder<Locale>(
      valueListenable: S.localeNotifier,
      builder: (context, locale, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: configService.themeModeNotifier,
          builder: (context, themeMode, _) {
            return MaterialApp(
              navigatorKey: globalNavigatorKey,
              title: 'MCP Switch',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              locale: locale,
              home: const MainWindow(),
              builder: (context, child) {
                // 在 Navigator 之上包装一层 Stack，放置全局悬浮图标和终端面板
                // 使用 Overlay 包装以支持 Tooltip 等需要 Overlay 的 widget
                return Overlay(
                  initialEntries: [
                    OverlayEntry(
                      builder: (context) => Consumer2<TerminalService, AiChatService>(
                        builder: (context, terminalService, aiChatService, _) {
                          // 使用 LayoutBuilder 获取实际窗口尺寸
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final windowSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              return Stack(
                                children: [
                                  child ?? const SizedBox.shrink(),
                                  // 全局悬浮终端图标
                                  FloatingTerminalIcon(
                                    parentSize: windowSize,
                                    onTap: () async {
                                      // Windows 首次打开终端：弹窗选择 Shell
                                      if (Platform.isWindows) {
                                        final navContext = globalNavigatorKey.currentContext;
                                        if (navContext != null) {
                                          final configService = navContext.read<ConfigService>();
                                          if (!configService.hasWindowsShellPreference) {
                                            final shellType = await WindowsShellSelectorDialog.show(navContext);
                                            if (shellType != null) {
                                              await configService.setWindowsShell(shellType.name);
                                            } else {
                                              await configService.setWindowsShell('powershell');
                                            }
                                          }
                                          terminalService.setConfigService(configService);
                                        }
                                      }
                                      terminalService.openTerminalPanel();
                                    },
                                  ),
                                  // 全局悬浮 AI Chatbot 图标
                                  FloatingChatbotIcon(
                                    parentSize: windowSize,
                                    onTap: () {
                                      aiChatService.openPanel();
                                    },
                                  ),
                                  // 全局 AI 聊天面板（侧边滑出样式）
                                  if (aiChatService.isPanelOpen)
                                    GlobalChatbotPanel(
                                      onClose: () {
                                        aiChatService.closePanel();
                                      },
                                    ),
                                  // 全局终端面板（侧边滑出样式）- 放在最上层，覆盖 Chatbot
                                  if (terminalService.isTerminalPanelOpen)
                                    GlobalTerminalPanel(
                                      onClose: () {
                                        terminalService.closeTerminalPanel();
                                      },
                                    ),
                                  // Debug 按钮（仅 Debug 模式显示）
                                  const FloatingDebugButton(),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
