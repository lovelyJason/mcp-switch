import 'package:flutter/material.dart';

/// A card wrapper that adds a premium hover effect:
/// - Lifts up with increased shadow
/// - Border becomes more prominent
/// - Smooth 200ms animation
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.borderRadius = 10,
    this.borderColor,
    this.borderWidth = 1,
    this.onTap,
  });

  final Widget child;
  final double borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBorder =
        widget.borderColor ?? Colors.grey.withValues(alpha: 0.2);
    final hoverBorder = widget.borderColor != null
        ? widget.borderColor!.withValues(alpha: 0.7)
        : (isDark ? Colors.grey.shade600 : Colors.grey.shade400);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor:
          widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: _hovering
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _hovering ? hoverBorder : baseBorder,
            width: widget.borderWidth,
          ),
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          clipBehavior: Clip.antiAlias,
          child: widget.onTap != null
              ? InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: widget.child,
                )
              : widget.child,
        ),
      ),
    );
  }
}
