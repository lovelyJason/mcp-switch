import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../config/mcp_presets_config.dart';
import '../../../../l10n/s.dart';
import '../../../../models/editor_type.dart';
import '../../../components/mcp_editor_switcher.dart';

/// 预设 Chip 按钮
class PresetChip extends StatelessWidget {
  final McpPreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const PresetChip({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preset.icon != null) ...[
              SvgPicture.asset(
                preset.icon!,
                width: 16,
                height: 16,
                placeholderBuilder: (context) =>
                    const SizedBox(width: 16, height: 16),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              preset.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.blue
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            // 灯泡提示图标
            if (preset.tips != null) ...[
              const SizedBox(width: 6),
              Tooltip(
                richMessage: WidgetSpan(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      preset.tips!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                preferBelow: false,
                verticalOffset: 16,
                waitDuration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 14,
                  color: isSelected
                      ? Colors.blue.shade300
                      : (isDark ? Colors.white54 : Colors.grey.shade500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 连接类型 Radio 选项
class ConnectionTypeRadio extends StatelessWidget {
  final McpConnectionType connType;
  final String groupValue;
  final ConnectionTypeDef? def;
  final ValueChanged<String> onChanged;

  const ConnectionTypeRadio({
    super.key,
    required this.connType,
    required this.groupValue,
    required this.def,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: InkWell(
        onTap: () => onChanged(connType.type),
        borderRadius: BorderRadius.circular(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: connType.type,
              groupValue: groupValue,
              onChanged: (v) => onChanged(v ?? 'local'),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            Text(def?.displayLabel ?? connType.type),
            if (connType.recommended) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  S.get('recommended'),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 保存模式切换按钮
class SaveModeToggle extends StatelessWidget {
  final String currentMode;
  final ValueChanged<String> onModeChanged;

  const SaveModeToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildOption('file', S.get('save_mode_file'), isDark),
          const SizedBox(width: 4),
          _buildOption('cli', S.get('save_mode_cli'), isDark),
        ],
      ),
    );
  }

  Widget _buildOption(String mode, String label, bool isDark) {
    final isSelected = currentMode == mode;
    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.shade700 : Colors.blue)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

/// 导入/导出按钮组
class ImportExportButtons extends StatelessWidget {
  final VoidCallback onImport;
  final VoidCallback onExport;

  const ImportExportButtons({
    super.key,
    required this.onImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.file_upload_outlined,
            size: 20,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          tooltip: S.get('import_presets'),
          onPressed: onImport,
        ),
        IconButton(
          icon: Icon(
            Icons.file_download_outlined,
            size: 20,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          tooltip: S.get('export_presets'),
          onPressed: onExport,
        ),
      ],
    );
  }
}

/// Section 标题
class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }
}

/// 字段标签
class FieldLabel extends StatelessWidget {
  final String label;
  final String? subLabel;
  final bool required;

  const FieldLabel({
    super.key,
    required this.label,
    this.subLabel,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
          if (subLabel != null && subLabel!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              subLabel!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 底部操作栏
class EditBottomBar extends StatelessWidget {
  final bool isEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const EditBottomBar({
    super.key,
    required this.isEditMode,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
            ),
            child: Text(S.get('cancel')),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onSave,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: const Color(0xFF007AFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.save_outlined, size: 20),
            label: Text(
              isEditMode ? S.get('save') : S.get('add'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// 编辑页面头部
class EditHeader extends StatelessWidget {
  final EditorType editorType;
  final bool isEditMode;
  final String claudeSaveMode;
  final ValueChanged<String> onSaveModeChanged;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final VoidCallback onBack;
  final ValueChanged<EditorType>? onEditorTypeChanged;

  const EditHeader({
    super.key,
    required this.editorType,
    required this.isEditMode,
    required this.claudeSaveMode,
    required this.onSaveModeChanged,
    required this.onImport,
    required this.onExport,
    required this.onBack,
    this.onEditorTypeChanged,
  });

  String? _getEditorIconPath(EditorType type) {
    switch (type) {
      case EditorType.cursor:
        return 'assets/icons/cursor.svg';
      case EditorType.windsurf:
        return 'assets/icons/windsurf.svg';
      case EditorType.claude:
        return 'assets/icons/claude.svg';
      case EditorType.codex:
        return 'assets/icons/codex.svg';
      case EditorType.antigravity:
        return 'assets/icons/antigravity.svg';
      case EditorType.gemini:
        return 'assets/icons/gemini.svg';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.only(top: 38, left: 24, right: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onBack,
            ),
          ),
          const SizedBox(width: 16),
          if (_getEditorIconPath(editorType) != null) ...[
            SvgPicture.asset(
              _getEditorIconPath(editorType)!,
              width: 24,
              height: 24,
              colorFilter: (editorType == EditorType.claude ||
                      editorType == EditorType.codex)
                  ? const ColorFilter.mode(Color(0xFFd97757), BlendMode.srcIn)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            isEditMode
                ? S.get('edit_mcp_title').replaceAll('{editor}', editorType.label)
                : S.get('add_mcp_title').replaceAll('{editor}', editorType.label),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          // 编辑器切换下拉按钮（仅新增模式且提供了回调时显示）- 放在标题旁边
          if (!isEditMode && onEditorTypeChanged != null) ...[
            const SizedBox(width: 8),
            McpEditorSwitcher(
              currentEditor: editorType,
              onSwitch: onEditorTypeChanged!,
            ),
          ],
          const Spacer(),
          if (!isEditMode) ...[
            ImportExportButtons(onImport: onImport, onExport: onExport),
            const SizedBox(width: 12),
          ],
          if (editorType == EditorType.claude && !isEditMode)
            SaveModeToggle(
              currentMode: claudeSaveMode,
              onModeChanged: onSaveModeChanged,
            ),
        ],
      ),
    );
  }
}

