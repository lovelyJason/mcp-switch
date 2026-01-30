part of '../../claude_code_skills_screen.dart';

/// 插件详情弹窗
class _PluginDetailDialog extends StatefulWidget {
  final InstalledPlugin plugin;

  const _PluginDetailDialog({required this.plugin});

  @override
  State<_PluginDetailDialog> createState() => _PluginDetailDialogState();
}

class _PluginDetailDialogState extends State<_PluginDetailDialog> {
  List<Map<String, String>> _skills = [];
  List<Map<String, String>> _agents = [];
  List<Map<String, String>> _commands = [];
  bool _loading = true;
  final _skillsService = SkillsService();

  // plugin.json 信息
  String? _pluginDescription;
  String? _pluginAuthor;
  String? _githubUrl;

  // 是否为远程源插件（source 是 URL 而非本地路径）
  bool _isRemoteSource = false;

  // 远程源插件的 marketplace repo（从 marketplace.json 解析）
  String? _remoteMarketplaceRepo;

  // README 路径（智能查找后的实际路径）
  String? _readmePath;

  @override
  void initState() {
    super.initState();
    _loadPluginInfo();
    _loadGithubUrl();
    _loadSkills();
    _loadAgents();
    _loadCommands();
    _findReadmePath();
    _loadRemoteMarketplaceRepo();
  }

  /// 智能查找 README 文件（大小写不敏感）
  Future<void> _findReadmePath() async {
    final installPath = widget.plugin.installPath;
    final dir = Directory(installPath);

    if (!await dir.exists()) return;

    try {
      // 可能的 README 文件名变体
      final possibleNames = [
        'README.md',
        'readme.md',
        'Readme.md',
        'README.MD',
        'ReadMe.md',
      ];

      await for (final entity in dir.list()) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          if (possibleNames.contains(fileName)) {
            setState(() => _readmePath = entity.path);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error finding README: $e');
    }
  }

  /// 从 marketplace.json 解析远程 marketplace repo
  Future<void> _loadRemoteMarketplaceRepo() async {
    try {
      final installPath = widget.plugin.installPath;
      final marketplaceJsonPath = '$installPath/.claude-plugin/marketplace.json';
      final marketplaceJsonFile = File(marketplaceJsonPath);

      if (await marketplaceJsonFile.exists()) {
        final content = await marketplaceJsonFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final plugins = json['plugins'] as List<dynamic>?;

        if (plugins != null && plugins.isNotEmpty) {
          // 取第一个插件的 source
          final firstPlugin = plugins[0] as Map<String, dynamic>;
          final source = firstPlugin['source'] as Map<String, dynamic>?;

          if (source != null) {
            final sourceType = source['source'] as String?;
            if (sourceType == 'github') {
              final repo = source['repo'] as String?;
              if (repo != null && repo.isNotEmpty) {
                setState(() => _remoteMarketplaceRepo = repo);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading marketplace repo: $e');
    }
  }

  /// 加载 plugin.json 信息
  Future<void> _loadPluginInfo() async {
    try {
      final installPath = widget.plugin.installPath;
      final pluginJsonPath = '$installPath/.claude-plugin/plugin.json';
      final pluginJsonFile = File(pluginJsonPath);

      if (await pluginJsonFile.exists()) {
        final content = await pluginJsonFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        setState(() {
          _pluginDescription = json['description'] as String?;
          final author = json['author'];
          if (author is Map<String, dynamic>) {
            _pluginAuthor = author['name'] as String?;
          } else if (author is String) {
            _pluginAuthor = author;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading plugin.json: $e');
    }
  }

  /// 从 known_marketplaces.json 和 marketplace.json 加载 GitHub URL
  Future<void> _loadGithubUrl() async {
    try {
      final home = PlatformUtils.userHome;
      final knownMarketplacesFile = File(PlatformUtils.joinPath(home, '.claude', 'plugins', 'known_marketplaces.json'));

      if (await knownMarketplacesFile.exists()) {
        final content = await knownMarketplacesFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        // scope 就是 marketplace 的名称
        final scope = widget.plugin.scope;
        if (json.containsKey(scope)) {
          final marketplaceInfo = json[scope] as Map<String, dynamic>;
          final marketplaceSource = marketplaceInfo['source'] as Map<String, dynamic>?;
          final installLocation = marketplaceInfo['installLocation'] as String?;

          // 插件名称（不含 @scope）
          final pluginName = widget.plugin.name.split('@').first;

          // 先从 marketplace.json 查找插件的 source 信息
          if (installLocation != null) {
            final marketplaceJsonFile = File('$installLocation/.claude-plugin/marketplace.json');
            if (await marketplaceJsonFile.exists()) {
              final marketplaceContent = await marketplaceJsonFile.readAsString();
              final marketplaceJson = jsonDecode(marketplaceContent) as Map<String, dynamic>;
              final plugins = marketplaceJson['plugins'] as List<dynamic>?;
              if (plugins != null) {
                for (final plugin in plugins) {
                  if (plugin is Map<String, dynamic> && plugin['name'] == pluginName) {
                    final pluginSource = plugin['source'];

                    // 情况1: source 是对象，包含 url 字段（外部插件）
                    if (pluginSource is Map<String, dynamic>) {
                      final sourceType = pluginSource['source'] as String?;
                      if (sourceType == 'url' || sourceType == 'github') {
                        // 检查插件是否实际可用（skills 或 commands 目录存在）
                        // 如果插件已正确安装且有内容，则不是"远程源"问题
                        final installPath = widget.plugin.installPath;
                        final skillsDir = Directory('$installPath/skills');
                        final commandsDir = Directory('$installPath/commands');
                        final hasLocalContent = await skillsDir.exists() || await commandsDir.exists();

                        // 只有当插件目录下没有 skills/commands 时才标记为远程源
                        if (!hasLocalContent) {
                          setState(() => _isRemoteSource = true);
                        }

                        if (sourceType == 'url') {
                          final url = pluginSource['url'] as String?;
                          if (url != null && url.contains('github.com')) {
                            // 从 .git URL 提取 GitHub 仓库链接
                            var githubUrl = url.replaceAll('.git', '');
                            setState(() {
                              _githubUrl = githubUrl;
                            });
                            return;
                          }
                        } else if (sourceType == 'github') {
                          final repo = pluginSource['repo'] as String?;
                          if (repo != null) {
                            setState(() {
                              _githubUrl = 'https://github.com/$repo';
                            });
                            return;
                          }
                        }
                      }
                    }
                    // 情况2: source 是字符串，表示本地路径（如 "./plugins/xxx"）
                    else if (pluginSource is String) {
                      // 去掉开头的 "./"
                      final pluginPath = pluginSource.startsWith('./')
                          ? pluginSource.substring(2)
                          : pluginSource;

                      // 使用 marketplace 的 repo 构建 URL
                      if (marketplaceSource != null && marketplaceSource['source'] == 'github') {
                        final repo = marketplaceSource['repo'] as String?;
                        if (repo != null && repo.isNotEmpty) {
                          setState(() {
                            _githubUrl = 'https://github.com/$repo/tree/main/$pluginPath';
                          });
                          return;
                        }
                      }
                    }
                    break;
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading GitHub URL: $e');
    }
  }

  Future<void> _loadSkills() async {
    setState(() => _loading = true);

    try {
      final skills = <Map<String, String>>[];
      final installPath = widget.plugin.installPath;
      final pluginDir = Directory(installPath);

      if (await pluginDir.exists()) {
        // 遍历插件目录，查找所有 SKILL.md 文件
        await for (final entity in pluginDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('SKILL.md')) {
            final content = await entity.readAsString();
            // 解析 SKILL.md 获取名称和描述
            final name = _parseSkillName(content, entity.path);
            final description = _skillsService.parseSkillDescription(content) ?? '';
            skills.add({
              'name': name,
              'description': description,
              'path': entity.path,
            });
          }
        }
      }

      // 按名称排序
      skills.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));

      setState(() {
        _skills = skills;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading skills: $e');
      setState(() => _loading = false);
    }
  }

  /// 加载 agents 目录下的 .md 文件（递归扫描子目录）
  Future<void> _loadAgents() async {
    try {
      final installPath = widget.plugin.installPath;
      final agentsDir = Directory('$installPath/agents');

      if (!await agentsDir.exists()) return;

      final agents = <Map<String, String>>[];
      // 递归扫描，支持 agents/xxx.md 和 agents/plugin-name/xxx.md 两种结构
      await for (final entity in agentsDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.md')) {
          final content = await entity.readAsString();
          final name = _parseMdName(content, entity.path);
          final description = _parseMdDescription(content);
          agents.add({
            'name': name,
            'description': description,
            'path': entity.path,
          });
        }
      }

      agents.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      setState(() => _agents = agents);
    } catch (e) {
      debugPrint('Error loading agents: $e');
    }
  }

  /// 加载 commands 目录下的 .md 文件（递归扫描子目录）
  Future<void> _loadCommands() async {
    try {
      final installPath = widget.plugin.installPath;
      final commandsDir = Directory('$installPath/commands');

      if (!await commandsDir.exists()) return;

      final commands = <Map<String, String>>[];
      // 递归扫描，支持 commands/xxx.md 和 commands/plugin-name/xxx.md 两种结构
      await for (final entity in commandsDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.md')) {
          final content = await entity.readAsString();
          final name = _parseMdName(content, entity.path);
          final description = _parseMdDescription(content);
          commands.add({
            'name': name,
            'description': description,
            'path': entity.path,
          });
        }
      }

      commands.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      setState(() => _commands = commands);
    } catch (e) {
      debugPrint('Error loading commands: $e');
    }
  }

  /// 从 .md 文件中解析名称（支持 frontmatter 的 name 字段或文件名）
  String _parseMdName(String content, String filePath) {
    // 尝试从 frontmatter 解析 name
    final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(content);
    if (nameMatch != null) {
      return nameMatch.group(1)?.trim() ?? '';
    }

    // 使用文件名（不含扩展名）
    final fileName = filePath.split('/').last;
    return fileName.replaceAll('.md', '');
  }

  /// 从 .md 文件中解析描述（支持 frontmatter 的 description 字段）
  String _parseMdDescription(String content) {
    final descMatch = RegExp(r'^description:\s*(.+)$', multiLine: true).firstMatch(content);
    if (descMatch != null) {
      return descMatch.group(1)?.trim() ?? '';
    }
    return '';
  }

  String _parseSkillName(String content, String filePath) {
    // 尝试从 SKILL.md 内容解析名称
    // 格式可能是: name: xxx 或 # xxx
    final nameMatch = RegExp(r'^name:\s*(.+)$', multiLine: true).firstMatch(content);
    if (nameMatch != null) {
      return nameMatch.group(1)?.trim() ?? '';
    }

    // 尝试从标题获取
    final titleMatch = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
    if (titleMatch != null) {
      return titleMatch.group(1)?.trim() ?? '';
    }

    // 使用目录名作为名称
    final parts = filePath.split('/');
    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    return 'Unknown Skill';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parts = widget.plugin.name.split('@');
    final pluginName = parts[0];
    final marketplace = parts.length > 1 ? parts[1] : '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(pluginName, marketplace, isDark),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 插件描述（来自 plugin.json）
                    if (_pluginDescription != null && _pluginDescription!.isNotEmpty) ...[
                      _buildDescriptionRow(_pluginDescription!, isDark),
                      const SizedBox(height: 12),
                    ],

                    // 远程源警告提示
                    if (_isRemoteSource) ...[
                      _buildRemoteSourceWarning(isDark),
                      const SizedBox(height: 12),
                    ],

                    // 插件基本信息
                    _buildInfoRow(
                      S.get('plugin_version'),
                      widget.plugin.version,
                      Icons.tag,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      S.get('plugin_scope'),
                      widget.plugin.scope,
                      Icons.layers,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    // 作者（来自 plugin.json）
                    if (_pluginAuthor != null && _pluginAuthor!.isNotEmpty) ...[
                      _buildInfoRow(
                        S.get('plugin_author'),
                        _pluginAuthor!,
                        Icons.person_outline,
                        isDark,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildInfoRow(
                      S.get('plugin_installed_at'),
                      _skillsService.formatDate(widget.plugin.installedAt),
                      Icons.calendar_today,
                      isDark,
                    ),
                    const SizedBox(height: 12),
                    // 安装路径（可点击打开）
                    _buildInstallPathRow(isDark),

                    const SizedBox(height: 12),

                    // 使用说明按钮（读取 README.md）
                    _buildReadmeButton(isDark),

                    const SizedBox(height: 20),

                    // Skills 列表
                    _buildSkillsSection(isDark),

                    // Agents 列表
                    if (_agents.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildAgentsSection(isDark),
                    ],

                    // Commands 列表
                    if (_commands.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildCommandsSection(isDark),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String pluginName, String marketplace, bool isDark) {
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
                Text(
                  pluginName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (marketplace.isNotEmpty)
                  Text(
                    '@$marketplace',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
          ),
          // GitHub 跳转按钮
          if (_githubUrl != null) ...[
            InkWell(
              onTap: () => _openGithubUrl(),
              borderRadius: BorderRadius.circular(6),
              child: Tooltip(
                message: 'View on GitHub',
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.github,
                    size: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
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

  Future<void> _openGithubUrl() async {
    if (_githubUrl != null) {
      await PlatformUtils.openUrl(_githubUrl!);
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.withValues(alpha: 0.8),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black87,
              fontFamily: label == S.get('plugin_version') ? 'monospace' : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionRow(String description, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.blue.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 远程源警告提示
  Widget _buildRemoteSourceWarning(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.orange.shade700,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  S.get('plugin_remote_source_warning'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          // 尝试安装按钮（仅当解析到 repo 时显示）
          if (_remoteMarketplaceRepo != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _tryInstallMarketplace,
                icon: const Icon(Icons.download_outlined, size: 14),
                label: Text(S.get('try_install_marketplace')),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.deepPurple,
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 尝试安装远程 marketplace
  Future<void> _tryInstallMarketplace() async {
    if (_remoteMarketplaceRepo == null) return;

    final terminalService = context.read<TerminalService>();
    terminalService.setFloatingTerminal(true);
    terminalService.openTerminalPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand('claude plugin marketplace add $_remoteMarketplaceRepo');

    // 关闭当前弹窗
    if (mounted) {
      Navigator.of(context).pop({'action': 'marketplace_installed', 'repo': _remoteMarketplaceRepo});
    }
  }

  Widget _buildInstallPathRow(bool isDark) {
    return InkWell(
      onTap: () => _openInFinder(widget.plugin.installPath),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 16,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.plugin.installPath,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.8),
                  fontFamily: 'monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: Colors.blue.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadmeButton(bool isDark) {
    final hasReadme = _readmePath != null;

    return Opacity(
      opacity: hasReadme ? 1.0 : 0.5,
      child: InkWell(
        onTap: hasReadme ? () => _showPluginReadme() : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.withValues(alpha: hasReadme ? 0.3 : 0.15),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 16,
                color: hasReadme ? Colors.orange : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasReadme ? S.get('plugin_readme') : S.get('no_readme'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: hasReadme ? Colors.orange : Colors.grey,
                  ),
                ),
              ),
              if (hasReadme)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.orange.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology, size: 18, color: Colors.teal),
            const SizedBox(width: 8),
            Text(
              'Skills (${_skills.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_skills.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                S.get('no_skills'),
                style: TextStyle(
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
              ),
            ),
          )
        else
          ...(_skills.map((skill) => _buildSkillItem(skill, isDark))),
      ],
    );
  }

  Widget _buildAgentsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.smart_toy_outlined, size: 18, color: Colors.deepPurple),
            const SizedBox(width: 8),
            Text(
              'Agents (${_agents.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_agents.map((agent) => _buildMdItem(
              agent,
              isDark,
              Colors.deepPurple,
              Icons.smart_toy_outlined,
            ))),
      ],
    );
  }

  Widget _buildCommandsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.terminal, size: 18, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              'Commands (${_commands.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...(_commands.map((cmd) => _buildCommandItem(cmd, isDark))),
      ],
    );
  }

  /// Command 项展示（带复制功能）
  Widget _buildCommandItem(Map<String, String> cmd, bool isDark) {
    final name = cmd['name'] ?? '';
    final description = cmd['description'] ?? '';
    // Commands 格式：/插件名:命令名（带冒号）
    final pluginName = widget.plugin.name.split('@').first;
    final command = '/$pluginName:$name';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.indigo.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.indigo.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.terminal, size: 14, color: Colors.indigo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              // 复制按钮
              InkWell(
                onTap: () => _copySkillCommand(command),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.content_copy,
                    size: 14,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 查看内容按钮
              InkWell(
                onTap: () => _showMdContent(cmd['path'] ?? '', name),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 打开文件夹按钮
              InkWell(
                onTap: () => _openInFinder(cmd['path'] ?? ''),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.folder_open_outlined,
                    size: 16,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          // 指令
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 4),
            child: Text(
              command,
              style: TextStyle(
                fontSize: 10,
                color: Colors.indigo.withValues(alpha: 0.7),
                fontFamily: 'monospace',
              ),
            ),
          ),
          // 描述
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 2),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  /// 通用的 .md 文件项展示
  Widget _buildMdItem(
    Map<String, String> item,
    bool isDark,
    Color color,
    IconData icon,
  ) {
    final name = item['name'] ?? '';
    final description = item['description'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              // 查看内容按钮
              InkWell(
                onTap: () => _showMdContent(item['path'] ?? '', name),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 打开文件夹按钮
              InkWell(
                onTap: () => _openInFinder(item['path'] ?? ''),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.folder_open_outlined,
                    size: 16,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 6),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  /// 显示 .md 文件内容
  Future<void> _showMdContent(String path, String name) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SkillContentDialog(
        skillPath: path,
        skillName: name,
        isReadme: false,
      ),
    );
  }

  Widget _buildSkillItem(Map<String, String> skill, bool isDark) {
    final skillName = skill['name'] ?? '';
    final command = '/$skillName';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.teal.withValues(alpha: 0.1) : Colors.teal.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.teal.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行：图标 + 名称 + 三个按钮
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  skillName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              // 复制按钮
              InkWell(
                onTap: () => _copySkillCommand(command),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.content_copy,
                    size: 14,
                    color: Colors.grey.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 查看 SKILL.md 按钮
              InkWell(
                onTap: () => _showSkillContent(skill['path'] ?? ''),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 打开文件夹按钮
              InkWell(
                onTap: () => _openInFinder(skill['path'] ?? ''),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.folder_open_outlined,
                    size: 16,
                    color: Colors.grey.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          // 指令
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 4),
            child: Text(
              command,
              style: TextStyle(
                fontSize: 10,
                color: Colors.teal.withValues(alpha: 0.7),
                fontFamily: 'monospace',
              ),
            ),
          ),
          // 描述
          if ((skill['description'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 40, top: 2),
              child: Text(
                skill['description'] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  void _copySkillCommand(String command) {
    Clipboard.setData(ClipboardData(text: command));
    Toast.show(
      context,
      message: S.get('skill_copied_hint'),
      type: ToastType.success,
    );
  }

  Future<void> _openInFinder(String path) async {
    await PlatformUtils.openInFileManager(path);
  }

  Future<void> _showSkillContent(String skillPath) async {
    // skillPath 是 SKILL.md 的完整路径
    // 从路径中提取 skill 名称
    final parts = skillPath.split('/');
    final skillName = parts.length >= 2 ? parts[parts.length - 2] : 'Skill';

    await showDialog<void>(
      context: context,
      builder: (context) => _SkillContentDialog(
        skillPath: skillPath,
        skillName: skillName,
        isReadme: false,
      ),
    );
  }

  Future<void> _showPluginReadme() async {
    if (_readmePath == null) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _SkillContentDialog(
        skillPath: _readmePath!,
        skillName: widget.plugin.name.split('@').first,
        isReadme: true,
      ),
    );
  }
}
