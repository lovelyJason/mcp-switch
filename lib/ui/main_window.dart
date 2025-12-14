
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/terminal_service.dart';
import '../l10n/s.dart';
import '../../models/editor_type.dart';
import 'components/editor_selector.dart';
import 'components/custom_toast.dart';
import 'config_list_screen.dart';
import 'settings_screen.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'mcp_server_edit_screen.dart';
import 'claude_prompts_screen.dart';
import 'rules_screen.dart';
import 'components/claude_terminal.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow>
    with WindowListener, TrayListener {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      _attemptAppExit();
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
      await _attemptAppExit();
    }
  }

  Future<void> _attemptAppExit() async {
    final terminalService = context.read<TerminalService>();
    
    // Graceful Exit Logic
    if (terminalService.isPtyActive) {
      // Check for active REPL/Process
      final hasActiveProcess = await terminalService
          .hasActiveForegroundProcess();

      if (hasActiveProcess) {
        // Force make window visible if it was hidden (e.g. from tray)
        if (!await windowManager.isVisible()) {
          await windowManager.show();
          await windowManager.focus();
        }

        // Force open drawer
        if (_scaffoldKey.currentState?.isEndDrawerOpen != true) {
          _scaffoldKey.currentState?.openEndDrawer();
        }
        // Show warning
        if (mounted) {
          Toast.show(
            context,
            message: S.get('terminal_active_task_warning'),
            type: ToastType.warning,
            duration: const Duration(seconds: 4),
          );
        }
        // ABORT EXIT
        return;
      }

      // Open drawer if closed (visual feedback for auto-exit) if window is visible
      if (await windowManager.isVisible()) {
        if (_scaffoldKey.currentState?.isEndDrawerOpen != true) {
          _scaffoldKey.currentState?.openEndDrawer();
        }
      }
        
        // Send exit command
        terminalService.sendCommand('exit');
        
        // Wait for animation and process exit
        // Give it a second to show the "logout" effect
        await Future.delayed(const Duration(milliseconds: 800));
    }

    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    // Custom Title Bar Height
    const double kTitleBarHeight = 60.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      endDrawer: ClaudeTerminal(onClose: () => Navigator.of(context).pop()),
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
                          ).setEditor(editor);

                          Provider.of<ConfigService>(
                            context,
                            listen: false,
                          ).reloadProfiles();
                        },
                      ),
                    ),
                  ),
                ),
                
                // Action Group (Prompt + Rules)
                const SizedBox(width: 16),
                Builder(
                  builder: (context) {
                    final isClaude = _selectedEditor == EditorType.claude;
                    final showPrompt = isClaude;
                    // Removed unused isDark variable

                    // Rules Button
                    final rulesBtn = IconButton(
                      icon: Icon(
                        Icons.article_outlined,
                        size: 18,
                        color: Theme.of(context).textTheme.bodyMedium?.color, 
                      ),
                      tooltip: 'Rules',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        if (_selectedEditor == EditorType.cursor) {
                          Toast.show(
                            context,
                            message: S.get(
                              'cursor_configure_hint',
                            ), // Or direct string
                            type: ToastType.info,
                          );
                          return;
                        }
                        if (_selectedEditor == EditorType.claude) {
                          Toast.show(
                            context,
                            message: S.get('claude_rules_hint'),
                            type: ToastType.info,
                          );
                          return;
                        }
                        if (_selectedEditor == EditorType.codex) {
                          Toast.show(
                            context,
                            message: S.get('codex_rules_hint'),
                            type: ToastType.info,
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RulesScreen(editorType: _selectedEditor),
                          ),
                        );
                      },
                    );

                    // Prompt Button
                    final promptBtn = IconButton(
                      icon: const Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                        color: Colors.orange,
                      ),
                      tooltip: S.get('prompt_name'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ClaudePromptsScreen(),
                          ),
                        );
                      },
                    );

                    if (showPrompt) {
                      // Grouped Container
                      return Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(
                            8,
                          ), // Pill shape wrapper
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            promptBtn,
                            Container(
                              width: 1,
                              height: 20,
                              color: Colors.grey.withOpacity(0.2),
                            ),
                            rulesBtn,
                          ],
                        ),
                      );
                    } else {
                      // Single Rules Button Container
                      return Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: rulesBtn,
                      );
                    }
                  },
                ),

                const SizedBox(width: 8),

                // if (_selectedEditor == EditorType.claude) ...[
                // ],
                const SizedBox(width: 8),
                Builder(
                    builder: (context) => IconButton(
                      onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      },
                      icon: const Icon(Icons.terminal, size: 20),
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                      tooltip: S.get('terminal_title'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
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
