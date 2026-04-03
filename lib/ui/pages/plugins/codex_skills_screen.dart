import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../../../l10n/s.dart';
import '../../../models/editor_type.dart';
import '../../../services/codex_skills_service.dart';
import '../../../services/codex_plugins_service.dart';
import '../../../utils/platform_utils.dart';
import '../../../models/codex_skill.dart';
import '../../../models/codex_plugin.dart';
import '../../components/custom_toast.dart';
import '../../components/custom_dialog.dart';
import '../../components/skills_editor_switcher.dart';
import 'claude_code_skills_screen.dart';
import 'gemini_skills_screen.dart';
import 'antigravity_skills_screen.dart';

// Part 文件 - Dialogs
part 'codex_skills/dialogs/codex_skill_detail_dialog.dart';
part 'codex_skills/dialogs/custom_skill_install_dialog.dart';
// Part 文件 - Sections
part 'codex_skills/sections/plugin_section.dart';

/// Codex Skills 管理页面
class CodexSkillsScreen extends StatefulWidget {
  const CodexSkillsScreen({super.key});

  @override
  State<CodexSkillsScreen> createState() => _CodexSkillsScreenState();
}

class _CodexSkillsScreenState extends State<CodexSkillsScreen> with SingleTickerProviderStateMixin {
  final _skillsService = CodexSkillsService();
  final _pluginsService = CodexPluginsService();

  List<CodexSkill> _localSkills = [];
  List<CodexSkill> _agentsSkills = [];
  List<CuratedCodexSkill> _curatedSkills = [];
  List<CodexPlugin> _marketplacePlugins = [];
  bool _loadingLocal = true;
  bool _loadingAgents = true;
  bool _loadingCurated = true;
  bool _loadingPlugins = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadLocalSkills();
    _loadAgentsSkills();
    _loadMarketplacePlugins();
    _loadCuratedSkills();
  }

  Future<void> _loadLocalSkills() async {
    setState(() => _loadingLocal = true);
    try {
      final skills = await _skillsService.loadLocalSkills();
      setState(() {
        _localSkills = skills;
        _loadingLocal = false;
      });
    } catch (e) {
      setState(() {
        _localSkills = [];
        _loadingLocal = false;
      });
    }
  }

  Future<void> _loadAgentsSkills() async {
    setState(() => _loadingAgents = true);
    try {
      final skills = await _skillsService.loadAgentsSkills();
      setState(() {
        _agentsSkills = skills;
        _loadingAgents = false;
      });
    } catch (e) {
      setState(() {
        _agentsSkills = [];
        _loadingAgents = false;
      });
    }
  }

  Future<void> _loadMarketplacePlugins() async {
    setState(() => _loadingPlugins = true);
    try {
      final plugins = await _pluginsService.loadMarketplacePlugins();
      setState(() {
        _marketplacePlugins = plugins;
        _loadingPlugins = false;
      });
    } catch (e) {
      setState(() {
        _marketplacePlugins = [];
        _loadingPlugins = false;
      });
    }
  }

  Future<void> _loadCuratedSkills({bool forceRefresh = false}) async {
    setState(() => _loadingCurated = true);
    try {
      final skills = await _skillsService.loadCuratedSkills(
        forceRefresh: forceRefresh,
      );
      setState(() {
        _curatedSkills = skills;
        _loadingCurated = false;
      });
    } catch (e) {
      setState(() {
        _curatedSkills = [];
        _loadingCurated = false;
      });
    }
  }

  Future<void> _refreshCuratedSkills() async {
    _skillsService.clearCache();
    await _loadCuratedSkills(forceRefresh: true);
    if (mounted) {
      Toast.show(
        context,
        message: S.get('codex_curated_refreshed'),
        type: ToastType.success,
      );
    }
  }

  Future<void> _showSkillDetailDialog(CodexSkill skill) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CodexSkillDetailDialog(
        skill: skill,
        onDeleted: _loadLocalSkills,
      ),
    );
  }

  void _copySkillCommand(String skillName) {
    final command = '\$$skillName';
    Clipboard.setData(ClipboardData(text: command));
    Toast.show(
      context,
      message: S.get('codex_skill_copied').replaceAll('{name}', command),
      type: ToastType.success,
    );
  }

  void _copyInstallCommand(CuratedCodexSkill skill) {
    Clipboard.setData(ClipboardData(text: skill.installCommand));
    Toast.show(
      context,
      message: S.get('codex_install_command_copied'),
      type: ToastType.success,
    );
  }

  Future<void> _confirmDeleteSkill(CodexSkill skill) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_delete_title'),
      content: S.get('codex_delete_skill_confirm').replaceAll('{name}', skill.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      try {
        final dir = Directory(skill.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          _loadLocalSkills();
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

  void _openGitHub() {
    launchUrl(Uri.parse('https://github.com/openai/skills'));
  }

  void _showCustomSkillInstallDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => _CodexCustomSkillInstallDialog(
        onInstalled: _loadLocalSkills,
      ),
    );
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
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLocalSkillsSection(isDark),
                    const SizedBox(height: 24),
                    _buildAgentsSkillsSection(isDark),
                    const SizedBox(height: 24),
                    _buildMarketplacePluginsSection(isDark),
                    const SizedBox(height: 24),
                    _buildCuratedSkillsSection(isDark),
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
            case EditorType.claude:
              return const SkillsScreen();
            case EditorType.gemini:
              return const GeminiSkillsScreen();
            case EditorType.antigravity:
              return const AntigravitySkillsScreen();
            default:
              return const CodexSkillsScreen();
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
            S.get('codex_skills_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 8),
          // 编辑器切换下拉按钮
          SkillsEditorSwitcher(
            currentEditor: EditorType.codex,
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

  // ============ 本地 Skills 区域 ============
  Widget _buildLocalSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithAction(
          S.get('codex_local_skills'),
          Icons.folder_special,
          Colors.green,
          actionIcon: Icons.add,
          actionTooltip: S.get('custom_skill_install'),
          onAction: _showCustomSkillInstallDialog,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('codex_local_skills_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingLocal)
          const Center(child: CircularProgressIndicator())
        else if (_localSkills.isEmpty)
          _buildEmptyCard(S.get('codex_no_local_skills'))
        else
          _buildLocalSkillCards(isDark),
      ],
    );
  }

  Widget _buildLocalSkillCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _localSkills.map((skill) => _buildLocalSkillCard(skill, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildLocalSkillCard(CodexSkill skill, bool isDark, double cardWidth) {
    final accentColor = skill.isSystem ? Colors.blue : Colors.green;

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _showSkillDetailDialog(skill),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: accentColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        skill.isSystem ? Icons.settings : Icons.folder_special,
                        size: 16,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        skill.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (skill.isSystem)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          S.get('codex_system_skill'),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (skill.hasSkillMd)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(
                            alpha: isDark ? 0.2 : 0.1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  skill.description ?? S.get('no_description'),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () => _copySkillCommand(skill.name),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: accentColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    if (!skill.isSystem) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _confirmDeleteSkill(skill),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ Agents Skills 区域 ============
  Widget _buildAgentsSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          S.get('codex_agents_skills'),
          Icons.smart_toy_outlined,
          Colors.orange,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('codex_agents_skills_hint'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingAgents)
          const Center(child: CircularProgressIndicator())
        else if (_agentsSkills.isEmpty)
          _buildEmptyCard(S.get('codex_no_agents_skills'))
        else
          _buildAgentsSkillCards(isDark),
      ],
    );
  }

  Widget _buildAgentsSkillCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth =
            (constraints.maxWidth - (spacing * (cardsPerRow - 1))) /
            cardsPerRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _agentsSkills
              .map((skill) => _buildAgentsSkillCard(skill, isDark, cardWidth))
              .toList(),
        );
      },
    );
  }

  Widget _buildAgentsSkillCard(
    CodexSkill skill,
    bool isDark,
    double cardWidth,
  ) {
    const accentColor = Colors.orange;

    return SizedBox(
      width: cardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      skill.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (skill.groupName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        skill.groupName!,
                        style: const TextStyle(
                          fontSize: 9,
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (skill.isSymlink) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'symlink',
                      child: Icon(
                        Icons.link,
                        size: 13,
                        color: Colors.grey.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                skill.description ?? S.get('no_description'),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.withValues(alpha: 0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () => _copySkillCommand(skill.name),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 精选 Skills 区域 ============
  Widget _buildCuratedSkillsSection(bool isDark) {
    final curatedList = _curatedSkills.where((s) => s.isCurated).toList();
    final experimentalList = _curatedSkills.where((s) => s.isExperimental).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, size: 20, color: Colors.orange),
            const SizedBox(width: 8),
            Text(
              S.get('codex_curated_skills'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20, color: Colors.orange),
              onPressed: _refreshCuratedSkills,
              tooltip: S.get('refresh_config'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            IconButton(
              icon: const Icon(Icons.open_in_new, size: 20, color: Colors.orange),
              onPressed: _openGitHub,
              tooltip: S.get('codex_open_github'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('codex_curated_skills_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingCurated)
          const Center(child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ))
        else if (_curatedSkills.isEmpty)
          _buildEmptyCard(S.get('codex_loading_curated'))
        else
          Column(
            children: [
              // Tab 切换
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: isDark ? Colors.grey.shade700 : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: isDark ? Colors.white : Colors.black87,
                  unselectedLabelColor: Colors.grey,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: '${S.get('codex_curated_tab')} (${curatedList.length})'),
                    Tab(text: '${S.get('codex_experimental_tab')} (${experimentalList.length})'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Tab 内容
              SizedBox(
                height: 300, // 固定高度，避免布局问题
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCuratedSkillCards(curatedList, isDark),
                    _buildCuratedSkillCards(experimentalList, isDark),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildCuratedSkillCards(List<CuratedCodexSkill> skills, bool isDark) {
    if (skills.isEmpty) {
      return Center(child: Text(S.get('no_skills')));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return SingleChildScrollView(
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: skills.map((skill) => _buildCuratedSkillCard(skill, isDark, cardWidth)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildCuratedSkillCard(CuratedCodexSkill skill, bool isDark, double cardWidth) {
    final tagColor = skill.isCurated ? Colors.orange : Colors.purple;

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _copyInstallCommand(skill),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: tagColor.withValues(alpha: 0.3), width: 1),
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
                        color: tagColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        skill.isCurated ? Icons.star : Icons.science,
                        size: 16,
                        color: tagColor,
                      ),
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
                  ],
                ),
                const SizedBox(height: 8),
                // 安装命令
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    skill.installCommand,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: tagColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 复制按钮
                    InkWell(
                      onTap: () => _copyInstallCommand(skill),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 14, color: tagColor.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              S.get('copy'),
                              style: TextStyle(fontSize: 11, color: tagColor.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // GitHub 按钮
                    InkWell(
                      onTap: () => launchUrl(Uri.parse(skill.githubUrl)),
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
          ),
        ),
      ),
    );
  }

  // ============ 公共组件 ============
  Widget _buildSectionTitle(String title, IconData icon, Color color) {
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
