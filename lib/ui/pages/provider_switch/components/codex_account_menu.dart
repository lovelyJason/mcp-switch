import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/database.dart';
import '../../../../l10n/s.dart';
import '../../../../services/provider_switch_service.dart';
import '../../../components/custom_toast.dart';
import 'account_dialogs.dart';

/// 菜单项意图
class _MenuValue {
  final String type; // 'switch' | 'import' | 'saveclear' | 'manage'
  final String? id;
  const _MenuValue(this.type, [this.id]);
}

/// 官方卡上的 Codex 多账号子菜单（视觉收拢）。
///
/// 与 Claude 不同：codex 账号本就是各自独立的 ProviderProfile（token 存
/// ~/.codex/auth.json，每账号带自己的 model）。本菜单只把它们收拢展示，
/// 切换/导入/新增全部复用现有 profile 操作，不引入新表。
class CodexAccountMenu extends StatelessWidget {
  /// 该组官方账号（isOfficialProvider 的 codex profiles）
  final List<ProviderProfile> officialAccounts;
  final VoidCallback? onChanged;

  const CodexAccountMenu({
    super.key,
    required this.officialAccounts,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = officialAccounts.where((p) => p.isActive).firstOrNull;
    return PopupMenuButton<_MenuValue>(
      tooltip: S.get('codex_account_menu_tooltip'),
      offset: const Offset(0, 8),
      elevation: 4,
      shadowColor: Colors.black26,
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (v) => _onSelected(context, v),
      itemBuilder: (context) => _buildItems(context, active),
      child: _buildTrigger(isDark, active),
    );
  }

  Widget _buildTrigger(bool isDark, ProviderProfile? active) {
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
            active?.name ?? S.get('codex_account_menu_tooltip'),
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
    ProviderProfile? active,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final items = <PopupMenuEntry<_MenuValue>>[];

    if (officialAccounts.isEmpty) {
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
      for (final a in officialAccounts) {
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
                if ((a.model ?? '').isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    a.model!,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    items.add(const PopupMenuDivider(height: 1));
    // 已有账号被选中（=当前登录已保存）时，禁用「导入当前登录」
    items.add(
      _actionItem(
        'import',
        Icons.download_outlined,
        S.get('claude_account_import_current'),
        textColor,
        enabled: active == null,
      ),
    );
    items.add(
      _actionItem(
        'saveclear',
        Icons.logout_outlined,
        S.get('claude_account_save_and_clear'),
        textColor,
      ),
    );
    if (officialAccounts.isNotEmpty) {
      items.add(
        _actionItem(
          'manage',
          Icons.settings_outlined,
          S.get('claude_account_manage'),
          textColor,
          iconColor: Colors.grey.shade600,
        ),
      );
    }
    return items;
  }

  PopupMenuItem<_MenuValue> _actionItem(
    String type,
    IconData icon,
    String label,
    Color textColor, {
    Color? iconColor,
    bool enabled = true,
  }) {
    return PopupMenuItem<_MenuValue>(
      value: _MenuValue(type),
      enabled: enabled,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: enabled
                ? (iconColor ?? Colors.orange)
                : Colors.grey.shade500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: enabled ? textColor : Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
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
        _saveAndLoginNew(context);
        break;
      case 'manage':
        final service = context.read<ProviderSwitchService>();
        showAccountManageDialog(
          context,
          itemsBuilder: () => service.codexProfiles
              .where((p) => p.isOfficialProvider)
              .map(
                (p) => AccountManageItem(
                  id: p.id,
                  name: p.name,
                  subtitle: p.model,
                  isActive: p.isActive,
                  canSyncAuth: true,
                ),
              )
              .toList(),
          onDelete: (id) => service.deleteProfile(id, 'codex'),
          onSyncAuth: (id) async {
            await service.syncCodexAuthToProfile(id);
            if (!context.mounted) return;
            Toast.show(
              context,
              message: S
                  .get('provider_apply_auth_success')
                  .replaceAll(
                    '{name}',
                    service.codexProfiles
                            .where((p) => p.id == id)
                            .firstOrNull
                            ?.name ??
                        '',
                  ),
              type: ToastType.success,
            );
            onChanged?.call();
          },
        );
        break;
    }
  }

  Future<void> _switchTo(BuildContext context, String id) async {
    final service = context.read<ProviderSwitchService>();
    final account = officialAccounts.where((p) => p.id == id).firstOrNull;
    if (account == null) return;
    try {
      await service.toggleActive(id, 'codex', true);
      if (!context.mounted) return;
      Toast.show(
        context,
        message: S
            .get('codex_account_switch_success')
            .replaceAll('{name}', account.name),
        type: ToastType.success,
      );
      onChanged?.call();
    } catch (e) {
      if (!context.mounted) return;
      Toast.show(context, message: e.toString(), type: ToastType.error);
    }
  }

  Future<void> _importCurrent(BuildContext context) async {
    final service = context.read<ProviderSwitchService>();
    final oauth = await ProviderSwitchService.readCodexOauthDataFromAuthFile();
    if (oauth == null || oauth.isEmpty) {
      if (!context.mounted) return;
      Toast.show(
        context,
        message: S.get('codex_account_no_current_login'),
        type: ToastType.error,
      );
      return;
    }
    if (!context.mounted) return;
    final name = await promptAccountName(
      context,
      isNameAvailable: (n) =>
          service.isProviderNameAvailable(editorType: 'codex', name: n),
    );
    if (name == null) return;
    try {
      await service.addProfile(
        editorType: 'codex',
        name: name,
        isOfficialProvider: true,
        oauthData: oauth,
        model: ProviderSwitchService.codexModels.first,
        modelReasoningEffort: 'high',
        website: 'https://openai.com',
      );
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

  /// 新增一个空 OAuth 官方账号并切换（清空 auth.json → 触发 codex login）。
  /// 当前账号本就以 profile 形式保存着，无需另存。
  Future<void> _saveAndLoginNew(BuildContext context) async {
    final service = context.read<ProviderSwitchService>();
    final name = await promptAccountName(
      context,
      isNameAvailable: (n) =>
          service.isProviderNameAvailable(editorType: 'codex', name: n),
    );
    if (name == null) return;
    try {
      await service.addProfile(
        editorType: 'codex',
        name: name,
        isOfficialProvider: true,
        model: ProviderSwitchService.codexModels.first,
        modelReasoningEffort: 'high',
        website: 'https://openai.com',
      );
      final created = service.codexProfiles
          .where((p) => p.name == name)
          .firstOrNull;
      if (created != null) {
        await service.toggleActive(created.id, 'codex', true);
      }
      if (!context.mounted) return;
      Toast.show(
        context,
        message: S
            .get('codex_account_save_login_success')
            .replaceAll('{name}', name),
        type: ToastType.success,
        duration: const Duration(seconds: 6),
      );
      onChanged?.call();
    } catch (e) {
      if (!context.mounted) return;
      Toast.show(context, message: e.toString(), type: ToastType.error);
    }
  }
}
