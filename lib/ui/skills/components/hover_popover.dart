import 'package:flutter/material.dart';

/// Hover Popover 组件 - Ant Design 风格
/// 鼠标悬浮时显示提示信息
class HoverPopover extends StatefulWidget {
  final String message;
  final bool isDark;

  const HoverPopover({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  State<HoverPopover> createState() => _HoverPopoverState();
}

class _HoverPopoverState extends State<HoverPopover> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _iconKey = GlobalKey();

  void _showPopover() {
    if (_overlayEntry != null) return;

    // 获取图标位置
    final RenderBox? renderBox =
        _iconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final iconPosition = renderBox.localToGlobal(Offset.zero);
    final screenWidth = MediaQuery.of(context).size.width;
    const popoverWidth = 240.0;

    // 判断显示方向：靠近右边界时往左显示，否则往右显示
    final bool showOnLeft = iconPosition.dx + popoverWidth + 20 > screenWidth;

    // 计算位置
    final double left =
        showOnLeft ? iconPosition.dx - popoverWidth - 8 : iconPosition.dx + 20;
    final double top = iconPosition.dy + 20;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        width: popoverWidth,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF3A3A3C) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.isDark
                    ? Colors.grey.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.white70 : Colors.black87,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hidePopover() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hidePopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showPopover(),
      onExit: (_) => _hidePopover(),
      child: Padding(
        key: _iconKey,
        padding: const EdgeInsets.only(left: 4),
        child: Icon(
          Icons.help_outline,
          size: 14,
          color: widget.isDark ? Colors.grey.shade400 : Colors.grey.shade500,
        ),
      ),
    );
  }
}
