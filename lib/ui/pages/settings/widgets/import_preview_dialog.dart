import 'package:flutter/material.dart';

import '../../../../l10n/s.dart';
import '../../../../services/backup_service.dart';
import '../../../../services/backup_import_service.dart';

class ImportPreviewDialog extends StatefulWidget {
  final BackupData data;

  const ImportPreviewDialog({super.key, required this.data});

  static Future<List<BackupCategory>?> show(
    BuildContext context,
    BackupData data,
  ) {
    return showDialog<List<BackupCategory>>(
      context: context,
      builder: (_) => ImportPreviewDialog(data: data),
    );
  }

  @override
  State<ImportPreviewDialog> createState() => _ImportPreviewDialogState();
}

class _ImportPreviewDialogState extends State<ImportPreviewDialog> {
  final Set<BackupCategory> _selected = {};

  @override
  void initState() {
    super.initState();
    for (final cat in BackupCategory.values) {
      if (widget.data.categories.contains(cat.name)) {
        _selected.add(cat);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = BackupCategory.values
        .where((c) => widget.data.categories.contains(c.name))
        .toList();
    final manifest = widget.data.manifest;
    final exportDate = manifest['exportDate'] as String? ?? '';
    final appVer = manifest['appVersion'] as String? ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            _buildMeta(isDark, exportDate, appVer),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            Flexible(child: _buildCategoryList(isDark, available)),
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
          const Icon(Icons.download_rounded, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Text(
            S.get('import_backup_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(bool isDark, String date, String version) {
    final dateDisplay = date.length >= 10 ? date.substring(0, 10) : date;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 14,
              color: isDark ? Colors.white38 : Colors.black38),
          const SizedBox(width: 8),
          Text(
            '${S.get('import_export_date')}: $dateDisplay',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            version,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(bool isDark, List<BackupCategory> available) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      children: available.map((c) => _buildItem(c, isDark)).toList(),
    );
  }

  Widget _buildItem(BackupCategory category, bool isDark) {
    final isSelected = _selected.contains(category);
    final info = _categoryMeta(category);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? Colors.orange.withValues(alpha: isDark ? 0.12 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => setState(() {
            isSelected ? _selected.remove(category) : _selected.add(category);
          }),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => setState(() {
                    isSelected
                        ? _selected.remove(category)
                        : _selected.add(category);
                  }),
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
                  child: Text(
                    info.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(S.get('cancel')),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed:
                _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
            icon: const Icon(Icons.download, size: 18),
            label: Text(S.get('import_start')),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color, String title}) _categoryMeta(
    BackupCategory c,
  ) {
    switch (c) {
      case BackupCategory.preferences:
        return (
          icon: Icons.settings_outlined,
          color: Colors.blue,
          title: S.get('export_cat_preferences'),
        );
      case BackupCategory.mcpConfigs:
        return (
          icon: Icons.dns_outlined,
          color: Colors.teal,
          title: S.get('export_cat_mcp_configs'),
        );
      case BackupCategory.prompts:
        return (
          icon: Icons.article_outlined,
          color: Colors.purple,
          title: S.get('export_cat_prompts'),
        );
      case BackupCategory.skills:
        return (
          icon: Icons.extension_outlined,
          color: Colors.orange,
          title: S.get('export_cat_skills'),
        );
      case BackupCategory.providers:
        return (
          icon: Icons.storage_outlined,
          color: Colors.indigo,
          title: S.get('export_cat_providers'),
        );
    }
  }
}
