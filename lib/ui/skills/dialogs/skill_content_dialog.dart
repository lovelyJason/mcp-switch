part of '../../skills_screen.dart';

/// Skill/Plugin 内容查看弹窗
class _SkillContentDialog extends StatefulWidget {
  final String skillPath;
  final String skillName;
  final bool isReadme;

  const _SkillContentDialog({
    required this.skillPath,
    required this.skillName,
    this.isReadme = false,
  });

  @override
  State<_SkillContentDialog> createState() => _SkillContentDialogState();
}

class _SkillContentDialogState extends State<_SkillContentDialog> {
  String _originalContent = '';
  String _translatedContent = '';
  bool _loading = true;
  bool _translating = false;
  bool _showTranslated = false;
  bool _hasTranslation = false;

  // 翻译缓存文件路径
  String get _translatedPath {
    final basePath = widget.skillPath;
    if (basePath.endsWith('.md')) {
      return '${basePath.substring(0, basePath.length - 3)}-zh.md';
    }
    return '$basePath-zh';
  }

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() => _loading = true);

    try {
      final file = File(widget.skillPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        _originalContent = content;

        // 检查是否有翻译缓存
        final translatedFile = File(_translatedPath);
        if (await translatedFile.exists()) {
          _translatedContent = await translatedFile.readAsString();
          _hasTranslation = true;
        }

        setState(() => _loading = false);
      } else {
        setState(() {
          _originalContent = 'File not found: ${widget.skillPath}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _originalContent = 'Error loading file: $e';
        _loading = false;
      });
    }
  }

  Future<void> _translateContent() async {
    if (_translating) return;

    setState(() => _translating = true);

    // 显示开始翻译的提示
    if (mounted) {
      Toast.show(
        context,
        message: S.get('translating'),
        type: ToastType.info,
      );
    }

    try {
      // 使用 TranslationService 进行翻译
      final translationService = TranslationService();

      // 从 ConfigService 获取 DeepL API Key（如果有）
      final configService = Provider.of<ConfigService>(context, listen: false);
      translationService.setDeepLApiKey(configService.deeplApiKey);

      final result = await translationService.translate(_originalContent);

      // 翻译成功
      _translatedContent = result.text;
      _hasTranslation = true;

      // 缓存翻译结果
      final translatedFile = File(_translatedPath);
      await translatedFile.writeAsString(result.text);

      setState(() {
        _showTranslated = true;
        _translating = false;
      });

      // 如果发生了引擎切换，显示提示
      if (result.engineSwitched && mounted) {
        Toast.show(
          context,
          message: S.get('engine_switched').replaceAll('{engine}', result.engineUsed),
          type: ToastType.info,
        );
      }
    } catch (e) {
      setState(() => _translating = false);
      if (mounted) {
        // 提取简短的错误信息（支持多语言）
        String errorMsg = e.toString();
        if (errorMsg.contains('ALL_ENGINES_FAILED')) {
          errorMsg = S.get('error_all_engines_failed');
        } else if (errorMsg.contains('RATE_LIMIT')) {
          errorMsg = S.get('error_rate_limit');
        } else if (errorMsg.contains('TimeoutException')) {
          errorMsg = S.get('error_timeout');
        } else if (errorMsg.contains('SocketException') || errorMsg.contains('Failed host lookup')) {
          errorMsg = S.get('error_network');
        } else if (errorMsg.contains('API_ERROR_')) {
          // 提取状态码
          final match = RegExp(r'API_ERROR_(\d+)').firstMatch(errorMsg);
          errorMsg = 'API Error: ${match?.group(1) ?? 'Unknown'}';
        } else if (errorMsg.contains('EMPTY_RESULT')) {
          errorMsg = S.get('error_empty_result');
        } else if (errorMsg.length > 50) {
          errorMsg = errorMsg.substring(0, 50);
        }
        Toast.show(
          context,
          message: S.get('translate_failed').replaceAll('{error}', errorMsg),
          type: ToastType.error,
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = widget.isReadme ? Colors.orange : Colors.teal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 700,
        height: 550,
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
                  Icon(
                    widget.isReadme ? Icons.description_outlined : Icons.auto_awesome,
                    color: iconColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.skillName} - ${widget.isReadme ? 'README' : 'SKILL'}',
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
                    const SizedBox(width: 8),
                  ],
                  // 翻译按钮
                  if (!_hasTranslation && !_loading)
                    IconButton(
                      icon: _translating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orange,
                              ),
                            )
                          : const Icon(Icons.translate, size: 20, color: Colors.orange),
                      onPressed: _translating ? null : _translateContent,
                      tooltip: S.get('translate'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  // 关闭按钮
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
                        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
