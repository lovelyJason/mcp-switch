part of '../../gemini_skills_screen.dart';

/// 社区 Extension 详情弹窗（带安装功能）
class _CommunityExtensionDetailDialog extends StatefulWidget {
  final CommunityGeminiExtension extension;
  final VoidCallback onInstalled;

  const _CommunityExtensionDetailDialog({
    required this.extension,
    required this.onInstalled,
  });

  @override
  State<_CommunityExtensionDetailDialog> createState() =>
      _CommunityExtensionDetailDialogState();
}

class _CommunityExtensionDetailDialogState
    extends State<_CommunityExtensionDetailDialog> {
  String _originalContent = '';
  String _translatedContent = '';
  bool _loading = true;
  bool _installing = false;
  bool _translating = false;
  bool _showTranslated = false;
  bool _hasTranslation = false;

  @override
  void initState() {
    super.initState();
    _loadReadmeFromGitHub();
  }

  /// 从 GitHub 获取 README 内容
  Future<void> _loadReadmeFromGitHub() async {
    setState(() => _loading = true);
    try {
      if (widget.extension.githubUrl != null) {
        // 从 GitHub raw 获取 README
        final repoUrl = widget.extension.githubUrl!;
        // https://github.com/org/repo -> https://raw.githubusercontent.com/org/repo/main/README.md
        final rawUrl = repoUrl
            .replaceFirst('github.com', 'raw.githubusercontent.com')
            .replaceFirst(RegExp(r'/?$'), '/main/README.md');

        final response = await http.get(Uri.parse(rawUrl)).timeout(
              const Duration(seconds: 10),
            );

        if (response.statusCode == 200) {
          _originalContent = response.body;
        } else {
          // 尝试 master 分支
          final masterUrl = rawUrl.replaceFirst('/main/', '/master/');
          final masterResponse = await http.get(Uri.parse(masterUrl)).timeout(
                const Duration(seconds: 10),
              );
          if (masterResponse.statusCode == 200) {
            _originalContent = masterResponse.body;
          } else {
            _originalContent = _buildFallbackContent();
          }
        }
      } else {
        _originalContent = _buildFallbackContent();
      }
    } catch (e) {
      _originalContent = _buildFallbackContent();
    }
    setState(() => _loading = false);
  }

  /// 构建备用内容
  String _buildFallbackContent() {
    final ext = widget.extension;
    return '''
# ${ext.name}

${ext.description ?? S.get('no_description')}

${ext.author != null ? '**Author:** ${ext.author}' : ''}

## ${S.get('gemini_install_title')}

```bash
${ext.installCommand} --consent
```

${ext.githubUrl != null ? '[${S.get('view_on_github')}](${ext.githubUrl})' : ''}
''';
  }

  /// 安装扩展
  Future<void> _installExtension() async {
    setState(() => _installing = true);

    try {
      final terminalService = context.read<TerminalService>();
      terminalService.setFloatingTerminal(true);
      terminalService.openTerminalPanel();
      await Future.delayed(const Duration(milliseconds: 500));

      // 执行安装命令
      final command = '${widget.extension.installCommand} --consent';
      terminalService.sendCommand(command);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onInstalled();
        Toast.show(
          context,
          message: S.get('gemini_install_started'),
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('gemini_install_failed')}: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _installing = false);
      }
    }
  }

  /// 打开 GitHub 页面
  Future<void> _openGitHub() async {
    if (widget.extension.githubUrl != null) {
      await launchUrl(Uri.parse(widget.extension.githubUrl!));
    }
  }

  /// 翻译内容
  Future<void> _translateContent() async {
    if (_translating) return;

    setState(() => _translating = true);

    try {
      final translated = await _translateWithFreeApi(_originalContent);

      if (translated != null && translated.isNotEmpty) {
        _translatedContent = translated;
        _hasTranslation = true;

        if (mounted) {
          setState(() {
            _showTranslated = true;
            _translating = false;
          });
        }
      } else {
        throw Exception('Translation returned empty');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _translating = false);
        Toast.show(
          context,
          message: S.get('translate_failed'),
          type: ToastType.error,
        );
      }
    }
  }

  /// 使用免费翻译 API（MyMemory）
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
            fontSize: 11,
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
    final ext = widget.extension;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 650,
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
                  // 图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.public, size: 22, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  // 名称和描述
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                ext.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (ext.author != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  ext.author!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (ext.description != null)
                          Text(
                            ext.description!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // 操作按钮
                  if (ext.githubUrl != null)
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 20),
                      onPressed: _openGitHub,
                      tooltip: S.get('view_on_github'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
                              color: Colors.orange,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.translate, size: 20),
                            color: Colors.orange,
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
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
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
                            backgroundColor:
                                isDark ? Colors.grey.shade800 : Colors.grey.shade200,
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

            // 底部操作栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  // 安装命令预览
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${ext.installCommand} --consent',
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.orange.withValues(alpha: 0.9),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 安装按钮
                  FilledButton.icon(
                    onPressed: _installing ? null : _installExtension,
                    icon: _installing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download, size: 18),
                    label: Text(_installing ? S.get('installing') : S.get('install')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
