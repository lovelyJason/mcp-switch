import 'dart:convert';
import 'dart:io';
import '../models/session_meta.dart';
import '../utils/platform_utils.dart';

class SessionService {
  String get _home => PlatformUtils.userHome;

  /// Claude 会话根目录: ~/.claude/projects/
  String get _claudeProjectsDir =>
      PlatformUtils.joinPath(_home, '.claude', 'projects');

  /// Codex 会话根目录: ~/.codex/sessions/
  String get _codexSessionsDir =>
      PlatformUtils.joinPath(_home, '.codex', 'sessions');

  /// 扫描所有会话（Claude + Codex）
  Future<List<SessionMeta>> scanAllSessions() async {
    final results = await Future.wait([
      _scanClaudeSessions(),
      _scanCodexSessions(),
    ]);
    final all = [...results[0], ...results[1]];
    all.sort((a, b) {
      final aTs = a.lastActiveAt ?? a.createdAt ?? DateTime(2000);
      final bTs = b.lastActiveAt ?? b.createdAt ?? DateTime(2000);
      return bTs.compareTo(aTs);
    });
    return all;
  }

  /// 加载某会话的消息列表
  Future<List<SessionMessage>> loadMessages(SessionMeta session) async {
    if (session.sourcePath == null) return [];
    final file = File(session.sourcePath!);
    if (!await file.exists()) return [];

    if (session.providerId == 'claude') {
      return _loadClaudeMessages(file);
    } else if (session.providerId == 'codex') {
      return _loadCodexMessages(file);
    }
    return [];
  }

  /// 删除会话（删除 JSONL 文件和关联的 sidecar 目录）
  Future<bool> deleteSession(SessionMeta session) async {
    if (session.sourcePath == null) return false;
    final file = File(session.sourcePath!);
    if (!await file.exists()) return false;

    try {
      if (session.providerId == 'claude') {
        final stem = file.path.replaceAll('.jsonl', '');
        final sidecarDir = Directory(stem);
        if (await sidecarDir.exists()) {
          await sidecarDir.delete(recursive: true);
        }
      }
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ========== Claude 会话扫描 ==========

  Future<List<SessionMeta>> _scanClaudeSessions() async {
    final dir = Directory(_claudeProjectsDir);
    if (!await dir.exists()) return [];

    final jsonlFiles = <File>[];
    await _collectJsonlFiles(dir, jsonlFiles);

    final sessions = <SessionMeta>[];
    for (final file in jsonlFiles) {
      if (file.path.contains('/agent-')) continue;
      try {
        final meta = await _parseClaudeSession(file);
        if (meta != null) sessions.add(meta);
      } catch (_) {}
    }
    return sessions;
  }

  Future<SessionMeta?> _parseClaudeSession(File file) async {
    final lines = await _readHeadTailLines(file, 10, 30);
    if (lines == null) return null;

    final (head, tail) = lines;
    String? sessionId;
    String? projectDir;
    DateTime? createdAt;

    for (final line in head) {
      final map = _tryParseJson(line);
      if (map == null) continue;
      sessionId ??= map['sessionId'] as String?;
      projectDir ??= map['cwd'] as String?;
      createdAt ??= _parseTimestamp(map['timestamp']);
    }

    DateTime? lastActiveAt;
    String? summary;

    for (final line in tail.reversed) {
      final map = _tryParseJson(line);
      if (map == null) continue;
      lastActiveAt ??= _parseTimestamp(map['timestamp']);
      if (summary == null && map['isMeta'] != true) {
        final message = map['message'];
        if (message is Map<String, dynamic>) {
          final text = _extractText(message['content']);
          if (text.trim().isNotEmpty) summary = text;
        }
      }
      if (lastActiveAt != null && summary != null) break;
    }

    sessionId ??= _inferSessionIdFromFilename(file);
    if (sessionId == null) return null;

    return SessionMeta(
      providerId: 'claude',
      sessionId: sessionId,
      title: projectDir?.split('/').last,
      summary: _truncate(summary, 160),
      projectDir: projectDir,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt,
      sourcePath: file.path,
      resumeCommand: 'claude --resume $sessionId',
    );
  }

  Future<List<SessionMessage>> _loadClaudeMessages(File file) async {
    final messages = <SessionMessage>[];
    final lines = await file.readAsLines();
    for (final line in lines) {
      final map = _tryParseJson(line);
      if (map == null) continue;
      if (map['isMeta'] == true) continue;
      final message = map['message'];
      if (message is! Map<String, dynamic>) continue;
      final role = (message['role'] as String?) ?? 'unknown';
      final content = _extractText(message['content']);
      if (content.trim().isEmpty) continue;
      final ts = _parseTimestamp(map['timestamp']);
      messages.add(SessionMessage(role: role, content: content, timestamp: ts));
    }
    return messages;
  }

  // ========== Codex 会话扫描 ==========

  Future<List<SessionMeta>> _scanCodexSessions() async {
    final dir = Directory(_codexSessionsDir);
    if (!await dir.exists()) return [];

    final jsonlFiles = <File>[];
    await _collectJsonlFiles(dir, jsonlFiles);

    final sessions = <SessionMeta>[];
    for (final file in jsonlFiles) {
      try {
        final meta = await _parseCodexSession(file);
        if (meta != null) sessions.add(meta);
      } catch (_) {}
    }
    return sessions;
  }

  Future<SessionMeta?> _parseCodexSession(File file) async {
    final lines = await _readHeadTailLines(file, 10, 30);
    if (lines == null) return null;

    final (head, tail) = lines;
    String? sessionId;
    String? projectDir;
    DateTime? createdAt;

    for (final line in head) {
      final map = _tryParseJson(line);
      if (map == null) continue;
      createdAt ??= _parseTimestamp(map['timestamp']);
      if (map['type'] == 'session_meta') {
        final payload = map['payload'];
        if (payload is Map<String, dynamic>) {
          sessionId ??= payload['id'] as String?;
          projectDir ??= payload['cwd'] as String?;
        }
      }
    }

    DateTime? lastActiveAt;
    String? summary;

    for (final line in tail.reversed) {
      final map = _tryParseJson(line);
      if (map == null) continue;
      lastActiveAt ??= _parseTimestamp(map['timestamp']);
      if (summary == null && map['type'] == 'response_item') {
        final payload = map['payload'];
        if (payload is Map<String, dynamic> && payload['type'] == 'message') {
          final text = _extractText(payload['content']);
          if (text.trim().isNotEmpty) summary = text;
        }
      }
      if (lastActiveAt != null && summary != null) break;
    }

    sessionId ??= _inferCodexSessionId(file);
    if (sessionId == null) return null;

    return SessionMeta(
      providerId: 'codex',
      sessionId: sessionId,
      title: projectDir?.split('/').last,
      summary: _truncate(summary, 160),
      projectDir: projectDir,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt,
      sourcePath: file.path,
      resumeCommand: 'codex resume $sessionId',
    );
  }

  Future<List<SessionMessage>> _loadCodexMessages(File file) async {
    final messages = <SessionMessage>[];
    final lines = await file.readAsLines();
    for (final line in lines) {
      final map = _tryParseJson(line);
      if (map == null) continue;
      if (map['type'] != 'response_item') continue;
      final payload = map['payload'];
      if (payload is! Map<String, dynamic>) continue;
      if (payload['type'] != 'message') continue;
      final role = (payload['role'] as String?) ?? 'unknown';
      final content = _extractText(payload['content']);
      if (content.trim().isEmpty) continue;
      final ts = _parseTimestamp(map['timestamp']);
      messages.add(SessionMessage(role: role, content: content, timestamp: ts));
    }
    return messages;
  }

  // ========== 工具方法 ==========

  Future<void> _collectJsonlFiles(Directory dir, List<File> files) async {
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.jsonl')) {
        files.add(entity);
      }
    }
  }

  Future<(List<String>, List<String>)?> _readHeadTailLines(
    File file, int headN, int tailN,
  ) async {
    try {
      final allLines = await file.readAsLines();
      if (allLines.isEmpty) return null;
      final head = allLines.take(headN).toList();
      final skip = allLines.length > tailN ? allLines.length - tailN : 0;
      final tail = allLines.skip(skip).toList();
      return (head, tail);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryParseJson(String line) {
    try {
      final result = jsonDecode(line);
      if (result is Map<String, dynamic>) return result;
    } catch (_) {}
    return null;
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return null;
  }

  /// 从 message.content 中提取文本（可以是 String/List/Map）
  String _extractText(dynamic content) {
    if (content is String) return content;
    if (content is List) {
      return content
          .map((item) {
            if (item is Map<String, dynamic>) {
              return item['text'] as String? ??
                  item['input_text'] as String? ??
                  item['output_text'] as String? ??
                  '';
            }
            if (item is String) return item;
            return '';
          })
          .where((s) => s.isNotEmpty)
          .join('\n');
    }
    if (content is Map<String, dynamic>) {
      return content['text'] as String? ?? '';
    }
    return '';
  }

  String? _inferSessionIdFromFilename(File file) {
    final name = file.uri.pathSegments.last.replaceAll('.jsonl', '');
    return name.isNotEmpty ? name : null;
  }

  String? _inferCodexSessionId(File file) {
    final name = file.uri.pathSegments.last;
    final uuidPattern = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );
    final match = uuidPattern.firstMatch(name);
    return match?.group(0);
  }

  String? _truncate(String? text, int maxChars) {
    if (text == null) return null;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= maxChars) return trimmed;
    return '${trimmed.substring(0, maxChars)}...';
  }
}
