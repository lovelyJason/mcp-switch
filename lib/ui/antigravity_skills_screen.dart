import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/s.dart';
import '../models/editor_type.dart';
import '../services/antigravity_skills_service.dart';
import '../services/terminal_service.dart';
import '../utils/platform_utils.dart';
import '../models/antigravity_skill.dart';
import 'components/custom_toast.dart';
import 'components/custom_dialog.dart';
import 'components/skills_editor_switcher.dart';
import 'claude_code_skills_screen.dart';
import 'codex_skills_screen.dart';
import 'gemini_skills_screen.dart';

// Part 文件 - Dialogs
part 'antigravity_skills/dialogs/antigravity_skill_detail_dialog.dart';
part 'antigravity_skills/dialogs/custom_skill_install_dialog.dart';

/// Antigravity Skills 管理页面
class AntigravitySkillsScreen extends StatefulWidget {
  const AntigravitySkillsScreen({super.key});

  @override
  State<AntigravitySkillsScreen> createState() => _AntigravitySkillsScreenState();
}

class _AntigravitySkillsScreenState extends State<AntigravitySkillsScreen> {
  final _skillsService = AntigravitySkillsService();

  List<AntigravitySkill> _globalSkills = [];
  bool _loadingGlobal = true;

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
    _loadGlobalSkills();
  }

  Future<void> _loadGlobalSkills() async {
    setState(() => _loadingGlobal = true);
    try {
      final skills = await _skillsService.loadGlobalSkills();
      setState(() {
        _globalSkills = skills;
        _loadingGlobal = false;
      });
    } catch (e) {
      setState(() {
        _globalSkills = [];
        _loadingGlobal = false;
      });
    }
  }

  Future<void> _showSkillDetailDialog(AntigravitySkill skill) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AntigravitySkillDetailDialog(
        skill: skill,
        onDeleted: _loadGlobalSkills,
      ),
    );
  }

  Future<void> _confirmDeleteSkill(AntigravitySkill skill) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_delete_title'),
      content: S.get('antigravity_delete_skill_confirm').replaceAll('{name}', skill.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      try {
        final dir = Directory(skill.path);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          _loadGlobalSkills();
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

  void _openDocsUrl() {
    launchUrl(Uri.parse('https://antigravity.google/docs/skills'));
  }

  void _openGlobalSkillsFolder() {
    PlatformUtils.openInFileManager(_skillsService.globalSkillsPath);
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
                    _buildGlobalSkillsSection(isDark),
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
            case EditorType.gemini:
              return const GeminiSkillsScreen();
            default:
              return const AntigravitySkillsScreen();
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
            S.get('antigravity_skills_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(width: 8),
          // 编辑器切换下拉按钮
          SkillsEditorSwitcher(
            currentEditor: EditorType.antigravity,
            onSwitch: _switchToEditor,
          ),
          const SizedBox(width: 8),
          // 问号提示按钮
          _buildSkillsInfoTooltip(isDark),
          const Spacer(),
          // 打开文件夹按钮
          IconButton(
            icon: const Icon(Icons.folder_open, size: 20),
            onPressed: _openGlobalSkillsFolder,
            tooltip: S.get('open_skills_folder'),
            color: Colors.purple,
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

  /// 构建技能库配置说明的悬浮提示
  Widget _buildSkillsInfoTooltip(bool isDark) {
    return Tooltip(
      richMessage: TextSpan(
        children: [
          const TextSpan(
            text: '目前 Antigravity 支援兩種層級的技能庫，請依照你的需求配置：\n\n',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const TextSpan(
            text: '👉 Workspace Skills (專案專用)\n',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const TextSpan(
            text: '如果這個技能只適用於當前專案，例如特定的部署流程或專案架構規範，請將資料夾放在該專案目錄下：\n',
            style: TextStyle(fontSize: 12),
          ),
          TextSpan(
            text: '<workspace-root>/.agent/skills/\n\n',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.purple.shade200,
            ),
          ),
          const TextSpan(
            text: '👉 Global Skills (全域通用)\n',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const TextSpan(
            text: '如果你希望工具能跟隨你到任何專案，像是你個人的 Coding Style 或通用除錯工具，請放在 Antigravity 的安裝目錄下：\n',
            style: TextStyle(fontSize: 12),
          ),
          TextSpan(
            text: '~/.gemini/antigravity/skills/\n\n',
            style: TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.purple.shade200,
            ),
          ),
          const TextSpan(
            text: '📚 看一下官方文件了解怎麼寫：\n',
            style: TextStyle(fontSize: 12),
          ),
          TextSpan(
            text: 'https://antigravity.google/docs/skills',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blue.shade300,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 200),
      showDuration: const Duration(seconds: 10),
      child: InkWell(
        onTap: _openDocsUrl,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.help_outline,
            size: 18,
            color: Colors.purple.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  /// 显示社区 Skill 安装弹窗
  Future<void> _showCustomSkillInstallDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _AntigravityCustomSkillInstallDialog(
        onInstalled: _loadData,
      ),
    );
  }

  // ============ 全局 Skills 区域 ============
  Widget _buildGlobalSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitleWithAction(
          S.get('antigravity_global_skills'),
          Icons.psychology,
          Colors.purple,
          actionIcon: Icons.add_circle_outline,
          actionTooltip: S.get('custom_skill_install'),
          onAction: _showCustomSkillInstallDialog,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('antigravity_global_skills_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingGlobal)
          const Center(child: CircularProgressIndicator())
        else if (_globalSkills.isEmpty)
          _buildEmptyCard(S.get('antigravity_no_global_skills'))
        else
          _buildGlobalSkillCards(isDark),
      ],
    );
  }

  Widget _buildGlobalSkillCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _globalSkills.map((skill) => _buildSkillCard(skill, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildSkillCard(AntigravitySkill skill, bool isDark, double cardWidth) {
    final scopeColor = skill.scope == SkillScope.global ? Colors.purple : Colors.teal;

    return SizedBox(
      width: cardWidth,
      child: InkWell(
        onTap: () => _showSkillDetailDialog(skill),
        borderRadius: BorderRadius.circular(10),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: scopeColor.withValues(alpha: 0.3), width: 1),
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
                        color: scopeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.psychology, size: 16, color: scopeColor),
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
                          color: scopeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.check, size: 10, color: scopeColor),
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
                    // 打开文件夹按钮
                    InkWell(
                      onTap: () => PlatformUtils.openInFileManager(skill.path),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.folder_open, size: 16, color: Colors.grey.withValues(alpha: 0.7)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 删除按钮
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
