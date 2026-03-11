import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../models/session_meta.dart';
import '../../../services/session_service.dart';
import '../../../l10n/s.dart';
import '../../components/custom_toast.dart';
import '../../components/custom_dialog.dart';
import 'widgets/project_list_panel.dart';
import 'widgets/session_list_panel.dart';
import 'widgets/session_detail_panel.dart';

class SessionManagerScreen extends StatefulWidget {
  const SessionManagerScreen({super.key});

  @override
  State<SessionManagerScreen> createState() => _SessionManagerScreenState();
}

class _SessionManagerScreenState extends State<SessionManagerScreen> {
  final SessionService _sessionService = SessionService();

  List<SessionMeta> _allSessions = [];
  List<SessionProject> _projects = [];
  List<SessionProject> _filteredProjects = [];

  SessionProject? _selectedProject;
  SessionMeta? _selectedSession;
  List<SessionMessage> _messages = [];

  bool _isLoading = true;
  bool _isLoadingMessages = false;
  String _searchQuery = '';
  String _providerFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final sessions = await _sessionService.scanAllSessions();
      if (!mounted) return;
      setState(() {
        _allSessions = sessions;
        _projects = SessionProject.groupSessions(sessions);
        _isLoading = false;
        _applyFilters();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    var result = _projects.toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((p) {
        return p.displayName.toLowerCase().contains(q) ||
            p.projectKey.toLowerCase().contains(q) ||
            p.sessions.any((s) =>
                s.summary?.toLowerCase().contains(q) == true ||
                s.sessionId.toLowerCase().contains(q));
      }).toList();
    }
    _filteredProjects = result;

    if (_selectedProject != null) {
      final still = _filteredProjects
          .where((p) => p.projectKey == _selectedProject!.projectKey);
      if (still.isEmpty) {
        _selectedProject =
            _filteredProjects.isNotEmpty ? _filteredProjects.first : null;
        _selectedSession = null;
        _messages = [];
      } else {
        _selectedProject = still.first;
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onProviderFilterChanged(String provider) {
    setState(() {
      _providerFilter = provider;
      _applyFilters();
    });
  }

  void _onProjectSelected(SessionProject project) {
    setState(() {
      _selectedProject = project;
      _selectedSession = null;
      _messages = [];
    });
  }

  Future<void> _onSessionSelected(SessionMeta session) async {
    setState(() => _selectedSession = session);
    await _loadMessages(session);
  }

  Future<void> _loadMessages(SessionMeta session) async {
    setState(() {
      _isLoadingMessages = true;
      _messages = [];
    });
    try {
      final messages = await _sessionService.loadMessages(session);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _onResumeSession() async {
    if (_selectedSession?.resumeCommand == null) return;
    await Clipboard.setData(
      ClipboardData(text: _selectedSession!.resumeCommand!),
    );
    if (!mounted) return;
    Toast.show(context,
        message: S.get('session_resume_copied'), type: ToastType.success);
  }

  Future<void> _onDeleteSession() async {
    if (_selectedSession == null) return;
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('session_delete_title'),
      content: S.get('session_delete_confirm')
          .replaceAll('{title}', _selectedSession!.displayTitle),
      confirmText: S.get('delete'),
      confirmColor: Colors.red,
    );
    if (confirmed != true || !mounted) return;

    final success = await _sessionService.deleteSession(_selectedSession!);
    if (!mounted) return;
    if (success) {
      Toast.show(context,
          message: S.get('session_deleted'), type: ToastType.success);
      _allSessions.removeWhere((s) =>
          s.sessionId == _selectedSession!.sessionId &&
          s.providerId == _selectedSession!.providerId);
      _selectedSession = null;
      _messages = [];
      _projects = SessionProject.groupSessions(_allSessions);
      setState(() => _applyFilters());
    } else {
      Toast.show(context,
          message: S.get('session_delete_failed'), type: ToastType.error);
    }
  }

  Future<void> _onCopyMessage(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    Toast.show(context,
        message: S.get('copied'), type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 38),
          _buildAppBar(isDark),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 200,
                  child: ProjectListPanel(
                    projects: _filteredProjects,
                    isLoading: _isLoading,
                    selectedProject: _selectedProject,
                    searchQuery: _searchQuery,
                    onSearchChanged: _onSearchChanged,
                    onProjectSelected: _onProjectSelected,
                    onRefresh: _loadSessions,
                  ),
                ),
                VerticalDivider(
                    width: 0.5, thickness: 0.5, color: dividerColor),
                SizedBox(
                  width: 220,
                  child: SessionListPanel(
                    project: _selectedProject,
                    selectedSession: _selectedSession,
                    providerFilter: _providerFilter,
                    onSessionSelected: _onSessionSelected,
                    onProviderFilterChanged: _onProviderFilterChanged,
                  ),
                ),
                VerticalDivider(
                    width: 0.5, thickness: 0.5, color: dividerColor),
                Expanded(
                  child: SessionDetailPanel(
                    session: _selectedSession,
                    messages: _messages,
                    isLoadingMessages: _isLoadingMessages,
                    onResume: _onResumeSession,
                    onDelete: _onDeleteSession,
                    onCopyMessage: _onCopyMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: S.get('back'),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            S.get('session_manager'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}
