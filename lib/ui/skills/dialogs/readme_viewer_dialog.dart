part of '../../skills_screen.dart';

/// README 查看弹窗
class _ReadmeViewerDialog extends StatefulWidget {
  final InstalledMarketplace marketplace;

  const _ReadmeViewerDialog({required this.marketplace});

  @override
  State<_ReadmeViewerDialog> createState() => _ReadmeViewerDialogState();
}

class _ReadmeViewerDialogState extends State<_ReadmeViewerDialog> {
  String _originalContent = '';
  String _translatedContent = '';
  bool _loading = true;
  bool _translating = false;
  bool _showTranslated = false;
  bool _hasTranslation = false;

  @override
  void initState() {
    super.initState();
    _loadReadme();
  }

  Future<void> _loadReadme() async {
    setState(() => _loading = true);

    try {
      // 读取原始 README
      final readmeFile = File(widget.marketplace.readmePath);
      if (await readmeFile.exists()) {
        _originalContent = await readmeFile.readAsString();
      }

      // 检查是否有缓存的翻译
      final translatedFile = File(widget.marketplace.translatedReadmePath);
      if (await translatedFile.exists()) {
        _translatedContent = await translatedFile.readAsString();
        _hasTranslation = true;
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _originalContent = 'Error loading README: $e';
      });
    }
  }

  Future<void> _translateContent() async {
    if (_translating) return;

    setState(() => _translating = true);

    try {
      // 使用免费翻译 API
      final translated = await _translateWithFreeApi(_originalContent);

      if (translated != null && translated.isNotEmpty) {
        _translatedContent = translated;
        _hasTranslation = true;

        // 缓存翻译结果到文件
        final translatedFile = File(widget.marketplace.translatedReadmePath);
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

  // 使用免费翻译 API（MyMemory - 无需 API Key，每天 5000 字免费）
  Future<String?> _translateWithFreeApi(String text) async {
    try {
      // 分段翻译（MyMemory 限制 500 字符）
      final chunks = _splitTextIntoChunks(text, 450);
      final translatedChunks = <String>[];

      for (int i = 0; i < chunks.length; i++) {
        final chunk = chunks[i];
        final encoded = Uri.encodeComponent(chunk);
        // MyMemory 免费翻译 API
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
            // 如果翻译失败，保留原文
            translatedChunks.add(chunk);
          }
        } else {
          throw Exception('API returned ${response.statusCode}');
        }

        // 避免请求过快（MyMemory 有速率限制）
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        height: 550,
        padding: const EdgeInsets.all(0),
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
                  const Icon(
                    Icons.description_outlined,
                    color: Colors.orange,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.marketplace.name} - README',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                    const SizedBox(width: 12),
                  ],
                  // 翻译按钮
                  if (!_hasTranslation)
                    _translating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.orange,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.translate, size: 20),
                            color: Colors.orange,
                            tooltip: S.get('translate'),
                            onPressed: _translateContent,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      child: Markdown(
                        data: _showTranslated ? _translatedContent : _originalContent,
                        selectable: true,
                        padding: const EdgeInsets.all(20),
                        onTapLink: (text, href, title) {
                          if (href != null && href.isNotEmpty) {
                            launchUrl(Uri.parse(href));
                          }
                        },
                        styleSheet: _buildMarkdownStyleSheet(context, isDark),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.orange.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? Colors.orange.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? Colors.orange : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet(BuildContext context, bool isDark) {
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
      h1: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      h2: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      h3: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      a: TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        decorationColor: Colors.blue.withValues(alpha: 0.5),
      ),
      code: TextStyle(
        fontSize: 13,
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        color: isDark ? Colors.orange.shade200 : Colors.orange.shade800,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquoteDecoration: BoxDecoration(
        color: isDark
            ? Colors.blue.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.05),
        border: Border(
          left: BorderSide(
            color: Colors.blue.withValues(alpha: 0.5),
            width: 4,
          ),
        ),
      ),
    );
  }
}
