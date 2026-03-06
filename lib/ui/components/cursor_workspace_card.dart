import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/cursor_workspace_service.dart';
import '../../utils/project_type_detector.dart';
import '../../l10n/s.dart';
import 'custom_toast.dart';
import 'cursor_mcp_action_dialog.dart';

/// Cursor workspace 项目卡片
///
/// 展示单个项目中各 MCP server 的启用/禁用状态，
/// 数据来自 workspace SQLite 数据库 (state.vscdb)。
class CursorWorkspaceCard extends StatefulWidget {
  final CursorWorkspace workspace;
  final List<String> globalServerNames;

  const CursorWorkspaceCard({
    super.key,
    required this.workspace,
    required this.globalServerNames,
  });

  @override
  State<CursorWorkspaceCard> createState() => _CursorWorkspaceCardState();
}

class _CursorWorkspaceCardState extends State<CursorWorkspaceCard> {
  bool _isHovering = false;
  bool _isOpening = false;
  ProjectIconInfo? _iconInfo;

  @override
  void initState() {
    super.initState();
    _detectProjectType();
  }

  Future<void> _detectProjectType() async {
    final dir = widget.workspace.folderPath;
    if (dir.isEmpty) return;
    final info = await ProjectTypeDetector.detect(dir);
    if (mounted) setState(() => _iconInfo = info);
  }

  String get _displayPath {
    final path = widget.workspace.folderPath;
    final home = RegExp(r'^/Users/[^/]+').firstMatch(path)?.group(0) ?? '';
    if (home.isNotEmpty && path.startsWith(home)) {
      return '~${path.substring(home.length)}';
    }
    return path;
  }

  String get _projectName {
    final parts = widget.workspace.folderPath.split('/');
    return parts.isNotEmpty ? parts.last : widget.workspace.id;
  }

  Future<void> _onToggleTapped(String serverName, bool currentEnabled) async {
    final action = await CursorMcpActionDialog.show(context);
    if (action == null || !mounted) return;

    if (action == CursorMcpAction.operateHere) {
      _toggleViaSqlite(serverName, currentEnabled);
    } else {
      await _openInCursorSettings();
    }
  }

  void _toggleViaSqlite(String serverName, bool currentEnabled) {
    final cursorWs = CursorWorkspaceService.instance;
    final success = cursorWs.toggleServerInWorkspace(
      widget.workspace, serverName, currentEnabled,
    );
    setState(() {});
    if (success && mounted) {
      Toast.show(
        context,
        message: S.get('cursor_workspace_toggle_tip'),
        type: ToastType.info,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _openInCursorSettings() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);

    // 先播放引导图（两步轮播自动关闭）
    if (mounted) await CursorMcpGuideOverlay.show(context);

    // 引导结束后打开 Cursor 项目窗口
    if (mounted) {
      try {
        await CursorWorkspaceService.instance
            .openCursorProject(widget.workspace.folderPath);
      } catch (e) {
        if (mounted) {
          Toast.show(context, message: 'Failed to open Cursor', type: ToastType.error);
        }
      }
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    final cursorWs = CursorWorkspaceService.instance;
    final disabledServers = cursorWs.getDisabledServers(widget.workspace.dbPath);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: _isHovering
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: _buildProjectIcon(isDark, borderColor),
            title: Text(
              _projectName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _displayPath,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontFamily: 'Menlo'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            children: _buildServerList(disabledServers, isDark),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildServerList(List<String> disabledServers, bool isDark) {
    if (widget.globalServerNames.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            S.get('no_mcp_configured'),
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ),
      ];
    }
    return widget.globalServerNames.map((name) {
      final isDisabled = disabledServers.contains('user-$name');
      return _buildServerRow(name, !isDisabled, isDark);
    }).toList();
  }

  Widget _buildServerRow(String serverName, bool isEnabled, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 36, right: 16),
        dense: true,
        leading: Container(
          width: 30, height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            serverName.isNotEmpty ? serverName[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(serverName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isEnabled
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isEnabled ? S.get('enabled') : S.get('disabled'),
                style: TextStyle(
                  fontSize: 10,
                  color: isEnabled ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: Transform.scale(
          scale: 0.7,
          child: Switch(
            value: isEnabled,
            onChanged: (_) => _onToggleTapped(serverName, isEnabled),
            activeTrackColor: Colors.green.shade400,
            inactiveTrackColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildProjectIcon(bool isDark, Color borderColor) {
    final info = _iconInfo;
    if (info?.faviconPath != null) {
      return Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
          border: Border.all(color: borderColor),
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Image.file(
              File(info!.faviconPath!),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.folder_open,
                color: isDark ? Colors.white70 : Colors.grey,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    final type = info?.type ?? ProjectType.unknown;
    final iconData = ProjectTypeDetector.getIcon(type);
    final iconColor = type == ProjectType.unknown
        ? (isDark ? Colors.white70 : Colors.grey)
        : ProjectTypeDetector.getColor(type);

    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
        border: Border.all(color: borderColor),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }
}
