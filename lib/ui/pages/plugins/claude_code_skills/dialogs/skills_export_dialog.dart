part of '../../claude_code_skills_screen.dart';

/// Claude 品牌橙色
const _exportOrange = Color(0xFFD97757);

/// Skills 导出弹窗
/// 显示可导出的 skills 列表，带复选框选择
class _SkillsExportDialog extends StatefulWidget {
  final List<CommunitySkill> skills;

  const _SkillsExportDialog({required this.skills});

  @override
  State<_SkillsExportDialog> createState() => _SkillsExportDialogState();
}

class _SkillsExportDialogState extends State<_SkillsExportDialog> {
  final Set<String> _selectedSkills = {};
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    // 默认全选
    _selectedSkills.addAll(widget.skills.map((s) => s.name));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(context),
            const Divider(height: 1),
            // 全选/取消全选
            _buildSelectAllRow(isDark),
            const Divider(height: 1),
            // 列表
            Flexible(child: _buildSkillsList(isDark)),
            // 底部按钮
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
          const Icon(Icons.upload_rounded, size: 20, color: _exportOrange),
          const SizedBox(width: 8),
          Text(
            S.get('export_skills_title'),
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
    final allSelected = _selectedSkills.length == widget.skills.length;
    final someSelected = _selectedSkills.isNotEmpty && !allSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: allSelected ? true : (someSelected ? null : false),
            tristate: true,
            onChanged: _isExporting
                ? null
                : (value) {
                    setState(() {
                      if (allSelected || someSelected) {
                        _selectedSkills.clear();
                      } else {
                        _selectedSkills.addAll(widget.skills.map((s) => s.name));
                      }
                    });
                  },
            activeColor: _exportOrange,
          ),
          Text(
            allSelected
                ? S.get('deselect_all')
                : S.get('select_all'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const Spacer(),
          Text(
            '${_selectedSkills.length}/${widget.skills.length}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsList(bool isDark) {
    if (widget.skills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 48,
              color: Colors.grey.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              S.get('no_skills_to_export'),
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: widget.skills.length,
      itemBuilder: (context, index) {
        final skill = widget.skills[index];
        final isSelected = _selectedSkills.contains(skill.name);

        return _buildSkillItem(skill, isSelected, isDark);
      },
    );
  }

  Widget _buildSkillItem(CommunitySkill skill, bool isSelected, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? _exportOrange.withValues(alpha: isDark ? 0.12 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _isExporting
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedSkills.remove(skill.name);
                    } else {
                      _selectedSkills.add(skill.name);
                    }
                  });
                },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: _isExporting
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _selectedSkills.add(skill.name);
                            } else {
                              _selectedSkills.remove(skill.name);
                            }
                          });
                        },
                  activeColor: _exportOrange,
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _exportOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.bolt, size: 14, color: _exportOrange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (skill.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          skill.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (skill.hasSkillMd)
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: Colors.green.withValues(alpha: 0.7),
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
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
            child: Text(S.get('cancel')),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _selectedSkills.isEmpty || _isExporting
                ? null
                : _handleExport,
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
            style: FilledButton.styleFrom(
              backgroundColor: _exportOrange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport() async {
    if (_selectedSkills.isEmpty) return;

    setState(() => _isExporting = true);

    try {
      // 让用户选择保存位置
      final fileName = 'skills_export_${DateTime.now().millisecondsSinceEpoch}.zip';
      final outputPath = await FilePicker.platform.saveFile(
        dialogTitle: S.get('select_export_location'),
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (outputPath == null) {
        setState(() => _isExporting = false);
        return;
      }

      // 确保文件扩展名是 .zip
      final finalPath = outputPath.endsWith('.zip') ? outputPath : '$outputPath.zip';

      // 执行导出
      final archiveService = SkillsArchiveService();
      final (success, error) = await archiveService.exportSkills(
        _selectedSkills.toList(),
        finalPath,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
        Toast.show(
          context,
          message: S.get('export_success'),
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
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}
