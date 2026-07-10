import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/s.dart';
import '../../../data/database.dart';
import '../../../services/provider_switch_service.dart';
import '../../components/custom_dialog.dart';
import '../../components/custom_toast.dart';
import 'provider_edit_screen.dart';

class ProviderListScreen extends StatefulWidget {
  final String initialEditorType;

  const ProviderListScreen({
    super.key,
    this.initialEditorType = 'claude',
  });

  @override
  State<ProviderListScreen> createState() => _ProviderListScreenState();
}

class _ProviderListScreenState extends State<ProviderListScreen> {
  late String _selectedEditor;
  bool? _isConfigSynced;

  /// 当前 ~/.codex/auth.json 是否含有 OAuth 数据（用于"应用当前登录态"按钮）
  bool _hasLocalCodexAuth = false;
  String _localCodexAuthPreview = '';

  @override
  void initState() {
    super.initState();
    _selectedEditor = widget.initialEditorType;
    _checkConfigSync();
    _loadLocalCodexAuth();
  }

  void _checkConfigSync() {
    final service = Provider.of<ProviderSwitchService>(
      context,
      listen: false,
    );
    service.checkConfigSync(_selectedEditor).then((synced) {
      if (mounted) setState(() => _isConfigSynced = synced);
    });
  }

  Future<void> _applyAuthToProfile(ProviderProfile profile) async {
    final service = Provider.of<ProviderSwitchService>(
      context,
      listen: false,
    );
    final oauthData =
        await ProviderSwitchService.readCodexOauthDataFromAuthFile();
    if (oauthData == null || oauthData.isEmpty) return;
    if (!mounted) return;
    await service.updateProfile(
      id: profile.id,
      editorType: _selectedEditor,
      name: profile.name,
      oauthData: Value(oauthData),
    );
    await _loadLocalCodexAuth();
    if (!mounted) return;
    Toast.show(
      context,
      message: S.get('provider_apply_auth_success')
          .replaceAll('{name}', profile.name),
      type: ToastType.success,
    );
  }

  Future<void> _loadLocalCodexAuth() async {
    final oauthData =
        await ProviderSwitchService.readCodexOauthDataFromAuthFile();
    final preview = await ProviderSwitchService.readCodexAuthFile();
    if (mounted) {
      setState(() {
        _hasLocalCodexAuth = oauthData != null && oauthData.isNotEmpty;
        _localCodexAuthPreview = preview;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, textColor),
            Expanded(child: _buildProfileList(isDark)),
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
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: S.get('cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            S.get('provider_switch_title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          _buildEditorSwitcher(isDark),
          const Spacer(),
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () async {
                final service = Provider.of<ProviderSwitchService>(
                  context,
                  listen: false,
                );
                await service.refreshFromConfig();
                if (mounted) {
                  _checkConfigSync();
                  Toast.show(
                    context,
                    message: S.get('config_refreshed'),
                    type: ToastType.success,
                  );
                }
              },
              tooltip: S.get('refresh_config'),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFd97757),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProviderEditScreen(
                      editorType: _selectedEditor,
                    ),
                  ),
                );
                if (mounted) _checkConfigSync();
              },
              tooltip: S.get('provider_add'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorSwitcher(bool isDark) {
    // (type, label, icon, fixedColor, useOriginalColor)
    final editors = [
      ('claude', 'Claude Code', 'assets/icons/editors/claude.svg', const Color(0xFFd97757), false),
      ('codex', 'Codex', 'assets/icons/editors/chatgpt.svg', null, false),
      ('gemini', 'Gemini', 'assets/icons/editors/gemini.svg', null, true),
    ];

    ColorFilter? colorFilter(Color? fixedColor, bool useOriginal) {
      if (useOriginal) return null;
      if (fixedColor != null) return ColorFilter.mode(fixedColor, BlendMode.srcIn);
      return ColorFilter.mode(
        isDark ? Colors.white70 : Colors.black87,
        BlendMode.srcIn,
      );
    }

    return PopupMenuButton<String>(
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 8,
      shadowColor: Colors.black45,
      tooltip: S.get('provider_switch_tooltip'),
      onSelected: (type) {
        setState(() {
          _selectedEditor = type;
          _isConfigSynced = null;
        });
        _checkConfigSync();
      },
      itemBuilder: (context) => editors.map((e) {
        final (type, label, icon, fixedColor, useOriginal) = e;
        final isSelected = _selectedEditor == type;
        return PopupMenuItem<String>(
          value: type,
          height: 40,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                icon,
                width: 16,
                height: 16,
                colorFilter: colorFilter(fixedColor, useOriginal),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check, size: 16, color: Color(0xFFd97757)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              editors.firstWhere((e) => e.$1 == _selectedEditor).$3,
              width: 16,
              height: 16,
              colorFilter: colorFilter(
                editors.firstWhere((e) => e.$1 == _selectedEditor).$4,
                editors.firstWhere((e) => e.$1 == _selectedEditor).$5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(bool isDark) {
    return Consumer<ProviderSwitchService>(
      builder: (context, service, child) {
        final profiles = service.getProfiles(_selectedEditor);
        if (profiles.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  S.get('provider_no_profiles'),
                  style: TextStyle(color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                Text(
                  S.get('provider_no_profiles_hint'),
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        final activeProfile = service.getActiveProfile(_selectedEditor);
        final activeName =
            activeProfile?.name ?? S.get('provider_none_active');
        final statusText = S
            .get('provider_total_active')
            .replaceAll('{count}', profiles.length.toString())
            .replaceAll('{name}', activeName);

        final configPath = _selectedEditor == 'claude'
            ? S.get('provider_claude_file_path')
            : _selectedEditor == 'gemini'
                ? S.get('provider_gemini_file_path')
                : S.get('provider_codex_file_path');

        return Column(
          children: [
            // 状态卡片
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(
                left: 24, right: 24, top: 16, bottom: 16,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 12, horizontal: 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    configPath,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                      fontFamily: 'Menlo',
                    ),
                  ),
                ],
              ),
            ),
            // 列表
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: profiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return _ProviderListItem(
                    profile: profile,
                    editorType: _selectedEditor,
                    isDark: isDark,
                    isConfigSynced: profile.isActive
                        ? _isConfigSynced
                        : null,
                    isActiveSynced: _isConfigSynced,
                    onReturnFromEdit: _checkConfigSync,
                    hasLocalCodexAuth: _hasLocalCodexAuth,
                    localCodexAuthPreview: _localCodexAuthPreview,
                    onApplyAuth: () =>
                        _applyAuthToProfile(profile),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProviderListItem extends StatefulWidget {
  final ProviderProfile profile;
  final String editorType;
  final bool isDark;
  final bool? isConfigSynced;
  final bool? isActiveSynced;
  final VoidCallback? onReturnFromEdit;
  final bool hasLocalCodexAuth;
  final String localCodexAuthPreview;
  final VoidCallback? onApplyAuth;

  const _ProviderListItem({
    required this.profile,
    required this.editorType,
    required this.isDark,
    this.isConfigSynced,
    this.isActiveSynced,
    this.onReturnFromEdit,
    this.hasLocalCodexAuth = false,
    this.localCodexAuthPreview = '',
    this.onApplyAuth,
  });

  @override
  State<_ProviderListItem> createState() => _ProviderListItemState();
}

class _ProviderListItemState extends State<_ProviderListItem> {
  bool _isHovering = false;

  /// 是否为 Codex OAuth 供应商（通过 isOfficialProvider 标识）
  bool get _isCodexOauthProfile =>
      widget.editorType == 'codex' && widget.profile.isOfficialProvider;

  bool get _isNotLoggedIn =>
      _isCodexOauthProfile &&
      (widget.profile.oauthData ?? '').trim().isEmpty;

  @override
  Widget build(BuildContext context) {
    final cardColor =
        widget.isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor =
        widget.isDark ? Colors.white10 : Colors.grey.shade200;

    final isActive = widget.profile.isActive;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovering
                ? const Color(0xFFd97757)
                : isActive
                    ? const Color(0xFFd97757).withValues(alpha: 0.5)
                    : borderColor,
          ),
            boxShadow: [
              if (!widget.isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              if (isActive)
                Container(
                  width: 4,
                  color: const Color(0xFFd97757),
                ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: isActive ? 12 : 16,
                    top: 16,
                    bottom: 16,
                    right: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildTextContent()),
                      if (_isHovering) ...[
                        const SizedBox(width: 12),
                        if (isActive)
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFd97757).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              S.get('provider_in_use'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFd97757),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (!isActive) _buildActivateButton(),
                        const SizedBox(width: 8),
                        _buildEditButton(),
                        const SizedBox(width: 8),
                        _buildDeleteButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                widget.profile.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.profile.description?.isNotEmpty == true) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.profile.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.isDark
                        ? Colors.white38
                        : Colors.grey.shade500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (widget.profile.website?.isNotEmpty == true) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  final url = Uri.tryParse(widget.profile.website!);
                  if (url != null) launchUrl(url);
                },
                child: Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: widget.isDark
                      ? Colors.deepPurple.shade300
                      : Colors.deepPurple,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _buildSubtitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: widget.isDark
                ? Colors.grey.shade400
                : Colors.grey.shade600,
          ),
        ),
        if (_isNotLoggedIn || (_isCodexOauthProfile && widget.hasLocalCodexAuth))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (_isNotLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          S.get('provider_not_logged_in'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                // 仅当该 profile 自身还没有 auth.json（oauthData 为空）时，
                // 才显示「应用当前登录态」按钮；已登录的预设不再展示。
                if (_isNotLoggedIn && widget.hasLocalCodexAuth)
                  _AuthPopoverButton(
                    preview: widget.localCodexAuthPreview,
                    onApply: () => widget.onApplyAuth?.call(),
                  ),
              ],
            ),
          ),
        if (widget.profile.isActive)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFd97757).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    S.get('provider_in_use'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFd97757),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.isConfigSynced == false)
                  Tooltip(
                    message: S.get('provider_config_sync_hint'),
                    child: GestureDetector(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProviderEditScreen(
                              editorType: widget.editorType,
                              profile: widget.profile,
                            ),
                          ),
                        );
                        widget.onReturnFromEdit?.call();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 12,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              S.get('provider_config_out_of_sync'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (widget.profile.model != null && widget.profile.model!.isNotEmpty) {
      parts.add(widget.profile.model!);
    }
    if (widget.profile.baseUrl != null &&
        widget.profile.baseUrl!.isNotEmpty) {
      parts.add(widget.profile.baseUrl!);
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  Widget _buildActivateButton() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFd97757).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextButton.icon(
        onPressed: () {
          if (widget.isActiveSynced == false) {
            Toast.show(
              context,
              message: S.get('provider_switch_blocked_by_sync'),
              type: ToastType.warning,
              duration: const Duration(seconds: 4),
            );
            return;
          }
          final service = Provider.of<ProviderSwitchService>(
            context,
            listen: false,
          );
          service.toggleActive(
            widget.profile.id,
            widget.editorType,
            true,
          );
          Toast.show(
            context,
            message: S
                .get('provider_activate_success')
                .replaceAll('{name}', widget.profile.name),
            type: ToastType.success,
          );
        },
        icon: const Icon(Icons.power_settings_new, size: 14),
        label: Text(S.get('provider_activate')),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFd97757),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.edit, size: 18),
        color: widget.isDark ? Colors.white70 : Colors.grey.shade700,
        padding: EdgeInsets.zero,
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProviderEditScreen(
                editorType: widget.editorType,
                profile: widget.profile,
              ),
            ),
          );
          widget.onReturnFromEdit?.call();
        },
        tooltip: S.get('provider_edit'),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 20),
      color: Colors.redAccent,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: () {
        if (widget.profile.isActive) {
          Toast.show(
            context,
            message: S.get('provider_delete_active_hint'),
            type: ToastType.warning,
          );
          return;
        }
        CustomConfirmDialog.show(
          context,
          title: S.get('delete'),
          content: S.get('delete_confirm'),
          confirmText: S.get('delete'),
          cancelText: S.get('cancel'),
          confirmColor: Colors.redAccent,
          onConfirm: () {
            Provider.of<ProviderSwitchService>(
              context,
              listen: false,
            ).deleteProfile(widget.profile.id, widget.editorType);
          },
        );
      },
      tooltip: S.get('delete'),
    );
  }

}

/// 「应用当前登录态」按钮：悬浮时以 Popover 展示 auth.json 内容
class _AuthPopoverButton extends StatefulWidget {
  final String preview;
  final VoidCallback? onApply;

  const _AuthPopoverButton({required this.preview, this.onApply});

  @override
  State<_AuthPopoverButton> createState() => _AuthPopoverButtonState();
}

class _AuthPopoverButtonState extends State<_AuthPopoverButton> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  Timer? _hideTimer;

  void _showPopover() {
    _hideTimer?.cancel();
    if (_overlayEntry != null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _overlayEntry = OverlayEntry(
      builder: (_) => _AuthPopoverOverlay(
        link: _layerLink,
        preview: widget.preview,
        isDark: isDark,
        onMouseEnter: () => _hideTimer?.cancel(),
        onMouseExit: _scheduleHide,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 150), _hidePopover);
  }

  void _hidePopover() {
    _hideTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hidePopover();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _showPopover(),
        onExit: (_) => _scheduleHide(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.onApply?.call();
            _hidePopover();
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                    Icons.login, size: 12, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  S.get('provider_apply_current_auth'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPopoverOverlay extends StatelessWidget {
  final LayerLink link;
  final String preview;
  final bool isDark;
  final VoidCallback onMouseEnter;
  final VoidCallback onMouseExit;

  const _AuthPopoverOverlay({
    required this.link,
    required this.preview,
    required this.isDark,
    required this.onMouseEnter,
    required this.onMouseExit,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final border = isDark ? Colors.white12 : Colors.grey.shade200;
    final textColor = isDark ? Colors.grey.shade300 : Colors.grey.shade800;

    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: CompositedTransformFollower(
            link: link,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 6),
            child: Material(
              color: Colors.transparent,
              child: MouseRegion(
                onEnter: (_) => onMouseEnter(),
                onExit: (_) => onMouseExit(),
                child: Container(
                  width: 280,
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Text(
                          '~/.codex/auth.json',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: border),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(10),
                          child: SelectableText(
                            preview.isNotEmpty ? preview : '(empty)',
                            style: TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: textColor,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
