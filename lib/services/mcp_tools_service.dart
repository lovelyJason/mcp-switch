import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/platform_utils.dart';
import 'logger_service.dart';

class McpTool {
  final String name;
  final String? description;
  const McpTool(this.name, [this.description]);

  static const authRequired = McpTool('__auth_required__');
  static const httpUnreachable = McpTool('__http_unreachable__');
}

/// MCP Server tools 查询服务
///
/// - Codex: 通过 `codex app-server` JSON-RPC 批量查询
/// - Cursor/其他: 通过 stdio JSON-RPC 逐个查询
class McpToolsService {
  McpToolsService._();

  static const int _initializeRequestId = 0;
  static const int _listRequestId = 1;
  static const Duration _queryTimeout = Duration(seconds: 10);
  static const Duration _stdioTimeout = Duration(seconds: 30);

  static final Map<String, List<McpTool>> _cache = {};
  static bool _codexBatchQueried = false;
  static Future<void>? _codexBatchFuture;

  static List<McpTool>? getCached(String mcpName) => _cache[mcpName];

  static void clearCache() {
    _cache.clear();
    _codexBatchQueried = false;
    _codexBatchFuture = null;
  }

  /// 标记 HTTP MCP 为外部不可查询（编辑器内部管理 OAuth）
  static void markHttpUnreachable(String mcpName) {
    if (!_cache.containsKey(mcpName)) {
      _cache[mcpName] = [McpTool.httpUnreachable];
    }
  }

  /// Codex 专用：首次查询时一次性拉取全部 MCP 的 tools
  static Future<List<McpTool>> queryCodexTools({
    required String mcpName,
  }) async {
    if (_cache.containsKey(mcpName)) return _cache[mcpName]!;

    final inflight = _codexBatchFuture;
    if (inflight != null) {
      try {
        await inflight;
      } catch (_) {}
      return _cache[mcpName] ?? const [];
    }

    if (!_codexBatchQueried) {
      final future = _queryAllViaAppServer();
      _codexBatchFuture = future;
      try {
        await future;
        _codexBatchQueried = true;
      } catch (e) {
        LoggerService.warning('[McpTools] codex app-server query failed: $e');
      } finally {
        _codexBatchFuture = null;
      }
    }

    return _cache[mcpName] ?? const [];
  }

  /// 通用 stdio 查询：启动 MCP 进程，发送 initialize + tools/list
  static Future<List<McpTool>> queryToolsViaStdio({
    required String mcpName,
    required String command,
    required List<String> args,
  }) async {
    if (_cache.containsKey(mcpName)) return _cache[mcpName]!;

    Process? process;
    _StdioReader? reader;
    try {
      final resolvedCmd = await _resolveCommand(command);
      final env = await PlatformUtils.getUpdatedEnvironment();
      LoggerService.debug(
        '[McpTools] starting $mcpName: $resolvedCmd ${args.join(" ")}',
      );
      process = await Process.start(
        resolvedCmd,
        args,
        environment: env,
      );

      process.stderr.transform(utf8.decoder).listen((data) {
        LoggerService.debug('[McpTools:$mcpName:stderr] $data');
      });

      reader = _StdioReader(process.stdout);

      final initMsg = {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'mcp-switch', 'version': '1.0.0'},
        },
      };

      // 先用 NDJSON 发送（Playwright 等），超时后回退 Content-Length 帧
      await _sendJsonLine(process.stdin, initMsg);
      Map<String, dynamic>? initResp;
      try {
        initResp = await reader
            .nextMessage()
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        LoggerService.debug(
          '[McpTools] $mcpName NDJSON init timeout, retrying with Content-Length',
        );
        await _sendContentLength(process.stdin, initMsg);
        initResp = await reader.nextMessage().timeout(_stdioTimeout);
      }

      if (initResp == null) throw StateError('no init response');

      final notif = {
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      };
      await _sendJsonLine(process.stdin, notif);

      final listMsg = {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      };
      await _sendJsonLine(process.stdin, listMsg);

      final resp = await reader.nextMessage().timeout(
        const Duration(seconds: 15),
      );

      final rawTools = (resp?['result']?['tools'] as List?) ?? [];
      final tools = rawTools
          .whereType<Map>()
          .map((t) => McpTool(
                (t['name'] ?? '').toString(),
                t['description']?.toString(),
              ))
          .where((t) => t.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      _cache[mcpName] = tools;
      LoggerService.info(
        '[McpTools] $mcpName: found ${tools.length} tools via stdio',
      );
      return tools;
    } catch (e) {
      LoggerService.warning('[McpTools] stdio query failed for $mcpName: $e');
      _cache[mcpName] = [];
      return [];
    } finally {
      reader?.dispose();
      if (process != null) await _terminateProcess(process);
    }
  }

  /// HTTP (Streamable HTTP) 查询：POST JSON-RPC 到 MCP url
  static Future<List<McpTool>> queryToolsViaHttp({
    required String mcpName,
    required String url,
  }) async {
    if (_cache.containsKey(mcpName)) return _cache[mcpName]!;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    String? sessionId;

    try {
      LoggerService.debug('[McpTools] HTTP query $mcpName → $url');

      // 1. initialize
      final initResp = await _postJsonRpc(client, url, sessionId, {
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'mcp-switch', 'version': '1.0.0'},
        },
      });
      sessionId = initResp.$2;
      LoggerService.debug(
        '[McpTools] HTTP $mcpName init response: ${initResp.$1 != null ? "ok" : "null"}, session: $sessionId',
      );

      // 2. initialized notification
      await _postJsonRpc(client, url, sessionId, {
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });

      // 3. tools/list
      final toolsResp = await _postJsonRpc(client, url, sessionId, {
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      final body = toolsResp.$1;
      final rawTools = (body?['result']?['tools'] as List?) ?? [];
      final tools = rawTools
          .whereType<Map>()
          .map((t) => McpTool(
                (t['name'] ?? '').toString(),
                t['description']?.toString(),
              ))
          .where((t) => t.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      _cache[mcpName] = tools;
      LoggerService.info(
        '[McpTools] $mcpName: found ${tools.length} tools via HTTP',
      );
      return tools;
    } catch (e) {
      LoggerService.warning('[McpTools] HTTP query failed for $mcpName: $e');
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('403') || msg.contains('OAuth')) {
        _cache[mcpName] = [McpTool.authRequired];
      } else {
        _cache[mcpName] = [];
      }
      return _cache[mcpName]!;
    } finally {
      client.close(force: true);
    }
  }

  /// POST JSON-RPC to MCP HTTP endpoint, returns (parsed body, session id)
  static Future<(Map<String, dynamic>?, String?)> _postJsonRpc(
    HttpClient client,
    String url,
    String? sessionId,
    Map<String, dynamic> payload,
  ) async {
    final uri = Uri.parse(url);
    final request = await client.postUrl(uri);
    request.headers.set('Content-Type', 'application/json');
    request.headers.set('Accept', 'application/json, text/event-stream');
    if (sessionId != null) {
      request.headers.set('Mcp-Session-Id', sessionId);
    }
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      await response.drain<void>();
      throw StateError('HTTP ${response.statusCode}: 需要 OAuth 授权');
    }
    if (response.statusCode >= 400) {
      final body = await response.transform(utf8.decoder).join();
      throw StateError('HTTP ${response.statusCode}: $body');
    }

    final newSession = response.headers.value('mcp-session-id') ?? sessionId;
    final contentType = response.headers.contentType?.mimeType ?? '';

    // text/event-stream: SSE 格式，提取 data 行中的 JSON
    if (contentType.contains('text/event-stream')) {
      final raw = await response.transform(utf8.decoder).join();
      for (final line in raw.split('\n')) {
        if (line.startsWith('data: ')) {
          try {
            final json = jsonDecode(line.substring(6));
            if (json is Map<String, dynamic>) return (json, newSession);
          } catch (_) {}
        }
      }
      return (null, newSession);
    }

    // application/json 直接解析
    final raw = await response.transform(utf8.decoder).join();
    if (raw.trim().isEmpty) return (null, newSession);
    try {
      final json = jsonDecode(raw);
      return (json is Map<String, dynamic> ? json : null, newSession);
    } catch (_) {
      return (null, newSession);
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  Codex app-server 内部实现
  // ══════════════════════════════════════════════════════════════

  static Future<void> _queryAllViaAppServer() async {
    final env = await PlatformUtils.getUpdatedEnvironment();
    final executable = await PlatformUtils.findCodexExePath() ?? 'codex';

    Process? process;
    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;
    final completer = Completer<Map<String, List<McpTool>>>();

    try {
      process = await Process.start(
        executable,
        const ['app-server'],
        runInShell: Platform.isWindows,
        environment: env,
      );

      stdoutSub = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => _handleAppServerLine(line, completer));

      stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isEmpty) return;
        LoggerService.debug('[McpTools:app-server:stderr] $line');
      });

      unawaited(
        process.exitCode.then((code) {
          if (!completer.isCompleted) {
            completer.completeError(StateError(
              'codex app-server exited before response: $code',
            ));
          }
        }),
      );

      process.stdin.writeln(jsonEncode({
        'id': _initializeRequestId,
        'method': 'initialize',
        'params': {
          'clientInfo': {'name': 'mcp-switch', 'version': '1.0.0'},
        },
      }));
      process.stdin.writeln(jsonEncode({'method': 'initialized'}));
      process.stdin.writeln(jsonEncode({
        'id': _listRequestId,
        'method': 'mcpServerStatus/list',
        'params': {'limit': 200},
      }));
      await process.stdin.flush();

      final parsed = await completer.future.timeout(_queryTimeout);
      _cache
        ..clear()
        ..addAll(parsed);

      LoggerService.info(
        '[McpTools] queried ${parsed.length} MCPs via codex app-server',
      );
    } finally {
      await stdoutSub?.cancel();
      await stderrSub?.cancel();
      if (process != null) await _terminateProcess(process);
    }
  }

  static void _handleAppServerLine(
    String line,
    Completer<Map<String, List<McpTool>>> completer,
  ) {
    if (completer.isCompleted) return;
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return;

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map || decoded['id'] != _listRequestId) return;

      final error = decoded['error'];
      if (error != null) {
        completer.completeError(
          StateError('mcpServerStatus/list failed: $error'),
        );
        return;
      }

      final data = (decoded['result'] as Map?)?['data'];
      if (data is! List) return;
      completer.complete(_parseServerStatuses(data));
    } catch (_) {}
  }

  static Map<String, List<McpTool>> _parseServerStatuses(List<dynamic> data) {
    final parsed = <String, List<McpTool>>{};

    for (final item in data) {
      if (item is! Map) continue;
      final serverName = item['name']?.toString().trim();
      if (serverName == null || serverName.isEmpty) continue;

      final toolList = <McpTool>[];
      final tools = item['tools'];
      if (tools is Map) {
        for (final entry in tools.entries) {
          final v = entry.value;
          final name = v is Map && v['name'] != null
              ? v['name'].toString().trim()
              : entry.key.toString().trim();
          if (name.isEmpty) continue;
          final desc = v is Map ? v['description']?.toString() : null;
          toolList.add(McpTool(name, desc));
        }
      }

      toolList.sort((a, b) => a.name.compareTo(b.name));
      parsed[serverName] = toolList;
    }

    return parsed;
  }

  // ══════════════════════════════════════════════════════════════
  //  Stdio JSON-RPC helpers
  // ══════════════════════════════════════════════════════════════

  /// 通过交互式 shell 解析命令的完整路径（解决 macOS 上 PATH 不完整的问题）
  static Future<String> _resolveCommand(String command) async {
    if (command.contains('/')) return command;
    try {
      final result = await PlatformUtils.runCommand('which $command');
      final resolved = result.stdout.toString().trim();
      if (resolved.isNotEmpty &&
          !resolved.contains('not found') &&
          resolved.startsWith('/')) {
        LoggerService.debug('[McpTools] resolved "$command" → $resolved');
        return resolved;
      }
    } catch (_) {}
    return command;
  }

  /// NDJSON 格式（newline-delimited JSON）— 多数 MCP server 使用此格式
  static Future<void> _sendJsonLine(IOSink sink, Map<String, dynamic> msg) async {
    sink.writeln(jsonEncode(msg));
    await sink.flush();
  }

  /// Content-Length 帧格式 — 部分旧 MCP server 使用此格式
  static Future<void> _sendContentLength(
    IOSink sink,
    Map<String, dynamic> msg,
  ) async {
    final body = jsonEncode(msg);
    final bodyBytes = utf8.encode(body);
    sink.write('Content-Length: ${bodyBytes.length}\r\n\r\n$body');
    await sink.flush();
  }

  static Future<void> _terminateProcess(Process process) async {
    // 先 SIGTERM，让进程优雅退出（避免先关 stdin 导致 EPIPE）
    try {
      process.kill();
    } catch (_) {}
    try {
      await process.exitCode.timeout(const Duration(milliseconds: 500));
      return;
    } catch (_) {}
    try {
      await process.stdin.close();
    } catch (_) {}
    try {
      await process.exitCode.timeout(const Duration(milliseconds: 300));
      return;
    } catch (_) {}
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {}
    try {
      await process.exitCode.timeout(const Duration(milliseconds: 300));
    } catch (_) {}
  }
}

/// 从 MCP Server stdout 读取 JSON-RPC 消息
class _StdioReader {
  final List<int> _buf = [];
  late final StreamSubscription<List<int>> _sub;

  _StdioReader(Stream<List<int>> stream) {
    _sub = stream.listen((data) => _buf.addAll(data));
  }

  /// 读取下一条 JSON-RPC 响应（包含 id 或 result/error 的消息）
  /// 自动跳过 notification（method 但无 id 的消息）
  Future<Map<String, dynamic>?> nextMessage() async {
    const poll = Duration(milliseconds: 50);
    while (true) {
      final msg = _tryParseContentLength() ?? _tryParseLineJson();
      if (msg != null) {
        if (msg.containsKey('id') || msg.containsKey('result') || msg.containsKey('error')) {
          return msg;
        }
        // notification — 跳过，继续等
        continue;
      }
      await Future.delayed(poll);
    }
  }

  Map<String, dynamic>? _tryParseContentLength() {
    if (_buf.length < 20) return null;
    final raw = utf8.decode(_buf, allowMalformed: true);
    final idx = raw.indexOf('\r\n\r\n');
    if (idx < 0) return null;

    final header = raw.substring(0, idx);
    final m = RegExp(r'Content-Length:\s*(\d+)').firstMatch(header);
    if (m == null) return null;

    final contentLen = int.parse(m.group(1)!);
    final headerByteLen = utf8.encode(raw.substring(0, idx + 4)).length;
    if (_buf.length < headerByteLen + contentLen) return null;

    final bodyBytes = _buf.sublist(headerByteLen, headerByteLen + contentLen);
    _buf.removeRange(0, headerByteLen + contentLen);
    try {
      return jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _tryParseLineJson() {
    final raw = utf8.decode(_buf, allowMalformed: true);
    final nlIdx = raw.indexOf('\n');
    if (nlIdx < 0) return null;

    final line = raw.substring(0, nlIdx).trim();
    final consumed = utf8.encode(raw.substring(0, nlIdx + 1)).length;

    if (line.isEmpty || !line.startsWith('{')) {
      _buf.removeRange(0, consumed);
      return null;
    }

    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      _buf.removeRange(0, consumed);
      if (obj.containsKey('jsonrpc')) return obj;
      return null;
    } catch (_) {
      _buf.removeRange(0, consumed);
      return null;
    }
  }

  void dispose() => _sub.cancel();
}
