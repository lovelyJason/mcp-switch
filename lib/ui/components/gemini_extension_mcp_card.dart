import 'package:flutter/material.dart';
import '../../services/gemini_extension_mcp_service.dart';

/// Gemini Extension MCP 卡片
/// 显示从 ~/.gemini/extensions/ 加载的 MCP 服务器
class GeminiExtensionMcpCard extends StatelessWidget {
  final List<GeminiExtensionMcpServer> mcpServers;

  const GeminiExtensionMcpCard({super.key, required this.mcpServers});

  @override
  Widget build(BuildContext context) {
    if (mcpServers.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.withValues(alpha: 0.2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.blue.shade50,
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.extension,
              color: isDark ? Colors.blue.shade300 : Colors.blue,
              size: 20,
            ),
          ),
          title: const Text(
            'Extension MCPs',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${mcpServers.length} servers from installed extensions',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          initiallyExpanded: true,
          children: mcpServers.map(_buildServerItem).toList(),
        ),
      ),
    );
  }

  Widget _buildServerItem(GeminiExtensionMcpServer server) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      IconData typeIcon;
      Color typeColor;
      switch (server.type) {
        case 'http':
          typeIcon = Icons.language;
          typeColor = Colors.blue;
          break;
        case 'sse':
          typeIcon = Icons.stream;
          typeColor = Colors.orange;
          break;
        default:
          typeIcon = Icons.terminal;
          typeColor = Colors.green;
      }

      return Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 36, right: 24),
          dense: true,
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
            child: Icon(typeIcon, size: 18, color: typeColor),
          ),
          title: Row(
            children: [
              Text(
                server.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  server.type.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    color: typeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                server.connectionInfo,
                style: TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.extension_outlined,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${server.extension.name} v${server.extension.version}'
                      '${server.extension.isEnabled ? '' : ' (disabled)'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: server.extension.isEnabled
                            ? Colors.grey.shade500
                            : Colors.orange.shade400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
          isThreeLine: true,
        ),
      );
    });
  }
}
