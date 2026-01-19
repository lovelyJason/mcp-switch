import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import '../l10n/s.dart';
import '../models/editor_type.dart';
import '../services/terminal_service.dart';
import '../services/skills_service.dart';
import '../services/translation_service.dart';
import '../services/config_service.dart';
import '../utils/platform_utils.dart';
import '../models/skills/preset_marketplace.dart';
import '../models/skills/installed_plugin.dart';
import '../models/skills/installed_marketplace.dart';
import '../models/skills/community_skill.dart';
import 'components/custom_toast.dart';
import 'components/custom_dialog.dart';
import 'components/skills_editor_switcher.dart';
import 'claude_code_skills/components/hover_popover.dart';
import 'codex_skills_screen.dart';
import 'gemini_skills_screen.dart';
import 'antigravity_skills_screen.dart';

// Part 文件 - Dialogs
part 'claude_code_skills/dialogs/add_marketplace_dialog.dart';
part 'claude_code_skills/dialogs/readme_viewer_dialog.dart';
part 'claude_code_skills/dialogs/plugin_detail_dialog.dart';
part 'claude_code_skills/dialogs/marketplace_detail_dialog.dart';
part 'claude_code_skills/dialogs/skill_content_dialog.dart';
part 'claude_code_skills/dialogs/community_skill_detail_dialog.dart';
part 'claude_code_skills/dialogs/custom_skill_install_dialog.dart';

/// Skills 管理页面
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final _skillsService = SkillsService();

  List<InstalledPlugin> _plugins = [];
  List<InstalledMarketplace> _marketplaces = [];
  List<CommunitySkill> _communitySkills = [];
  bool _loading = true;
  bool _wasTerminalOpen = false;
  TerminalService? _terminalService;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupTerminalListener();
  }

  @override
  void dispose() {
    _terminalService?.removeListener(_onTerminalStateChanged);
    super.dispose();
  }

  void _setupTerminalListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _terminalService = context.read<TerminalService>();
      _terminalService!.addListener(_onTerminalStateChanged);
      _wasTerminalOpen = _terminalService!.isTerminalPanelOpen;
    });
  }

  void _onTerminalStateChanged() {
    if (!mounted || _terminalService == null) return;

    final isOpen = _terminalService!.isTerminalPanelOpen;
    // 当终端从打开变成关闭时，刷新数据
    if (_wasTerminalOpen && !isOpen) {
      _loadData();
    }
    _wasTerminalOpen = isOpen;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final plugins = await _skillsService.loadPlugins();
      final marketplaces = await _skillsService.loadMarketplaces();
      final communitySkills = await _skillsService.loadCommunitySkills();

      setState(() {
        _plugins = plugins;
        _marketplaces = marketplaces;
        _communitySkills = communitySkills;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _plugins = [];
        _marketplaces = [];
        _communitySkills = [];
        _loading = false;
      });
    }
  }

  Future<void> _showAddMarketplaceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AddMarketplaceDialog(
        installedMarketplaces: _marketplaces,
        onAdded: _loadData,
      ),
    );
  }

  Future<void> _showCommunitySkillDetailDialog(CommunitySkill skill) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CommunitySkillDetailDialog(
        skill: skill,
        onDeleted: _loadData,
      ),
    );
  }

  Future<void> _showPluginDetailDialog(InstalledPlugin plugin) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PluginDetailDialog(plugin: plugin),
    );
  }

  Future<void> _showMarketplaceDetailDialog(InstalledMarketplace marketplace) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _MarketplaceDetailDialog(
        marketplace: marketplace,
        installedPlugins: _plugins,
        onInstalled: _loadData,
      ),
    );
  }

  Future<void> _showReadmeDialog(InstalledMarketplace marketplace) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ReadmeViewerDialog(marketplace: marketplace),
    );
  }

  Future<void> _openInFinder(String marketplace) async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude', 'plugins', 'marketplaces', marketplace);
    await PlatformUtils.openInFileManager(path);
  }

  Future<void> _updateMarketplace(String marketplaceName) async {
    final terminalService = context.read<TerminalService>();
    terminalService.setFloatingTerminal(true);
    terminalService.openTerminalPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand('claude plugin marketplace update $marketplaceName');
  }

  // 市场提示信息映射
  String? _getMarketplaceHint(String name) {
    final hints = {
      'claude-code-plugins': 'marketplace_hint_claude_code',
      'anthropic-agent-skills': 'marketplace_hint_agent_skills',
      'claude-plugins-official': 'marketplace_hint_official',
      'superpowers-dev': 'marketplace_hint_superpowers',
    };
    final key = hints[name];
    return key != null ? S.get(key) : null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      body: Column(
        children: [
          // 红绿灯占位区域
          const SizedBox(height: 38),
          // 自定义 AppBar
          _buildAppBar(isDark),
          // 内容区域
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPluginsSection(isDark),
                        const SizedBox(height: 16),
                        _buildCommunitySkillsSection(isDark),
                        const SizedBox(height: 16),
                        _buildMarketplacesSection(isDark),
                      ],
                    ),
                  ),
                ),
          ),
        ],
      ),
    );
  }

  void _switchToEditor(EditorType editor) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          switch (editor) {
            case EditorType.codex:
              return const CodexSkillsScreen();
            case EditorType.gemini:
              return const GeminiSkillsScreen();
            case EditorType.antigravity:
              return const AntigravitySkillsScreen();
            default:
              return const SkillsScreen();
          }
        },
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 带圆角背景的返回按钮
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: S.get('back'),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            S.get('plugin_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 8),
          // 编辑器切换下拉按钮
          SkillsEditorSwitcher(
            currentEditor: EditorType.claude,
            onSwitch: _switchToEditor,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: S.get('refresh_config'),
          ),
        ],
      ),
    );
  }

  // ============ 本地插件区域 ============
  Widget _buildPluginsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(S.get('local_plugins'), Icons.extension, Colors.blue),
        const SizedBox(height: 12),
        if (_plugins.isEmpty)
          _buildEmptyCard(S.get('no_skills'))
        else
          _buildPluginCards(isDark),
      ],
    );
  }

  Widget _buildPluginCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _plugins.map((plugin) => _buildPluginCard(plugin, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildPluginCard(InstalledPlugin plugin, bool isDark, double cardWidth) {
    final parts = plugin.name.split('@');
    final pluginName = parts[0];
    final marketplace = parts.length > 1 ? parts[1] : '';
    final isEnabled = plugin.isEnabled;

    return SizedBox(
      width: cardWidth,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isEnabled
                  ? Colors.grey.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: () => _showPluginDetailDialog(plugin),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 图标和名称
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.extension, size: 16, color: Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pluginName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          marketplace,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 版本和日期
                  Row(
                    children: [
                      Icon(Icons.tag, size: 11, color: Colors.grey.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        plugin.version.length > 10
                            ? '${plugin.version.substring(0, 10)}...'
                            : plugin.version,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.withValues(alpha: 0.8),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.calendar_today, size: 11, color: Colors.grey.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        _skillsService.formatDate(plugin.installedAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 操作按钮行
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 禁用/启用开关
                      InkWell(
                        onTap: () => _togglePluginEnabled(plugin),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isEnabled ? Icons.toggle_on : Icons.toggle_off,
                            size: 22,
                            color: isEnabled
                                ? Colors.green.withValues(alpha: 0.8)
                                : Colors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 删除按钮
                      InkWell(
                        onTap: () => _confirmUninstallPlugin(plugin),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 切换插件启用状态
  Future<void> _togglePluginEnabled(InstalledPlugin plugin) async {
    final terminalService = context.read<TerminalService>();
    final command = plugin.isEnabled
        ? 'claude plugin disable ${plugin.name}'
        : 'claude plugin enable ${plugin.name}';

    terminalService.setFloatingTerminal(true);
    terminalService.openTerminalPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand(command);
  }

  /// 确认卸载插件
  Future<void> _confirmUninstallPlugin(InstalledPlugin plugin) async {
    final parts = plugin.name.split('@');
    final pluginName = parts[0];

    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_uninstall_title'),
      content: S.get('confirm_uninstall_content').replaceAll('{name}', pluginName),
      confirmText: S.get('uninstall'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      final terminalService = context.read<TerminalService>();
      terminalService.setFloatingTerminal(true);
      terminalService.openTerminalPanel();
      await Future.delayed(const Duration(milliseconds: 500));
      terminalService.sendCommand('claude plugin uninstall ${plugin.name}');
    }
  }

  // ============ 社区 Skills 区域 ============
  Widget _buildCommunitySkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithAction(
          S.get('community_skills'),
          Icons.folder_special,
          Colors.teal,
          actionIcon: Icons.add_circle_outline,
          actionTooltip: S.get('custom_skill_install'),
          onAction: _showCustomSkillInstallDialog,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('community_skills_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        if (_communitySkills.isEmpty)
          _buildEmptyCard(S.get('no_community_skills'))
        else
          _buildCommunitySkillCards(isDark),
      ],
    );
  }

  Future<void> _showCustomSkillInstallDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CustomSkillInstallDialog(
        onInstalled: _loadData,
      ),
    );
  }

  Widget _buildCommunitySkillCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              _communitySkills.map((skill) => _buildCommunitySkillCard(skill, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildCommunitySkillCard(CommunitySkill skill, bool isDark, double cardWidth) {
    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _showCommunitySkillDetailDialog(skill),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.teal.withValues(alpha: 0.3), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标和名称
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.folder_special, size: 16, color: Colors.teal),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        skill.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (skill.hasSkillMd)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.green),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // 描述
                Text(
                  skill.description ?? S.get('no_description'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // 操作按钮行
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 复制按钮
                    InkWell(
                      onTap: () => _copyCommunitySkillCommand(skill.name),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: Colors.teal.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 删除按钮
                    InkWell(
                      onTap: () => _confirmDeleteCommunitySkill(skill),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 复制社区 Skill 命令
  void _copyCommunitySkillCommand(String skillName) {
    final command = '/skill $skillName';
    Clipboard.setData(ClipboardData(text: command));
    Toast.show(
      context,
      message: S.get('skill_copied_hint'),
      type: ToastType.success,
    );
  }

  /// 确认删除社区 Skill
  Future<void> _confirmDeleteCommunitySkill(CommunitySkill skill) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_delete_title'),
      content: S.get('confirm_delete_skill_content').replaceAll('{name}', skill.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      try {
        final dir = Directory(skill.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          _loadData();
          if (mounted) {
            Toast.show(context, message: S.get('skill_deleted'), type: ToastType.success);
          }
        }
      } catch (e) {
        if (mounted) {
          Toast.show(context, message: S.get('skill_delete_failed'), type: ToastType.error);
        }
      }
    }
  }

  // ============ 市场区域 ============
  Widget _buildMarketplacesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithAction(
          S.get('marketplaces'),
          Icons.store,
          Colors.orange,
          actionIcon: Icons.add_circle_outline,
          actionTooltip: S.get('add_marketplace'),
          onAction: _showAddMarketplaceDialog,
        ),
        const SizedBox(height: 12),
        if (_marketplaces.isEmpty)
          _buildEmptyCard(S.get('no_marketplaces'))
        else
          _buildMarketplaceCards(isDark),
      ],
    );
  }

  Widget _buildMarketplaceCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              _marketplaces.map((marketplace) => _buildMarketplaceCard(marketplace, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildMarketplaceCard(InstalledMarketplace marketplace, bool isDark, double cardWidth) {
    final isOfficial = marketplace.isOfficial;
    final tagColor = isOfficial ? Colors.blue : Colors.purple;
    final hint = _getMarketplaceHint(marketplace.name);

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _showMarketplaceDetailDialog(marketplace),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图标和标签
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isOfficial ? Icons.verified : Icons.groups,
                        size: 16,
                        color: tagColor,
                      ),
                    ),
                    // 有提示信息时显示问号
                    if (hint != null) HoverPopover(message: hint, isDark: isDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        marketplace.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOfficial ? S.get('official') : S.get('community'),
                        style: TextStyle(
                          fontSize: 9,
                          color: tagColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Repo 信息
                Row(
                  children: [
                    Icon(Icons.link, size: 12, color: Colors.grey.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        marketplace.repo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.withValues(alpha: 0.8),
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 更新时间和操作按钮
                Row(
                  children: [
                    Icon(Icons.update, size: 12, color: Colors.grey.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _skillsService.formatDate(marketplace.lastUpdated),
                      style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                    ),
                    const Spacer(),
                    // 更新市场按钮
                    InkWell(
                      onTap: () => _updateMarketplace(marketplace.name),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.sync,
                          size: 16,
                          color: Colors.blue.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    // README 查看按钮
                    if (marketplace.hasReadme)
                      InkWell(
                        onTap: () => _showReadmeDialog(marketplace),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: Colors.orange.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    // 打开文件夹按钮
                    InkWell(
                      onTap: () => _openInFinder(marketplace.name),
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
                    // 删除市场按钮
                    InkWell(
                      onTap: () => _confirmRemoveMarketplace(marketplace),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 确认移除市场
  Future<void> _confirmRemoveMarketplace(InstalledMarketplace marketplace) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_remove_marketplace_title'),
      content: S.get('confirm_remove_marketplace_content').replaceAll('{name}', marketplace.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      final terminalService = context.read<TerminalService>();
      terminalService.setFloatingTerminal(true);
      terminalService.openTerminalPanel();
      await Future.delayed(const Duration(milliseconds: 500));
      terminalService.sendCommand('claude plugin marketplace remove ${marketplace.name}');
    }
  }

  // ============ 公共组件 ============
  Widget _buildSectionTitle(String title, IconData icon, Color color, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitleWithAction(
    String title,
    IconData icon,
    Color color, {
    required IconData actionIcon,
    required String actionTooltip,
    required VoidCallback onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(actionIcon, size: 20, color: color),
          onPressed: onAction,
          tooltip: actionTooltip,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
      ),
    );
  }
}
