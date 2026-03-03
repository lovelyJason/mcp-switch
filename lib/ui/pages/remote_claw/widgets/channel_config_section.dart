import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/s.dart';
import '../../../../services/config_service.dart';
import '../../../../services/remote_claw_service.dart';
import '../../../components/custom_toast.dart';

/// Telegram + 钉钉渠道配置区域
class ChannelConfigSection extends StatefulWidget {
  const ChannelConfigSection({super.key, required this.service});

  final RemoteClawService service;

  @override
  State<ChannelConfigSection> createState() => _ChannelConfigSectionState();
}

class _ChannelConfigSectionState extends State<ChannelConfigSection> {
  // Telegram
  late bool _telegramEnabled;
  late TextEditingController _tgTokenCtrl;
  late TextEditingController _tgChatIdCtrl;

  // 钉钉
  late bool _dingtalkEnabled;
  late TextEditingController _ddWebhookCtrl;
  late TextEditingController _ddSecretCtrl;

  bool _saving = false;
  bool _tgExpanded = false;
  bool _ddExpanded = false;

  @override
  void initState() {
    super.initState();
    final svc = widget.service;
    _telegramEnabled = svc.telegramEnabled;
    _tgTokenCtrl = TextEditingController(text: svc.telegramBotToken);
    _tgChatIdCtrl = TextEditingController(text: svc.telegramChatId);
    _dingtalkEnabled = svc.dingtalkEnabled;
    _ddWebhookCtrl = TextEditingController(text: svc.dingtalkWebhookUrl);
    _ddSecretCtrl = TextEditingController(text: svc.dingtalkSecret);

    // 有配置的渠道默认展开
    if (svc.telegramBotToken.isNotEmpty) _tgExpanded = true;
    if (svc.dingtalkWebhookUrl.isNotEmpty) _ddExpanded = true;
  }

  @override
  void dispose() {
    _tgTokenCtrl.dispose();
    _tgChatIdCtrl.dispose();
    _ddWebhookCtrl.dispose();
    _ddSecretCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 校验必填项
    if (_dingtalkEnabled) {
      if (_ddWebhookCtrl.text.trim().isEmpty) {
        Toast.show(context,
            message: S.get('remote_claw_dd_webhook_required'),
            type: ToastType.warning);
        setState(() => _ddExpanded = true);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final configService = context.read<ConfigService>();

      await widget.service.updateTelegramConfig(
        enabled: _telegramEnabled,
        botToken: _tgTokenCtrl.text.trim(),
        chatId: _tgChatIdCtrl.text.trim(),
      );
      await widget.service.updateDingtalkConfig(
        enabled: _dingtalkEnabled,
        webhookUrl: _ddWebhookCtrl.text.trim(),
        secret: _ddSecretCtrl.text.trim(),
      );

      await configService.saveRemoteClawConfig(
        telegramEnabled: _telegramEnabled,
        telegramBotToken: _tgTokenCtrl.text.trim(),
        telegramChatId: _tgChatIdCtrl.text.trim(),
        dingtalkEnabled: _dingtalkEnabled,
        dingtalkWebhookUrl: _ddWebhookCtrl.text.trim(),
        dingtalkSecret: _ddSecretCtrl.text.trim(),
      );

      if (mounted) {
        Toast.show(context,
            message: S.get('remote_claw_config_saved'),
            type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context,
            message: '${S.get('remote_claw_config_save_failed')}: $e',
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部标题行
            Row(
              children: [
                const Icon(Icons.notifications, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  S.get('remote_claw_channels'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save, size: 13),
                  label: Text(S.get('remote_claw_save_config')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange,
                    textStyle: const TextStyle(fontSize: 11),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Telegram 行
            _buildChannelRow(
              label: 'Telegram',
              enabled: _telegramEnabled,
              expanded: _tgExpanded,
              onToggle: (v) {
                if (v) {
                  Toast.show(context,
                      message: S.get('remote_claw_telegram_coming_soon'),
                      type: ToastType.info);
                  return;
                }
                setState(() => _telegramEnabled = false);
              },
              onExpand: () => setState(() => _tgExpanded = !_tgExpanded),
              expandedContent: _buildTelegramFields(isDark),
            ),
            const SizedBox(height: 6),
            // 钉钉行
            _buildChannelRow(
              label: S.get('remote_claw_dingtalk'),
              enabled: _dingtalkEnabled,
              expanded: _ddExpanded,
              onToggle: (v) => setState(() => _dingtalkEnabled = v),
              onExpand: () => setState(() => _ddExpanded = !_ddExpanded),
              expandedContent: _buildDingtalkFields(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelRow({
    required String label,
    required bool enabled,
    required bool expanded,
    required ValueChanged<bool> onToggle,
    required VoidCallback onExpand,
    required Widget expandedContent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Transform.scale(
              scale: 0.75,
              child: Switch(
                value: enabled,
                activeThumbColor: Colors.orange,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onToggle,
              ),
            ),
            const SizedBox(width: 2),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(
              onTap: onExpand,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    expanded ? S.get('remote_claw_collapse') : S.get('remote_claw_configure'),
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (expanded) ...[
          const SizedBox(height: 6),
          expandedContent,
        ],
      ],
    );
  }

  Widget _buildTelegramFields(bool isDark) {
    return _buildFieldRow(
      isDark: isDark,
      left: _FieldConfig(
        controller: _tgTokenCtrl,
        label: S.get('remote_claw_tg_token'),
        hint: 'BotFather Token',
        obscure: true,
      ),
      right: _FieldConfig(
        controller: _tgChatIdCtrl,
        label: S.get('remote_claw_tg_chatid'),
        hint: 'Chat ID',
      ),
    );
  }

  Widget _buildDingtalkFields(bool isDark) {
    return _buildFieldRow(
      isDark: isDark,
      left: _FieldConfig(
        controller: _ddWebhookCtrl,
        label: S.get('remote_claw_dd_webhook'),
        hint: 'https://oapi.dingtalk.com/robot/send?access_token=xxx',
      ),
      right: _FieldConfig(
        controller: _ddSecretCtrl,
        label: S.get('remote_claw_dd_secret'),
        hint: 'SEC...',
        obscure: true,
      ),
    );
  }

  Widget _buildFieldRow({
    required bool isDark,
    required _FieldConfig left,
    required _FieldConfig right,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTextField(config: left, isDark: isDark)),
        const SizedBox(width: 10),
        Expanded(child: _buildTextField(config: right, isDark: isDark)),
      ],
    );
  }

  Widget _buildTextField({
    required _FieldConfig config,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          config.label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: config.controller,
          obscureText: config.obscure,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            hintText: config.hint,
            hintStyle: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldConfig {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;

  const _FieldConfig({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
  });
}
