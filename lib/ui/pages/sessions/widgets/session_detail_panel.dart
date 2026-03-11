import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../models/session_meta.dart';
import '../../../../l10n/s.dart';
import '../../../../utils/platform_utils.dart';
import '../../../components/custom_toast.dart';

class SessionDetailPanel extends StatelessWidget {
  final SessionMeta? session;
  final List<SessionMessage> messages;
  final bool isLoadingMessages;
  final VoidCallback onResume;
  final VoidCallback onDelete;
  final ValueChanged<String> onCopyMessage;

  const SessionDetailPanel({
    super.key,
    required this.session,
    required this.messages,
    required this.isLoadingMessages,
    required this.onResume,
    required this.onDelete,
    required this.onCopyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (session == null) return _buildEmptyState(context);
    return Column(
      children: [
        _buildDetailHeader(context),
        Expanded(child: _buildMessageList(context)),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 40,
              color: Colors.grey.shade200),
          const SizedBox(height: 10),
          Text(
            S.get('session_select_hint'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = session!;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                s.providerId == 'claude'
                    ? Icons.smart_toy_outlined : Icons.code,
                size: 18,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.displayTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _buildResumeButton(context),
              const SizedBox(width: 6),
              _buildDeleteButton(context),
            ],
          ),
          const SizedBox(height: 8),
          _buildMetaRow(context, isDark),
          if (s.resumeCommand != null) ...[
            const SizedBox(height: 10),
            _buildResumeCommandBar(context, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(BuildContext context, bool isDark) {
    final s = session!;
    final metaColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        _metaChip(Icons.access_time, _formatTime(s.lastActiveAt ?? s.createdAt),
            metaColor),
        if (s.projectDir != null)
          GestureDetector(
            onTap: () =>
                Clipboard.setData(ClipboardData(text: s.projectDir!)),
            child: _metaChip(Icons.folder_outlined,
                s.projectDir!.split('/').last, metaColor,
                tooltip: s.projectDir),
          ),
        _metaChip(
          Icons.label_outline,
          s.providerId == 'claude' ? 'Claude Code' : 'Codex',
          metaColor,
        ),
      ],
    );
  }

  Widget _metaChip(IconData icon, String text, Color color,
      {String? tooltip}) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
    return tooltip != null ? Tooltip(message: tooltip, child: content) : content;
  }

  Widget _buildResumeCommandBar(BuildContext context, bool isDark) {
    return _ResumeCommandBar(
      command: session!.resumeCommand!,
      isDark: isDark,
      onCopyMessage: onCopyMessage,
    );
  }

  Widget _buildResumeButton(BuildContext context) {
    if (session?.resumeCommand == null) {
      return TextButton.icon(
        onPressed: null,
        icon: const Icon(Icons.play_arrow, size: 14),
        label: Text(S.get('session_resume')),
        style: TextButton.styleFrom(
          foregroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }
    return _ResumeTerminalDropdown(
      command: session!.resumeCommand!,
      workingDir: session!.projectDir,
      onFallbackCopy: onResume,
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return TextButton.icon(
      onPressed: onDelete,
      icon: Icon(Icons.delete_outline, size: 14,
          color: Colors.red.shade300),
      label: Text(S.get('session_delete')),
      style: TextButton.styleFrom(
        foregroundColor: Colors.red.shade300,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildMessageList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isLoadingMessages) {
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.orange.shade300,
          ),
        ),
      );
    }
    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 32,
                color: Colors.grey.shade200),
            const SizedBox(height: 8),
            Text(
              S.get('session_no_messages'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          child: Row(
            children: [
              Icon(Icons.chat_outlined, size: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500),
              const SizedBox(width: 5),
              Text(
                S.get('session_conversation_history'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${messages.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: messages.length,
            itemBuilder: (context, index) => _SessionMessageItem(
              message: messages[index],
              isDark: isDark,
              onCopy: () => onCopyMessage(messages[index].content),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return 'Unknown';
    return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _SessionMessageItem extends StatefulWidget {
  final SessionMessage message;
  final bool isDark;
  final VoidCallback onCopy;

  const _SessionMessageItem({
    required this.message,
    required this.isDark,
    required this.onCopy,
  });

  @override
  State<_SessionMessageItem> createState() => _SessionMessageItemState();
}

class _SessionMessageItemState extends State<_SessionMessageItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isAssistant = widget.message.isAssistant;
    final isDark = widget.isDark;

    Color bgColor;
    EdgeInsets margin;

    if (isUser) {
      bgColor = isDark
          ? Colors.orange.withValues(alpha: 0.06)
          : Colors.orange.withValues(alpha: 0.03);
      margin = const EdgeInsets.only(left: 40, bottom: 6);
    } else if (isAssistant) {
      bgColor = isDark
          ? Colors.blue.withValues(alpha: 0.05)
          : Colors.blue.withValues(alpha: 0.02);
      margin = const EdgeInsets.only(right: 40, bottom: 6);
    } else {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.03)
          : Colors.grey.withValues(alpha: 0.03);
      margin = const EdgeInsets.only(bottom: 6);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        margin: margin,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _roleLabel(widget.message.role),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isUser
                            ? Colors.orange.shade400
                            : isAssistant
                                ? Colors.blue.shade400
                                : Colors.grey.shade500,
                      ),
                    ),
                    const Spacer(),
                    if (widget.message.timestamp != null)
                      Text(
                        _formatMsgTime(widget.message.timestamp!),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                SelectableText(
                  widget.message.content,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            if (_hovering)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: widget.onCopy,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(Icons.copy, size: 12,
                        color: Colors.grey.shade400),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'user': return 'User';
      case 'assistant': return 'Assistant';
      case 'tool': return 'Tool';
      case 'system': return 'System';
      default: return role;
    }
  }

  String _formatMsgTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _ResumeCommandBar extends StatefulWidget {
  final String command;
  final bool isDark;
  final ValueChanged<String> onCopyMessage;

  const _ResumeCommandBar({
    required this.command,
    required this.isDark,
    required this.onCopyMessage,
  });

  @override
  State<_ResumeCommandBar> createState() => _ResumeCommandBarState();
}

class _ResumeCommandBarState extends State<_ResumeCommandBar> {
  bool _copied = false;

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.command));
    setState(() => _copied = true);
    widget.onCopyMessage(widget.command);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.command,
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: widget.isDark
                    ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _handleCopy,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _copied ? Icons.check : Icons.copy,
                    key: ValueKey(_copied),
                    size: 13,
                    color: _copied ? Colors.green : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 恢复会话终端选择下拉按钮
class _ResumeTerminalDropdown extends StatefulWidget {
  final String command;
  final String? workingDir;
  final VoidCallback onFallbackCopy;

  const _ResumeTerminalDropdown({
    required this.command,
    required this.workingDir,
    required this.onFallbackCopy,
  });

  @override
  State<_ResumeTerminalDropdown> createState() =>
      _ResumeTerminalDropdownState();
}

class _ResumeTerminalDropdownState extends State<_ResumeTerminalDropdown> {
  List<TerminalOption> _terminals = [];
  bool _detected = false;

  @override
  void initState() {
    super.initState();
    _detectTerminals();
  }

  Future<void> _detectTerminals() async {
    final terminals = await PlatformUtils.detectAvailableTerminals();
    if (mounted) setState(() { _terminals = terminals; _detected = true; });
  }

  Future<void> _launch(String terminalId) async {
    final success = await PlatformUtils.launchInTerminal(
      terminalId: terminalId,
      command: widget.command,
      workingDir: widget.workingDir,
    );
    if (!mounted) return;
    if (success) {
      Toast.show(context,
          message: S.get('session_resume_launched'), type: ToastType.success);
    } else {
      Toast.show(context,
          message: S.get('session_resume_launch_failed'), type: ToastType.error);
    }
  }

  Widget _terminalIcon(String id, bool isDark) {
    const double size = 18;
    final Color color;
    final IconData icon;
    switch (id) {
      case 'terminal':
        icon = Icons.terminal_rounded;
        color = isDark ? Colors.grey.shade300 : Colors.black87;
        break;
      case 'iterm2':
        icon = Icons.terminal_rounded;
        color = const Color(0xFF34C759);
        break;
      case 'powershell':
        icon = Icons.code_rounded;
        color = const Color(0xFF0078D4);
        break;
      case 'cmd':
        icon = Icons.square_rounded;
        color = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
        break;
      case 'windows_terminal':
        icon = Icons.web_asset_rounded;
        color = const Color(0xFF4D4D4D);
        break;
      default:
        icon = Icons.terminal_rounded;
        color = isDark ? Colors.grey.shade300 : Colors.black87;
    }
    return Icon(icon, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_detected || _terminals.isEmpty) {
      return TextButton.icon(
        onPressed: widget.onFallbackCopy,
        icon: const Icon(Icons.play_arrow, size: 14),
        label: Text(S.get('session_resume')),
        style: TextButton.styleFrom(
          foregroundColor: Colors.orange,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == '_copy') {
          widget.onFallbackCopy();
        } else {
          _launch(value);
        }
      },
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 8,
      shadowColor: Colors.black45,
      itemBuilder: (_) {
        final items = <PopupMenuEntry<String>>[];
        for (final t in _terminals) {
          items.add(PopupMenuItem<String>(
            value: t.id,
            height: 44,
            child: Row(
              children: [
                _terminalIcon(t.id, isDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ));
        }
        items.add(const PopupMenuDivider(height: 1));
        items.add(PopupMenuItem<String>(
          value: '_copy',
          height: 44,
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 18,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.get('session_copy_command'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ));
        return items;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              S.get('session_resume'),
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Colors.orange,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                color: Colors.orange.shade300),
          ],
        ),
      ),
    );
  }
}
