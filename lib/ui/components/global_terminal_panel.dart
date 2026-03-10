import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../../l10n/s.dart';
import '../../services/terminal_service.dart';
import '../../services/prompt_service.dart';
import '../../services/config_service.dart';
import 'terminal_ai_input_dialog.dart';

/// 全局终端面板 - 不依赖 Scaffold，可以在任何页面显示
class GlobalTerminalPanel extends StatefulWidget {
  final VoidCallback onClose;

  const GlobalTerminalPanel({super.key, required this.onClose});

  @override
  State<GlobalTerminalPanel> createState() => _GlobalTerminalPanelState();
}

// 自定义 Intent 用于 AI 输入快捷键
class _ToggleAIInputIntent extends Intent {
  const _ToggleAIInputIntent();
}

class _GlobalTerminalPanelState extends State<GlobalTerminalPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final FocusNode _terminalFocusNode = FocusNode();
  bool _showAIInput = false;
  bool _showProxyOverlay = false;
  final TextEditingController _proxyPortController = TextEditingController(text: '7897');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // 添加全局键盘监听（优先级最高，能在 TerminalView 之前拦截）
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);

    // 初始化终端
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalService = context.read<TerminalService>();
      final promptService = context.read<PromptService>();

      terminalService.init(
        () async {
          await promptService.ensureInitialized;
          return promptService.hasSeenTerminalArt;
        },
        () async => await promptService.markTerminalArtLoaded(),
      );

      // 确保终端获得焦点
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _terminalFocusNode.requestFocus();
        }
      });
    });

    // 播放进入动画
    _animationController.forward();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _animationController.dispose();
    _terminalFocusNode.dispose();
    _proxyPortController.dispose();
    super.dispose();
  }

  /// 全局键盘事件处理 - 优先级高于 TerminalView
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // ESC 关闭 AI 输入框
      if (_showAIInput && event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _showAIInput = false);
        _terminalFocusNode.requestFocus();
        return true;
      }

      // Command+I (macOS) 或 Ctrl+I (Windows/Linux)
      final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
      final hasCmd = pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.metaRight);
      final hasCtrl = pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
          pressedKeys.contains(LogicalKeyboardKey.controlRight);
      final isMeta = Platform.isMacOS ? hasCmd : hasCtrl;

      if (isMeta && event.logicalKey == LogicalKeyboardKey.keyI) {
        _toggleAIInput();
        return true; // 阻止事件继续传播
      }
    }
    return false; // 不拦截其他事件
  }

  void _toggleAIInput() {
    setState(() => _showAIInput = !_showAIInput);
  }

  /// 处理 AI 命令接受 - 将命令发送到终端执行
  void _handleAIAccept(String command) {
    setState(() => _showAIInput = false);
    _terminalFocusNode.requestFocus();
    // 将命令发送到终端执行
    context.read<TerminalService>().sendCommand(command);
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  void _runCommand(String command) {
    context.read<TerminalService>().sendCommand(command);
  }

  void _submitProxy() {
    final port = _proxyPortController.text.trim();
    if (port.isNotEmpty) {
      _runCommand('export all_proxy=http://127.0.0.1:$port');
    }
    setState(() => _showProxyOverlay = false);
    _terminalFocusNode.requestFocus();
  }

  Widget _buildProxyOverlay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.wifi_tethering, size: 14, color: Colors.orange.shade300),
              const SizedBox(width: 6),
              const Text(
                '设置代理端口',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() => _showProxyOverlay = false);
                  _terminalFocusNode.requestFocus();
                },
                child: const Icon(Icons.close, size: 16, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '将在终端执行：export all_proxy=http://127.0.0.1:<端口>',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[400],
              fontFamily: 'Menlo',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'http://127.0.0.1:',
                style: TextStyle(fontSize: 12, color: Colors.grey[400], fontFamily: 'Menlo'),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _proxyPortController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Menlo'),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    hintText: '7897',
                    hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Colors.orange),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF1E1E1E),
                  ),
                  onSubmitted: (_) => _submitProxy(),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _submitProxy,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('执行', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 定义快捷键绑定
    final shortcuts = <ShortcutActivator, Intent>{
      // macOS: Command+I
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true): const _ToggleAIInputIntent(),
      // Windows/Linux: Ctrl+I
      const SingleActivator(LogicalKeyboardKey.keyI, control: true): const _ToggleAIInputIntent(),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToggleAIInputIntent: CallbackAction<_ToggleAIInputIntent>(
            onInvoke: (_) {
              _toggleAIInput();
              return null;
            },
          ),
        },
        child: Stack(
        children: [
          // 半透明背景遮罩
          GestureDetector(
            onTap: _close,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Container(
                color: Colors.black.withValues(alpha: 0.3 * _animationController.value),
              ),
            ),
          ),
          // 终端面板
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 500,
            child: SlideTransition(
              position: _slideAnimation,
              child: Material(
                elevation: 16,
                child: Container(
                  color: const Color(0xFF1E1E1E),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            color: const Color(0xFF252526),
                            child: Row(
                              children: [
                                const Icon(Icons.terminal, color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  S.get('terminal_title'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                // 代理设置按钮
                                IconButton(
                                  icon: Icon(
                                    Icons.wifi_tethering,
                                    size: 18,
                                    color: _showProxyOverlay ? Colors.orange : Colors.white70,
                                  ),
                                  tooltip: '设置代理（export all_proxy）',
                                  onPressed: () => setState(() => _showProxyOverlay = !_showProxyOverlay),
                                ),
                                // AI 输入按钮
                                IconButton(
                                  icon: Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                    color: _showAIInput ? Colors.amber : Colors.white70,
                                  ),
                                  tooltip: '${S.get('terminal_ai_input')} (${Platform.isMacOS ? '⌘' : 'Ctrl'}+I)',
                                  onPressed: _toggleAIInput,
                                ),
                                Consumer<TerminalService>(
                                  builder: (context, service, _) => IconButton(
                                    icon: Icon(
                                      service.floatingTerminalEnabled
                                          ? Icons.picture_in_picture_alt
                                          : Icons.picture_in_picture_outlined,
                                      size: 18,
                                      color: service.floatingTerminalEnabled
                                          ? Colors.orange
                                          : Colors.white70,
                                    ),
                                    tooltip: S.get('floating_terminal'),
                                    onPressed: () {
                                      service.toggleFloatingTerminal();
                                      if (service.floatingTerminalEnabled) {
                                        _close();
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cleaning_services_outlined,
                                      size: 18, color: Colors.white70),
                                  tooltip: S.get('terminal_clear'),
                                  onPressed: () {
                                    _runCommand('clear');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                                  tooltip: S.get('terminal_close'),
                                  onPressed: _close,
                                ),
                              ],
                            ),
                          ),

                          // Terminal View
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Consumer<TerminalService>(
                                builder: (context, service, _) {
                                  return TerminalView(
                                    service.terminal,
                                    controller: service.terminalController,
                                    focusNode: _terminalFocusNode,
                                    autofocus: true,
                                    backgroundOpacity: 0,
                                    hardwareKeyboardOnly: Platform.isWindows || Platform.isMacOS || Platform.isLinux,
                                    textStyle: TerminalStyle(
                                      fontFamily: Platform.isWindows ? 'Consolas' : 'Menlo',
                                      fontSize: 13,
                                    ),
                                    theme: TerminalThemes.defaultTheme,
                                    // 拦截快捷键，阻止 i 字符输入到终端
                                    // 注意：不在这里调用 _toggleAIInput()，因为 _handleGlobalKeyEvent 已经处理了
                                    // 这里只负责阻止字符输入到终端
                                    onKeyEvent: (node, event) {
                                      if (event is KeyDownEvent) {
                                        // Command+I (macOS) 或 Ctrl+I (Windows/Linux)
                                        // 只阻止事件传播，不执行 toggle（已在 _handleGlobalKeyEvent 中执行）
                                        final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
                                        final hasCmd = pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
                                            pressedKeys.contains(LogicalKeyboardKey.metaRight);
                                        final hasCtrl = pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
                                            pressedKeys.contains(LogicalKeyboardKey.controlRight);
                                        final isMeta = Platform.isMacOS ? hasCmd : hasCtrl;
                                        if (isMeta && event.logicalKey == LogicalKeyboardKey.keyI) {
                                          return KeyEventResult.handled; // 只阻止，不执行
                                        }
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                  );
                                },
                              ),
                            ),
                          ),

                          // Quick Actions Toolbar
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF252526),
                              border: Border(top: BorderSide(color: Colors.white12)),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildQuickAction('claude update'),
                                  _buildQuickAction('claude login'),
                                  _buildQuickAction('claude doctor'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 代理设置弹窗 - 覆盖在终端上方
                      if (_showProxyOverlay)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 60,
                          child: _buildProxyOverlay(),
                        ),

                      // AI 输入弹窗 - 覆盖在终端上方
                      if (_showAIInput)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 60,
                          child: Consumer<ConfigService>(
                            builder: (context, configService, _) => TerminalAIInputDialog(
                              onAccept: _handleAIAccept,
                              apiKey: configService.claudeApiKey,
                              apiBaseUrl: configService.claudeApiBaseUrl,
                              initialModelId: configService.terminalAiModelId,
                              onModelChanged: (modelId) {
                                configService.setTerminalAiModelId(modelId);
                              },
                              onCancel: () {
                                setState(() => _showAIInput = false);
                                _terminalFocusNode.requestFocus();
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String cmd) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TextButton(
        onPressed: () => _runCommand(cmd),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          backgroundColor: Colors.white10,
          foregroundColor: Colors.white70,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(cmd, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
