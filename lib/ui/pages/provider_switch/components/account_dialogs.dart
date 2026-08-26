import 'package:flutter/material.dart';

import '../../../../l10n/s.dart';
import '../../../components/custom_dialog.dart';
import '../../../components/custom_toast.dart';

/// 弹出「给账号起名」输入框，返回合法名称；取消返回 null。
/// 校验：非空 + [isNameAvailable] 通过（重名检测由调用方按各自数据源判断）。
Future<String?> promptAccountName(
  BuildContext context, {
  required bool Function(String name) isNameAvailable,
  String? initial,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final controller = TextEditingController(text: initial ?? '');
  final formKey = GlobalKey<FormState>();

  final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;

  return showDialog<String>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('claude_account_name_label'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: S.get('claude_account_name_hint'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) {
                  final name = (v ?? '').trim();
                  if (name.isEmpty) {
                    return S.get('claude_account_name_required');
                  }
                  if (!isNameAvailable(name)) {
                    return S.get('claude_account_name_duplicate');
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(ctx).pop(controller.text.trim());
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(S.get('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () {
                      if (formKey.currentState!.validate()) {
                        Navigator.of(ctx).pop(controller.text.trim());
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

/// 账号管理列表的一项
class AccountManageItem {
  final String id;
  final String name;
  final String? subtitle;
  final bool isActive;
  final bool canSyncAuth;

  const AccountManageItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.isActive = false,
    this.canSyncAuth = false,
  });
}

/// 通用账号管理弹窗：列出账号，可删除。删除激活中的账号由 [onDelete] 抛错拦截。
Future<void> showAccountManageDialog(
  BuildContext context, {
  required List<AccountManageItem> Function() itemsBuilder,
  required Future<void> Function(String id) onDelete,
  Future<bool> Function(String id)? onEdit,
  Future<void> Function(String id)? onSyncAuth,
  Future<void> Function()? onRefreshAll,
  String? refreshLabel,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
  final textColor = isDark ? Colors.white : Colors.black87;
  var refreshing = false;

  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final items = itemsBuilder();
        return Dialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            width: 440,
            constraints: const BoxConstraints(maxHeight: 480),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      S.get('claude_account_manage'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    if (onRefreshAll != null)
                      TextButton.icon(
                        onPressed: refreshing
                            ? null
                            : () async {
                                setState(() => refreshing = true);
                                try {
                                  await onRefreshAll();
                                } finally {
                                  setState(() => refreshing = false);
                                }
                              },
                        icon: refreshing
                            ? const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.orange,
                                  ),
                                ),
                              )
                            : const Icon(Icons.refresh, size: 14),
                        label: Text(refreshLabel ?? S.get('refresh_config')),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      S.get('claude_account_empty'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                      ),
                      itemBuilder: (_, i) {
                        final a = items[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            a.name,
                            style: TextStyle(color: textColor, fontSize: 14),
                          ),
                          subtitle: a.subtitle != null
                              ? Text(
                                  a.subtitle!,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (onEdit != null)
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: Colors.orange,
                                  ),
                                  onPressed: () async {
                                    final changed = await onEdit(a.id);
                                    if (changed) setState(() {});
                                  },
                                ),
                              if (onSyncAuth != null && a.canSyncAuth)
                                IconButton(
                                  tooltip: S.get('provider_apply_current_auth'),
                                  icon: const Icon(
                                    Icons.sync_alt,
                                    size: 18,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () async {
                                    try {
                                      await onSyncAuth(a.id);
                                      setState(() {});
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      Toast.show(
                                        context,
                                        message: e.toString(),
                                        type: ToastType.error,
                                      );
                                    }
                                  },
                                ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  final ok = await CustomConfirmDialog.show(
                                    context,
                                    title: S.get('claude_account_delete_title'),
                                    content: S
                                        .get('claude_account_delete_content')
                                        .replaceAll('{name}', a.name),
                                    confirmText: S.get('delete'),
                                    cancelText: S.get('cancel'),
                                    confirmColor: Colors.red,
                                  );
                                  if (ok != true) return;
                                  try {
                                    await onDelete(a.id);
                                    setState(() {});
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    Toast.show(
                                      context,
                                      message: e.toString(),
                                      type: ToastType.error,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(S.get('cancel')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
