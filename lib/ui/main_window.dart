
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../../models/editor_type.dart';
import 'components/editor_selector.dart';
import 'components/custom_toast.dart';
import 'config_list_screen.dart';
import 'settings_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'mcp_server_edit_screen.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow>
    with WindowListener, TrayListener {
  EditorType _selectedEditor = EditorType.cursor; // Default
  
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
    _initWindow();
  }

  Future<void> _initWindow() async {
    // Enforce prevent close to ensure onWindowClose is triggered
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
      print('Initializing Tray...');

      try {
        final iconPath = await _extractIcon();
        print('Extracted icon path: $iconPath');
        if (iconPath != null) {
          await trayManager.setIcon(iconPath);
          print('Tray icon set from file.');
        } else {
          // Fallback to native asset if extraction fails?
          await trayManager.setIcon('TrayIcon');
        }
      } catch (e) {
        print('Error setting tray icon: $e');
      }

      try {
        // Force title as verification
        await trayManager.setTitle("MCP");
      } catch (e) {
        print('Error setting tray title: $e');
      }
    } catch (e) {
      print('General error init tray: $e');
    }
    
    if (!mounted) return;

    // Create Menu
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
      windowManager.destroy();
    }
  }

  @override
  void onWindowClose() async {
    final config = Provider.of<ConfigService>(context, listen: false);
    bool shouldMinimize = config.minimizeToTray;

    print('Window Close Requested. MinimizeToTray: $shouldMinimize');

    if (shouldMinimize) {
      if (mounted) {
        // Optional: keeping toast or removing it. Removing it for cleaner UX now that we verified.
        // Toast.show(context, message: 'App minimized to tray', type: ToastType.info);
      }
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Custom Title Bar Height
    const double kTitleBarHeight = 60.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Custom Header
          Container(
            height: kTitleBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                // Drag Region for Moving Window (Left Side - Traffic Lights area)
                const SizedBox(width: 70), // Space for traffic lights
                
                // App Title
                Text(
                  'MCP Switch',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent, // Match brand color in screenshot
                      ),
                ),
                const SizedBox(width: 8),
                
                // Settings Button
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: () {
                   Navigator.of(context).push(
                     MaterialPageRoute(builder: (_) => const SettingsScreen()),
                   );
                  },
                  tooltip: 'Settings',
                ),

                Expanded(
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: EditorSelector(
                        selected: _selectedEditor,
                        onChanged: (editor) {
                          setState(() {
                            _selectedEditor = editor;
                          });
                          // Refresh profiles when switching tabs
                          Provider.of<ConfigService>(
                            context,
                            listen: false,
                          ).reloadProfiles();
                        },
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),

                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新配置',
                  onPressed: () async {
                    await Provider.of<ConfigService>(
                      context,
                      listen: false,
                    ).reloadProfiles();
                    if (context.mounted) {
                      Toast.show(
                        context,
                        message: '配置已刷新',
                        type: ToastType.success,
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                
                // Add Button (Primary Action)
                FloatingActionButton.small(
                  onPressed: () {
                    if (_selectedEditor == EditorType.cursor) {
                      Toast.show(
                        context,
                        message: 'Cursor 请前往客户端界面进行编辑',
                        type: ToastType.info,
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            McpServerEditScreen(editorType: _selectedEditor),
                      ),
                    );
                  },
                  backgroundColor: Colors.orange,
                  elevation: 0,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
          
          // Allow dragging on the header empty space
          // Ideally wrap the Row in DragToMoveArea, but WindowManager handles this if we use specialized widgets.
          // For now, we assume user drags on empty space. 
          // Actually, we should use `WindowCaption` or `DragToMoveArea` from window_manager if available, 
          // or just wrap the top container in `GestureDetector` that calls `windowManager.startDragging()`.
          
          // Main Content
          Expanded(
            child: ConfigListScreen(editorType: _selectedEditor),
          ),
        ],
      ),
    );
  }
}
