import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/s.dart';
import '../models/editor_type.dart';
import '../services/gemini_skills_service.dart';
import '../services/terminal_service.dart';
import '../utils/platform_utils.dart';
import '../models/gemini_skill.dart';
import 'components/custom_toast.dart';
import 'components/custom_dialog.dart';
import 'components/skills_editor_switcher.dart';
import 'claude_code_skills_screen.dart';
import 'codex_skills_screen.dart';
import 'antigravity_skills_screen.dart';

// Part 文件 - Dialogs
part 'gemini_skills/dialogs/gemini_skill_detail_dialog.dart';
part 'gemini_skills/dialogs/gemini_extension_detail_dialog.dart';
part 'gemini_skills/dialogs/community_extension_detail_dialog.dart';
part 'gemini_skills/dialogs/community_extensions_browser_dialog.dart';
part 'gemini_skills/dialogs/custom_skill_install_dialog.dart';

/// Gemini Skills & Extensions 管理页面
class GeminiSkillsScreen extends StatefulWidget {
  const GeminiSkillsScreen({super.key});

  @override
  State<GeminiSkillsScreen> createState() => _GeminiSkillsScreenState();
}

class _GeminiSkillsScreenState extends State<GeminiSkillsScreen> {
  final _skillsService = GeminiSkillsService();

  List<GeminiSkill> _localSkills = [];
  List<GeminiExtension> _localExtensions = [];
  bool _loadingSkills = true;
  bool _loadingExtensions = true;

  // 终端状态监听，用于在终端关闭后自动刷新数据
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
    _loadLocalSkills();
    _loadLocalExtensions();
  }

  Future<void> _loadLocalSkills() async {
    setState(() => _loadingSkills = true);
    try {
      final skills = await _skillsService.loadLocalSkills();
      setState(() {
        _localSkills = skills;
        _loadingSkills = false;
      });
    } catch (e) {
      setState(() {
        _localSkills = [];
        _loadingSkills = false;
      });
    }
  }

  Future<void> _loadLocalExtensions() async {
    setState(() => _loadingExtensions = true);
    try {
      final extensions = await _skillsService.loadLocalExtensions();
      setState(() {
        _localExtensions = extensions;
        _loadingExtensions = false;
      });
    } catch (e) {
      setState(() {
        _localExtensions = [];
        _loadingExtensions = false;
      });
    }
  }

  Future<void> _showSkillDetailDialog(GeminiSkill skill) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _GeminiSkillDetailDialog(
        skill: skill,
        onDeleted: _loadLocalSkills,
      ),
    );
  }

  Future<void> _showExtensionDetailDialog(GeminiExtension extension) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _GeminiExtensionDetailDialog(
        extension: extension,
        onDeleted: _loadLocalExtensions,
      ),
    );
  }

  void _copySkillCommand(String skillName) {
    final command = '/skills enable $skillName';
    Clipboard.setData(ClipboardData(text: command));
    Toast.show(
      context,
      message: S.get('gemini_skill_copied').replaceAll('{name}', skillName),
      type: ToastType.success,
    );
  }

  /// 打开社区扩展浏览器弹窗
  Future<void> _showCommunityExtensionsBrowser() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CommunityExtensionsBrowserDialog(
        skillsService: _skillsService,
        onInstalled: _loadData,
      ),
    );
  }

  Future<void> _confirmDeleteSkill(GeminiSkill skill) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_delete_title'),
      content: S.get('gemini_delete_skill_confirm').replaceAll('{name}', skill.name),
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

  Future<void> _confirmDeleteExtension(GeminiExtension ext) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_delete_title'),
      content: S.get('gemini_delete_extension_confirm').replaceAll('{name}', ext.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      // 使用终端执行卸载命令
      final terminalService = context.read<TerminalService>();
      terminalService.setFloatingTerminal(true);
      terminalService.openTerminalPanel();
      await Future.delayed(const Duration(milliseconds: 500));
      terminalService.sendCommand(ext.uninstallCommand);
    }
  }

  void _openGallery() {
    launchUrl(Uri.parse('https://geminicli.com/extensions/'));
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
                    _buildLocalExtensionsSection(isDark),
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
            case EditorType.codex:
              return const CodexSkillsScreen();
            case EditorType.antigravity:
              return const AntigravitySkillsScreen();
            default:
              return const GeminiSkillsScreen();
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
            S.get('gemini_skills_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 8),
          // 编辑器切换下拉按钮
          SkillsEditorSwitcher(
            currentEditor: EditorType.gemini,
            onSwitch: _switchToEditor,
          ),
          const Spacer(),
          // Gallery 按钮
          IconButton(
            icon: const Icon(Icons.store_outlined, size: 20),
            onPressed: _openGallery,
            tooltip: S.get('gemini_open_gallery'),
          ),
          // 刷新按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _skillsService.clearCache();
              _loadData();
            },
            tooltip: S.get('refresh_config'),
          ),
        ],
      ),
    );
  }

  /// 显示社区 Skill 安装弹窗
  Future<void> _showCustomSkillInstallDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _GeminiCustomSkillInstallDialog(
        onInstalled: _loadData,
      ),
    );
  }

  // ============ 本地 Skills 区域 ============
  Widget _buildLocalSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithAction(
          S.get('gemini_local_skills'),
          Icons.psychology,
          Colors.green,
          actionIcon: Icons.add_circle_outline,
          actionTooltip: S.get('custom_skill_install'),
          onAction: _showCustomSkillInstallDialog,
          tooltip: S.get('gemini_skills_tooltip'),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('gemini_local_skills_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingSkills)
          const Center(child: CircularProgressIndicator())
        else if (_localSkills.isEmpty)
          _buildEmptyCard(S.get('gemini_no_local_skills'))
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

  Widget _buildLocalSkillCard(GeminiSkill skill, bool isDark, double cardWidth) {
    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _showSkillDetailDialog(skill),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.green.withValues(alpha: 0.3), width: 1),
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
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.psychology, size: 16, color: Colors.green),
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
                Text(
                  skill.description ?? S.get('no_description'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
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
                        child: Icon(Icons.copy, size: 16, color: Colors.green.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _confirmDeleteSkill(skill),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline, size: 18, color: Colors.red.withValues(alpha: 0.7)),
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

  // ============ 本地 Extensions 区域 ============
  Widget _buildLocalExtensionsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSectionTitle(S.get('gemini_local_extensions'), Icons.extension, Colors.blue),
            ),
            // 社区扩展浏览器按钮
            TextButton.icon(
              onPressed: _showCommunityExtensionsBrowser,
              icon: const Icon(Icons.public, size: 14),
              label: Text(S.get('browse_community')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('gemini_local_extensions_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingExtensions)
          const Center(child: CircularProgressIndicator())
        else if (_localExtensions.isEmpty)
          _buildEmptyCard(S.get('gemini_no_local_extensions'))
        else
          _buildLocalExtensionCards(isDark),
      ],
    );
  }

  Widget _buildLocalExtensionCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _localExtensions.map((ext) => _buildLocalExtensionCard(ext, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildLocalExtensionCard(GeminiExtension ext, bool isDark, double cardWidth) {
    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _showExtensionDetailDialog(ext),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.blue.withValues(alpha: 0.3), width: 1),
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
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.extension, size: 16, color: Colors.blue),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ext.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (ext.version != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v${ext.version}',
                          style: const TextStyle(fontSize: 9, color: Colors.blue),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  ext.description ?? S.get('no_description'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // 打开文件夹按钮
                    InkWell(
                      onTap: () => PlatformUtils.openInFileManager(ext.path),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.folder_open, size: 18, color: Colors.grey.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 删除按钮
                    InkWell(
                      onTap: () => _confirmDeleteExtension(ext),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline, size: 18, color: Colors.red.withValues(alpha: 0.7)),
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
  Widget _buildSectionTitle(String title, IconData icon, Color color, {String? tooltip}) {
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
        if (tooltip != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: tooltip,
            preferBelow: false,
            textStyle: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.help_outline,
              size: 16,
              color: Colors.grey.withValues(alpha: 0.6),
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
    String? tooltip,
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
        if (tooltip != null) ...[
          const SizedBox(width: 6),
          Tooltip(
            message: tooltip,
            preferBelow: false,
            textStyle: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.help_outline,
              size: 16,
              color: Colors.grey.withValues(alpha: 0.6),
            ),
          ),
        ],
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
