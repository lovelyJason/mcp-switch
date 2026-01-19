import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/editor_type.dart';
import '../../l10n/s.dart';
import 'custom_toast.dart';

/// Skills 页面可用的编辑器类型及其对应的 Skills 界面
class SkillsEditorInfo {
  final EditorType type;
  final bool hasSkillsScreen;
  final String? unavailableHint;

  const SkillsEditorInfo({
    required this.type,
    required this.hasSkillsScreen,
    this.unavailableHint,
  });

  /// 所有编辑器的 Skills 支持信息
  static final List<SkillsEditorInfo> all = [
    const SkillsEditorInfo(
      type: EditorType.claude,
      hasSkillsScreen: true,
    ),
    const SkillsEditorInfo(
      type: EditorType.codex,
      hasSkillsScreen: true,
    ),
    const SkillsEditorInfo(
      type: EditorType.gemini,
      hasSkillsScreen: true,
    ),
    const SkillsEditorInfo(
      type: EditorType.antigravity,
      hasSkillsScreen: true,
    ),
    const SkillsEditorInfo(
      type: EditorType.cursor,
      hasSkillsScreen: false,
      unavailableHint: 'skills_not_supported',
    ),
    const SkillsEditorInfo(
      type: EditorType.windsurf,
      hasSkillsScreen: false,
      unavailableHint: 'skills_not_supported',
    ),
  ];

  static SkillsEditorInfo? getByType(EditorType type) {
    return all.where((info) => info.type == type).firstOrNull;
  }
}

/// 编辑器切换下拉按钮组件
class SkillsEditorSwitcher extends StatelessWidget {
  final EditorType currentEditor;
  final void Function(EditorType editor) onSwitch;

  const SkillsEditorSwitcher({
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
        final info = SkillsEditorInfo.getByType(editor);
        if (info == null || !info.hasSkillsScreen) {
          Toast.show(
            context,
            message: S.get('skills_not_supported_hint'),
            type: ToastType.info,
          );
          return;
        }
        onSwitch(editor);
      },
      itemBuilder: (context) => SkillsEditorInfo.all.map((info) {
        final isSelected = info.type == currentEditor;
        final isDisabled = !info.hasSkillsScreen;

        return PopupMenuItem<EditorType>(
          value: info.type,
          enabled: !isDisabled,
          height: 40,
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIcon(info.type, isSelected, isDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.type == EditorType.claude ? 'Claude Code' : info.type.label,
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
                  Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.deepPurple,
                  ),
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
            _buildIcon(currentEditor, true, isDark),
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

  Widget _buildIcon(EditorType type, bool isSelected, bool isDark) {
    final color = isDark ? Colors.white70 : Colors.black87;
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
          colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn),
        );
      case EditorType.windsurf:
        return SvgPicture.asset(
          'assets/icons/windsurf.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn),
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
