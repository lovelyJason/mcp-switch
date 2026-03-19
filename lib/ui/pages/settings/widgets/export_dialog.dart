import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../data/database.dart';
import '../../../../l10n/s.dart';
import '../../../../services/backup_service.dart';
import '../../../../services/config/config_service.dart';
import '../../../components/custom_toast.dart';

class ExportDialog extends StatefulWidget {
  const ExportDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const ExportDialog(),
    );
  }

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final Set<BackupCategory> _selected = Set.of(BackupCategory.values);
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            _buildSelectAllRow(isDark),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            Flexible(child: _buildCategoryList(isDark)),
            _buildFooter(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          const Icon(Icons.upload_rounded, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            S.get('export_backup_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllRow(bool isDark) {
    final allSelected = _selected.length == BackupCategory.values.length;
    final someSelected = _selected.isNotEmpty && !allSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: allSelected ? true : (someSelected ? null : false),
            tristate: true,
            onChanged: _isExporting
                ? null
                : (_) => setState(() {
                      if (allSelected || someSelected) {
                        _selected.clear();
                      } else {
                        _selected.addAll(BackupCategory.values);
                      }
                    }),
            activeColor: Colors.orange,
          ),
          Text(
            allSelected ? S.get('deselect_all') : S.get('select_all'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const Spacer(),
          Text(
            '${_selected.length}/${BackupCategory.values.length}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(bool isDark) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: BackupCategory.values
          .map((c) => _buildCategoryItem(c, isDark))
          .toList(),
    );
  }

  Widget _buildCategoryItem(BackupCategory category, bool isDark) {
    final isSelected = _selected.contains(category);
    final info = _categoryInfo(category);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? Colors.orange.withValues(alpha: isDark ? 0.12 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _isExporting ? null : () => _toggleCategory(category),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: _isExporting
                      ? null
                      : (_) => _toggleCategory(category),
                  activeColor: Colors.orange,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(info.icon, size: 16, color: info.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    final hasSensitive = _selected.contains(BackupCategory.preferences);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSensitive)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      S.get('export_sensitive_warning'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _isExporting ? null : () => Navigator.of(context).pop(),
                child: Text(S.get('cancel')),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed:
                    _selected.isEmpty || _isExporting ? null : _handleExport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(S.get('export')),
                style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _toggleCategory(BackupCategory category) {
    setState(() {
      if (_selected.contains(category)) {
        _selected.remove(category);
      } else {
        _selected.add(category);
      }
    });
  }

  Future<void> _handleExport() async {
    if (_selected.isEmpty) return;

    final configService =
        Provider.of<ConfigService>(context, listen: false);

    setState(() => _isExporting = true);

    try {
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'mcp_switch_backup_$dateStr.mcpsw';

      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: S.get('export_select_location'),
        fileName: fileName,
      );

      if (outputPath == null) {
        setState(() => _isExporting = false);
        return;
      }

      final finalPath =
          outputPath.endsWith('.mcpsw') ? outputPath : '$outputPath.mcpsw';

      final service = BackupService(configService, AppDatabase());
      final (success, error) =
          await service.exportBackup(_selected.toList(), finalPath);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
        Toast.show(
          context,
          message: S.get('export_backup_success'),
          type: ToastType.success,
        );
      } else {
        Toast.show(
          context,
          message: '${S.get('export_failed')}: $error',
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('export_failed')}: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  _CategoryInfo _categoryInfo(BackupCategory category) {
    switch (category) {
      case BackupCategory.preferences:
        return _CategoryInfo(
          icon: Icons.settings_outlined,
          color: Colors.blue,
          title: S.get('export_cat_preferences'),
          subtitle: S.get('export_cat_preferences_desc'),
        );
      case BackupCategory.mcpConfigs:
        return _CategoryInfo(
          icon: Icons.dns_outlined,
          color: Colors.teal,
          title: S.get('export_cat_mcp_configs'),
          subtitle: S.get('export_cat_mcp_configs_desc'),
        );
      case BackupCategory.prompts:
        return _CategoryInfo(
          icon: Icons.article_outlined,
          color: Colors.purple,
          title: S.get('export_cat_prompts'),
          subtitle: S.get('export_cat_prompts_desc'),
        );
      case BackupCategory.skills:
        return _CategoryInfo(
          icon: Icons.extension_outlined,
          color: Colors.orange,
          title: S.get('export_cat_skills'),
          subtitle: S.get('export_cat_skills_desc'),
        );
      case BackupCategory.providers:
        return _CategoryInfo(
          icon: Icons.storage_outlined,
          color: Colors.indigo,
          title: S.get('export_cat_providers'),
          subtitle: S.get('export_cat_providers_desc'),
        );
    }
  }
}

class _CategoryInfo {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _CategoryInfo({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
