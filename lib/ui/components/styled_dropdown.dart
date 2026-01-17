import 'package:flutter/material.dart';

/// 通用的下拉选择组件，风格与项目保持一致
/// 比原生 DropdownButton 更紧凑美观
class StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<StyledDropdownItem<T>> items;
  final void Function(T) onChanged;
  final double? width;
  final String? hint;
  final bool dense;

  const StyledDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width,
    this.hint,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedItem = items.firstWhere(
      (item) => item.value == value,
      orElse: () => items.first,
    );

    return SizedBox(
      width: width,
      child: PopupMenuButton<T>(
        tooltip: '',
        offset: const Offset(0, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4,
        shadowColor: Colors.black26,
        color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
        onSelected: onChanged,
        itemBuilder: (context) {
          return items.map<PopupMenuEntry<T>>((item) {
            final isSelected = item.value == value;
            return PopupMenuItem<T>(
              value: item.value,
              height: dense ? 36 : 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: dense ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Flexible(
                child: Text(
                  selectedItem.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 下拉选项
class StyledDropdownItem<T> {
  final T value;
  final String label;

  const StyledDropdownItem({
    required this.value,
    required this.label,
  });
}
