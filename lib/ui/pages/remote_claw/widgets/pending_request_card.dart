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

  bool get _isResolved => request.decision != PermissionDecision.pending;
  bool get _isAllowed => request.decision == PermissionDecision.allow;
  bool get _isExternallyHandled => request.decision == PermissionDecision.externallyHandled;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: _isResolved ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: _isResolved ? 0 : 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              if (request.commandSummary.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildCommandPreview(isDark),
              ],
              const SizedBox(height: 10),
              _isResolved ? _buildResolvedBadge(isDark) : _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
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
    );
  }

  Widget _buildCommandPreview(bool isDark) {
    return Container(
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
    );
  }

  Widget _buildActionButtons() {
    return Row(
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
    );
  }

  Widget _buildResolvedBadge(bool isDark) {
    final Color color;
    final IconData icon;
    final String label;

    if (_isExternallyHandled) {
      color = isDark ? Colors.grey[400]! : Colors.grey[600]!;
      icon = Icons.device_unknown_outlined;
      label = S.get('remote_claw_externally_handled');
    } else if (_isAllowed) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      label = S.get('remote_claw_approved');
    } else {
      color = Colors.red;
      icon = Icons.cancel_outlined;
      label = S.get('remote_claw_denied');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
