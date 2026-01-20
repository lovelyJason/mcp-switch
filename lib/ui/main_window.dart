import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/terminal_service.dart';
import '../l10n/s.dart';
import 'components/custom_toast.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/global_keys.dart';
import 'pages/home/home_page.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow>
    with WindowListener, TrayListener {
  GlobalKey<ScaffoldState> get _scaffoldKey => globalScaffoldKey;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
    _initWindow();
  }

  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    try {
      final iconPath = await _extractIcon();
      if (iconPath != null) {
        await trayManager.setIcon(iconPath);
      } else {
        await trayManager.setIcon('TrayIcon');
      }
      await trayManager.setTitle("MCP");
    } catch (e) {
      print('Error init tray: $e');
    }

    if (!mounted) return;

    Menu menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'Show MCP Switch'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Exit'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  Future<String?> _extractIcon() async {
    try {
      final byteData = await rootBundle.load('assets/images/tray_icon.png');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/tray_icon.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      print('Failed to extract icon: $e');
      return null;
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      _attemptAppExit();
    }
  }

  @override
  void onWindowClose() async {
    final config = Provider.of<ConfigService>(context, listen: false);
    bool shouldMinimize = config.minimizeToTray;

    if (shouldMinimize) {
      await windowManager.hide();
    } else {
      await _attemptAppExit();
    }
  }

  Future<void> _attemptAppExit() async {
    final terminalService = context.read<TerminalService>();

    if (terminalService.isPtyActive) {
      final hasActiveProcess = await terminalService.hasActiveForegroundProcess();

      if (hasActiveProcess) {
        if (!await windowManager.isVisible()) {
          await windowManager.show();
          await windowManager.focus();
        }

        if (_scaffoldKey.currentState?.isEndDrawerOpen != true) {
          _scaffoldKey.currentState?.openEndDrawer();
        }

        if (mounted) {
          Toast.show(
            context,
            message: S.get('terminal_active_task_warning'),
            type: ToastType.warning,
            duration: const Duration(seconds: 4),
          );
        }
        return;
      }

      if (await windowManager.isVisible()) {
        if (_scaffoldKey.currentState?.isEndDrawerOpen != true) {
          _scaffoldKey.currentState?.openEndDrawer();
        }
      }

      terminalService.sendCommand('exit');
      await Future.delayed(const Duration(milliseconds: 800));
    }

    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: HomePage(scaffoldKey: _scaffoldKey),
    );
  }
}
