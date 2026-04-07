part of '../../claude_code_skills_screen.dart';

// ─── Community skills section (mixed into _SkillsScreenState) ──────────────

extension CommunitySkillsSectionExt on _SkillsScreenState {
  // ============ 社区 Skills 区域 ============
  Widget buildCommunitySkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_special, size: 20, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              S.get('community_skills'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.download_rounded, size: 20, color: Colors.teal),
              onPressed: _importSkills,
              tooltip: S.get('import_skills'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: Icon(
                Icons.upload_rounded,
                size: 20,
                color: _communitySkills.isEmpty ? Colors.grey : Colors.teal,
              ),
              onPressed: _communitySkills.isEmpty ? null : _showExportSkillsDialog,
              tooltip: S.get('export_skills'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.teal),
              onPressed: _showCustomSkillInstallDialog,
              tooltip: S.get('custom_skill_install'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('community_skills_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        if (_communitySkills.isEmpty)
          buildEmptyCard(S.get('no_community_skills'))
        else
          _buildCommunitySkillCards(isDark),
      ],
    );
  }

  Future<void> _showCustomSkillInstallDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CustomSkillInstallDialog(
        onInstalled: _loadData,
      ),
    );
  }

  Future<void> _showExportSkillsDialog() async {
    if (_communitySkills.isEmpty) {
      Toast.show(context, message: S.get('no_skills_to_export'), type: ToastType.info);
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _SkillsExportDialog(skills: _communitySkills),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _importSkills() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: S.get('select_import_file'),
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final filePath = result.files.first.path;
    if (filePath == null) return;

    final imported = await showDialog<bool>(
      context: context,
      builder: (context) => _SkillsImportDialog(zipPath: filePath),
    );

    if (imported == true && mounted) {
      _loadData();
    }
  }

  Widget _buildCommunitySkillCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              _communitySkills.map((skill) => _buildCommunitySkillCard(skill, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildCommunitySkillCard(CommunitySkill skill, bool isDark, double cardWidth) {
    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _showCommunitySkillDetailDialog(skill),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.teal.withValues(alpha: 0.3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.folder_special, size: 16, color: Colors.teal),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        skill.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (skill.hasSkillMd)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.green),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  skill.description ?? S.get('no_description'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _copyCommunitySkillCommand(skill.name),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: Colors.teal.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _confirmDeleteCommunitySkill(skill),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyCommunitySkillCommand(String skillName) {
    final command = '/$skillName';
    Clipboard.setData(ClipboardData(text: command));
    Toast.show(
      context,
      message: S.get('skill_copied_hint'),
      type: ToastType.success,
    );
  }

  Future<void> _confirmDeleteCommunitySkill(CommunitySkill skill) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_delete_title'),
      content: S.get('confirm_delete_skill_content').replaceAll('{name}', skill.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      try {
        final dir = Directory(skill.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          _loadData();
          if (mounted) {
            Toast.show(context, message: S.get('skill_deleted'), type: ToastType.success);
          }
        }
      } catch (e) {
        if (mounted) {
          Toast.show(context, message: S.get('skill_delete_failed'), type: ToastType.error);
        }
      }
    }
  }
}
