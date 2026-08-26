import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../data/database.dart';
import '../../../../l10n/s.dart';
import '../../../../services/claude_account_service.dart';
import '../../../components/custom_toast.dart';

/// 编辑 Claude 账号：改名 + 手动粘贴/修正 oauthAccount 身份 JSON。
/// 成功返回 true。
Future<bool?> showClaudeAccountEditDialog(
  BuildContext context,
  ClaudeAccountService service,
  ClaudeAccount account,
) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;

  // 预填：从现有 accountInfo 拆出 userID 与 oauthAccount
  String? existingUserId;
  String prefillOAuth = '';
  final info = account.accountInfo;
  if (info != null && info.isNotEmpty) {
    try {
      final d = jsonDecode(info);
      if (d is Map) {
        existingUserId = d['userID'] as String?;
        if (d['oauthAccount'] != null) {
          prefillOAuth =
              const JsonEncoder.withIndent('  ').convert(d['oauthAccount']);
        }
      }
    } catch (_) {}
  }

  final nameCtrl = TextEditingController(text: account.name);
  final oauthCtrl = TextEditingController(text: prefillOAuth);
  final formKey = GlobalKey<FormState>();

  InputDecoration deco(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      );

  return showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 560,
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('claude_account_edit_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.get('claude_account_name_label'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: nameCtrl,
                style: TextStyle(color: textColor),
                decoration: deco(S.get('claude_account_name_hint')),
                validator: (v) {
                  final name = (v ?? '').trim();
                  if (name.isEmpty) {
                    return S.get('claude_account_name_required');
                  }
                  if (!service.isNameAvailable(name, excludeId: account.id)) {
                    return S.get('claude_account_name_duplicate');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text(
                S.get('claude_account_oauth_label'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: TextFormField(
                  controller: oauthCtrl,
                  style: TextStyle(
                    color: textColor,
                    fontFamily: 'Menlo',
                    fontSize: 12,
                  ),
                  maxLines: null,
                  minLines: 8,
                  keyboardType: TextInputType.multiline,
                  decoration: deco('{ "emailAddress": "...", ... }'),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null; // 允许留空=不改身份
                    try {
                      final d = jsonDecode(t);
                      if (d is! Map) return S.get('claude_account_oauth_invalid');
                    } catch (_) {
                      return S.get('claude_account_oauth_invalid');
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(S.get('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.orange),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      String? accountInfo;
                      final t = oauthCtrl.text.trim();
                      if (t.isNotEmpty) {
                        final oauth = jsonDecode(t);
                        accountInfo = jsonEncode({
                          if (existingUserId != null) 'userID': existingUserId,
                          'oauthAccount': oauth,
                        });
                      }
                      try {
                        await service.updateAccount(
                          id: account.id,
                          name: nameCtrl.text.trim(),
                          accountInfo: accountInfo,
                        );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop(true);
                      } catch (e) {
                        if (!ctx.mounted) return;
                        Toast.show(ctx,
                            message: e.toString(), type: ToastType.error);
                      }
                    },
                    child: Text(S.get('save')),
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
