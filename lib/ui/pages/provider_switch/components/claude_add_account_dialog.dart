import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/s.dart';
import '../../../../services/claude_account_service.dart';
import '../../../components/custom_toast.dart';

/// 「登录并保存新账号」弹窗：
/// 记录打开时的当前账号为基线，点开始后每几秒检测 ~/.claude.json + Keychain，
/// 一旦检测到换成了另一个账号（用户在 Claude Code 里 /login 了新账号）就自动
/// 捕获为新账号并激活，toast 后 800ms 关闭。点关闭则什么都不做。
class ClaudeAddAccountDialog extends StatefulWidget {
  final ClaudeAccountService service;
  const ClaudeAddAccountDialog({super.key, required this.service});

  @override
  State<ClaudeAddAccountDialog> createState() => _ClaudeAddAccountDialogState();
}

class _ClaudeAddAccountDialogState extends State<ClaudeAddAccountDialog> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Timer? _timer;
  bool _polling = false;
  bool _done = false;
  String? _baselineKey;

  @override
  void initState() {
    super.initState();
    ClaudeAccountService.currentAccountKey().then((k) {
      if (mounted) _baselineKey = k;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _start() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _polling = true);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_done) return;
    final token = await ClaudeAccountService.readCurrentToken();
    final key = await ClaudeAccountService.currentAccountKey();
    // 需要：有 token、有身份、且账号标识与打开时不同（换了账号）
    if (token == null || key == null || key == _baselineKey) return;
    _done = true;
    _timer?.cancel();
    try {
      final name = _nameCtrl.text.trim();
      await widget.service.captureCurrentAsNewAccount(name);
      if (!mounted) return;
      Toast.show(
        context,
        message:
            S.get('claude_account_add_success').replaceAll('{name}', name),
        type: ToastType.success,
      );
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _done = false;
      if (!mounted) return;
      Toast.show(context, message: e.toString(), type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('claude_account_add_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                autofocus: true,
                enabled: !_polling,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: S.get('claude_account_name_label'),
                  hintText: S.get('claude_account_name_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                validator: (v) {
                  final name = (v ?? '').trim();
                  if (name.isEmpty) {
                    return S.get('claude_account_name_required');
                  }
                  if (!widget.service.isNameAvailable(name)) {
                    return S.get('claude_account_name_duplicate');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Text(
                S.get('claude_account_add_hint'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              if (_polling) _buildWaiting(textColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(S.get('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: _polling ? null : _start,
                    child: Text(S.get('claude_account_add_start')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaiting(Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(Colors.orange),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.get('claude_account_add_waiting'),
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
