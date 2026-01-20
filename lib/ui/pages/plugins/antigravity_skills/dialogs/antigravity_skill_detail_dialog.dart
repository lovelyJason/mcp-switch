part of '../../antigravity_skills_screen.dart';

/// Antigravity Skill 详情弹窗
class _AntigravitySkillDetailDialog extends StatefulWidget {
  final AntigravitySkill skill;
  final VoidCallback onDeleted;

  const _AntigravitySkillDetailDialog({
    required this.skill,
    required this.onDeleted,
  });

  @override
  State<_AntigravitySkillDetailDialog> createState() =>
      _AntigravitySkillDetailDialogState();
}

class _AntigravitySkillDetailDialogState
    extends State<_AntigravitySkillDetailDialog> {
  String _originalContent = '';
  String _translatedContent = '';
  bool _loading = true;
  bool _translating = false;
  bool _showTranslated = false;
  bool _hasTranslation = false;

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
        _originalContent = await skillMdFile.readAsString();

        // 检查是否有缓存的翻译
        final translatedPath = '${widget.skill.path}/SKILL_zh.md';
        final translatedFile = File(translatedPath);
        if (await translatedFile.exists()) {
          _translatedContent = await translatedFile.readAsString();
          _hasTranslation = true;
        }
      } else {
        _originalContent = '# ${widget.skill.name}\n\nNo SKILL.md found.';
      }
    } catch (e) {
      _originalContent = 'Error loading content: $e';
    }
    setState(() => _loading = false);
  }

  Future<void> _translateContent() async {
    if (_translating) return;

    setState(() => _translating = true);

    try {
      final translated = await _translateWithFreeApi(_originalContent);

      if (translated != null && translated.isNotEmpty) {
        _translatedContent = translated;
        _hasTranslation = true;

        // 缓存翻译结果到文件
        final translatedPath = '${widget.skill.path}/SKILL_zh.md';
        final translatedFile = File(translatedPath);
        await translatedFile.writeAsString(translated);

        setState(() {
          _showTranslated = true;
          _translating = false;
        });
      } else {
        throw Exception('Translation returned empty');
      }
    } catch (e) {
      setState(() => _translating = false);
      if (mounted) {
        Toast.show(
          context,
          message: S.get('translate_failed'),
          type: ToastType.error,
        );
      }
    }
  }

  Future<String?> _translateWithFreeApi(String text) async {
    try {
      final chunks = _splitTextIntoChunks(text, 450);
      final translatedChunks = <String>[];

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final encoded = Uri.encodeComponent(chunk);
        final url = 'https://api.mymemory.translated.net/get'
            '?q=$encoded&langpair=en|zh-CN';

        final response = await http
            .get(Uri.parse(url), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final translatedText = json['responseData']?['translatedText'];
          if (translatedText != null && translatedText.toString().isNotEmpty) {
            translatedChunks.add(translatedText.toString());
          } else {
            translatedChunks.add(chunk);
          }
        } else {
          throw Exception('API returned ${response.statusCode}');
        }

        if (i < chunks.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      return translatedChunks.join('\n');
    } catch (e) {
      debugPrint('Translation error: $e');
      return null;
    }
  }

  List<String> _splitTextIntoChunks(String text, int maxLength) {
    final chunks = <String>[];
    final lines = text.split('\n');
    var currentChunk = StringBuffer();

    for (final line in lines) {
      if (currentChunk.length + line.length + 1 > maxLength) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.toString());
          currentChunk = StringBuffer();
        }
      }
      if (currentChunk.isNotEmpty) {
        currentChunk.write('\n');
      }
      currentChunk.write(line);
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString());
    }

    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scopeColor =
        widget.skill.scope == SkillScope.global ? Colors.purple : Colors.teal;
    final scopeLabel =
        widget.skill.scope == SkillScope.global ? 'Global' : 'Workspace';

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
                      color: scopeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(Icons.psychology, size: 22, color: scopeColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.skill.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: scopeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                scopeLabel,
                                style:
                                    TextStyle(fontSize: 10, color: scopeColor),
                              ),
                            ),
                          ],
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
                  // 语言切换 Tab
                  if (_hasTranslation) ...[
                    _buildTabButton(
                      label: 'EN',
                      isActive: !_showTranslated,
                      onTap: () => setState(() => _showTranslated = false),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 4),
                    _buildTabButton(
                      label: '中文',
                      isActive: _showTranslated,
                      onTap: () => setState(() => _showTranslated = true),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // 翻译按钮
                  if (!_hasTranslation)
                    _translating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.purple,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.translate, size: 20),
                            color: Colors.purple,
                            tooltip: S.get('translate'),
                            onPressed: _translateContent,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                          ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
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
                        data: _showTranslated
                            ? _translatedContent
                            : _originalContent,
                        selectable: true,
                        padding: const EdgeInsets.all(20),
                        onTapLink: (text, href, title) {
                          if (href != null && href.isNotEmpty) {
                            launchUrl(Uri.parse(href));
                          }
                        },
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                            .copyWith(
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
                            backgroundColor: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade200,
                            color: isDark
                                ? Colors.purple.shade200
                                : Colors.purple.shade800,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2D2D2D)
                                : Colors.grey.shade100,
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

  Widget _buildTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.purple.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? Colors.purple.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? Colors.purple
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
