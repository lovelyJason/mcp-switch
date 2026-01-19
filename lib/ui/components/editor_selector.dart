
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui';
import '../../models/editor_type.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EditorSelector extends StatefulWidget {
  final EditorType selected;
  final ValueChanged<EditorType> onChanged;
  final bool enabled;

  const EditorSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<EditorSelector> createState() => _EditorSelectorState();
}

class _EditorSelectorState extends State<EditorSelector> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 延迟滚动到选中项，确保布局完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected();
    });
  }

  @override
  void didUpdateWidget(EditorSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当选中项变化时，滚动到新选中项
    if (oldWidget.selected != widget.selected) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;

    final index = EditorType.values.indexOf(widget.selected);
    if (index < 0) return;

    // 每个 tab 大约宽度（图标16 + 间距8 + 文字约60 + padding24）≈ 108
    // 但因为文字长度不同，这里用估算值
    const double estimatedTabWidth = 110.0;
    final targetOffset = index * estimatedTabWidth;

    // 确保不超出滚动范围
    final maxScroll = _scrollController.position.maxScrollExtent;
    final scrollTo = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      scrollTo,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 这里是顶部 Tab 栏
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final offset = _scrollController.offset + event.scrollDelta.dy;
            if (event.scrollDelta.dy != 0) {
              _scrollController.jumpTo(
                offset.clamp(
                  _scrollController.position.minScrollExtent,
                  _scrollController.position.maxScrollExtent,
                ),
              );
            }
          }
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Opacity(
              opacity: widget.enabled ? 1.0 : 0.5,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: EditorType.values.map((type) {
                  final isSelected = type == widget.selected;
                  return GestureDetector(
                    onTap: widget.enabled ? () => widget.onChanged(type) : null,
                    child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                      child: Row(
                        children: [
                          _buildIcon(type, isSelected),
                          const SizedBox(width: 8),
                          Text(
                            type == EditorType.claude
                                ? 'Claude Code'
                                : type.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.black87
                                  : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(EditorType type, bool isSelected) {
    final color = isSelected ? Colors.black87 : Colors.grey;
    const double size = 16;
    
    switch (type) {
      case EditorType.claude:
        return SvgPicture.asset(
          'assets/icons/claude.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(
            Color(0xFFd97757),
            BlendMode.srcIn,
          ),
        );
      case EditorType.gemini:
        return SvgPicture.asset(
          'assets/icons/gemini.svg',
          width: size,
          height: size,
        );
      case EditorType.codex:
         return SvgPicture.asset(
          'assets/icons/chatgpt.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case EditorType.cursor:
        return SvgPicture.asset(
          'assets/icons/cursor.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );
      case EditorType.windsurf:
        return SvgPicture.asset(
          'assets/icons/windsurf.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(
            isSelected ? color : const Color(0xFF0b100f),
            BlendMode.srcIn,
          ),
        );
      case EditorType.antigravity:
        return SvgPicture.asset(
          'assets/icons/antigravity.svg',
          width: size,
          height: size,
        );
    }
  }
}
