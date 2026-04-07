import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../../l10n/s.dart';
import '../../../models/editor_type.dart';
import '../../../services/terminal_service.dart';
import '../../../services/skills_service.dart';
import '../../../services/skills_archive_service.dart';
import '../../../services/translation_service.dart';
import '../../../services/config/config_service.dart';
import '../../../utils/platform_utils.dart';
import '../../../models/skills/preset_marketplace.dart';
import '../../../models/skills/installed_plugin.dart';
import '../../../models/skills/skill_usage_item.dart';
import '../../../models/skills/installed_marketplace.dart';
import '../../../models/skills/community_skill.dart';
import '../../../models/skills/slash_command.dart';
import '../../components/custom_toast.dart';
import '../../components/custom_dialog.dart';
import '../../components/skills_editor_switcher.dart';
import '../../components/hover_card.dart';
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
part 'claude_code_skills/dialogs/slash_command_search_dialog.dart';
part 'claude_code_skills/dialogs/skill_usage_dialog.dart';
part 'claude_code_skills/dialogs/skills_export_dialog.dart';
part 'claude_code_skills/dialogs/skills_import_dialog.dart';

// Part 文件 - Sections
part 'claude_code_skills/sections/plugins_section.dart';
part 'claude_code_skills/sections/community_skills_section.dart';
part 'claude_code_skills/sections/marketplace_section.dart';

/// Skills 管理页面
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final _skillsService = SkillsService();
  final _scrollController = ScrollController();
  final _marketplaceSectionKey = GlobalKey();

  List<InstalledPlugin> _plugins = [];
  List<InstalledMarketplace> _marketplaces = [];
  List<CommunitySkill> _communitySkills = [];
  List<SkillUsageItem> _skillUsageItems = [];
  bool _loading = true;
  bool _wasTerminalOpen = false;
  TerminalService? _terminalService;

  String? _highlightedMarketplace;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupTerminalListener();
  }

  @override
  void dispose() {
    _terminalService?.removeListener(_onTerminalStateChanged);
    _scrollController.dispose();
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
    if (_wasTerminalOpen && !isOpen) {
      _loadData();
    }
    _wasTerminalOpen = isOpen;
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _skillsService.loadPlugins(),
        _skillsService.loadMarketplaces(),
        _skillsService.loadCommunitySkills(),
        _skillsService.loadSkillUsage(),
      ]);

      setState(() {
        _plugins = results[0] as List<InstalledPlugin>;
        _marketplaces = results[1] as List<InstalledMarketplace>;
        _communitySkills = results[2] as List<CommunitySkill>;
        _skillUsageItems = results[3] as List<SkillUsageItem>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _plugins = [];
        _marketplaces = [];
        _communitySkills = [];
        _skillUsageItems = [];
        _loading = false;
      });
    }
  }

  // ─── Dialog launchers ────────────────────────────────────────────────────────

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
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => _PluginDetailDialog(plugin: plugin),
    );

    if (result != null && result['action'] == 'marketplace_installed' && mounted) {
      final repo = result['repo'] as String?;
      if (repo != null) {
        Toast.show(
          context,
          message: S.get('marketplace_install_started'),
          type: ToastType.success,
          duration: const Duration(seconds: 4),
        );

        final marketplaceName = repo.split('/').last;
        setState(() => _highlightedMarketplace = marketplaceName);
        _scrollToMarketplaceSection();

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _highlightedMarketplace = null);
          }
        });
      }
    }
  }

  void _scrollToMarketplaceSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = _marketplaceSectionKey.currentContext;
      if (keyContext != null) {
        Scrollable.ensureVisible(
          keyContext,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
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

  Future<void> _showSkillUsageDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _SkillUsageDialog(items: _skillUsageItems),
    );
  }

  Future<void> _showSlashCommandSearchDialog() async {
    final commands = await _skillsService.scanSlashCommands(_plugins);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _SlashCommandSearchDialog(commands: commands),
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

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 38),
          _buildAppBar(isDark),
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
                        buildPluginsSection(isDark),
                        const SizedBox(height: 16),
                        buildCommunitySkillsSection(isDark),
                        const SizedBox(height: 16),
                        buildMarketplacesSection(isDark),
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
          SkillsEditorSwitcher(
            currentEditor: EditorType.claude,
            onSwitch: _switchToEditor,
          ),
          const Spacer(),
          if (_skillUsageItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFFD97757)),
              onPressed: _showSkillUsageDialog,
              tooltip: S.get('skill_usage_title'),
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSlashCommandSearchDialog,
            tooltip: S.get('search_slash_commands'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: S.get('refresh_config'),
          ),
        ],
      ),
    );
  }

  // ============ 公共组件 ============

  Widget buildSectionTitleWithAction(
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

  Widget buildEmptyCard(String text) {
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
