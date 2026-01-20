import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/editor_type.dart';
import '../../../services/terminal_service.dart';
import '../../../l10n/s.dart';
import '../../components/custom_toast.dart';
import '../rules/rules_screen.dart';
import '../plugins/claude_code_skills_screen.dart';
import '../prompts/claude_prompts_screen.dart';
import '../plugins/codex_skills_screen.dart';
import '../plugins/gemini_skills_screen.dart';
import '../plugins/antigravity_skills_screen.dart';

/// 头部操作按钮组（胶囊样式）
/// 根据不同编辑器类型显示不同的按钮组合：
/// - Claude: Skills + Prompt + More (Rules在下拉菜单)
/// - Codex: Skills only
/// - Gemini: Skills only
/// - Antigravity: Skills + Rules
/// - Others: Rules only
class HeaderActionButtons extends StatelessWidget {
  final EditorType selectedEditor;
  final bool isClaudeInstalled;
  final bool isCodexInstalled;
  final bool isGeminiInstalled;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const HeaderActionButtons({
    super.key,
    required this.selectedEditor,
    required this.isClaudeInstalled,
    required this.isCodexInstalled,
    required this.isGeminiInstalled,
    required this.scaffoldKey,
  });

  @override
  Widget build(BuildContext context) {
    final isClaude = selectedEditor == EditorType.claude;
    final isCodex = selectedEditor == EditorType.codex;
    final isGemini = selectedEditor == EditorType.gemini;
    final isAntigravity = selectedEditor == EditorType.antigravity;

    // 功能按钮是否禁用（未安装 CLI 时禁用）
    final claudeDisabled = isClaude && !isClaudeInstalled;
    final codexDisabled = isCodex && !isCodexInstalled;
    final geminiDisabled = isGemini && !isGeminiInstalled;

    if (isClaude) {
      return _buildClaudeButtons(context, claudeDisabled);
    } else if (isCodex) {
      return _buildCodexButtons(context, codexDisabled);
    } else if (isGemini) {
      return _buildGeminiButtons(context, geminiDisabled);
    } else if (isAntigravity) {
      return _buildAntigravityButtons(context);
    } else {
      return _buildDefaultButtons(context);
    }
  }

  /// Claude: Skills + Prompt + More (Rules在下拉菜单)
  Widget _buildClaudeButtons(BuildContext context, bool disabled) {
    final skillsBtn = _buildSkillsButton(context, disabled);
    final promptBtn = _buildPromptButton(context, disabled);
    final moreBtn = _buildMoreButton(context, disabled);

    return _buildCapsuleContainer(
      context,
      children: [
        skillsBtn,
        _buildDivider(),
        promptBtn,
        _buildDivider(),
        moreBtn,
      ],
    );
  }

  /// Codex: Skills only
  Widget _buildCodexButtons(BuildContext context, bool disabled) {
    final codexSkillsBtn = IconButton(
      icon: Icon(
        Icons.extension_outlined,
        size: 18,
        color: disabled ? Colors.grey : Colors.orange,
      ),
      tooltip: disabled ? S.get('codex_not_installed_title') : S.get('codex_skills'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: disabled ? null : () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CodexSkillsScreen()),
        );
      },
    );

    return _buildSingleButtonContainer(context, codexSkillsBtn);
  }

  /// Gemini: Skills only
  Widget _buildGeminiButtons(BuildContext context, bool disabled) {
    final geminiSkillsBtn = IconButton(
      icon: Icon(
        Icons.extension_outlined,
        size: 18,
        color: disabled ? Colors.grey : Colors.orange,
      ),
      tooltip: disabled ? S.get('gemini_not_installed_title') : S.get('gemini_skills_title'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: disabled ? null : () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GeminiSkillsScreen()),
        );
      },
    );

    return _buildSingleButtonContainer(context, geminiSkillsBtn);
  }

  /// Antigravity: Skills + Rules
  Widget _buildAntigravityButtons(BuildContext context) {
    final antigravitySkillsBtn = IconButton(
      icon: const Icon(
        Icons.psychology_outlined,
        size: 18,
        color: Colors.purple,
      ),
      tooltip: S.get('antigravity_skills_title'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AntigravitySkillsScreen()),
        );
      },
    );

    final rulesBtn = _buildRulesButton(context);

    return _buildCapsuleContainer(
      context,
      children: [
        antigravitySkillsBtn,
        _buildDivider(),
        rulesBtn,
      ],
    );
  }

  /// 其他编辑器: Rules only
  Widget _buildDefaultButtons(BuildContext context) {
    return _buildSingleButtonContainer(context, _buildRulesButton(context));
  }

  /// Skills 按钮 (Claude)
  Widget _buildSkillsButton(BuildContext context, bool disabled) {
    return IconButton(
      icon: Icon(
        Icons.extension_outlined,
        size: 18,
        color: disabled ? Colors.grey : Colors.orange,
      ),
      tooltip: disabled ? S.get('claude_not_installed_title') : S.get('plugins_menu'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: disabled ? null : () async {
        final terminalService = context.read<TerminalService>();
        final command = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const SkillsScreen()),
        );
        // 如果返回了命令，打开终端并执行
        if (command != null && command.isNotEmpty) {
          scaffoldKey.currentState?.openEndDrawer();
          await Future.delayed(const Duration(milliseconds: 500));
          terminalService.sendCommand(command);
        }
      },
    );
  }

  /// Prompt 按钮 (Claude)
  Widget _buildPromptButton(BuildContext context, bool disabled) {
    return IconButton(
      icon: Icon(
        Icons.tips_and_updates_outlined,
        size: 18,
        color: disabled ? Colors.grey : Colors.orange,
      ),
      tooltip: disabled ? S.get('claude_not_installed_title') : S.get('prompt_name'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: disabled ? null : () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ClaudePromptsScreen()),
        );
      },
    );
  }

  /// More 按钮带下拉菜单 (Claude)
  Widget _buildMoreButton(BuildContext context, bool disabled) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_horiz,
        size: 18,
        color: disabled ? Colors.grey : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      tooltip: disabled ? S.get('claude_not_installed_title') : S.get('more'),
      enabled: !disabled,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Theme.of(context).cardColor,
      elevation: 4,
      shadowColor: Colors.black26,
      onSelected: (value) => _handleMoreMenuSelection(context, value),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'rules',
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 10),
              Text(
                'Rules',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Rules 按钮
  Widget _buildRulesButton(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.article_outlined,
        size: 18,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
      tooltip: 'Rules',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      onPressed: () => _handleRulesNavigation(context),
    );
  }

  /// 处理 More 菜单选择
  void _handleMoreMenuSelection(BuildContext context, String value) {
    if (value == 'rules') {
      _handleRulesNavigation(context);
    }
  }

  /// 处理 Rules 导航
  void _handleRulesNavigation(BuildContext context) {
    if (selectedEditor == EditorType.cursor) {
      Toast.show(context, message: S.get('cursor_configure_hint'), type: ToastType.info);
      return;
    }
    if (selectedEditor == EditorType.claude) {
      Toast.show(context, message: S.get('claude_rules_hint'), type: ToastType.info);
      return;
    }
    if (selectedEditor == EditorType.codex) {
      Toast.show(context, message: S.get('codex_rules_hint'), type: ToastType.info);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RulesScreen(editorType: selectedEditor)),
    );
  }

  /// 胶囊容器（多按钮）
  Widget _buildCapsuleContainer(BuildContext context, {required List<Widget> children}) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// 单按钮容器
  Widget _buildSingleButtonContainer(BuildContext context, Widget button) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: button,
    );
  }

  /// 按钮间分隔线
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 20,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}
