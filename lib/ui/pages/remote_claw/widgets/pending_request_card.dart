import 'package:flutter/material.dart';

import '../../../../l10n/s.dart';
import '../../../../models/permission_request.dart';

class PendingRequestCard extends StatelessWidget {
  const PendingRequestCard({
    super.key,
    required this.request,
    required this.onAllow,
    required this.onDeny,
  });

  final PermissionRequest request;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _toolEmoji(request.toolName),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  request.toolName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.projectName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _timeAgo(request.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
            if (request.commandSummary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.commandSummary,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDeny,
                  icon: const Icon(Icons.close, size: 14),
                  label: Text(S.get('remote_claw_deny')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onAllow,
                  icon: const Icon(Icons.check, size: 14),
                  label: Text(S.get('remote_claw_allow')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _toolEmoji(String toolName) {
    switch (toolName) {
      case 'Bash':
        return '⚡';
      case 'Write':
        return '✏️';
      case 'Edit':
        return '📝';
      case 'Read':
        return '📖';
      case 'Glob':
      case 'Grep':
        return '🔍';
      default:
        return '🔧';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
