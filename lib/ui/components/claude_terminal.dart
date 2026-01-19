import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../../l10n/s.dart';
import '../../services/terminal_service.dart';
import '../../services/prompt_service.dart';
import '../../services/config_service.dart';

class ClaudeTerminal extends StatefulWidget {
  final VoidCallback onClose;

  const ClaudeTerminal({super.key, required this.onClose});

  @override
  State<ClaudeTerminal> createState() => _ClaudeTerminalState();
}

class _ClaudeTerminalState extends State<ClaudeTerminal> {
  
  @override
  void initState() {
    super.initState();
    // Initialize service (idempotent)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final terminalService = context.read<TerminalService>();
      final promptService = context.read<PromptService>();
      final configService = context.read<ConfigService>();

      // 设置 context 和 configService 以支持 Windows Shell 选择弹窗
      terminalService.setContext(context, configService);

      terminalService.init(
        () async {
        await promptService.ensureInitialized;
        return promptService.hasSeenTerminalArt;
      },
        () async => await promptService.markTerminalArtLoaded(),
      );
    });
  }

  void _runCommand(String command) {
    context.read<TerminalService>().sendCommand(command);
  }

  @override
  Widget build(BuildContext context) {
    
    return Container(
      width: 500,
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
                        widget.onClose();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: Colors.white70),
                  tooltip: S.get('terminal_clear'),
                  onPressed: () {
                    _runCommand('clear');
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  tooltip: S.get('terminal_close'),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          
          // Terminal View
          Expanded(
            child: Consumer<TerminalService>(
              builder: (context, service, _) {
                if (!service.isPtyActive) {
                  // Should technically wait for init, but text will appear in terminal buffer anyway
                  // or we can show loader if not initialized
                }

                return TerminalView(
                  service.terminal,
                  controller: service.terminalController,
                  autofocus: true,
                  backgroundOpacity: 0,
                  textStyle: const TerminalStyle(
                    fontFamily: 'Menlo',
                    fontSize: 13,
                  ),
                  theme: TerminalThemes.defaultTheme,
                );
              },
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
