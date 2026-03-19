import 'package:flutter/material.dart';

import '../../../../l10n/s.dart';
import '../../../../services/backup_import_service.dart';

class ConflictWizardDialog extends StatefulWidget {
  final List<ImportConflict> conflicts;

  const ConflictWizardDialog({super.key, required this.conflicts});

  static Future<List<ImportConflict>?> show(
    BuildContext context,
    List<ImportConflict> conflicts,
  ) {
    return showDialog<List<ImportConflict>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ConflictWizardDialog(conflicts: conflicts),
    );
  }

  @override
  State<ConflictWizardDialog> createState() => _ConflictWizardDialogState();
}

class _ConflictWizardDialogState extends State<ConflictWizardDialog> {
  int _currentIndex = 0;
  bool _showManualEdit = false;
  late TextEditingController _manualController;

  ImportConflict get _current => widget.conflicts[_currentIndex];
  bool get _isLast => _currentIndex == widget.conflicts.length - 1;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: _current.backupValue);
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.conflicts.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      surfaceTintColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark, total),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
            Expanded(child: _buildBody(isDark)),
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Row(
        children: [
          Icon(Icons.compare_arrows, size: 20,
              color: Colors.amber.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${S.get('conflict_title')} ${_currentIndex + 1}/$total',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _current.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: S.get('cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Expanded(child: _buildComparisonPanels(isDark)),
          if (_showManualEdit) ...[
            const SizedBox(height: 8),
            _buildManualEditArea(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildComparisonPanels(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildPanel(
          isDark,
          S.get('conflict_local'),
          _current.localValue,
          Colors.blue,
        )),
        const SizedBox(width: 8),
        Expanded(child: _buildPanel(
          isDark,
          S.get('conflict_backup'),
          _current.backupValue,
          Colors.orange,
        )),
      ],
    );
  }

  Widget _buildPanel(bool isDark, String label, String content, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade50,
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualEditArea(bool isDark) {
    return SizedBox(
      height: 120,
      child: TextField(
        controller: _manualController,
        maxLines: null,
        expands: true,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(10),
          filled: true,
          fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Colors.amber.shade300,
            ),
          ),
          hintText: S.get('conflict_manual_hint'),
          hintStyle: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white30 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => setState(() {
              _showManualEdit = !_showManualEdit;
              if (_showManualEdit) {
                _manualController.text = _current.backupValue;
              }
            }),
            icon: Icon(
              _showManualEdit ? Icons.edit_off : Icons.edit,
              size: 14,
            ),
            label: Text(S.get('conflict_manual_edit')),
            style: TextButton.styleFrom(
              foregroundColor: Colors.amber.shade700,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: () => _resolve(ConflictResolution.keepLocal),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(S.get('conflict_keep_local')),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _resolve(ConflictResolution.useBackup),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(S.get('conflict_use_backup')),
          ),
          if (_showManualEdit) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _resolve(ConflictResolution.manual),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: Text(S.get('conflict_apply_manual')),
            ),
          ],
        ],
      ),
    );
  }

  void _resolve(ConflictResolution resolution) {
    _current.resolution = resolution;
    if (resolution == ConflictResolution.manual) {
      _current.manualValue = _manualController.text;
    }

    if (_isLast) {
      Navigator.of(context).pop(widget.conflicts);
      return;
    }

    setState(() {
      _currentIndex++;
      _showManualEdit = false;
      _manualController.text = _current.backupValue;
    });
  }
}
