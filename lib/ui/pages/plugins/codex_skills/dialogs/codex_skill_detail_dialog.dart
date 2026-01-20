part of '../../codex_skills_screen.dart';

/// Codex Skill 详情弹窗
class _CodexSkillDetailDialog extends StatefulWidget {
  final CodexSkill skill;
  final VoidCallback onDeleted;

  const _CodexSkillDetailDialog({
    required this.skill,
    required this.onDeleted,
  });

  @override
  State<_CodexSkillDetailDialog> createState() => _CodexSkillDetailDialogState();
}

class _CodexSkillDetailDialogState extends State<_CodexSkillDetailDialog> {
  String _skillContent = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkillContent();
  }

  Future<void> _loadSkillContent() async {
    setState(() => _loading = true);
    try {
      final skillMdFile = File('${widget.skill.path}/SKILL.md');
      if (await skillMdFile.exists()) {
        _skillContent = await skillMdFile.readAsString();
      } else {
        _skillContent = '# ${widget.skill.name}\n\nNo SKILL.md found.';
      }
    } catch (e) {
      _skillContent = 'Error loading SKILL.md: $e';
    }
    setState(() => _loading = false);
  }

  Future<void> _deleteSkill() async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('delete'),
      content: S.get('codex_delete_skill_confirm').replaceAll('{name}', widget.skill.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed != true) return;

    try {
      final dir = Directory(widget.skill.path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context, message: 'Failed to delete: $e', type: ToastType.error);
      }
    }
  }

  Future<void> _openInFinder() async {
    await PlatformUtils.openInFileManager(widget.skill.path);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_special, size: 22, color: Colors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.skill.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.skill.path,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.withValues(alpha: 0.7),
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 打开文件夹按钮
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 20),
                    onPressed: _openInFinder,
                    tooltip: S.get('open_in_finder'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  // 删除按钮
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                    onPressed: _deleteSkill,
                    tooltip: S.get('delete'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),

            // Content - SKILL.md 内容
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      child: Markdown(
                        data: _skillContent,
                        selectable: true,
                        padding: const EdgeInsets.all(20),
                        onTapLink: (text, href, title) {
                          if (href != null && href.isNotEmpty) {
                            launchUrl(Uri.parse(href));
                          }
                        },
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                          p: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          h1: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          h2: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          code: TextStyle(
                            fontSize: 13,
                            backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                            color: isDark ? Colors.green.shade200 : Colors.green.shade800,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
