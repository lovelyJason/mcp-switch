import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/editor_type.dart';
import '../../l10n/s.dart';

/// MCP 配置页面可用的编辑器类型
class McpEditorInfo {
  final EditorType type;
  final bool canEdit; // 是否可以在此页面编辑配置

  const McpEditorInfo({
    required this.type,
    required this.canEdit,
  });

  /// 支持 MCP 配置的编辑器
  static final List<McpEditorInfo> all = [
    const McpEditorInfo(type: EditorType.claude, canEdit: true),
    const McpEditorInfo(type: EditorType.cursor, canEdit: false), // Cursor 需要在客户端配置
    const McpEditorInfo(type: EditorType.windsurf, canEdit: true),
    const McpEditorInfo(type: EditorType.codex, canEdit: true),
    const McpEditorInfo(type: EditorType.antigravity, canEdit: true),
    const McpEditorInfo(type: EditorType.gemini, canEdit: true),
  ];
}

/// MCP 编辑器切换下拉按钮组件
class McpEditorSwitcher extends StatelessWidget {
  final EditorType currentEditor;
  final void Function(EditorType editor) onSwitch;

  const McpEditorSwitcher({
    super.key,
    required this.currentEditor,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<EditorType>(
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 8,
      shadowColor: Colors.black45,
      tooltip: S.get('switch_skills_editor'),
      onSelected: (editor) {
        final info = McpEditorInfo.all.firstWhere(
          (i) => i.type == editor,
          orElse: () => McpEditorInfo.all.first,
        );
        if (!info.canEdit) return; // 不可编辑的编辑器不响应
        onSwitch(editor);
      },
      itemBuilder: (context) => McpEditorInfo.all.map((info) {
        final isSelected = info.type == currentEditor;
        final isDisabled = !info.canEdit;

        return PopupMenuItem<EditorType>(
          value: info.type,
          enabled: !isDisabled,
          height: 40,
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(info.type, isDark, isDisabled: isDisabled),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.type.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isDisabled
                          ? Colors.grey
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 16, color: Colors.deepPurple),
                if (isDisabled)
                  Text(
                    S.get('not_available'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(currentEditor, isDark),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(EditorType type, bool isDark, {bool isDisabled = false}) {
    final color = isDisabled ? Colors.grey : (isDark ? Colors.white70 : Colors.black87);
    const double size = 16;

    switch (type) {
      case EditorType.claude:
        return SvgPicture.asset(
          'assets/icons/claude.svg',
          width: size,
          height: size,
          colorFilter: const ColorFilter.mode(Color(0xFFd97757), BlendMode.srcIn),
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
          colorFilter: isDisabled
              ? ColorFilter.mode(Colors.grey, BlendMode.srcIn)
              : null,
        );
      case EditorType.windsurf:
        return SvgPicture.asset(
          'assets/icons/windsurf.svg',
          width: size,
          height: size,
        );
      case EditorType.antigravity:
        return SvgPicture.asset(
          'assets/icons/antigravity.svg',
          width: size,
          height: size,
        );
      case EditorType.gemini:
        return SvgPicture.asset(
          'assets/icons/gemini.svg',
          width: size,
          height: size,
        );
    }
  }
}
