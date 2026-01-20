part of '../../gemini_skills_screen.dart';

/// Gemini Extension 详情弹窗
class _GeminiExtensionDetailDialog extends StatefulWidget {
  final GeminiExtension extension;
  final VoidCallback onDeleted;

  const _GeminiExtensionDetailDialog({
    required this.extension,
    required this.onDeleted,
  });

  @override
  State<_GeminiExtensionDetailDialog> createState() => _GeminiExtensionDetailDialogState();
}

class _GeminiExtensionDetailDialogState extends State<_GeminiExtensionDetailDialog> {
  String _originalContent = '';
  String _translatedContent = '';
  bool _loading = true;
  bool _translating = false;
  bool _showTranslated = false;
  bool _hasTranslation = false;

  @override
  void initState() {
    super.initState();
    _loadReadmeContent();
  }

  Future<void> _loadReadmeContent() async {
    setState(() => _loading = true);
    try {
      // 尝试多种 README 文件名
      final possibleNames = ['README.md', 'readme.md', 'Readme.md', 'README.MD'];
      File? readmeFile;

      for (final name in possibleNames) {
        final file = File('${widget.extension.path}/$name');
        if (await file.exists()) {
          readmeFile = file;
          break;
        }
      }

      if (readmeFile != null) {
        _originalContent = await readmeFile.readAsString();

        // 检查是否有缓存的翻译
        final translatedPath = '${widget.extension.path}/README_zh.md';
        final translatedFile = File(translatedPath);
        if (await translatedFile.exists()) {
          _translatedContent = await translatedFile.readAsString();
          _hasTranslation = true;
        }
      } else {
        // 尝试读取 gemini-extension.json 作为替代
        final configFile = File('${widget.extension.path}/gemini-extension.json');
        if (await configFile.exists()) {
          final content = await configFile.readAsString();
          _originalContent = '# ${widget.extension.name}\n\n```json\n$content\n```';
        } else {
          _originalContent = '# ${widget.extension.name}\n\nNo README or config found.';
        }
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
        final translatedPath = '${widget.extension.path}/README_zh.md';
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

  // 使用免费翻译 API（MyMemory）
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.extension, size: 22, color: Colors.blue),
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
                                widget.extension.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.extension.version != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'v${widget.extension.version}',
                                  style: const TextStyle(fontSize: 11, color: Colors.blue),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          widget.extension.path,
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
                              color: Colors.blue,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.translate, size: 20),
                            color: Colors.blue,
                            tooltip: S.get('translate'),
                            onPressed: _translateContent,
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

            // Content - README 内容
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
                            color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
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
          color: isActive ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? Colors.blue.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? Colors.blue : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
