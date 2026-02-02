import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/terminal_service.dart';
import '../models/editor_type.dart';
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
  ConfigService? _configService;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initTray();
    _initWindow();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听 ConfigService 变化，自动刷新托盘菜单
    final newConfigService = Provider.of<ConfigService>(context, listen: false);
    if (_configService != newConfigService) {
      _configService?.removeListener(_onConfigChanged);
      _configService = newConfigService;
      _configService?.addListener(_onConfigChanged);
    }
  }

  void _onConfigChanged() {
    _updateTrayMenu();
  }

  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    _configService?.removeListener(_onConfigChanged);
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
    await _updateTrayMenu();
  }

  /// 更新托盘菜单，显示按编辑器分组的 MCP 服务列表
  Future<void> _updateTrayMenu() async {
    if (!mounted) return;
    final configService = Provider.of<ConfigService>(context, listen: false);

    final List<MenuItem> menuItems = [
      MenuItem(key: 'show_window', label: 'Show MCP Switch'),
      MenuItem.separator(),
    ];

    // 遍历所有编辑器类型
    for (final editor in EditorType.values) {
      final profiles = configService.getProfiles(editor);
      final List<MenuItem> serverItems = [];

      if (profiles.isEmpty) {
        // 没有 MCP 服务，显示提示
        serverItems.add(MenuItem(
          key: '${editor.name}_empty',
          label: S.get('tray_no_mcp_service'),
          disabled: true,
        ));
      } else {
        // Claude 只显示 Global 配置（name 为 'Global Configuration' 或 content['isGlobal'] == true）
        final displayProfiles = editor == EditorType.claude
            ? profiles.where((p) =>
                p.name == 'Global Configuration' ||
                p.content['isGlobal'] == true
              ).toList()
            : profiles;

        if (displayProfiles.isEmpty) {
          serverItems.add(MenuItem(
            key: '${editor.name}_empty',
            label: S.get('tray_no_mcp_service'),
            disabled: true,
          ));
        } else {
          for (final profile in displayProfiles) {
            // 获取 mcpServers 下的所有服务器
            final mcpServers = profile.content['mcpServers'];
            if (mcpServers is Map<String, dynamic>) {
              for (final serverName in mcpServers.keys) {
                final serverConfig = mcpServers[serverName];
                final isDisabled = serverConfig is Map &&
                    serverConfig['disabled'] == true;

                serverItems.add(MenuItem.checkbox(
                  key: '${editor.name}|${profile.id}|$serverName',
                  label: serverName,
                  checked: !isDisabled,
                ));
              }
            }
          }
        }

        // 如果解析后仍然没有服务器
        if (serverItems.isEmpty) {
          serverItems.add(MenuItem(
            key: '${editor.name}_empty',
            label: S.get('tray_no_mcp_service'),
            disabled: true,
          ));
        }
      }

      // 添加编辑器子菜单
      menuItems.add(MenuItem.submenu(
        key: editor.name,
        label: editor.label,
        submenu: Menu(items: serverItems),
      ));
    }

    menuItems.add(MenuItem.separator());
    menuItems.add(MenuItem(key: 'exit_app', label: 'Exit'));

    await trayManager.setContextMenu(Menu(items: menuItems));
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
    } else if (menuItem.key?.contains('|') == true) {
      // MCP 服务器点击，格式: editorName|profileId|serverName
      _handleMcpServerClick(menuItem.key!);
    }
  }

  /// 处理 MCP 服务器菜单点击，切换启用/禁用状态
  Future<void> _handleMcpServerClick(String key) async {
    final parts = key.split('|');
    if (parts.length != 3) return;

    final editorName = parts[0];
    final profileId = parts[1];
    final serverName = parts[2];

    // 查找对应的 EditorType
    final editor = EditorType.values.firstWhere(
      (e) => e.name == editorName,
      orElse: () => EditorType.cursor,
    );

    final configService = Provider.of<ConfigService>(context, listen: false);

    // 使用现有的 toggleServerStatus 方法切换状态
    // 但需要特殊处理，因为 toggleServerStatus 是按 profileId 切换
    // 这里需要找到包含该 serverName 的 profile 并切换
    final profiles = configService.getProfiles(editor);
    for (final profile in profiles) {
      final mcpServers = profile.content['mcpServers'];
      if (mcpServers is Map<String, dynamic> && mcpServers.containsKey(serverName)) {
        // 找到了包含此服务器的 profile
        final serverConfig = mcpServers[serverName];
        if (serverConfig is Map<String, dynamic>) {
          final isDisabled = serverConfig['disabled'] == true;
          serverConfig['disabled'] = !isDisabled;
          await configService.saveProfile(editor, profile);
        }
        break;
      }
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
