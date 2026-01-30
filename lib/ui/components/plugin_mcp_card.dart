import 'package:flutter/material.dart';
import '../../services/plugin_mcp_service.dart';

/// 插件 MCP 卡片组件
/// 显示从 Marketplace 插件加载的 MCP 服务器
class PluginMcpCard extends StatefulWidget {
  final List<PluginMcpServer> mcpServers;

  const PluginMcpCard({
    super.key,
    required this.mcpServers,
  });

  @override
  State<PluginMcpCard> createState() => _PluginMcpCardState();
}

class _PluginMcpCardState extends State<PluginMcpCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.mcpServers.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);

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
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.deepPurple.withOpacity(0.2)
                  : Colors.deepPurple.shade50,
              border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
            ),
            child: Icon(
              Icons.extension,
              color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
              size: 20,
            ),
          ),
          title: const Text(
            'Plugin MCPs',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${widget.mcpServers.length} servers from installed plugins',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          initiallyExpanded: true,
          children: widget.mcpServers.map((server) {
            return _buildServerItem(server);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildServerItem(PluginMcpServer server) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 根据类型选择图标
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
                ? Colors.white.withOpacity(0.05)
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
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
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
            // 连接类型标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
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
            // 连接信息
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
            // 插件来源
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 12,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${server.plugin.name}@${server.plugin.marketplace} (v${server.plugin.version})',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
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
  }
}
