part of '../../skills_screen.dart';

/// 市场详情弹窗 - 显示市场内的所有插件
class _MarketplaceDetailDialog extends StatefulWidget {
  final InstalledMarketplace marketplace;
  final List<InstalledPlugin> installedPlugins;
  final VoidCallback onInstalled;

  const _MarketplaceDetailDialog({
    required this.marketplace,
    required this.installedPlugins,
    required this.onInstalled,
  });

  @override
  State<_MarketplaceDetailDialog> createState() => _MarketplaceDetailDialogState();
}

class _MarketplaceDetailDialogState extends State<_MarketplaceDetailDialog> {
  List<Map<String, dynamic>> _plugins = [];
  bool _loading = true;
  String? _marketplaceDescription;

  // 判断插件是否已安装（通过名称和市场名称匹配）
  bool _isPluginInstalled(String pluginName) {
    final marketplaceName = widget.marketplace.name;
    // 已安装插件的格式是 "pluginName@marketplaceName"
    return widget.installedPlugins.any((p) {
      final parts = p.name.split('@');
      final installedName = parts[0];
      final installedMarketplace = parts.length > 1 ? parts[1] : '';
      return installedName == pluginName && installedMarketplace == marketplaceName;
    });
  }

  // 安装插件
  Future<void> _installPlugin(String pluginName) async {
    // 获取终端服务
    final terminalService = context.read<TerminalService>();

    // 开启悬浮终端图标
    terminalService.setFloatingTerminal(true);

    // 关闭当前弹窗
    Navigator.of(context).pop();

    // 打开全局终端面板并执行安装命令
    terminalService.openTerminalPanel();

    // 稍微延迟让终端初始化
    await Future.delayed(const Duration(milliseconds: 500));

    // 执行安装命令：claude plugin install pluginName@marketplaceName
    final marketplaceName = widget.marketplace.name;
    terminalService.sendCommand('claude plugin install $pluginName@$marketplaceName');

    // 通知刷新
    widget.onInstalled();
  }

  @override
  void initState() {
    super.initState();
    _loadMarketplacePlugins();
  }

  Future<void> _loadMarketplacePlugins() async {
    setState(() => _loading = true);

    try {
      final manifestPath = '${widget.marketplace.installLocation}/.claude-plugin/marketplace.json';
      final manifestFile = File(manifestPath);

      if (await manifestFile.exists()) {
        final content = await manifestFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        // 获取市场描述
        _marketplaceDescription = json['description'] as String? ??
            (json['metadata'] as Map<String, dynamic>?)?['description'] as String?;

        // 解析插件列表
        final pluginsList = json['plugins'] as List<dynamic>? ?? [];
        final plugins = <Map<String, dynamic>>[];

        for (final plugin in pluginsList) {
          final pluginMap = plugin as Map<String, dynamic>;
          final name = pluginMap['name'] as String? ?? '';
          final description = pluginMap['description'] as String? ?? '';
          final skills = pluginMap['skills'] as List<dynamic>?;
          final source = pluginMap['source'];

          // 判断是 skills 组合型还是 source plugin 型
          final isSkillsBased = skills != null && skills.isNotEmpty;

          plugins.add({
            'name': name,
            'description': description,
            'isSkillsBased': isSkillsBased,
            'skills': skills ?? [],
            'source': source,
          });
        }

        setState(() {
          _plugins = plugins;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('Error loading marketplace plugins: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOfficial = widget.marketplace.isOfficial;
    final tagColor = isOfficial ? Colors.blue : Colors.purple;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(tagColor, isOfficial, isDark),

            // Content
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 市场描述
                          if (_marketplaceDescription != null &&
                              _marketplaceDescription!.isNotEmpty) ...[
                            Text(
                              _marketplaceDescription!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // 插件列表标题
                          Row(
                            children: [
                              const Icon(Icons.extension, size: 18, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(
                                '${S.get('available_plugins')} (${_plugins.length})',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              HoverPopover(
                                message: S.get('available_plugins_hint'),
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_plugins.isEmpty)
                            _buildEmptyState(isDark)
                          else
                            ...(_plugins.map((plugin) => _buildPluginItem(plugin, isDark))),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color tagColor, bool isOfficial, bool isDark) {
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
              color: tagColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOfficial ? Icons.verified : Icons.groups,
              size: 22,
              color: tagColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.marketplace.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.marketplace.repo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isOfficial ? S.get('official') : S.get('community'),
              style: TextStyle(
                fontSize: 11,
                color: tagColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          S.get('no_plugins'),
          style: TextStyle(
            color: Colors.grey.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildPluginItem(Map<String, dynamic> plugin, bool isDark) {
    final name = plugin['name'] as String;
    final description = plugin['description'] as String;
    final isSkillsBased = plugin['isSkillsBased'] as bool;
    final skills = plugin['skills'] as List<dynamic>;
    final isInstalled = _isPluginInstalled(name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isInstalled
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (isSkillsBased ? Colors.teal : Colors.orange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isSkillsBased ? Icons.psychology : Icons.extension,
              size: 16,
              color: isSkillsBased ? Colors.teal : Colors.orange,
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          subtitle: description.isNotEmpty
              ? Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: _buildPluginTrailing(isInstalled, isSkillsBased, name, isDark),
          children: [
            if (isSkillsBased)
              // Skills 列表
              ...skills.map((skill) => _buildSkillSubItem(skill.toString(), isDark))
            else
              // Plugin README
              _buildPluginReadmeButton(plugin, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildPluginTrailing(bool isInstalled, bool isSkillsBased, String name, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 安装状态标签
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
                const SizedBox(width: 3),
                Text(
                  S.get('enabled'),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          // 下载按钮
          InkWell(
            onTap: () => _installPlugin(name),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download, size: 10, color: Colors.blue),
                  const SizedBox(width: 3),
                  Text(
                    S.get('add'),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (isSkillsBased ? Colors.teal : Colors.orange).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            isSkillsBased ? 'Skills' : 'Plugin',
            style: TextStyle(
              fontSize: 9,
              color: isSkillsBased ? Colors.teal : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.expand_more, size: 20),
      ],
    );
  }

  Widget _buildSkillSubItem(String skillPath, bool isDark) {
    // 从路径提取 skill 名称，如 ./skills/xlsx -> xlsx
    final skillName = skillPath.split('/').last;

    return InkWell(
      onTap: () => _showSkillContent(skillPath),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.teal.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 14,
              color: Colors.teal,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                skillName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSkillContent(String skillPath) async {
    // 构建 SKILL.md 路径
    final basePath = widget.marketplace.installLocation;
    // skillPath 格式: ./skills/xlsx -> 转为绝对路径
    final normalizedPath = skillPath.startsWith('./') ? skillPath.substring(2) : skillPath;
    final skillMdPath = '$basePath/$normalizedPath/SKILL.md';

    await showDialog<void>(
      context: context,
      builder: (context) => _SkillContentDialog(
        skillPath: skillMdPath,
        skillName: skillPath.split('/').last,
      ),
    );
  }

  Widget _buildPluginReadmeButton(Map<String, dynamic> plugin, bool isDark) {
    return InkWell(
      onTap: () => _showPluginReadme(plugin),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 14,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                S.get('view_readme'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPluginReadme(Map<String, dynamic> plugin) async {
    final basePath = widget.marketplace.installLocation;
    final source = plugin['source'];

    String readmePath;
    if (source is String) {
      // source 格式: ./plugins/xxx -> 转为绝对路径
      final normalizedPath = source.startsWith('./') ? source.substring(2) : source;
      readmePath = '$basePath/$normalizedPath/README.md';
    } else {
      // source 是对象（外部插件），使用 name 构建路径
      final name = plugin['name'] as String;
      readmePath = '$basePath/plugins/$name/README.md';
    }

    await showDialog<void>(
      context: context,
      builder: (context) => _SkillContentDialog(
        skillPath: readmePath,
        skillName: plugin['name'] as String,
        isReadme: true,
      ),
    );
  }
}
