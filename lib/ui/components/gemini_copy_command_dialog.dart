import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/platform_commands_config.dart';
import '../../l10n/s.dart';

/// Gemini 复制安装命令弹窗
class GeminiCopyCommandDialog extends StatefulWidget {
  const GeminiCopyCommandDialog({super.key});

  /// 显示弹窗
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const GeminiCopyCommandDialog(),
    );
  }

  @override
  State<GeminiCopyCommandDialog> createState() => _GeminiCopyCommandDialogState();
}

class _GeminiCopyCommandDialogState extends State<GeminiCopyCommandDialog> {
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final command = PlatformCommandsConfig.geminiDisplayCommand;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.terminal, color: Colors.blue, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      S.get('gemini_copy_install_command'),
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
                S.get('gemini_copy_command_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),

            // 命令内容区
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
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
                          color: Colors.blue.shade300,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 底部复制按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _copyCommand,
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
        ),
      ),
    );
  }

  void _copyCommand() {
    final command = PlatformCommandsConfig.geminiDisplayCommand;
    Clipboard.setData(ClipboardData(text: command));
    setState(() => _isCopied = true);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }
}
