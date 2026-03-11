import 'package:flutter/material.dart';
import '../../../../models/session_meta.dart';
import '../../../../l10n/s.dart';

class ProjectListPanel extends StatefulWidget {
  final List<SessionProject> projects;
  final bool isLoading;
  final SessionProject? selectedProject;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SessionProject> onProjectSelected;
  final VoidCallback onRefresh;

  const ProjectListPanel({
    super.key,
    required this.projects,
    required this.isLoading,
    required this.selectedProject,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onProjectSelected,
    required this.onRefresh,
  });

  @override
  State<ProjectListPanel> createState() => _ProjectListPanelState();
}

class _ProjectListPanelState extends State<ProjectListPanel> {
  bool _isSearchOpen = false;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(child: _buildList(isDark)),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    if (_isSearchOpen) return _buildSearchBar(isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 6),
      child: Row(
        children: [
          Text(
            S.get('session_projects'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              '${widget.projects.length}',
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange,
              ),
            ),
          ),
          const Spacer(),
          _iconBtn(Icons.search, () {
            setState(() => _isSearchOpen = true);
            Future.delayed(const Duration(milliseconds: 50),
                () => _searchFocusNode.requestFocus());
          }),
          _iconBtn(Icons.refresh, widget.onRefresh),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: SizedBox(
        height: 30,
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: S.get('session_search_hint'),
            hintStyle: TextStyle(fontSize: 12,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
            prefixIcon: Icon(Icons.search, size: 15, color: Colors.grey.shade400),
            prefixIconConstraints: const BoxConstraints(minWidth: 30),
            suffixIcon: GestureDetector(
              onTap: () {
                _searchController.clear();
                widget.onSearchChanged('');
                setState(() => _isSearchOpen = false);
              },
              child: Icon(Icons.close, size: 13, color: Colors.grey.shade400),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 26),
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide(
                  color: Colors.orange.withValues(alpha: 0.4), width: 1),
            ),
          ),
          onChanged: widget.onSearchChanged,
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        icon: Icon(icon, size: 15, color: Colors.grey.shade500),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildList(bool isDark) {
    if (widget.isLoading) {
      return Center(
        child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: Colors.orange.shade300)),
      );
    }
    if (widget.projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 32, color: Colors.grey.shade300),
            const SizedBox(height: 6),
            Text(S.get('session_no_sessions'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      itemCount: widget.projects.length,
      separatorBuilder: (context, index) => const SizedBox(height: 1),
      itemBuilder: (_, index) {
        final project = widget.projects[index];
        final isSelected = widget.selectedProject?.projectKey ==
            project.projectKey;
        return _ProjectItem(
          project: project,
          isSelected: isSelected,
          isDark: isDark,
          onTap: () => widget.onProjectSelected(project),
        );
      },
    );
  }
}

class _ProjectItem extends StatefulWidget {
  final SessionProject project;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ProjectItem({
    required this.project,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ProjectItem> createState() => _ProjectItemState();
}

class _ProjectItemState extends State<_ProjectItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final isDark = widget.isDark;

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, size: 16,
                  color: isSelected ? Colors.orange : Colors.grey.shade400),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.project.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? (isDark ? Colors.orange.shade200
                                : Colors.orange.shade800)
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _relTime(widget.project.lastActiveAt),
                          style: TextStyle(fontSize: 11,
                              color: Colors.grey.shade500),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.project.sessionCount}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.orange.shade300
                                : Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.chat_bubble_outline, size: 10,
                            color: Colors.grey.shade400),
                      ],
                    ),
                  ],
                ),
              ),
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
