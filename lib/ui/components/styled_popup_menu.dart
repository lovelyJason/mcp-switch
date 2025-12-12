import 'package:flutter/material.dart';

class StyledPopupMenu<T> extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String? tooltip;
  final void Function(T) onSelected;
  final List<StyledPopupMenuItem<T>> items;
  final Offset offset;

  const StyledPopupMenu({
    super.key,
    this.icon,
    this.iconWidget,
    this.tooltip,
    required this.onSelected,
    required this.items,
    this.offset = const Offset(0, 48),
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        // Enable nice interaction effects
        splashFactory: InkRipple.splashFactory,
        hoverColor: const Color(0xFFF2F8FF), // Light Blue tint for hover
        highlightColor: const Color(0xFFE6F0FF),
        splashColor: const Color(0xFFD6E6FF),
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.withOpacity(0.12), width: 1),
          ),
          textStyle: const TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        icon: iconWidget ??
            Icon(icon ?? Icons.more_vert, color: Colors.grey.shade700, size: 20),
        splashRadius: 20,
        padding: EdgeInsets.zero,
        offset: offset,
        onSelected: onSelected,
        itemBuilder: (context) {
          return items.map<PopupMenuEntry<T>>((item) {
            if (item.isDivider) {
              return const PopupMenuDivider(height: 1);
            }
            return PopupMenuItem<T>(
              value: item.value,
              height: 40, // Slightly taller for better hit target
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _buildItemContent(item),
            );
          }).toList();
        },
      ),
    );
  }

  Widget _buildItemContent(StyledPopupMenuItem<T> item) {
    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            item.label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

class StyledPopupMenuItem<T> {
  final T? value;
  final String label;
  final IconData? icon;
  final bool isDivider;

  const StyledPopupMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.isDivider = false,
  });

  const StyledPopupMenuItem.divider()
      : value = null,
        label = '',
        icon = null,
        isDivider = true;
}
