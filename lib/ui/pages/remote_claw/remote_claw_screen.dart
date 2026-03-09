import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/s.dart';
import '../../../models/permission_request.dart';
import '../../../services/config_service.dart';
import '../../../services/remote_claw_service.dart';
import '../../components/custom_toast.dart';
import '../../components/custom_dialog.dart';
import 'widgets/pending_request_card.dart';
import 'widgets/channel_config_section.dart';

class RemoteClawScreen extends StatefulWidget {
  const RemoteClawScreen({super.key});

  @override
  State<RemoteClawScreen> createState() => _RemoteClawScreenState();
}

class _RemoteClawScreenState extends State<RemoteClawScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 自定义头部
            Container(
              padding: const EdgeInsets.only(
                top: 38,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white24
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, size: 20, color: textColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.asset(
                    'assets/icons/remote_claw.png',
                    width: 28,
                    height: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.get('remote_claw_title'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            // 内容区
            Expanded(
              child: Consumer<RemoteClawService>(
                builder: (context, service, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ServerStatusCard(service: service),
                        const SizedBox(height: 10),
                        _HookInstallCard(service: service),
                        const SizedBox(height: 10),
                        ChannelConfigSection(service: service),
                        const SizedBox(height: 10),
                        _PendingRequestsSection(service: service),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 服务状态卡片
// ──────────────────────────────────────────

class _ServerStatusCard extends StatefulWidget {
  const _ServerStatusCard({required this.service});
  final RemoteClawService service;

  @override
  State<_ServerStatusCard> createState() => _ServerStatusCardState();
}

class _ServerStatusCardState extends State<_ServerStatusCard> {
  static const String _tailscaleMachinesUrl =
      'https://login.tailscale.com/admin/machines';

  late TextEditingController _portCtrl;
  late TextEditingController _callbackHostCtrl;

  @override
  void initState() {
    super.initState();
    _portCtrl = TextEditingController(text: widget.service.port.toString());
    _callbackHostCtrl = TextEditingController(
      text: widget.service.callbackHost == '127.0.0.1'
          ? ''
          : widget.service.callbackHost,
    );
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _callbackHostCtrl.dispose();
    super.dispose();
  }

  Future<void> _showServerConfigDialog() async {
    final configService = context.read<ConfigService>();
    final result = await _RemoteClawServerConfigDialog.show(
      context,
      initialPort: _portCtrl.text.trim(),
      initialCallbackHost: _callbackHostCtrl.text.trim(),
      initialUseLocalCallback: widget.service.useLocalCallback,
      portEditable: !widget.service.isRunning,
    );
    if (result == null) return;

    final oldPort = widget.service.port;
    final newPort =
        int.tryParse(result.port.trim()) ?? RemoteClawService.kDefaultPort;
    final host = result.callbackHost.trim();

    if (!widget.service.isRunning && newPort != oldPort) {
      widget.service.setPort(newPort);
      // 若 hook 已安装，自动重装脚本更新端口
      if (await widget.service.isHookInstalled) {
        await widget.service.installHookScript();
        if (mounted) {
          Toast.show(
            context,
            message: S.get('remote_claw_hook_reinstalled'),
            type: ToastType.success,
          );
        }
      }
    }

    widget.service.setCallbackHost(host);
    widget.service.setUseLocalCallback(result.useLocalCallback);
    await configService.saveRemoteClawServerConfig(
      port: widget.service.port,
      callbackHost: host,
      useLocalCallback: result.useLocalCallback,
    );

    if (!mounted) return;
    _portCtrl.text = widget.service.port.toString();
    _callbackHostCtrl.text = widget.service.callbackHost == '127.0.0.1'
        ? ''
        : widget.service.callbackHost;
    setState(() {});
  }

  Future<void> _openTailscaleMachines() async {
    final uri = Uri.parse(_tailscaleMachinesUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      Toast.show(
        context,
        message: S.get('remote_claw_open_tailscale_failed'),
        type: ToastType.error,
      );
    }
  }

  Future<void> _showKeepAwakeCommandDialog() async {
    final command = _keepAwakeCommand;
    await _KeepAwakeCommandDialog.show(
      context,
      command: command,
      description: S.get('remote_claw_keep_awake_desc'),
      onCopy: () async {
        await Clipboard.setData(ClipboardData(text: command));
        if (!mounted) return;
        Toast.show(
          context,
          message: S.get('remote_claw_keep_awake_copy_success'),
          type: ToastType.success,
        );
      },
    );
  }

  String get _keepAwakeCommand {
    if (Platform.isWindows) {
      return r'''Add-Type -Name Win32 -Namespace P -MemberDefinition '[DllImport("kernel32.dll")]public static extern uint SetThreadExecutionState(uint esFlags);'; [P.Win32]::SetThreadExecutionState(0x80000002)''';
    }
    return 'caffeinate -dimsu';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = widget.service.isRunning ? Colors.green : Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.router, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  S.get('remote_claw_server'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // 端口输入
                Text(
                  S.get('remote_claw_port'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 64,
                  height: 28,
                  child: GestureDetector(
                    onTap: _showServerConfigDialog,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _portCtrl,
                        enabled: !widget.service.isRunning,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 状态指示灯
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.service.isRunning
                      ? S.get('remote_claw_running')
                      : S.get('remote_claw_stopped'),
                  style: TextStyle(color: statusColor, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.get('remote_claw_server_desc'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            // 回调地址（Tailscale / 内网穿透）
            Row(
              children: [
                Text(
                  S.get('remote_claw_callback_host'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                Tooltip(
                  message: S.get('remote_claw_callback_host_tooltip'),
                  preferBelow: true,
                  triggerMode: TooltipTriggerMode.tap,
                  textStyle: const TextStyle(fontSize: 12, color: Colors.white),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Icon(
                    Icons.help_outline,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  height: 28,
                  child: GestureDetector(
                    onTap: _showServerConfigDialog,
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _callbackHostCtrl,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: '100.x.x.x',
                          hintStyle: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _openTailscaleMachines,
                  icon: const Icon(Icons.open_in_new, size: 13),
                  label: Text(S.get('remote_claw_view_tailscale_devices')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _showKeepAwakeCommandDialog,
                  icon: const Icon(Icons.copy_all, size: 13),
                  label: Text(S.get('remote_claw_keep_awake_command')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    textStyle: const TextStyle(fontSize: 12),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 本机走 localhost 开关
            // Row(
            //   children: [
            //     Icon(
            //       Icons.computer,
            //       size: 13,
            //       color: isDark ? Colors.grey[400] : Colors.grey[600],
            //     ),
            //     const SizedBox(width: 4),
            //     Text(
            //       S.get('remote_claw_use_local_callback'),
            //       style: TextStyle(
            //         fontSize: 12,
            //         color: isDark ? Colors.grey[400] : Colors.grey[600],
            //       ),
            //     ),
            //     const SizedBox(width: 6),
            //     Transform.scale(
            //       scale: 0.75,
            //       alignment: Alignment.centerLeft,
            //       child: Switch(
            //         value: widget.service.useLocalCallback,
            //         activeTrackColor: Colors.orange,
            //         onChanged: (v) async {
            //           widget.service.setUseLocalCallback(v);
            //           await context
            //               .read<ConfigService>()
            //               .saveRemoteClawServerConfig(
            //                 port: widget.service.port,
            //                 callbackHost: widget.service.callbackHost,
            //                 useLocalCallback: v,
            //               );
            //         },
            //       ),
            //     ),
            //   ],
            // ),
            if (widget.service.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.service.lastError!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: widget.service.isRunning
                      ? null
                      : () {
                          widget.service.start();
                          context.read<ConfigService>().saveRemoteClawAutoStart(
                            true,
                          );
                        },
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: Text(S.get('remote_claw_start')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: widget.service.isRunning
                      ? () {
                          widget.service.stop();
                          context.read<ConfigService>().saveRemoteClawAutoStart(
                            false,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.stop, size: 14),
                  label: Text(S.get('remote_claw_stop')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteClawServerConfigResult {
  const _RemoteClawServerConfigResult({
    required this.port,
    required this.callbackHost,
    required this.useLocalCallback,
  });

  final String port;
  final String callbackHost;
  final bool useLocalCallback;
}

class _RemoteClawServerConfigDialog extends StatefulWidget {
  const _RemoteClawServerConfigDialog({
    required this.initialPort,
    required this.initialCallbackHost,
    required this.initialUseLocalCallback,
    required this.portEditable,
    required this.isDark,
  });

  final String initialPort;
  final String initialCallbackHost;
  final bool initialUseLocalCallback;
  final bool portEditable;
  final bool isDark;

  static Future<_RemoteClawServerConfigResult?> show(
    BuildContext context, {
    required String initialPort,
    required String initialCallbackHost,
    required bool initialUseLocalCallback,
    required bool portEditable,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showGeneralDialog<_RemoteClawServerConfigResult>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => _RemoteClawServerConfigDialog(
        initialPort: initialPort,
        initialCallbackHost: initialCallbackHost,
        initialUseLocalCallback: initialUseLocalCallback,
        portEditable: portEditable,
        isDark: isDark,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }

  @override
  State<_RemoteClawServerConfigDialog> createState() =>
      _RemoteClawServerConfigDialogState();
}

class _RemoteClawServerConfigDialogState
    extends State<_RemoteClawServerConfigDialog> {
  late final TextEditingController _portCtrl;
  late final TextEditingController _callbackHostCtrl;
  late bool _useLocalCallback;

  @override
  void initState() {
    super.initState();
    _portCtrl = TextEditingController(text: widget.initialPort);
    _callbackHostCtrl = TextEditingController(text: widget.initialCallbackHost);
    _useLocalCallback = widget.initialUseLocalCallback;
  }

  @override
  void dispose() {
    _portCtrl.dispose();
    _callbackHostCtrl.dispose();
    super.dispose();
  }

  void _onSave() {
    final parsedPort =
        int.tryParse(_portCtrl.text.trim()) ?? RemoteClawService.kDefaultPort;
    final normalizedPort = parsedPort.clamp(1, 65535);
    Navigator.of(context).pop(
      _RemoteClawServerConfigResult(
        port: normalizedPort.toString(),
        callbackHost: _callbackHostCtrl.text.trim(),
        useLocalCallback: _useLocalCallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final titleColor = widget.isDark ? Colors.white : Colors.black87;
    final labelColor = widget.isDark
        ? Colors.grey.shade300
        : Colors.grey.shade700;
    final hintColor = widget.isDark
        ? Colors.grey.shade600
        : Colors.grey.shade400;
    final cancelColor = widget.isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: widget.isDark ? 0.3 : 0.15,
                ),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('remote_claw_server'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.get('remote_claw_port'),
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _portCtrl,
                enabled: widget.portEditable,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: const OutlineInputBorder(),
                  hintText: '8099',
                  hintStyle: TextStyle(color: hintColor),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Text(
                S.get('remote_claw_callback_host'),
                style: TextStyle(
                  fontSize: 13,
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _callbackHostCtrl,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: const OutlineInputBorder(),
                  hintText: S.get('remote_claw_callback_host_hint'),
                  hintStyle: TextStyle(color: hintColor),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.get('remote_claw_use_local_callback'),
                          style: TextStyle(
                            fontSize: 13,
                            color: labelColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          S.get('remote_claw_use_local_callback_desc'),
                          style: TextStyle(
                            fontSize: 11,
                            color: hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _useLocalCallback,
                    activeThumbColor: Colors.orange,
                    onChanged: (v) => setState(() => _useLocalCallback = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: cancelColor),
                    child: Text(S.get('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(S.get('save')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepAwakeCommandDialog extends StatelessWidget {
  const _KeepAwakeCommandDialog({
    required this.command,
    required this.description,
    required this.onCopy,
    required this.isDark,
  });

  final String command;
  final String description;
  final Future<void> Function() onCopy;
  final bool isDark;

  static Future<void> show(
    BuildContext context, {
    required String command,
    required String description,
    required Future<void> Function() onCopy,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => _KeepAwakeCommandDialog(
        command: command,
        description: description,
        onCopy: onCopy,
        isDark: isDark,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final contentColor = isDark ? Colors.white70 : Colors.black54;
    final codeBg = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF6F6F7);
    final cancelTextColor = isDark
        ? Colors.grey.shade400
        : Colors.grey.shade600;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('remote_claw_keep_awake_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: contentColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: codeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: isDark ? 0.35 : 0.25),
                  ),
                ),
                child: SelectableText(
                  command,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 12,
                    height: 1.4,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: cancelTextColor,
                    ),
                    child: Text(S.get('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await onCopy();
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(S.get('remote_claw_copy_command')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
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
}

// ──────────────────────────────────────────
// Hook 安装卡片
// ──────────────────────────────────────────

class _HookInstallCard extends StatefulWidget {
  const _HookInstallCard({required this.service});
  final RemoteClawService service;

  @override
  State<_HookInstallCard> createState() => _HookInstallCardState();
}

class _HookInstallCardState extends State<_HookInstallCard> {
  bool _installing = false;
  bool _uninstalling = false;
  bool _isInstalled = false;

  @override
  void initState() {
    super.initState();
    _checkInstalled();
  }

  Future<void> _checkInstalled() async {
    final installed = await widget.service.isHookInstalled;
    if (mounted) setState(() => _isInstalled = installed);
  }

  Future<void> _install() async {
    setState(() => _installing = true);
    try {
      await widget.service.installHookScript();
      await widget.service.installClaudeSettings();
      if (mounted) {
        setState(() => _isInstalled = true);
        Toast.show(
          context,
          message: S.get('remote_claw_hook_installed'),
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('remote_claw_hook_install_failed')}: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _uninstall() async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('remote_claw_hook_uninstall'),
      content: S.get('remote_claw_hook_uninstall_confirm'),
      confirmText: S.get('remote_claw_hook_uninstall'),
      confirmColor: Colors.red,
    );
    if (confirmed != true) return;

    setState(() => _uninstalling = true);
    try {
      await widget.service.uninstallClaudeSettings();
      if (mounted) {
        setState(() => _isInstalled = false);
        Toast.show(
          context,
          message: S.get('remote_claw_hook_uninstalled'),
          type: ToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('remote_claw_hook_install_failed')}: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uninstalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  S.get('remote_claw_hook'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _isInstalled
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isInstalled ? Colors.green : Colors.grey,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    _isInstalled
                        ? S.get('remote_claw_hook_status_installed')
                        : S.get('remote_claw_hook_status_not_installed'),
                    style: TextStyle(
                      fontSize: 10,
                      color: _isInstalled ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              S.get('remote_claw_hook_desc'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '~/.claude/hooks/remote-claw.sh',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.orange.shade300 : Colors.orange,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _installing ? null : _install,
                  icon: _installing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_done, size: 14),
                  label: Text(
                    _isInstalled
                        ? S.get('remote_claw_hook_reinstall')
                        : S.get('remote_claw_hook_install'),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _uninstalling ? null : _uninstall,
                  icon: _uninstalling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 14),
                  label: Text(S.get('remote_claw_hook_uninstall')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 待审批请求列表
// ──────────────────────────────────────────

class _PendingRequestsSection extends StatelessWidget {
  const _PendingRequestsSection({required this.service});
  final RemoteClawService service;

  @override
  Widget build(BuildContext context) {
    final requests = service.pendingRequests
        .where((r) => r.decision == PermissionDecision.pending)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.pending_actions, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Text(
              S.get('remote_claw_pending'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (requests.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${requests.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (requests.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                S.get('remote_claw_no_pending'),
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          )
        else
          ...requests.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PendingRequestCard(
                request: r,
                onAllow: () => service.approveRequest(r.id),
                onDeny: () => service.denyRequest(r.id),
              ),
            ),
          ),
      ],
    );
  }
}
