import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../../l10n/s.dart';
import '../../services/terminal_service.dart';
import '../../services/prompt_service.dart';

/// 全局终端面板 - 不依赖 Scaffold，可以在任何页面显示
class GlobalTerminalPanel extends StatefulWidget {
  final VoidCallback onClose;

  const GlobalTerminalPanel({super.key, required this.onClose});

  @override
  State<GlobalTerminalPanel> createState() => _GlobalTerminalPanelState();
}

class _GlobalTerminalPanelState extends State<GlobalTerminalPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final FocusNode _terminalFocusNode = FocusNode();

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
    _animationController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  void _runCommand(String command) {
    context.read<TerminalService>().sendCommand(command);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 半透明背景遮罩
        GestureDetector(
          onTap: _close,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Container(
              color: Colors.black.withOpacity(0.3 * _animationController.value),
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
                child: Column(
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
                              // Windows 桌面应用只使用硬件键盘
                              hardwareKeyboardOnly: Platform.isWindows || Platform.isMacOS || Platform.isLinux,
                              textStyle: TerminalStyle(
                                // Windows 用 Consolas，macOS 用 Menlo
                                fontFamily: Platform.isWindows ? 'Consolas' : 'Menlo',
                                fontSize: 13,
                              ),
                              theme: TerminalThemes.defaultTheme,
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
              ),
            ),
          ),
        ),
      ],
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
