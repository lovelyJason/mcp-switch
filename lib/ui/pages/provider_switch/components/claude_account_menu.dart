import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/database.dart';
import '../../../../l10n/s.dart';
import '../../../../services/claude_account_service.dart';
import '../../../../services/provider_switch_service.dart';
import '../../../components/custom_toast.dart';
import 'account_dialogs.dart';
import 'claude_account_edit_dialog.dart';
import 'claude_add_account_dialog.dart';

/// 菜单项意图
class _MenuValue {
  final String type; // 'switch' | 'import' | 'manage'
  final String? id;
  const _MenuValue(this.type, [this.id]);
}

/// 官方卡上的 Claude 多账号子菜单：
/// 列出已存账号（点选=切换）、导入当前登录、管理账号。
/// 切换 = 写回 Keychain（[ClaudeAccountService]）+ 激活官方 profile 清 settings.json。
class ClaudeAccountMenu extends StatelessWidget {
  final ProviderProfile officialProfile;
  final VoidCallback? onChanged;

  const ClaudeAccountMenu({
    super.key,
    required this.officialProfile,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<ClaudeAccountService>(
      builder: (context, service, _) {
        final accounts = service.accounts;
        final active = service.activeAccount;
        return PopupMenuButton<_MenuValue>(
          tooltip: S.get('claude_account_menu_tooltip'),
          offset: const Offset(0, 8),
          elevation: 4,
          shadowColor: Colors.black26,
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onSelected: (v) => _onSelected(context, v),
          itemBuilder: (context) => _buildItems(context, accounts, active),
          child: _buildTrigger(isDark, active),
        );
      },
    );
  }

  Widget _buildTrigger(bool isDark, ClaudeAccount? active) {
    final fg = isDark ? Colors.orange.shade300 : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            active?.name ?? S.get('claude_account_menu_tooltip'),
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(Icons.arrow_drop_down, size: 18, color: fg),
        ],
      ),
    );
  }

  List<PopupMenuEntry<_MenuValue>> _buildItems(
    BuildContext context,
    List<ClaudeAccount> accounts,
    ClaudeAccount? active,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final items = <PopupMenuEntry<_MenuValue>>[];

    if (accounts.isEmpty) {
      items.add(
        PopupMenuItem<_MenuValue>(
          enabled: false,
          child: Text(
            S.get('claude_account_empty'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ),
      );
    } else {
      for (final a in accounts) {
        final isActive = a.id == active?.id;
        items.add(
          PopupMenuItem<_MenuValue>(
            value: _MenuValue('switch', a.id),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.check_circle : Icons.circle_outlined,
                  size: 16,
                  color: isActive ? Colors.green : Colors.grey.shade400,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    a.name,
                    style: TextStyle(color: textColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((ClaudeAccountService.emailOf(a) ?? a.subscriptionType) !=
                    null) ...[
                  const SizedBox(width: 8),
                  Text(
                    ClaudeAccountService.emailOf(a) ?? a.subscriptionType!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    items.add(const PopupMenuDivider(height: 1));
    // 已有账号被选中（=当前登录已保存）时，禁用「导入当前登录」，避免重复导入
    final importEnabled = active == null;
    items.add(
      PopupMenuItem<_MenuValue>(
        value: const _MenuValue('import'),
        enabled: importEnabled,
        child: Row(
          children: [
            Icon(
              Icons.download_outlined,
              size: 16,
              color: importEnabled ? Colors.orange : Colors.grey.shade500,
            ),
            const SizedBox(width: 10),
            Text(
              S.get('claude_account_import_current'),
              style: TextStyle(
                color: importEnabled ? textColor : Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
    items.add(
      PopupMenuItem<_MenuValue>(
        value: const _MenuValue('saveclear'),
        child: Row(
          children: [
            Icon(Icons.logout_outlined, size: 16, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                S.get('claude_account_save_and_clear'),
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
    if (accounts.isNotEmpty) {
      items.add(
        PopupMenuItem<_MenuValue>(
          value: const _MenuValue('manage'),
          child: Row(
            children: [
              Icon(
                Icons.settings_outlined,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 10),
              Text(
                S.get('claude_account_manage'),
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return items;
  }

  void _onSelected(BuildContext context, _MenuValue v) {
    switch (v.type) {
      case 'switch':
        if (v.id != null) _switchTo(context, v.id!);
        break;
      case 'import':
        _importCurrent(context);
        break;
      case 'saveclear':
        _openAddDialog(context);
        break;
      case 'manage':
        final claude = context.read<ClaudeAccountService>();
        showAccountManageDialog(
          context,
          refreshLabel: S.get('claude_account_refresh_usage'),
          onRefreshAll: () => claude.refreshAllUsage(),
          itemsBuilder: () => claude.accounts.map((a) {
            final email = ClaudeAccountService.emailOf(a) ?? a.subscriptionType;
            final u = claude.usageOf(a.id);
            final usageStr = u == null
                ? null
                : 'S(5h) ${u.fiveHourPercent.round()}% · W(7d) ${u.sevenDayPercent.round()}%';
            final sub = [email, usageStr].whereType<String>().join('  ·  ');
            return AccountManageItem(
              id: a.id,
              name: a.name,
              subtitle: sub.isEmpty ? null : sub,
              isActive: a.isActive,
            );
          }).toList(),
          onDelete: (id) => claude.deleteAccount(id),
          onEdit: (id) async {
            final acc = claude.accountById(id);
            if (acc == null) return false;
            final changed = await showClaudeAccountEditDialog(
              context,
              claude,
              acc,
            );
            return changed == true;
          },
        );
        break;
    }
  }

  Future<void> _switchTo(BuildContext context, String id) async {
    final claude = context.read<ClaudeAccountService>();
    final provider = context.read<ProviderSwitchService>();
    final account = claude.accounts.where((a) => a.id == id).firstOrNull;
    if (account == null) return;
    try {
      await claude.switchToAccount(id);
      await provider.toggleActive(
        officialProfile.id,
        officialProfile.editorType,
        true,
      );
      if (!context.mounted) return;
      Toast.show(
        context,
        message: S
            .get('claude_account_switch_success')
            .replaceAll('{name}', account.name),
        type: ToastType.success,
        duration: const Duration(seconds: 5),
      );
      onChanged?.call();
    } catch (e) {
      // 登录态已经切换成功，但代理/时区应用失败时仍需激活官方供应商，
      // 并明确告诉用户是哪一段环境配置失败。
      if (e.toString().contains('account_switched_environment_failed')) {
        try {
          await provider.toggleActive(
            officialProfile.id,
            officialProfile.editorType,
            true,
          );
        } catch (_) {}
        onChanged?.call();
      }
      if (!context.mounted) return;
      Toast.show(context, message: e.toString(), type: ToastType.error);
    }
  }

  /// 打开「登录并保存新账号」轮询弹窗。
  Future<void> _openAddDialog(BuildContext context) async {
    final claude = context.read<ClaudeAccountService>();
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClaudeAddAccountDialog(service: claude),
    );
    if (created == true) onChanged?.call();
  }

  Future<void> _importCurrent(BuildContext context) async {
    final claude = context.read<ClaudeAccountService>();
    String token;
    try {
      token = await claude.captureCurrentLogin();
    } catch (_) {
      if (!context.mounted) return;
      Toast.show(
        context,
        message: S.get('claude_account_no_current_login'),
        type: ToastType.error,
      );
      return;
    }
    if (!context.mounted) return;
    final name = await promptAccountName(
      context,
      isNameAvailable: (n) => claude.isNameAvailable(n),
    );
    if (name == null) return;
    try {
      final info = await ClaudeAccountService.readCurrentAccountInfo();
      await claude.addAccount(name: name, token: token, accountInfo: info);
      if (!context.mounted) return;
      Toast.show(
        context,
        message: S
            .get('claude_account_import_success')
            .replaceAll('{name}', name),
        type: ToastType.success,
      );
      onChanged?.call();
    } catch (e) {
      if (!context.mounted) return;
      Toast.show(context, message: e.toString(), type: ToastType.error);
    }
  }
}
