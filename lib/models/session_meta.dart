class SessionMeta {
  final String providerId;
  final String sessionId;
  final String? title;
  final String? summary;
  final String? projectDir;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final String? sourcePath;
  final String? resumeCommand;

  SessionMeta({
    required this.providerId,
    required this.sessionId,
    this.title,
    this.summary,
    this.projectDir,
    this.createdAt,
    this.lastActiveAt,
    this.sourcePath,
    this.resumeCommand,
  });

  String get displayTitle =>
      title ?? projectDir?.split('/').last ?? sessionId.substring(0, 8);

  String get shortId =>
      sessionId.length > 8 ? '${sessionId.substring(0, 8)}...' : sessionId;
}

class SessionMessage {
  final String role;
  final String content;
  final DateTime? timestamp;

  SessionMessage({
    required this.role,
    required this.content,
    this.timestamp,
  });

  bool get isUser => role.toLowerCase() == 'user';
  bool get isAssistant => role.toLowerCase() == 'assistant';
}

/// 按项目分组的会话集合
class SessionProject {
  final String projectKey;
  final String displayName;
  final List<SessionMeta> sessions;

  SessionProject({
    required this.projectKey,
    required this.displayName,
    required this.sessions,
  });

  DateTime? get lastActiveAt {
    DateTime? latest;
    for (final s in sessions) {
      final t = s.lastActiveAt ?? s.createdAt;
      if (t != null && (latest == null || t.isAfter(latest))) latest = t;
    }
    return latest;
  }

  int get sessionCount => sessions.length;

  /// 收集所有出现过的 provider
  Set<String> get providers => sessions.map((s) => s.providerId).toSet();

  /// 按 projectDir 或 title 分组
  static List<SessionProject> groupSessions(List<SessionMeta> sessions) {
    final map = <String, List<SessionMeta>>{};
    for (final s in sessions) {
      final key = s.projectDir ?? s.title ?? s.sessionId;
      map.putIfAbsent(key, () => []).add(s);
    }
    final projects = map.entries.map((e) {
      final name = e.value.first.projectDir?.split('/').last
          ?? e.value.first.title
          ?? e.key.substring(0, e.key.length.clamp(0, 8));
      return SessionProject(
        projectKey: e.key,
        displayName: name,
        sessions: e.value
          ..sort((a, b) {
            final aT = a.lastActiveAt ?? a.createdAt ?? DateTime(2000);
            final bT = b.lastActiveAt ?? b.createdAt ?? DateTime(2000);
            return bT.compareTo(aT);
          }),
      );
    }).toList();
    projects.sort((a, b) {
      final aT = a.lastActiveAt ?? DateTime(2000);
      final bT = b.lastActiveAt ?? DateTime(2000);
      return bT.compareTo(aT);
    });
    return projects;
  }
}
