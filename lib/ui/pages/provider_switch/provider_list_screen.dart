import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedEditor = widget.initialEditorType;
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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderEditScreen(
                    editorType: _selectedEditor,
                  ),
                ),
              ),
              tooltip: S.get('provider_add'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorSwitcher(bool isDark) {
    final editors = [
      ('claude', 'Claude Code', 'assets/icons/claude.svg', const Color(0xFFd97757)),
      ('codex', 'Codex', 'assets/icons/chatgpt.svg', null),
    ];

    return PopupMenuButton<String>(
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 8,
      shadowColor: Colors.black45,
      tooltip: S.get('provider_switch_tooltip'),
      onSelected: (type) => setState(() => _selectedEditor = type),
      itemBuilder: (context) => editors.map((e) {
        final (type, label, icon, fixedColor) = e;
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
                colorFilter: fixedColor != null
                    ? ColorFilter.mode(fixedColor, BlendMode.srcIn)
                    : (isDark
                        ? ColorFilter.mode(Colors.white70, BlendMode.srcIn)
                        : ColorFilter.mode(Colors.black87, BlendMode.srcIn)),
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
              colorFilter: editors.firstWhere((e) => e.$1 == _selectedEditor).$4 != null
                  ? ColorFilter.mode(
                      editors.firstWhere((e) => e.$1 == _selectedEditor).$4!,
                      BlendMode.srcIn,
                    )
                  : (isDark
                      ? ColorFilter.mode(Colors.white70, BlendMode.srcIn)
                      : ColorFilter.mode(Colors.black87, BlendMode.srcIn)),
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
                  return _ProviderListItem(
                    profile: profiles[index],
                    editorType: _selectedEditor,
                    isDark: isDark,
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

  const _ProviderListItem({
    required this.profile,
    required this.editorType,
    required this.isDark,
  });

  @override
  State<_ProviderListItem> createState() => _ProviderListItemState();
}

class _ProviderListItemState extends State<_ProviderListItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cardColor =
        widget.isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor =
        widget.isDark ? Colors.white10 : Colors.grey.shade200;

    final isActive = widget.profile.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? const Color(0xFFd97757) : borderColor,
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProviderEditScreen(
                    editorType: widget.editorType,
                    profile: widget.profile,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // 左侧激活指示条
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
                          // 文本内容
                          Expanded(child: _buildTextContent()),
                          // 悬停操作
                          if (_isHovering) ...[
                            const SizedBox(width: 12),
                            if (!isActive) _buildActivateButton(),
                            if (!isActive) const SizedBox(width: 8),
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
        if (widget.profile.isActive)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProviderEditScreen(
                editorType: widget.editorType,
                profile: widget.profile,
              ),
            ),
          );
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
        if (ProviderSwitchService.isOfficialProfile(widget.profile)) {
          Toast.show(
            context,
            message: S.get('provider_official_delete_hint'),
            type: ToastType.warning,
          );
          return;
        }
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
