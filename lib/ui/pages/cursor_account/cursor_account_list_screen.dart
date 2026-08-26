import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/s.dart';
import '../../../services/cursor_account_service.dart';
import '../../../services/cursor_auth_file_service.dart';
import '../../components/custom_toast.dart';
import 'cursor_account_edit_screen.dart';
import 'cursor_account_list_item.dart';

class CursorAccountListScreen extends StatefulWidget {
  const CursorAccountListScreen({super.key});

  @override
  State<CursorAccountListScreen> createState() => _CursorAccountListScreenState();
}

class _CursorAccountListScreenState extends State<CursorAccountListScreen> {
  final Map<String, bool> _syncMap = {};

  @override
  void initState() {
    super.initState();
    _refreshSync();
  }

  Future<void> _refreshSync() async {
    final service = context.read<CursorAccountService>();
    final map = <String, bool>{};
    for (final account in service.accounts) {
      map[account.id] = await service.isLiveAccountSynced(account.id);
    }
    if (mounted) setState(() => _syncMap..clear()..addAll(map));
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return Scaffold(
        body: SafeArea(
          child: Center(child: Text(S.get('cursor_account_macos_only'))),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, textColor),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 24, right: 24, bottom: 12),
      child: Row(
        children: [
          _headerIconButton(
            isDark: isDark,
            icon: Icons.arrow_back,
            color: textColor,
            onPressed: () => Navigator.of(context).pop(),
            tooltip: S.get('cancel'),
          ),
          const SizedBox(width: 16),
          Text(
            S.get('cursor_account_title'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          const Spacer(),
          _headerIconButton(
            isDark: isDark,
            icon: Icons.refresh,
            color: textColor,
            onPressed: () async {
              await context.read<CursorAccountService>().refresh();
              await _refreshSync();
              if (mounted) {
                Toast.show(context, message: S.get('config_refreshed'), type: ToastType.success);
              }
            },
            tooltip: S.get('refresh_config'),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CursorAccountEditScreen()),
                );
                await context.read<CursorAccountService>().refresh();
                await _refreshSync();
              },
              tooltip: S.get('cursor_account_add'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconButton({
    required bool isDark,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<CursorAccountService>(
      builder: (context, service, _) {
        final accounts = service.accounts;
        final active = service.activeAccount;
        final activeOutOfSync =
            active != null && _syncMap[active.id] == false;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            _buildStatusCard(accounts.length, active?.name),
            const SizedBox(height: 12),
            Text(
              S.get('cursor_account_config_paths'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'Menlo'),
            ),
            const SizedBox(height: 4),
            Text(
              CursorAuthFileService.instance.stateDbPath,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Menlo'),
            ),
            const SizedBox(height: 16),
            if (accounts.isEmpty)
              _buildEmpty()
            else
              ...accounts.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CursorAccountListItem(
                    account: a,
                    isSynced: _syncMap[a.id] ?? true,
                    activeOutOfSync: activeOutOfSync,
                    onChanged: () async {
                      await service.refresh();
                      await _refreshSync();
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard(int count, String? activeName) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.get('cursor_account_total_active')
                .replaceAll('{count}', '$count')
                .replaceAll('{name}', activeName ?? S.get('cursor_account_none_active')),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            S.get('cursor_account_cursor_running_hint'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.manage_accounts_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(S.get('cursor_account_no_accounts'), style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            S.get('cursor_account_no_accounts_hint'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
