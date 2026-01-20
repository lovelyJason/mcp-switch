part of '../../claude_code_skills_screen.dart';

/// 添加市场弹窗
class _AddMarketplaceDialog extends StatefulWidget {
  final List<InstalledMarketplace> installedMarketplaces;
  final VoidCallback onAdded;

  const _AddMarketplaceDialog({
    required this.installedMarketplaces,
    required this.onAdded,
  });

  @override
  State<_AddMarketplaceDialog> createState() => _AddMarketplaceDialogState();
}

class _AddMarketplaceDialogState extends State<_AddMarketplaceDialog> {
  final bool _isAdding = false;
  String? _addingRepo;
  final Map<String, int?> _starCounts = {}; // 缓存 star 数

  @override
  void initState() {
    super.initState();
    _loadStarCounts();
  }

  // 加载所有 marketplace 的 star 数
  Future<void> _loadStarCounts() async {
    for (final marketplace in presetMarketplaces) {
      _fetchStarCount(marketplace.repo);
    }
  }

  // 获取单个仓库的 star 数
  Future<void> _fetchStarCount(String repo) async {
    try {
      final response = await http
          .get(
            Uri.parse('https://api.github.com/repos/$repo'),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'User-Agent': 'MCP-Switch-App',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final stars = json['stargazers_count'] as int?;
        if (mounted && stars != null) {
          setState(() => _starCounts[repo] = stars);
        }
      } else {
        debugPrint('GitHub API returned ${response.statusCode} for $repo');
      }
    } catch (e) {
      // 忽略错误，star 数显示为空
      debugPrint('Failed to fetch stars for $repo: $e');
    }
  }

  // 格式化 star 数显示
  String _formatStarCount(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }

  // 用 repo 来判断是否已安装（因为安装后的目录名可能不同）
  bool _isInstalled(String repo) {
    return widget.installedMarketplaces.any((m) => m.repo == repo);
  }

  // 获取市场提示信息
  String? _getMarketplaceHint(PresetMarketplace marketplace) {
    if (marketplace.hintKey == null) return null;
    return S.get(marketplace.hintKey!);
  }

  Future<void> _addMarketplace(PresetMarketplace marketplace) async {
    // 先确认
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('add_marketplace'),
      content: S.get('marketplace_add_confirm').replaceAll('{name}', marketplace.repo),
      confirmText: S.get('add'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.orange,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    // 获取终端服务
    final terminalService = context.read<TerminalService>();

    // 开启悬浮终端图标
    terminalService.setFloatingTerminal(true);

    // 关闭当前弹窗
    Navigator.of(context).pop();

    // 直接打开全局终端面板并执行命令（留在当前页面）
    terminalService.openTerminalPanel();

    // 稍微延迟让终端初始化
    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand('claude plugin marketplace add ${marketplace.repo}');

    // 通知刷新
    widget.onAdded();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 固定的标题区域
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_business, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        S.get('add_marketplace_title'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    S.get('add_marketplace_desc'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 可滚动的内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 三列卡片布局
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ...presetMarketplaces.map((marketplace) {
                          final isInstalled = _isInstalled(marketplace.repo);
                          final isAddingThis = _addingRepo == marketplace.repo;

                          return _buildMarketplaceCard(
                            marketplace,
                            isInstalled,
                            isAddingThis,
                            isDark,
                          );
                        }),
                        // 自定义添加 marketplace 卡片
                        _buildCustomMarketplaceCard(isDark),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1),
                    const SizedBox(height: 20),

                    // 社区资源部分
                    _buildCommunityResourcesSection(isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceCard(
    PresetMarketplace marketplace,
    bool isInstalled,
    bool isAddingThis,
    bool isDark,
  ) {
    return SizedBox(
      width: 200,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isInstalled
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isInstalled || _isAdding ? null : () => _addMarketplace(marketplace),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标和标签
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (marketplace.isOfficial ? Colors.blue : Colors.purple)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        marketplace.isOfficial ? Icons.verified : Icons.groups,
                        size: 18,
                        color: marketplace.isOfficial ? Colors.blue : Colors.purple,
                      ),
                    ),
                    // 问号提示
                    if (_getMarketplaceHint(marketplace) != null)
                      HoverPopover(
                        message: _getMarketplaceHint(marketplace)!,
                        isDark: isDark,
                      ),
                    const Spacer(),
                    // Star 数显示（优先用 API 获取的，fallback 用预设的）
                    Builder(builder: (context) {
                      final stars = _starCounts[marketplace.repo] ?? marketplace.fallbackStars;
                      if (stars == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, size: 10, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              _formatStarCount(stars),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (marketplace.isOfficial ? Colors.blue : Colors.purple)
                            .withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        marketplace.isOfficial ? S.get('official') : S.get('community'),
                        style: TextStyle(
                          fontSize: 9,
                          color: marketplace.isOfficial ? Colors.blue : Colors.purple,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 名称
                Text(
                  marketplace.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Repo
                Text(
                  marketplace.repo,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withValues(alpha: 0.7),
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // 操作区域
                _buildActionArea(isInstalled, isAddingThis, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionArea(bool isInstalled, bool isAddingThis, bool isDark) {
    if (isInstalled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              S.get('marketplace_installed'),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (isAddingThis) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
            ),
            const SizedBox(width: 6),
            Text(
              S.get('marketplace_adding'),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, size: 14, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              S.get('add'),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  // 社区资源部分（仅 Marketplace 相关）
  Widget _buildCommunityResourcesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Row(
          children: [
            const Icon(Icons.explore, size: 18, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              S.get('community_resources'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          S.get('community_resources_desc'),
          style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 12),

        // Marketplace 导航站
        _buildResourceChip(
          'claudemarketplaces.com',
          'https://claudemarketplaces.com/',
          Icons.language,
          Colors.blue,
          isDark,
        ),
      ],
    );
  }

  Widget _buildResourceChip(String name, String url, IconData icon, Color color, bool isDark) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url)),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new, size: 12, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  // 自定义 marketplace 卡片
  Widget _buildCustomMarketplaceCard(bool isDark) {
    return SizedBox(
      width: 200,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.teal.withValues(alpha: 0.3),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showCustomMarketplaceDialog(),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.teal.withValues(alpha: 0.2),
                width: 1,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add_box_outlined,
                        size: 18,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 标题
                Text(
                  S.get('custom_marketplace_install'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // 描述
                Text(
                  S.get('custom_marketplace_install_desc'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // 添加按钮区域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit_note, size: 14, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text(
                        S.get('add'),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.teal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCustomMarketplaceDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CustomMarketplaceInputDialog(
        installedMarketplaces: widget.installedMarketplaces,
        onConfirm: (repo) => _addCustomMarketplace(repo),
      ),
    );
  }

  Future<void> _addCustomMarketplace(String repo) async {
    if (!mounted) return;

    // 获取终端服务
    final terminalService = context.read<TerminalService>();

    // 开启悬浮终端图标
    terminalService.setFloatingTerminal(true);

    // 关闭当前弹窗
    Navigator.of(context).pop();

    // 直接打开全局终端面板并执行命令
    terminalService.openTerminalPanel();

    // 稍微延迟让终端初始化
    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand('claude plugin marketplace add $repo');

    // 通知刷新
    widget.onAdded();
  }
}

/// 自定义 Marketplace 输入弹窗
class _CustomMarketplaceInputDialog extends StatefulWidget {
  final List<InstalledMarketplace> installedMarketplaces;
  final void Function(String repo) onConfirm;

  const _CustomMarketplaceInputDialog({
    required this.installedMarketplaces,
    required this.onConfirm,
  });

  @override
  State<_CustomMarketplaceInputDialog> createState() => _CustomMarketplaceInputDialogState();
}

class _CustomMarketplaceInputDialogState extends State<_CustomMarketplaceInputDialog> {
  final _controller = TextEditingController();
  String? _parsedRepo;
  String? _errorMessage;
  bool _isAlreadyInstalled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 解析输入，提取 owner/repo 格式
  String? _parseMarketplaceInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // 匹配 owner/repo 格式的正则
    final repoPattern = RegExp(r'^([a-zA-Z0-9_-]+)/([a-zA-Z0-9_.-]+)$');

    // 情况1: 直接是 owner/repo 格式
    if (repoPattern.hasMatch(trimmed)) {
      return trimmed;
    }

    // 情况2: /plugin marketplace add owner/repo
    final cmdPattern = RegExp(r'/plugin\s+marketplace\s+add\s+([a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+)');
    final cmdMatch = cmdPattern.firstMatch(trimmed);
    if (cmdMatch != null) {
      return cmdMatch.group(1);
    }

    // 情况3: claude plugin marketplace add owner/repo
    final claudePattern = RegExp(r'claude\s+plugin\s+marketplace\s+add\s+([a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+)');
    final claudeMatch = claudePattern.firstMatch(trimmed);
    if (claudeMatch != null) {
      return claudeMatch.group(1);
    }

    // 情况4: GitHub URL https://github.com/owner/repo
    final urlPattern = RegExp(r'github\.com/([a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+)');
    final urlMatch = urlPattern.firstMatch(trimmed);
    if (urlMatch != null) {
      // 去掉可能的 .git 后缀和路径
      var repo = urlMatch.group(1)!;
      repo = repo.replaceAll(RegExp(r'\.git$'), '');
      // 去掉可能的子路径 (如 /tree/main)
      if (repo.contains('/tree/') || repo.contains('/blob/')) {
        repo = repo.split('/').take(2).join('/');
      }
      return repo;
    }

    return null;
  }

  void _onInputChanged(String value) {
    final parsed = _parseMarketplaceInput(value);
    // 检查是否已安装
    bool alreadyInstalled = false;
    if (parsed != null) {
      alreadyInstalled = widget.installedMarketplaces.any((m) => m.repo == parsed);
    }
    setState(() {
      _parsedRepo = parsed;
      _isAlreadyInstalled = alreadyInstalled;
      _errorMessage = (value.trim().isNotEmpty && parsed == null)
          ? S.get('invalid_marketplace_format')
          : null;
    });
  }

  void _onConfirm() {
    if (_parsedRepo != null) {
      Navigator.of(context).pop();
      widget.onConfirm(_parsedRepo!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.add_box_outlined, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  S.get('custom_marketplace_install'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 输入框
            TextField(
              controller: _controller,
              onChanged: _onInputChanged,
              autofocus: true,
              decoration: InputDecoration(
                labelText: S.get('custom_marketplace_repo'),
                hintText: S.get('custom_marketplace_hint'),
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.5)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                errorText: _errorMessage,
                prefixIcon: const Icon(Icons.link, size: 20),
              ),
              onSubmitted: (_) => _onConfirm(),
            ),

            // 解析结果预览
            if (_parsedRepo != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isAlreadyInstalled
                      ? Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08)
                      : Colors.green.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isAlreadyInstalled
                        ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAlreadyInstalled ? Icons.warning_amber : Icons.check_circle,
                      size: 18,
                      color: _isAlreadyInstalled ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isAlreadyInstalled)
                            Text(
                              S.get('marketplace_already_installed'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else ...[
                            Text(
                              'claude plugin marketplace add',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _parsedRepo!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(S.get('cancel')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: (_parsedRepo != null && !_isAlreadyInstalled) ? _onConfirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  ),
                  child: Text(S.get('add')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
