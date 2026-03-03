import 'package:flutter/material.dart';
import '../../l10n/s.dart';

enum CursorMcpAction { operateHere, openInCursor }

/// Cursor MCP 开关操作选择弹窗
///
/// 解释正反向同步差异，提供两种操作路径：
/// - 在当前软件操作（写 SQLite，需重启 Cursor）
/// - 在 Cursor 中操作（自动打开 Settings，即时生效）
class CursorMcpActionDialog extends StatelessWidget {
  final bool isDark;
  const CursorMcpActionDialog._({required this.isDark});

  static Future<CursorMcpAction?> show(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showGeneralDialog<CursorMcpAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, a1, a2) => CursorMcpActionDialog._(isDark: isDark),
      transitionBuilder: (context, anim, a2, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * anim.value),
          child: Opacity(opacity: anim.value, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final bodyColor = isDark ? Colors.white70 : Colors.black54;
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
              Text(
                S.get('cursor_mcp_action_title'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor),
              ),
              const SizedBox(height: 16),
              _buildSyncInfo(bodyColor),
              const SizedBox(height: 20),
              _buildButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncInfo(Color bodyColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.get('cursor_mcp_action_desc'),
          style: TextStyle(fontSize: 13, color: bodyColor, height: 1.6),
        ),
        const SizedBox(height: 12),
        _buildSyncRow(
          icon: Icons.check_circle_outline,
          color: Colors.green,
          text: S.get('cursor_mcp_sync_forward'),
        ),
        const SizedBox(height: 6),
        _buildSyncRow(
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
          text: S.get('cursor_mcp_sync_reverse'),
        ),
      ],
    );
  }

  Widget _buildSyncRow({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(CursorMcpAction.operateHere),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(S.get('cursor_mcp_operate_here')),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(CursorMcpAction.openInCursor),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(S.get('cursor_mcp_open_in_cursor')),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }
}

/// 漫游引导覆盖层：两步引导用户打开 Cursor Settings > Tools & MCP
class CursorMcpGuideOverlay {
  static Future<void> show(BuildContext context) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, a1, a2) => const _GuideCarousel(),
      transitionBuilder: (context, anim, a2, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }
}

class _GuideStep {
  final String image;
  final String hintKey;
  const _GuideStep({required this.image, required this.hintKey});
}

const _steps = [
  _GuideStep(
    image: 'assets/images/cursor_settings_gear_guide.png',
    hintKey: 'cursor_guide_step1',
  ),
  _GuideStep(
    image: 'assets/images/cursor_tools_mcp_guide.png',
    hintKey: 'cursor_guide_step2',
  ),
];

class _GuideCarousel extends StatefulWidget {
  const _GuideCarousel();
  @override
  State<_GuideCarousel> createState() => _GuideCarouselState();
}

class _GuideCarouselState extends State<_GuideCarousel> {
  static const _secPerStep = 3;
  int _step = 0;
  int _remaining = _secPerStep;

  int get _totalRemaining => (_steps.length - _step - 1) * _secPerStep + _remaining;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        if (_step < _steps.length - 1) {
          setState(() {
            _step++;
            _remaining = _secPerStep;
          });
          return true;
        }
        if (mounted) Navigator.of(context).pop();
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final step = _steps[_step];

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(_step),
                  constraints: BoxConstraints(maxWidth: 360, maxHeight: screenHeight * 0.55),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(step.image, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  S.get(step.hintKey),
                  key: ValueKey(step.hintKey),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('${S.get('cursor_mcp_guide_dismiss')}  $_totalRemaining s'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_steps.length, (i) {
        final isActive = i == _step;
        return Container(
          width: isActive ? 20 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isActive
                ? Colors.orange
                : Colors.white.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}
