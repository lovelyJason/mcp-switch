import 'package:flutter/material.dart';
import '../../l10n/s.dart';

/// Windows Shell 类型
enum WindowsShellType {
  powershell,
  cmd,
}

/// Windows Shell 选择弹窗
/// 在 Windows 平台首次启动终端时显示，让用户选择使用 PowerShell 还是 CMD
class WindowsShellSelectorDialog extends StatelessWidget {
  final bool isDark;

  const WindowsShellSelectorDialog({
    super.key,
    this.isDark = false,
  });

  /// 显示选择弹窗，返回用户选择的 Shell 类型
  static Future<WindowsShellType?> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showGeneralDialog<WindowsShellType>(
      context: context,
      barrierDismissible: false, // 必须选择
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => WindowsShellSelectorDialog(
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
    final cardBgColor = isDark ? const Color(0xFF3C3C3E) : Colors.grey.shade100;
    final cardHoverColor = isDark ? const Color(0xFF4C4C4E) : Colors.grey.shade200;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.terminal,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    S.get('select_shell_title'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                S.get('select_shell_desc'),
                style: TextStyle(
                  fontSize: 13,
                  color: contentColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              // PowerShell 选项
              _ShellOptionCard(
                icon: Icons.electric_bolt,
                iconColor: Colors.blue,
                title: 'PowerShell',
                description: S.get('powershell_desc'),
                recommended: true,
                bgColor: cardBgColor,
                hoverColor: cardHoverColor,
                isDark: isDark,
                onTap: () => Navigator.of(context).pop(WindowsShellType.powershell),
              ),
              const SizedBox(height: 12),
              // CMD 选项
              _ShellOptionCard(
                icon: Icons.code,
                iconColor: Colors.grey,
                title: 'CMD',
                description: S.get('cmd_desc'),
                recommended: false,
                bgColor: cardBgColor,
                hoverColor: cardHoverColor,
                isDark: isDark,
                onTap: () => Navigator.of(context).pop(WindowsShellType.cmd),
              ),
              const SizedBox(height: 16),
              Text(
                S.get('shell_change_hint'),
                style: TextStyle(
                  fontSize: 11,
                  color: contentColor.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShellOptionCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool recommended;
  final Color bgColor;
  final Color hoverColor;
  final bool isDark;
  final VoidCallback onTap;

  const _ShellOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.recommended,
    required this.bgColor,
    required this.hoverColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ShellOptionCard> createState() => _ShellOptionCardState();
}

class _ShellOptionCardState extends State<_ShellOptionCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final titleColor = widget.isDark ? Colors.white : Colors.black87;
    final descColor = widget.isDark ? Colors.white60 : Colors.black54;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovering ? widget.hoverColor : widget.bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovering
                  ? Colors.deepPurple.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        if (widget.recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              S.get('recommended'),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: descColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: _isHovering ? Colors.deepPurple : descColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}