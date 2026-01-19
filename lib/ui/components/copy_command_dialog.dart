import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/platform_commands_config.dart';
import '../../l10n/s.dart';

/// 复制安装命令弹窗
/// 使用 Tab 切换显示当前平台所有可用 shell 的安装命令
class CopyCommandDialog extends StatefulWidget {
  const CopyCommandDialog({super.key});

  /// 显示弹窗
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const CopyCommandDialog(),
    );
  }

  @override
  State<CopyCommandDialog> createState() => _CopyCommandDialogState();
}

class _CopyCommandDialogState extends State<CopyCommandDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isCopied = false;
  final List<Map<String, dynamic>> _shells = PlatformCommandsConfig.allShellConfigs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _shells.length, vsync: this);
    _tabController.addListener(() {
      if (_isCopied) setState(() => _isCopied = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.terminal, color: Colors.deepPurple, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      S.get('copy_install_command'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: S.get('close'),
                  ),
                ],
              ),
            ),

            // 提示文字
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                S.get('copy_command_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),

            if (_shells.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(child: Text(S.get('no_shell_config'))),
              )
            else ...[
              // Tab 栏
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.deepPurple,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: _shells.map((shell) {
                    final name = shell['name'] as String? ?? '';
                    final displayName = shell['display_name'] as String? ?? name;
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getShellIcon(name), size: 16),
                          const SizedBox(width: 6),
                          Flexible(child: Text(displayName, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // 命令内容区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TabBarView(
                    controller: _tabController,
                    children: _shells.map((shell) {
                      final name = shell['name'] as String? ?? '';
                      final command = PlatformCommandsConfig.getFullCommandForShell(name);
                      return _buildCommandArea(command, isDark);
                    }).toList(),
                  ),
                ),
              ),

              // 底部复制按钮
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _copyCurrentCommand,
                    icon: Icon(_isCopied ? Icons.check : Icons.copy, size: 18),
                    label: Text(_isCopied ? S.get('copied') : S.get('copy')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCopied ? Colors.green : Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommandArea(String command, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade600,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            command,
            style: TextStyle(
              fontFamily: 'Menlo, Monaco, Consolas, monospace',
              fontSize: 12,
              color: Colors.green.shade300,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  void _copyCurrentCommand() {
    if (_shells.isEmpty) return;
    final currentShell = _shells[_tabController.index];
    final name = currentShell['name'] as String? ?? '';
    final command = PlatformCommandsConfig.getFullCommandForShell(name);

    Clipboard.setData(ClipboardData(text: command));
    setState(() => _isCopied = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  IconData _getShellIcon(String name) {
    switch (name.toLowerCase()) {
      case 'powershell':
        return Icons.terminal;
      case 'cmd':
        return Icons.computer;
      case 'bash':
      case 'zsh':
        return Icons.code;
      default:
        return Icons.terminal;
    }
  }
}