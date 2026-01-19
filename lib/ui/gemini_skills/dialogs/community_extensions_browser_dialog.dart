part of '../../gemini_skills_screen.dart';

/// 社区扩展浏览器弹窗 - 浏览和安装社区 Extensions
class _CommunityExtensionsBrowserDialog extends StatefulWidget {
  final GeminiSkillsService skillsService;
  final VoidCallback onInstalled;

  const _CommunityExtensionsBrowserDialog({
    required this.skillsService,
    required this.onInstalled,
  });

  @override
  State<_CommunityExtensionsBrowserDialog> createState() =>
      _CommunityExtensionsBrowserDialogState();
}

class _CommunityExtensionsBrowserDialogState
    extends State<_CommunityExtensionsBrowserDialog> {
  List<CommunityGeminiExtension> _communityExtensions = [];
  List<GeminiExtension> _installedExtensions = []; // 已安装的扩展列表
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _dataSource;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 并行加载社区扩展和已安装扩展
    await Future.wait([
      _loadCommunityExtensions(),
      _loadInstalledExtensions(),
    ]);
  }

  Future<void> _loadInstalledExtensions() async {
    try {
      final installed = await widget.skillsService.loadLocalExtensions();
      if (mounted) {
        setState(() => _installedExtensions = installed);
      }
    } catch (e) {
      // ignore
    }
  }

  Future<void> _loadCommunityExtensions() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final result = await widget.skillsService.loadCommunityExtensions();
      if (!mounted) return;
      setState(() {
        _communityExtensions = result.extensions;
        _hasMore = result.hasMore;
        _dataSource = result.source;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _communityExtensions = [];
        _hasMore = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || !mounted) return;

    setState(() => _loadingMore = true);
    try {
      final result = await widget.skillsService.loadMoreCommunityExtensions();
      if (!mounted) return;
      setState(() {
        _communityExtensions.addAll(result.extensions);
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
        _loadingMore = false;
      });
    }
  }

  void _copyInstallCommand(CommunityGeminiExtension ext) {
    Clipboard.setData(ClipboardData(text: '${ext.installCommand} --consent'));
    Toast.show(
      context,
      message: S.get('gemini_install_command_copied'),
      type: ToastType.success,
    );
  }

  Future<void> _installExtension(CommunityGeminiExtension ext) async {
    final terminalService = context.read<TerminalService>();
    terminalService.setFloatingTerminal(true);
    Navigator.of(context).pop();
    terminalService.openTerminalPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand('${ext.installCommand} --consent');
    widget.onInstalled();
  }

  void _openGitHub() {
    launchUrl(Uri.parse('https://github.com/gemini-cli-extensions'));
  }

  void _openGallery() {
    launchUrl(Uri.parse('https://geminicli.com/extensions/'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(isDark),

            // Content
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildExtensionsList(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
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
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.public, size: 22, color: Colors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.get('gemini_community_extensions'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  S.get('gemini_community_extensions_hint'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // 数据来源标签
          if (_dataSource != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _dataSource!,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Gallery 按钮
          IconButton(
            icon: const Icon(Icons.store_outlined, size: 20),
            onPressed: _openGallery,
            tooltip: S.get('gemini_open_gallery'),
            color: Colors.orange,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // GitHub 按钮
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: _openGitHub,
            tooltip: S.get('gemini_open_github'),
            color: Colors.orange,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionsList(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 扩展数量标题
          Row(
            children: [
              const Icon(Icons.extension, size: 18, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                '${S.get('available_extensions')} (${_communityExtensions.length}${_hasMore ? '+' : ''})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 扩展卡片网格
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              const cardsPerRow = 3;
              final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  ..._communityExtensions.map((ext) => _buildExtensionCard(ext, isDark, cardWidth)),
                  // 自定义市场卡片（始终显示在最后）
                  _buildCustomMarketCard(isDark, cardWidth),
                ],
              );
            },
          ),

          // 加载更多按钮
          if (_hasMore || _loadingMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: _loadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: Text(S.get('load_more')),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
              ),
            ),

          // 社区资源区块
          _buildCommunityResourcesSection(isDark),
        ],
      ),
    );
  }

  Widget _buildExtensionCard(CommunityGeminiExtension ext, bool isDark, double cardWidth) {
    // 检查是否已安装
    final isInstalled = _installedExtensions.any(
      (installed) => installed.name.toLowerCase() == ext.name.toLowerCase(),
    );

    return SizedBox(
      width: cardWidth,
      height: 120, // 固定高度保证对齐
      child: InkWell(
        onTap: () => _showExtensionDetail(ext),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isInstalled
                  ? Colors.green.withValues(alpha: 0.4)
                  : Colors.orange.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部：图标 + 名称 + 已安装标识
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isInstalled
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.extension,
                      size: 16,
                      color: isInstalled ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ext.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 已安装标识
                  if (isInstalled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 10, color: Colors.green),
                          const SizedBox(width: 2),
                          Text(
                            S.get('installed'),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // 描述
              Expanded(
                child: Text(
                  ext.description ?? S.get('no_description'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 底部操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 安装按钮（已安装时显示为灰色）
                  InkWell(
                    onTap: isInstalled ? null : () => _installExtension(ext),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isInstalled
                            ? Colors.grey.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInstalled ? Icons.check : Icons.download,
                            size: 12,
                            color: isInstalled ? Colors.grey : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isInstalled ? S.get('installed') : S.get('install'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isInstalled ? Colors.grey : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 右侧图标按钮
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 复制按钮
                      InkWell(
                        onTap: () => _copyInstallCommand(ext),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: Colors.grey.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      // GitHub 链接
                      if (ext.githubUrl != null)
                        InkWell(
                          onTap: () => launchUrl(Uri.parse(ext.githubUrl!)),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: Colors.grey.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 自定义市场卡片
  Widget _buildCustomMarketCard(bool isDark, double cardWidth) {
    return SizedBox(
      width: cardWidth,
      height: 120,
      child: InkWell(
        onTap: _showCustomMarketDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部图标
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.add_box_outlined, size: 16, color: Colors.orange),
              ),
              const SizedBox(height: 12),
              // 标题
              Text(
                S.get('gemini_custom_market'),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              // 描述
              Text(
                S.get('gemini_custom_market_hint'),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示自定义市场弹窗
  Future<void> _showCustomMarketDialog() async {
    final controller = TextEditingController();
    String? validatedRepo;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          // 检查是否已安装
          bool isInstalled = false;
          if (validatedRepo != null) {
            final repoName = validatedRepo!.split('/').last;
            isInstalled = _installedExtensions.any(
              (ext) => ext.name.toLowerCase() == repoName.toLowerCase(),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_box_outlined, size: 20, color: Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        S.get('gemini_custom_market'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 输入框
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: S.get('gemini_extension_repo'),
                      hintText: S.get('gemini_extension_repo_hint'),
                      prefixIcon: const Icon(Icons.link, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      // 验证格式：支持 owner/repo 或完整 GitHub URL
                      final trimmed = value.trim();

                      // 尝试从完整 GitHub URL 提取 owner/repo
                      // 支持格式：
                      // - https://github.com/owner/repo
                      // - http://github.com/owner/repo
                      // - github.com/owner/repo
                      // - owner/repo
                      final githubUrlPattern = RegExp(
                        r'^(?:https?://)?(?:www\.)?github\.com/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_.-]+)(?:/.*)?$',
                        caseSensitive: false,
                      );
                      final match = githubUrlPattern.firstMatch(trimmed);
                      if (match != null) {
                        final owner = match.group(1)!;
                        final repo = match.group(2)!.replaceAll(RegExp(r'\.git$'), ''); // 移除 .git 后缀
                        setDialogState(() => validatedRepo = '$owner/$repo');
                        return;
                      }

                      // 直接 owner/repo 格式
                      if (trimmed.contains('/') && trimmed.split('/').length == 2) {
                        final parts = trimmed.split('/');
                        if (parts[0].isNotEmpty && parts[1].isNotEmpty) {
                          setDialogState(() => validatedRepo = trimmed);
                          return;
                        }
                      }
                      setDialogState(() => validatedRepo = null);
                    },
                  ),
                  const SizedBox(height: 12),

                  // 验证结果提示
                  if (validatedRepo != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isInstalled
                            ? Colors.orange.withValues(alpha: 0.1)
                            : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isInstalled ? Icons.warning_amber : Icons.check_circle,
                            size: 18,
                            color: isInstalled ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isInstalled
                                      ? S.get('gemini_extension_already_installed')
                                      : 'gemini extension install $validatedRepo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isInstalled ? Colors.orange : Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!isInstalled)
                                  Text(
                                    validatedRepo!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(S.get('cancel')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (validatedRepo != null && !isInstalled)
                            ? () {
                                Navigator.of(dialogContext).pop();
                                _installCustomExtension(validatedRepo!);
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(S.get('add')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 安装自定义扩展
  /// repo 格式为 owner/repo，需要拼成完整 GitHub URL
  Future<void> _installCustomExtension(String repo) async {
    final terminalService = context.read<TerminalService>();
    terminalService.setFloatingTerminal(true);
    Navigator.of(context).pop();
    terminalService.openTerminalPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    // Gemini CLI 需要完整的 GitHub URL
    final githubUrl = 'https://github.com/$repo';
    terminalService.sendCommand('gemini extension install $githubUrl --consent');
    widget.onInstalled();
  }

  Widget _buildCommunityResourcesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.explore,
              size: 18,
              color: Colors.orange.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Text(
              S.get('community_resources'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          S.get('gemini_community_resources_desc'),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildResourceChip(
              'Gemini Extensions Gallery',
              'https://geminicli.com/extensions/',
              Icons.store_outlined,
              isDark,
            ),
            _buildResourceChip(
              'GitHub Community Repo',
              'https://github.com/gemini-cli-extensions',
              Icons.code,
              isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResourceChip(String label, String url, IconData icon, bool isDark) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 12,
              color: Colors.orange.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExtensionDetail(CommunityGeminiExtension ext) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CommunityExtensionDetailDialog(
        extension: ext,
        onInstalled: () {
          widget.onInstalled();
        },
      ),
    );
  }
}
