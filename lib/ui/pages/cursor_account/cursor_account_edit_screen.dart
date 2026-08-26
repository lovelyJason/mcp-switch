import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/database.dart';
import '../../../l10n/s.dart';
import '../../../services/cursor_account_service.dart';
import '../../components/custom_dialog.dart';
import '../../components/custom_toast.dart';

class CursorAccountEditScreen extends StatefulWidget {
  final String? accountId;

  const CursorAccountEditScreen({super.key, this.accountId});

  @override
  State<CursorAccountEditScreen> createState() => _CursorAccountEditScreenState();
}

class _CursorAccountEditScreenState extends State<CursorAccountEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _accessCtrl;
  late final TextEditingController _refreshCtrl;
  late final TextEditingController _membershipCtrl;
  late final TextEditingController _signUpCtrl;
  late final TextEditingController _machineCtrl;
  late final TextEditingController _macMachineCtrl;
  late final TextEditingController _devDeviceCtrl;
  late final TextEditingController _sqmCtrl;

  bool _loading = false;
  bool _saving = false;
  bool _obscureAccess = true;
  bool _obscureRefresh = true;
  String _initialSnapshot = '';

  /// 激活账号中与实时 Cursor 不一致的字段集合（email/accessToken/...）
  Set<String> _outOfSync = {};

  bool get _isEdit => widget.accountId != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _accessCtrl = TextEditingController();
    _refreshCtrl = TextEditingController();
    _membershipCtrl = TextEditingController();
    _signUpCtrl = TextEditingController();
    _machineCtrl = TextEditingController();
    _macMachineCtrl = TextEditingController();
    _devDeviceCtrl = TextEditingController();
    _sqmCtrl = TextEditingController();
    if (_isEdit) {
      _loadAccount();
    } else {
      _takeSnapshot();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _accessCtrl.dispose();
    _refreshCtrl.dispose();
    _membershipCtrl.dispose();
    _signUpCtrl.dispose();
    _machineCtrl.dispose();
    _macMachineCtrl.dispose();
    _devDeviceCtrl.dispose();
    _sqmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    setState(() => _loading = true);
    final service = context.read<CursorAccountService>();
    final account = await service.getAccountById(widget.accountId!);
    if (account == null && mounted) {
      Navigator.of(context).pop();
      return;
    }
    if (account != null) {
      _fillFromAccount(account);
      // 仅激活账号需要与实时 Cursor 比对，标出漂移字段
      if (account.isActive) {
        await _computeOutOfSync(service, account);
      }
    }
    _takeSnapshot();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _computeOutOfSync(
    CursorAccountService service,
    CursorAccount account,
  ) async {
    try {
      final live = await service.captureFromCursor();
      final diff = <String>{};
      bool same(String? a, String? b) => (a ?? '').trim() == (b ?? '').trim();
      if (!same(account.email, live.email)) diff.add('email');
      if (!same(account.accessToken, live.accessToken)) diff.add('accessToken');
      if (!same(account.refreshToken, live.refreshToken)) {
        diff.add('refreshToken');
      }
      if (!same(account.membershipType, live.membershipType)) {
        diff.add('membershipType');
      }
      if (!same(account.signUpType, live.signUpType)) diff.add('signUpType');
      _outOfSync = diff;
    } catch (_) {
      _outOfSync = {};
    }
  }

  void _fillFromAccount(CursorAccount account) {
    _nameCtrl.text = account.name;
    _emailCtrl.text = account.email ?? '';
    _accessCtrl.text = account.accessToken ?? '';
    _refreshCtrl.text = account.refreshToken ?? '';
    _membershipCtrl.text = account.membershipType ?? '';
    _signUpCtrl.text = account.signUpType ?? '';
    _machineCtrl.text = account.machineId ?? '';
    _macMachineCtrl.text = account.macMachineId ?? '';
    _devDeviceCtrl.text = account.devDeviceId ?? '';
    _sqmCtrl.text = account.sqmId ?? '';
  }

  void _takeSnapshot() {
    _initialSnapshot = [
      _nameCtrl.text,
      _emailCtrl.text,
      _accessCtrl.text,
      _refreshCtrl.text,
      _membershipCtrl.text,
      _signUpCtrl.text,
      _machineCtrl.text,
      _macMachineCtrl.text,
      _devDeviceCtrl.text,
      _sqmCtrl.text,
    ].join('|');
  }

  bool get _hasUnsavedChanges {
    final current = [
      _nameCtrl.text,
      _emailCtrl.text,
      _accessCtrl.text,
      _refreshCtrl.text,
      _membershipCtrl.text,
      _signUpCtrl.text,
      _machineCtrl.text,
      _macMachineCtrl.text,
      _devDeviceCtrl.text,
      _sqmCtrl.text,
    ].join('|');
    return current != _initialSnapshot;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_hasUnsavedChanges) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        final discard = await CustomConfirmDialog.show(
          context,
          title: S.get('unsaved_changes_title'),
          content: S.get('unsaved_changes_content'),
          confirmText: S.get('discard'),
          cancelText: S.get('keep_editing'),
          confirmColor: Colors.red,
        );
        if (discard == true && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.orange))
              : Column(
                  children: [
                    _buildHeader(textColor, isDark),
                    Expanded(child: _buildForm()),
                    _buildBottomBar(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 24, right: 24, bottom: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            _isEdit ? S.get('cursor_account_edit') : S.get('cursor_account_add'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _importFromCursor,
            icon: const Icon(Icons.download_outlined, size: 14),
            label: Text(S.get('cursor_account_import_current')),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        children: [
          if (_outOfSync.isNotEmpty) _buildSyncBanner(isDark),
          _buildSection(
            isDark: isDark,
            icon: Icons.person_outline,
            title: S.get('cursor_account_name'),
            children: [
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_name'),
                isRequired: true,
                child: _textField(
                  isDark: isDark,
                  controller: _nameCtrl,
                  hint: S.get('cursor_account_name_hint'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? S.get('cursor_account_name_required')
                      : null,
                ),
              ),
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_email'),
                outOfSync: _outOfSync.contains('email'),
                child: _textField(
                  isDark: isDark,
                  controller: _emailCtrl,
                  hint: 'user@example.com',
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildLabeledField(
                      isDark: isDark,
                      label: S.get('cursor_account_membership'),
                      outOfSync: _outOfSync.contains('membershipType'),
                      child: _textField(
                        isDark: isDark,
                        controller: _membershipCtrl,
                        hint: 'pro',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildLabeledField(
                      isDark: isDark,
                      label: S.get('cursor_account_sign_up_type'),
                      outOfSync: _outOfSync.contains('signUpType'),
                      child: _textField(
                        isDark: isDark,
                        controller: _signUpCtrl,
                        hint: 'Auth_0',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            isDark: isDark,
            icon: Icons.vpn_key_outlined,
            title: S.get('cursor_account_access_token'),
            children: [
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_access_token'),
                outOfSync: _outOfSync.contains('accessToken'),
                child: _textField(
                  isDark: isDark,
                  controller: _accessCtrl,
                  hint: 'eyJ...',
                  mono: true,
                  obscure: _obscureAccess,
                  suffixIcon: _obscureToggle(
                    isDark: isDark,
                    obscured: _obscureAccess,
                    onTap: () => setState(() => _obscureAccess = !_obscureAccess),
                  ),
                ),
              ),
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_refresh_token'),
                outOfSync: _outOfSync.contains('refreshToken'),
                child: _textField(
                  isDark: isDark,
                  controller: _refreshCtrl,
                  hint: 'eyJ...',
                  mono: true,
                  obscure: _obscureRefresh,
                  suffixIcon: _obscureToggle(
                    isDark: isDark,
                    obscured: _obscureRefresh,
                    onTap: () => setState(() => _obscureRefresh = !_obscureRefresh),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            isDark: isDark,
            icon: Icons.fingerprint,
            title: S.get('cursor_account_device_section'),
            children: [
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_machine_id'),
                child: _textField(
                  isDark: isDark,
                  controller: _machineCtrl,
                  hint: '',
                  mono: true,
                ),
              ),
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_mac_machine_id'),
                child: _textField(
                  isDark: isDark,
                  controller: _macMachineCtrl,
                  hint: '',
                  mono: true,
                ),
              ),
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_dev_device_id'),
                child: _textField(
                  isDark: isDark,
                  controller: _devDeviceCtrl,
                  hint: '',
                  mono: true,
                ),
              ),
              _buildLabeledField(
                isDark: isDark,
                label: S.get('cursor_account_sqm_id'),
                child: _textField(
                  isDark: isDark,
                  controller: _sqmCtrl,
                  hint: '',
                  mono: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required bool isDark,
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSyncBanner(bool isDark) {
    final labels = {
      'email': S.get('cursor_account_email'),
      'accessToken': S.get('cursor_account_access_token'),
      'refreshToken': S.get('cursor_account_refresh_token'),
      'membershipType': S.get('cursor_account_membership'),
      'signUpType': S.get('cursor_account_sign_up_type'),
    };
    final names = _outOfSync.map((k) => labels[k] ?? k).join('、');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.sync_problem, size: 16, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S
                  .get('cursor_account_out_of_sync_guide')
                  .replaceAll('{fields}', names),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField({
    required bool isDark,
    required String label,
    required Widget child,
    bool isRequired = false,
    bool outOfSync = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              if (isRequired)
                const Text(
                  ' *',
                  style: TextStyle(fontSize: 13, color: Colors.red),
                ),
              if (outOfSync) ...[
                const SizedBox(width: 6),
                const Icon(Icons.sync_problem, size: 13, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  S.get('cursor_account_field_out_of_sync'),
                  style: const TextStyle(fontSize: 11, color: Colors.amber),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _textField({
    required bool isDark,
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
    bool mono = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final fillColor = isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade50;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(
        fontSize: mono ? 12.5 : 14,
        fontFamily: mono ? 'Menlo' : null,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hint.isEmpty ? null : hint,
        hintStyle: TextStyle(
          fontSize: mono ? 12.5 : 14,
          fontFamily: mono ? 'Menlo' : null,
          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
        isDense: true,
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        suffixIcon: suffixIcon,
        suffixIconConstraints:
            const BoxConstraints(minWidth: 40, minHeight: 40),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.orange, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.4),
        ),
      ),
    );
  }

  Widget _obscureToggle({
    required bool isDark,
    required bool obscured,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(
        obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
      ),
      onPressed: onTap,
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
            child: Text(S.get('cancel')),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(S.get('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromCursor() async {
    final service = context.read<CursorAccountService>();
    try {
      final snapshot = await service.captureFromCursor();
      if (!snapshot.hasAuth) {
        Toast.show(context, message: S.get('cursor_account_import_failed'), type: ToastType.warning);
        return;
      }
      _emailCtrl.text = snapshot.email ?? '';
      _accessCtrl.text = snapshot.accessToken ?? '';
      _refreshCtrl.text = snapshot.refreshToken ?? '';
      _membershipCtrl.text = snapshot.membershipType ?? '';
      _signUpCtrl.text = snapshot.signUpType ?? '';
      _machineCtrl.text = snapshot.machineId ?? '';
      _macMachineCtrl.text = snapshot.macMachineId ?? '';
      _devDeviceCtrl.text = snapshot.devDeviceId ?? '';
      _sqmCtrl.text = snapshot.sqmId ?? '';
      if (_nameCtrl.text.trim().isEmpty && snapshot.email?.isNotEmpty == true) {
        _nameCtrl.text = snapshot.email!.split('@').first;
      }
      Toast.show(context, message: S.get('cursor_account_import_success'), type: ToastType.success);
    } catch (e) {
      Toast.show(
        context,
        message: S.get('cursor_account_import_failed'),
        type: ToastType.error,
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accessCtrl.text.trim().isEmpty && _refreshCtrl.text.trim().isEmpty) {
      Toast.show(context, message: S.get('cursor_account_auth_required'), type: ToastType.warning);
      return;
    }

    setState(() => _saving = true);
    final service = context.read<CursorAccountService>();
    try {
      if (_isEdit) {
        await service.updateAccount(
          id: widget.accountId!,
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          accessToken: _accessCtrl.text,
          refreshToken: _refreshCtrl.text,
          membershipType: _membershipCtrl.text,
          signUpType: _signUpCtrl.text,
          machineId: _machineCtrl.text,
          macMachineId: _macMachineCtrl.text,
          devDeviceId: _devDeviceCtrl.text,
          sqmId: _sqmCtrl.text,
        );
      } else {
        await service.addAccount(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          accessToken: _accessCtrl.text,
          refreshToken: _refreshCtrl.text,
          membershipType: _membershipCtrl.text,
          signUpType: _signUpCtrl.text,
          machineId: _machineCtrl.text,
          macMachineId: _macMachineCtrl.text,
          devDeviceId: _devDeviceCtrl.text,
          sqmId: _sqmCtrl.text,
        );
      }
      if (!mounted) return;
      Toast.show(context, message: S.get('cursor_account_save_success'), type: ToastType.success);
      Navigator.of(context).pop();
    } on DuplicateCursorAccountNameException {
      Toast.show(context, message: S.get('cursor_account_name_duplicate'), type: ToastType.warning);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
