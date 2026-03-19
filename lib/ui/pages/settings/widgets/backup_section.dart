import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/database.dart';
import '../../../../l10n/s.dart';
import '../../../../services/backup_import_service.dart';
import '../../../../services/backup_service.dart';
import '../../../../services/config/config_service.dart';
import '../../../components/custom_toast.dart';
import 'conflict_wizard_dialog.dart';
import 'export_dialog.dart';
import 'import_preview_dialog.dart';

class BackupSection extends StatelessWidget {
  const BackupSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.get('backup_section_title'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          S.get('backup_section_desc'),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ActionButton(
              icon: Icons.upload_rounded,
              label: S.get('export_data'),
              color: Colors.orange,
              onTap: () => ExportDialog.show(context),
            ),
            const SizedBox(width: 12),
            _ActionButton(
              icon: Icons.download_rounded,
              label: S.get('import_data'),
              color: Colors.blue,
              onTap: () => _handleImport(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: S.get('import_select_file'),
      type: FileType.custom,
      allowedExtensions: ['mcpsw'],
    );
    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final configService = Provider.of<ConfigService>(context, listen: false);
    final importService = BackupImportService(configService, AppDatabase());

    BackupData data;
    try {
      data = await importService.parseBackupFile(filePath);
    } catch (e) {
      if (!context.mounted) return;
      Toast.show(context,
          message: '${S.get('import_invalid_file')}: $e',
          type: ToastType.error);
      return;
    }

    if (!context.mounted) return;
    final categories = await ImportPreviewDialog.show(context, data);
    if (categories == null || categories.isEmpty) return;

    if (!context.mounted) return;
    _runImport(context, importService, data, categories);
  }

  Future<void> _runImport(
    BuildContext context,
    BackupImportService importService,
    BackupData data,
    List<BackupCategory> categories,
  ) async {
    final importResult =
        await importService.detectConflicts(data, categories);

    if (!context.mounted) return;

    if (importResult.conflicts.isNotEmpty) {
      final resolved = await ConflictWizardDialog.show(
        context,
        importResult.conflicts,
      );
      if (resolved == null) return;
    }

    if (!context.mounted) return;

    final (success, error) =
        await importService.applyImport(data, importResult, categories);

    if (!context.mounted) return;

    if (success) {
      Toast.show(context,
          message: S.get('import_backup_success'), type: ToastType.success);
    } else {
      Toast.show(context,
          message: '${S.get('import_backup_failed')}: $error',
          type: ToastType.error);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onTap == null;
    final effectiveColor = isDisabled ? Colors.grey.shade500 : color;

    Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDisabled
              ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
              : effectiveColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDisabled
                ? (isDark ? Colors.grey.shade800 : Colors.grey.shade300)
                : effectiveColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDisabled
                    ? Colors.grey.shade500
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );

    return button;
  }
}
