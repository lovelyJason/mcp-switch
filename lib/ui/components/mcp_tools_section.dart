import 'package:flutter/material.dart';
import '../../models/editor_type.dart';
import '../../models/mcp_profile.dart';
import '../../services/mcp_tools_service.dart';

/// 通用 MCP tools 展示区域，支持 Codex（批量查询）和 Cursor（stdio 查询）
class McpToolsSection extends StatefulWidget {
  final McpProfile profile;
  final EditorType editorType;
  final VoidCallback? onToolsLoaded;

  const McpToolsSection({
    super.key,
    required this.profile,
    required this.editorType,
    this.onToolsLoaded,
  });

  @override
  State<McpToolsSection> createState() => _McpToolsSectionState();
}

class _McpToolsSectionState extends State<McpToolsSection> {
  bool _loading = false;
  List<McpTool>? _tools;

  @override
  void initState() {
    super.initState();
    _tools = McpToolsService.getCached(widget.profile.name);
    if (_tools == null) _fetchTools();
  }

  Map<String, dynamic>? get _serverConfig {
    final servers = widget.profile.content['mcpServers'];
    if (servers is! Map) return null;
    final cfg = servers[widget.profile.name];
    return (cfg is Map) ? Map<String, dynamic>.from(cfg) : null;
  }

  Future<void> _fetchTools() async {
    if (_loading) return;
    setState(() => _loading = true);

    List<McpTool> tools;
    if (widget.editorType == EditorType.codex) {
      tools = await McpToolsService.queryCodexTools(
        mcpName: widget.profile.name,
      );
    } else {
      final cfg = _serverConfig;
      final cmd = cfg?['command']?.toString();
      final url = cfg?['url']?.toString();

      if (cmd != null && cmd.isNotEmpty) {
        final argsList = cfg?['args'];
        final args = (argsList is List)
            ? argsList.map((e) => e.toString()).toList()
            : <String>[];
        tools = await McpToolsService.queryToolsViaStdio(
          mcpName: widget.profile.name,
          command: cmd,
          args: args,
        );
      } else if (url != null && url.isNotEmpty) {
        // 非 Codex 编辑器无法使用编辑器内部的 OAuth token，直接标记
        McpToolsService.markHttpUnreachable(widget.profile.name);
        tools = McpToolsService.getCached(widget.profile.name) ?? [];
      } else {
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    if (mounted) {
      setState(() {
        _tools = tools;
        _loading = false;
      });
      widget.onToolsLoaded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.orange.shade300,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Querying tools...',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    if (_tools == null || _tools!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(
          'No tools found',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
        ),
      );
    }

    if (_tools!.length == 1 && _tools!.first.name == McpTool.httpUnreachable.name) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.language, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              '授权密钥存储在系统钥匙串中，请在编辑器设置中查看 tools',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    if (_tools!.length == 1 && _tools!.first.name == McpTool.authRequired.name) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 13, color: Colors.orange.shade300),
            const SizedBox(width: 4),
            Text(
              'OAuth 授权后可查看 tools',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children:
            _tools!.map((tool) => _buildToolChip(tool, isDark)).toList(),
      ),
    );
  }

  Widget _buildToolChip(McpTool tool, bool isDark) {
    final hasDesc = tool.description != null && tool.description!.isNotEmpty;
    if (!hasDesc) {
      return _chipBody(tool.name, isDark);
    }
    return _HoverableToolChip(
      toolName: tool.name,
      description: tool.description!,
      isDark: isDark,
    );
  }

  static Widget _chipBody(String name, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 0.5,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
      ),
    );
  }
}

/// 支持悬浮显示可选中描述文字的 tool chip
class _HoverableToolChip extends StatefulWidget {
  final String toolName;
  final String description;
  final bool isDark;

  const _HoverableToolChip({
    required this.toolName,
    required this.description,
    required this.isDark,
  });

  @override
  State<_HoverableToolChip> createState() => _HoverableToolChipState();
}

class _HoverableToolChipState extends State<_HoverableToolChip> {
  OverlayEntry? _entry;
  bool _chipHovered = false;
  bool _popoverHovered = false;

  static const _showDelay = Duration(milliseconds: 350);
  static const _hideDelay = Duration(milliseconds: 250);
  int _showToken = 0;
  int _hideToken = 0;

  void _scheduleShow() {
    final token = ++_showToken;
    Future.delayed(_showDelay, () {
      if (token == _showToken && _chipHovered && mounted) _show();
    });
  }

  void _scheduleHide() {
    final token = ++_hideToken;
    Future.delayed(_hideDelay, () {
      if (token == _hideToken && !_chipHovered && !_popoverHovered) _hide();
    });
  }

  void _show() {
    if (_entry != null) return;
    final overlay = Overlay.of(context);
    final box = context.findRenderObject() as RenderBox;
    final chipSize = box.size;
    final chipPos = box.localToGlobal(Offset.zero);

    _entry = OverlayEntry(
      builder: (ctx) {
        final screen = MediaQuery.of(ctx).size;
        const maxW = 340.0;
        const gap = 6.0;
        const edgePad = 16.0;

        double left = chipPos.dx;
        if (left + maxW > screen.width - edgePad) {
          left = screen.width - maxW - edgePad;
        }
        if (left < edgePad) left = edgePad;

        final spaceAbove = chipPos.dy - gap - edgePad;
        final spaceBelow = screen.height - chipPos.dy - chipSize.height - gap - edgePad;
        final showBelow = spaceAbove < 80;
        final maxH = (showBelow ? spaceBelow : spaceAbove).clamp(60.0, 400.0);

        return Stack(children: [
          Positioned(
            left: left,
            top: showBelow ? chipPos.dy + chipSize.height + gap : null,
            bottom: showBelow ? null : screen.height - chipPos.dy + gap,
            child: MouseRegion(
              onEnter: (_) {
                _popoverHovered = true;
                _hideToken++;
              },
              onExit: (_) {
                _popoverHovered = false;
                _scheduleHide();
              },
              child: Material(
                elevation: 6,
                shadowColor: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                color: widget.isDark
                    ? const Color(0xFF3A3A3C)
                    : Colors.grey.shade800,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
    );
    overlay.insert(_entry!);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _showToken++;
    _hideToken++;
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        _chipHovered = true;
        _hideToken++;
        _scheduleShow();
      },
      onExit: (_) {
        _chipHovered = false;
        _scheduleHide();
      },
      child: _McpToolsSectionState._chipBody(widget.toolName, widget.isDark),
    );
  }
}
