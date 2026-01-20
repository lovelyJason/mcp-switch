import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/editor_type.dart';
import '../../../services/config_service.dart';
import '../../../services/terminal_service.dart';
import '../../../l10n/s.dart';
import '../../components/editor_selector.dart';
import '../../components/custom_toast.dart';
import '../../components/windows_shell_selector_dialog.dart';
import '../settings/settings_screen.dart';
import '../mcp_config/mcp_server_edit_screen.dart';
import 'header_action_buttons.dart';

/// 首页头部组件
/// 包含：标题、设置按钮、编辑器选择器、操作按钮组、终端按钮、刷新按钮、添加按钮
class HomeHeader extends StatelessWidget {
  static const double kTitleBarHeight = 60.0;

  final EditorType selectedEditor;
  final bool isClaudeInstalled;
  final bool isCodexInstalled;
  final bool isGeminiInstalled;
  final bool isInstalling; // 任何 CLI 正在安装中
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ValueChanged<EditorType> onEditorChanged;

  const HomeHeader({
    super.key,
    required this.selectedEditor,
    required this.isClaudeInstalled,
    required this.isCodexInstalled,
    required this.isGeminiInstalled,
    required this.isInstalling,
    required this.scaffoldKey,
    required this.onEditorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isClaude = selectedEditor == EditorType.claude;
    final claudeDisabled = isClaude && !isClaudeInstalled;

    return Container(
      height: kTitleBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          // macOS 红绿灯占位
          const SizedBox(width: 70),

          // 应用标题
          _buildAppTitle(context),
          const SizedBox(width: 8),

          // 设置按钮
          _buildSettingsButton(context),

          // 编辑器选择器（右对齐）
          Expanded(child: _buildEditorSelector(context)),

          const SizedBox(width: 16),

          // 操作按钮组（胶囊样式）
          HeaderActionButtons(
            selectedEditor: selectedEditor,
            isClaudeInstalled: isClaudeInstalled,
            isCodexInstalled: isCodexInstalled,
            isGeminiInstalled: isGeminiInstalled,
            scaffoldKey: scaffoldKey,
          ),

          const SizedBox(width: 8),

          // 终端按钮
          _buildTerminalButton(context, claudeDisabled),

          const SizedBox(width: 8),

          // 刷新按钮
          _buildRefreshButton(context, claudeDisabled),

          const SizedBox(width: 8),

          // 添加按钮
          _buildAddButton(context, claudeDisabled),
        ],
      ),
    );
  }

  /// 应用标题
  Widget _buildAppTitle(BuildContext context) {
    return Text(
      'MCP Switch',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
    );
  }

  /// 设置按钮
  Widget _buildSettingsButton(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined, size: 20),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
      tooltip: 'Settings',
    );
  }

  /// 编辑器选择器
  Widget _buildEditorSelector(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        child: EditorSelector(
          selected: selectedEditor,
          enabled: !isInstalling,
          onChanged: (editor) {
            onEditorChanged(editor);
            // 刷新配置
            final configService = Provider.of<ConfigService>(context, listen: false);
            configService.setEditor(editor);
            configService.reloadProfiles();
          },
        ),
      ),
    );
  }

  /// 终端按钮
  Widget _buildTerminalButton(BuildContext context, bool disabled) {
    return IconButton(
      onPressed: disabled ? null : () => _openTerminal(context),
      icon: Icon(
        Icons.terminal,
        size: 20,
        color: disabled
            ? Colors.grey
            : (Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54),
      ),
      tooltip: disabled ? S.get('claude_not_installed_title') : S.get('terminal_title'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }

  /// 打开终端
  Future<void> _openTerminal(BuildContext context) async {
    final configService = context.read<ConfigService>();
    final terminalService = context.read<TerminalService>();

    // Windows 首次打开终端：弹窗选择 Shell
    if (Platform.isWindows && !configService.hasWindowsShellPreference) {
      final shellType = await WindowsShellSelectorDialog.show(context);
      if (shellType != null) {
        await configService.setWindowsShell(shellType.name);
      } else {
        // 用户关闭弹窗，默认使用 PowerShell
        await configService.setWindowsShell('powershell');
      }
    }

    // 确保 TerminalService 有 ConfigService 引用
    terminalService.setConfigService(configService);
    terminalService.openTerminalPanel();
  }

  /// 刷新按钮
  Widget _buildRefreshButton(BuildContext context, bool disabled) {
    return IconButton(
      icon: Icon(Icons.refresh, color: disabled ? Colors.grey : null),
      tooltip: disabled ? S.get('claude_not_installed_title') : '刷新配置',
      onPressed: disabled ? null : () async {
        await Provider.of<ConfigService>(context, listen: false).reloadProfiles();
        if (context.mounted) {
          Toast.show(context, message: '配置已刷新', type: ToastType.success);
        }
      },
    );
  }

  /// 添加按钮
  Widget _buildAddButton(BuildContext context, bool disabled) {
    return FloatingActionButton.small(
      onPressed: disabled ? null : () => _handleAdd(context),
      backgroundColor: disabled ? Colors.grey : Colors.orange,
      elevation: 0,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  /// 处理添加操作
  void _handleAdd(BuildContext context) {
    if (selectedEditor == EditorType.cursor) {
      Toast.show(
        context,
        message: 'Cursor 请前往客户端界面进行编辑',
        type: ToastType.info,
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => McpServerEditScreen(editorType: selectedEditor),
      ),
    );
  }
}
