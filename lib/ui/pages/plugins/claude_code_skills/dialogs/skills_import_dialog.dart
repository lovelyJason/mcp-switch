part of '../../claude_code_skills_screen.dart';

/// Claude 品牌橙色
const _importOrange = Color(0xFFD97757);

/// Skills 导入弹窗
/// 处理 zip 文件导入和冲突解决
class _SkillsImportDialog extends StatefulWidget {
  final String zipPath;

  const _SkillsImportDialog({required this.zipPath});

  @override
  State<_SkillsImportDialog> createState() => _SkillsImportDialogState();
}

class _SkillsImportDialogState extends State<_SkillsImportDialog> {
  final SkillsArchiveService _archiveService = SkillsArchiveService();

  List<SkillImportInfo>? _skills;
  String? _error;
  bool _isLoading = true;
  bool _isImporting = false;

  // 每个 skill 的导入决定
  final Map<String, SkillConflictResolution> _resolutions = {};
  final Map<String, String> _renamedNames = {};
  final Map<String, TextEditingController> _renameControllers = {};

  // 导入结果
  int _importedCount = 0;
  int _skippedCount = 0;

  @override
  void initState() {
    super.initState();
    _analyzeZip();
  }

  @override
  void dispose() {
    for (final controller in _renameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _analyzeZip() async {
    final (skills, error) = await _archiveService.extractAndAnalyze(widget.zipPath);

    if (!mounted) return;

    setState(() {
      _skills = skills;
      _error = error;
      _isLoading = false;

      // 初始化每个 skill 的默认决定
      for (final skill in skills) {
        if (skill.conflictType == SkillConflictType.exists) {
          _resolutions[skill.name] = SkillConflictResolution.skip;
        } else {
          _resolutions[skill.name] = SkillConflictResolution.overwrite; // 无冲突，直接导入
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Flexible(child: _buildContent(isDark)),
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
          const Icon(Icons.download_rounded, size: 20, color: _importOrange),
          const SizedBox(width: 8),
          Text(
            S.get('import_skills_title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(color: _importOrange),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              S.get('import_analyze_failed'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_skills == null || _skills!.isEmpty) {
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
              S.get('no_skills_in_zip'),
              style: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _skills!.length,
      itemBuilder: (context, index) => _buildSkillItem(_skills![index], isDark),
    );
  }

  Widget _buildSkillItem(SkillImportInfo skill, bool isDark) {
    final hasConflict = skill.conflictType == SkillConflictType.exists;
    final resolution = _resolutions[skill.name] ?? SkillConflictResolution.skip;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasConflict
            ? Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05)
            : _importOrange.withValues(alpha: isDark ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasConflict
              ? Colors.orange.withValues(alpha: 0.3)
              : _importOrange.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：名称 + 冲突标记
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _importOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bolt, size: 14, color: _importOrange),
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
                        fontSize: 14,
                      ),
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
              if (hasConflict)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        S.get('conflict'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // 冲突解决选项
          if (hasConflict) ...[
            const SizedBox(height: 12),
            _buildConflictOptions(skill, resolution, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildConflictOptions(
    SkillImportInfo skill,
    SkillConflictResolution resolution,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 跳过
        _buildRadioOption(
          skill: skill,
          value: SkillConflictResolution.skip,
          current: resolution,
          label: S.get('skip_import'),
          icon: Icons.skip_next,
          isDark: isDark,
        ),
        const SizedBox(height: 6),
        // 覆盖
        _buildRadioOption(
          skill: skill,
          value: SkillConflictResolution.overwrite,
          current: resolution,
          label: S.get('overwrite_existing'),
          icon: Icons.sync,
          isDark: isDark,
          isDestructive: true,
        ),
        const SizedBox(height: 6),
        // 重命名
        _buildRadioOption(
          skill: skill,
          value: SkillConflictResolution.rename,
          current: resolution,
          label: S.get('rename_import'),
          icon: Icons.edit,
          isDark: isDark,
        ),
        // 重命名输入框
        if (resolution == SkillConflictResolution.rename) ...[
          const SizedBox(height: 8),
          _buildRenameInput(skill, isDark),
        ],
      ],
    );
  }

  Widget _buildRadioOption({
    required SkillImportInfo skill,
    required SkillConflictResolution value,
    required SkillConflictResolution current,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isDestructive = false,
  }) {
    final isSelected = current == value;
    final color = isDestructive ? Colors.red : _importOrange;

    return InkWell(
      onTap: _isImporting
          ? null
          : () {
              setState(() {
                _resolutions[skill.name] = value;
                if (value == SkillConflictResolution.rename &&
                    !_renamedNames.containsKey(skill.name)) {
                  // 自动生成建议名称
                  _generateSuggestedName(skill.name);
                }
              });
            },
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Radio<SkillConflictResolution>(
              value: value,
              groupValue: current,
              onChanged: _isImporting
                  ? null
                  : (v) {
                      setState(() {
                        _resolutions[skill.name] = v!;
                        if (v == SkillConflictResolution.rename &&
                            !_renamedNames.containsKey(skill.name)) {
                          _generateSuggestedName(skill.name);
                        }
                      });
                    },
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Icon(icon, size: 14, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? (isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87))
                    : (isDark ? Colors.white54 : Colors.black45),
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRenameInput(SkillImportInfo skill, bool isDark) {
    _renameControllers[skill.name] ??= TextEditingController(
      text: _renamedNames[skill.name] ?? '${skill.name}_new',
    );

    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: TextField(
        controller: _renameControllers[skill.name],
        enabled: !_isImporting,
        decoration: InputDecoration(
          hintText: S.get('enter_new_name'),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _importOrange.withValues(alpha: 0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: _importOrange.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _importOrange),
          ),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (value) {
          _renamedNames[skill.name] = value;
        },
      ),
    );
  }

  Future<void> _generateSuggestedName(String baseName) async {
    final suggestedName = await _archiveService.generateNonConflictingName(baseName);
    if (mounted) {
      setState(() {
        _renamedNames[baseName] = suggestedName;
        _renameControllers[baseName]?.text = suggestedName;
      });
    }
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    final hasSkills = _skills != null && _skills!.isNotEmpty;
    final willImportAny = _resolutions.values.any(
      (r) => r != SkillConflictResolution.skip,
    );

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
            onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
            child: Text(S.get('cancel')),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: (!hasSkills || !willImportAny || _isImporting)
                ? null
                : _handleImport,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(S.get('import')),
            style: FilledButton.styleFrom(backgroundColor: _importOrange),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImport() async {
    if (_skills == null || _skills!.isEmpty) return;

    setState(() => _isImporting = true);
    _importedCount = 0;
    _skippedCount = 0;

    try {
      for (final skill in _skills!) {
        final resolution = _resolutions[skill.name] ?? SkillConflictResolution.skip;

        if (resolution == SkillConflictResolution.skip) {
          _skippedCount++;
          continue;
        }

        String? newName;
        if (resolution == SkillConflictResolution.rename) {
          newName = _renamedNames[skill.name]?.trim();
          if (newName == null || newName.isEmpty) {
            newName = await _archiveService.generateNonConflictingName(skill.name);
          }
        }

        final (success, _, error) = await _archiveService.importSkill(
          widget.zipPath,
          skill.name,
          resolution,
          newName: newName,
        );

        if (success) {
          _importedCount++;
        } else {
          // 如果导入失败，显示错误但继续处理其他 skill
          if (mounted) {
            Toast.show(
              context,
              message: '${skill.name}: $error',
              type: ToastType.warning,
            );
          }
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);

      // 显示导入结果
      if (_importedCount > 0) {
        Toast.show(
          context,
          message: S.get('import_success_count').replaceAll('{count}', '$_importedCount'),
          type: ToastType.success,
        );
      } else if (_skippedCount > 0) {
        Toast.show(
          context,
          message: S.get('all_skills_skipped'),
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('import_failed')}: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }
}
