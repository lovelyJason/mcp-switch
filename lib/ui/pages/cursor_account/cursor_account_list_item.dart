import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/database.dart';
import '../../../l10n/s.dart';
import '../../../services/cursor_account_service.dart';
import '../../components/custom_dialog.dart';
import '../../components/custom_toast.dart';
import 'cursor_account_edit_screen.dart';

class CursorAccountListItem extends StatefulWidget {
  final CursorAccount account;
  final bool isSynced;

  /// 当前激活账号是否与 Cursor 不同步；为 true 时禁止切换到其他账号，
  /// 避免用户手上最新的 Cursor 登录态被覆盖丢失。
  final bool activeOutOfSync;
  final VoidCallback onChanged;

  const CursorAccountListItem({
    super.key,
    required this.account,
    required this.isSynced,
    this.activeOutOfSync = false,
    required this.onChanged,
  });

  @override
  State<CursorAccountListItem> createState() => _CursorAccountListItemState();
}

class _CursorAccountListItemState extends State<CursorAccountListItem> {
  bool _hovering = false;
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = _hovering
        ? Colors.orange.withValues(alpha: 0.6)
        : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2));

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            if (widget.account.isActive)
              Container(
                width: 4,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(10),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.account.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.account.isActive)
                          _chip(S.get('cursor_account_in_use'), Colors.orange),
                        if (widget.account.isActive && !widget.isSynced)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _chip(
                              S.get('cursor_account_out_of_sync'),
                              Colors.amber,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (widget.account.email?.isNotEmpty == true)
                          widget.account.email,
                        if (widget.account.membershipType?.isNotEmpty == true)
                          widget.account.membershipType,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_hovering || _switching) _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.account.isActive)
            TextButton.icon(
              onPressed: _switching ? null : _onSwitch,
              icon: _switching
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.swap_horiz, size: 14),
              label: Text(S.get('cursor_account_switch')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.orange),
            tooltip: S.get('edit'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CursorAccountEditScreen(accountId: widget.account.id),
                ),
              );
              widget.onChanged();
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
            tooltip: S.get('delete'),
            onPressed: widget.account.isActive ? _showDeleteActiveToast : _onDelete,
          ),
        ],
      ),
    );
  }

  void _showDeleteActiveToast() {
    Toast.show(
      context,
      message: S.get('cursor_account_delete_active_hint'),
      type: ToastType.warning,
    );
  }

  Future<void> _onSwitch() async {
    // 当前激活账号与 Cursor 不同步时，禁止切换到其他账号（先同步再切）
    if (widget.activeOutOfSync) {
      Toast.show(
        context,
        message: S.get('cursor_account_sync_before_switch'),
        type: ToastType.warning,
        duration: const Duration(seconds: 5),
      );
      return;
    }
    setState(() => _switching = true);
    final service = context.read<CursorAccountService>();
    try {
      await service.switchToAccount(widget.account.id);
      if (!mounted) return;
      Toast.show(
        context,
        message: S.get('cursor_account_switch_success')
            .replaceAll('{name}', widget.account.name),
        type: ToastType.success,
      );
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      Toast.show(
        context,
        message: S.get('cursor_account_switch_failed')
            .replaceAll('{error}', _formatError(e)),
        type: ToastType.error,
        duration: const Duration(seconds: 4),
      );
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _onDelete() async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('delete'),
      content: widget.account.name,
      confirmColor: Colors.red,
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<CursorAccountService>().deleteAccount(widget.account.id);
      if (!mounted) return;
      Toast.show(context, message: S.get('cursor_account_deleted'), type: ToastType.success);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      Toast.show(
        context,
        message: _formatError(e),
        type: ToastType.error,
      );
    }
  }

  String _formatError(Object e) {
    final msg = e.toString().replaceFirst('Exception: ', '');
    return switch (msg) {
      'cursor_auth_db_not_found' => S.get('cursor_account_auth_db_not_found'),
      'account_missing_auth' => S.get('cursor_account_missing_auth'),
      'cannot_delete_active_account' => S.get('cursor_account_cannot_delete_active'),
      _ => msg,
    };
  }
}
