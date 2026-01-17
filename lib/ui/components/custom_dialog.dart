import 'package:flutter/material.dart';

class CustomConfirmDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmText;
  final String cancelText;
  final Color confirmColor;
  final VoidCallback? onConfirm;
  final bool isDark;

  const CustomConfirmDialog({
    super.key,
    required this.title,
    required this.content,
    this.onConfirm,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.confirmColor = Colors.blue,
    this.isDark = false,
  });

  /// 显示确认弹窗，返回用户选择结果
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String content,
    VoidCallback? onConfirm,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.blue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => CustomConfirmDialog(
        title: title,
        content: content,
        onConfirm: onConfirm,
        confirmText: confirmText,
        cancelText: cancelText,
        confirmColor: confirmColor,
        isDark: isDark,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final contentColor = isDark ? Colors.white70 : Colors.black54;
    final cancelTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: contentColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: cancelTextColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(cancelText),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirm?.call();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
