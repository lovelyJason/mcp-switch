import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/editor_type.dart';
import '../../../services/config/config_service.dart';
import '../../../utils/platform_utils.dart';
import '../../components/claude_not_installed_banner.dart';
import '../../components/claude_path_not_configured_banner.dart';
import '../../components/codex_not_installed_banner.dart';
import '../../components/gemini_not_installed_banner.dart';
import '../../components/windsurf_not_installed_banner.dart';
import '../../components/kiro_not_installed_banner.dart';
import '../../components/update_banner.dart';
import '../mcp_config/config_list_screen.dart';
import 'home_header.dart';

/// 首页容器组件
/// 包含：头部(HomeHeader) + 内容区域(Banner + Content)
/// 内容区域默认渲染 ConfigListScreen，后续可动态切换
class HomePage extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;

  const HomePage({super.key, required this.scaffoldKey});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late EditorType _selectedEditor;

  // Claude CLI 状态
  ClaudeInstallStatus? _claudeStatus;
  bool _checkingClaude = true;
  bool _isInstallingClaude = false;

  // Codex CLI 状态
  CodexInstallStatus? _codexStatus;
  bool _checkingCodex = true;
  bool _isInstallingCodex = false;

  // Gemini CLI 状态
  GeminiInstallStatus? _geminiStatus;
  bool _checkingGemini = true;
  bool _isInstallingGemini = false;

  // Windsurf 状态
  WindsurfInstallStatus? _windsurfStatus;
  bool _checkingWindsurf = true;

  // Kiro 状态
  KiroInstallStatus? _kiroStatus;
  bool _checkingKiro = true;

  // 便捷 getter
  bool get _isClaudeInstalled => _claudeStatus?.isInstalled ?? true;
  bool get _needsPathSetup => _claudeStatus?.needsPathSetup ?? false;
  bool get _isCodexInstalled => _codexStatus?.isInstalled ?? true;
  bool get _isGeminiInstalled => _geminiStatus?.isInstalled ?? true;
  bool get _isWindsurfInstalled => _windsurfStatus?.isInstalled ?? true;
  bool get _isKiroInstalled => _kiroStatus?.isInstalled ?? true;

  @override
  void initState() {
    super.initState();
    _selectedEditor = Provider.of<ConfigService>(context, listen: false).selectedEditor;
    _checkAllCliStatus();
  }

  Future<void> _checkAllCliStatus() async {
    await Future.wait([
      _checkClaudeStatus(),
      _checkCodexStatus(),
      _checkGeminiStatus(),
      _checkWindsurfStatus(),
      _checkKiroStatus(),
    ]);
  }

  Future<void> _checkClaudeStatus() async {
    final status = await PlatformUtils.checkClaudeInstallStatus();
    if (mounted) {
      setState(() {
        _claudeStatus = status;
        _checkingClaude = false;
      });
    }
  }

  Future<void> _checkCodexStatus() async {
    final status = await PlatformUtils.checkCodexInstallStatus();
    if (mounted) {
      setState(() {
        _codexStatus = status;
        _checkingCodex = false;
      });
    }
  }

  Future<void> _checkGeminiStatus() async {
    final status = await PlatformUtils.checkGeminiInstallStatus();
    if (mounted) {
      setState(() {
        _geminiStatus = status;
        _checkingGemini = false;
      });
    }
  }

  Future<void> _checkWindsurfStatus() async {
    final status = await PlatformUtils.checkWindsurfInstallStatus();
    if (mounted) {
      setState(() {
        _windsurfStatus = status;
        _checkingWindsurf = false;
      });
    }
  }

  Future<void> _checkKiroStatus() async {
    final status = await PlatformUtils.checkKiroInstallStatus();
    if (mounted) {
      setState(() {
        _kiroStatus = status;
        _checkingKiro = false;
      });
    }
  }

  void _handleEditorChanged(EditorType editor) {
    setState(() {
      _selectedEditor = editor;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 头部
        HomeHeader(
          selectedEditor: _selectedEditor,
          isClaudeInstalled: _isClaudeInstalled,
          isCodexInstalled: _isCodexInstalled,
          isGeminiInstalled: _isGeminiInstalled,
          isWindsurfInstalled: _isWindsurfInstalled,
          isKiroInstalled: _isKiroInstalled,
          isInstalling: _isInstallingClaude || _isInstallingCodex || _isInstallingGemini,
          scaffoldKey: widget.scaffoldKey,
          onEditorChanged: _handleEditorChanged,
        ),

        // 内容区域
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  /// 内容区域：Banner + 主内容
  Widget _buildContent() {
    return Column(
      children: [
        // 更新横幅（最优先显示）
        const UpdateBanner(),

        // CLI 状态 Banners
        ..._buildBanners(),

        // 主内容（当前固定为 ConfigListScreen，后续可扩展）
        Expanded(
          child: ConfigListScreen(editorType: _selectedEditor),
        ),
      ],
    );
  }

  /// 构建各种 Banner
  List<Widget> _buildBanners() {
    final banners = <Widget>[];

    // Claude 未安装 Banner
    if (_selectedEditor == EditorType.claude && !_checkingClaude && !_isClaudeInstalled) {
      banners.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ClaudeNotInstalledBanner(
            onInstallComplete: _checkClaudeStatus,
            onInstallStateChanged: (isInstalling) {
              setState(() => _isInstallingClaude = isInstalling);
            },
          ),
        ),
      );
    }

    // Claude 已安装但 PATH 未配置 Banner
    if (_selectedEditor == EditorType.claude &&
        !_checkingClaude &&
        _isClaudeInstalled &&
        _needsPathSetup &&
        _claudeStatus?.exePath != null) {
      banners.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ClaudePathNotConfiguredBanner(
            claudeExePath: _claudeStatus!.exePath!,
            onConfigureComplete: () {
              setState(() {
                _claudeStatus = ClaudeInstallStatus(
                  exePath: _claudeStatus!.exePath,
                  inPath: true,
                );
              });
            },
          ),
        ),
      );
    }

    // Codex 未安装 Banner
    if (_selectedEditor == EditorType.codex && !_checkingCodex && !_isCodexInstalled) {
      banners.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: CodexNotInstalledBanner(
            onInstallComplete: _checkCodexStatus,
            onInstallStateChanged: (isInstalling) {
              setState(() => _isInstallingCodex = isInstalling);
            },
          ),
        ),
      );
    }

    // Gemini 未安装 Banner
    if (_selectedEditor == EditorType.gemini && !_checkingGemini && !_isGeminiInstalled) {
      banners.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GeminiNotInstalledBanner(
            onInstallComplete: _checkGeminiStatus,
            onInstallStateChanged: (isInstalling) {
              setState(() => _isInstallingGemini = isInstalling);
            },
          ),
        ),
      );
    }

    // Windsurf 未安装 Banner
    if (_selectedEditor == EditorType.windsurf && !_checkingWindsurf && !_isWindsurfInstalled) {
      banners.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: WindsurfNotInstalledBanner(),
        ),
      );
    }

    // Kiro 未安装 Banner
    if (_selectedEditor == EditorType.kiro && !_checkingKiro && !_isKiroInstalled) {
      banners.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: KiroNotInstalledBanner(),
        ),
      );
    }

    return banners;
  }
}
