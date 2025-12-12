
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'services/config_service.dart';
import 'ui/main_window.dart';
import 'utils/app_theme.dart';
import 'l10n/s.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: configService),
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
              title: 'MCP Switch',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeMode,
              locale: locale,
              home: const MainWindow(),
            );
          },
        );
      },
    );
  }
}
