import 'package:flutter/material.dart';
import '../../../../models/session_meta.dart';
import '../../../../l10n/s.dart';

class _FilterOption {
  final String value;
  final String label;
  final IconData icon;
  const _FilterOption(this.value, this.label, this.icon);
}

final _filterOptions = [
  const _FilterOption('all', 'All', Icons.apps),
  const _FilterOption('claude', 'Claude Code', Icons.smart_toy_outlined),
  const _FilterOption('codex', 'Codex', Icons.code),
];

/// 中间栏：选中项目的会话列表
class SessionListPanel extends StatelessWidget {
  final SessionProject? project;
  final SessionMeta? selectedSession;
  final String providerFilter;
  final ValueChanged<SessionMeta> onSessionSelected;
  final ValueChanged<String> onProviderFilterChanged;

  const SessionListPanel({
    super.key,
    required this.project,
    required this.selectedSession,
    required this.providerFilter,
    required this.onSessionSelected,
    required this.onProviderFilterChanged,
  });

  List<SessionMeta> get _filteredSessions {
    if (project == null) return [];
    if (providerFilter == 'all') return project!.sessions;
    return project!.sessions
        .where((s) => s.providerId == providerFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (project == null) {
      return _emptyHint(isDark, S.get('session_pick_project'));
    }

    final sessions = _filteredSessions;

    return Column(
      children: [
        _buildHeader(isDark, sessions.length),
        if (sessions.isEmpty)
          Expanded(child: _emptyHint(isDark, S.get('session_no_sessions')))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              itemCount: sessions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 1),
              itemBuilder: (_, index) {
                final session = sessions[index];
                final isSelected = selectedSession != null &&
                    selectedSession!.sessionId == session.sessionId &&
                    selectedSession!.providerId == session.providerId;
                return _SessionItem(
                  session: session,
                  isSelected: isSelected,
                  isDark: isDark,
                  onTap: () => onSessionSelected(session),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(bool isDark, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              project!.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _ProviderFilterButton(
            currentFilter: providerFilter,
            isDark: isDark,
            onChanged: onProviderFilterChanged,
          ),
        ],
      ),
    );
  }

  Widget _emptyHint(bool isDark, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 32,
              color: Colors.grey.shade200),
          const SizedBox(height: 6),
          Text(text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

/// 筛选下拉按钮（参考 SkillsEditorSwitcher 胶囊样式）
class _ProviderFilterButton extends StatelessWidget {
  final String currentFilter;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _ProviderFilterButton({
    required this.currentFilter,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filterInfo = _filterOptions.firstWhere(
        (o) => o.value == currentFilter,
        orElse: () => _filterOptions.first);

    return PopupMenuButton<String>(
      initialValue: currentFilter,
      onSelected: onChanged,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      itemBuilder: (_) => _filterOptions.map((opt) {
        final isSelected = opt.value == currentFilter;
        return PopupMenuItem<String>(
          value: opt.value,
          height: 38,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(opt.icon, size: 16,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
              const SizedBox(width: 10),
              Text(
                opt.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(Icons.check, size: 15, color: Colors.orange),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filterInfo.icon, size: 14,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade600),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down, size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}

class _SessionItem extends StatefulWidget {
  final SessionMeta session;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _SessionItem({
    required this.session,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SessionItem> createState() => _SessionItemState();
}

class _SessionItemState extends State<_SessionItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isDark = widget.isDark;
    final session = widget.session;

    Color bg;
    if (isSelected) {
      bg = Colors.orange.withValues(alpha: isDark ? 0.12 : 0.07);
    } else if (_hovering) {
      bg = isDark ? Colors.white.withValues(alpha: 0.03)
          : Colors.grey.withValues(alpha: 0.04);
    } else {
      bg = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                session.providerId == 'claude'
                    ? Icons.smart_toy_outlined : Icons.code,
                size: 15,
                color: isSelected ? Colors.orange : Colors.grey.shade400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.shortId,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600 : FontWeight.w400,
                        fontFamily: 'monospace',
                        color: isSelected
                            ? (isDark ? Colors.orange.shade200
                                : Colors.orange.shade800)
                            : (isDark ? Colors.grey.shade400
                                : Colors.grey.shade700),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relTime(session.lastActiveAt ?? session.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                    if (session.summary != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.summary!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 13,
                  color: isSelected
                      ? Colors.orange.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.2)),
            ],
          ),
        ),
      ),
    );
  }

  String _relTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return S.get('session_time_just_now');
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${S.get('session_time_minutes_ago')}';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} ${S.get('session_time_hours_ago')}';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} ${S.get('session_time_days_ago')}';
    }
    return '${time.month}/${time.day}';
  }
}
