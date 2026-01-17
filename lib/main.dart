
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'services/config_service.dart';
import 'services/prompt_service.dart';
import 'services/terminal_service.dart';
import 'services/ai_chat_service.dart';
import 'ui/main_window.dart';
import 'ui/components/floating_terminal_icon.dart';
import 'ui/components/global_terminal_panel.dart';
import 'ui/components/floating_chatbot_icon.dart';
import 'ui/components/global_chatbot_panel.dart';
import 'utils/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'l10n/s.dart';
import 'services/logger_service.dart';

/// 全局 ScaffoldKey，用于控制 MainWindow 的 endDrawer
final GlobalKey<ScaffoldState> globalScaffoldKey = GlobalKey<ScaffoldState>();

/// 全局 NavigatorKey，用于在 Overlay 中导航
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

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
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(900, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Hide native title bar content but keep traffic lights
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

  LoggerService.info('''
  ════════════════════════════════════════════
     🚀 MCP Switch Initialized Successfully 🚀
     ----------------------------------------
     📁 Home:   ${Platform.environment['HOME']}
     🌏 Locale: ${S.localeNotifier.value}
     🛠️ Mode:   ${kReleaseMode ? 'Release' : 'Debug'}
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
        ChangeNotifierProvider(create: (_) => PromptService()..init()),
        ChangeNotifierProvider.value(value: terminalService),
        ChangeNotifierProvider.value(value: aiChatService),
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
                          return Stack(
                            children: [
                              child ?? const SizedBox.shrink(),
                              // 全局悬浮终端图标
                              FloatingTerminalIcon(
                                onTap: () {
                                  terminalService.openTerminalPanel();
                                },
                              ),
                              // 全局悬浮 AI Chatbot 图标
                              FloatingChatbotIcon(
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
                            ],
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
