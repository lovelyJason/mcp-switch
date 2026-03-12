import 'package:uuid/uuid.dart';

import '../../models/mcp_profile.dart';

/// Codex TOML / CLI 纯函数工具类
///
/// 负责 `~/.codex/config.toml` 的解析、生成，
/// 以及 `codex mcp list` CLI 输出的列式解析。
class CodexConfigHelper {
  CodexConfigHelper._();

  // ── TOML 解析 ──────────────────────────────────────────────────────

  static List<McpProfile> parseToml(
    String content,
    List<McpProfile> cachedProfiles,
  ) {
    final List<McpProfile> profiles = [];
    final lines = content.split('\n');
    String? currentServerName;
    String? currentCommand;
    String? currentUrl;
    List<String> currentArgs = [];
    Map<String, String> currentHttpHeaders = {};
    bool inArgs = false;
    bool currentDisabled = false;

    final Map<String, String> nameToId = {
      for (var p in cachedProfiles) p.name: p.id,
    };

    void saveCurrent() {
      if (currentServerName != null) {
        final serverConfig = <String, dynamic>{};
        if (currentUrl != null && currentUrl!.isNotEmpty) {
          serverConfig['url'] = currentUrl!;
          if (currentHttpHeaders.isNotEmpty) {
            serverConfig['http_headers'] = Map<String, String>.from(
              currentHttpHeaders,
            );
          }
        } else {
          serverConfig['command'] = currentCommand ?? '';
          serverConfig['args'] = currentArgs;
        }
        if (currentDisabled) {
          serverConfig['disabled'] = true;
        }
        profiles.add(
          McpProfile(
            id: nameToId[currentServerName] ?? const Uuid().v4(),
            name: currentServerName!,
            description: 'Codex Server configuration',
            content: {
              'mcpServers': {currentServerName: serverConfig},
            },
          ),
        );
      }
      currentServerName = null;
      currentCommand = null;
      currentUrl = null;
      currentArgs = [];
      currentHttpHeaders = {};
      inArgs = false;
      currentDisabled = false;
    }

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('[mcp_servers.') && line.endsWith(']')) {
        saveCurrent();
        currentServerName = line.substring(13, line.length - 1).trim();
        continue;
      }

      if (line.startsWith('enabled')) {
        final match = RegExp(r'enabled\s*=\s*(\w+)').firstMatch(line);
        if (match != null && match.group(1) == 'false') {
          currentDisabled = true;
        }
        continue;
      }

      if (line.startsWith('command')) {
        final match = RegExp(r'command\s*=\s*"(.*)"').firstMatch(line);
        if (match != null) currentCommand = match.group(1);
        continue;
      }

      if (line.startsWith('url')) {
        final match = RegExp(r'url\s*=\s*"(.*)"').firstMatch(line);
        if (match != null) currentUrl = match.group(1);
        continue;
      }

      if (line.startsWith('http_headers')) {
        final match = RegExp(r'http_headers\s*=\s*\{(.*)\}').firstMatch(line);
        if (match != null) {
          currentHttpHeaders = parseInlineTable(match.group(1)!);
        }
        continue;
      }

      if (line.startsWith('args')) {
        if (line.contains('[')) {
          final inlineMatch = RegExp(r'\[(.*)\]').firstMatch(line);
          if (inlineMatch != null && !line.endsWith('[')) {
            final raw = inlineMatch.group(1)!;
            if (raw.trim().isNotEmpty) {
              currentArgs = raw
                  .split(',')
                  .map((e) => e.trim().replaceAll('"', ''))
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          } else {
            inArgs = true;
          }
        }
        continue;
      }

      if (inArgs) {
        if (line.trim() == ']') {
          inArgs = false;
          continue;
        }
        final match = RegExp(r'"(.*)"').firstMatch(line);
        if (match != null) {
          currentArgs.add(match.group(1)!);
        }
      }
    }
    saveCurrent();
    return profiles;
  }

  // ── TOML 生成 ──────────────────────────────────────────────────────

  static String generateToml(List<McpProfile> profiles) {
    final buffer = StringBuffer();
    for (var profile in profiles) {
      final content = profile.content;
      if (content['mcpServers'] is! Map) continue;
      final servers = Map<String, dynamic>.from(content['mcpServers'] as Map);

      for (var entry in servers.entries) {
        final name = entry.key;
        final config = entry.value;
        if (config is! Map) continue;

        final safeName = name.contains(RegExp(r'[^a-zA-Z0-9_\-]'))
            ? '"$name"'
            : name;
        buffer.writeln('[mcp_servers.$safeName]');

        if (config['disabled'] == true) {
          buffer.writeln('enabled = false');
        }

        final url = config['url']?.toString() ?? '';
        if (url.isNotEmpty) {
          buffer.writeln('url = "${escapeTomlString(url)}"');
          final headers = stringMapFrom(config['http_headers']);
          if (headers.isNotEmpty) {
            final headerStr = headers.entries
                .map((e) =>
                    '"${escapeTomlString(e.key)}" = "${escapeTomlString(e.value)}"')
                .join(', ');
            buffer.writeln('http_headers = { $headerStr }');
          }
        } else {
          buffer.writeln(
            'command = "${escapeTomlString(config['command']?.toString() ?? '')}"',
          );
          final args = config['args'];
          if (args is List && args.isNotEmpty) {
            buffer.writeln('args = [');
            for (var i = 0; i < args.length; i++) {
              final suffix = (i == args.length - 1) ? '' : ',';
              buffer.writeln(
                  '  "${escapeTomlString(args[i].toString())}"$suffix');
            }
            buffer.writeln(']');
          } else {
            buffer.writeln('args = []');
          }
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }

  // ── CLI 输出解析 ───────────────────────────────────────────────────

  /// 从 `codex mcp list` 输出提取 name -> auth 映射
  static Map<String, String> parseAuthFromCli(String output) {
    final authMap = <String, String>{};
    final lines = output.split('\n');

    int i = 0;
    while (i < lines.length) {
      final headerLine = lines[i];
      if (headerLine.trim().isEmpty) { i++; continue; }

      final isStdioTable = headerLine.trimLeft().startsWith('Name') &&
          headerLine.contains('Command');
      final isHttpTable = headerLine.trimLeft().startsWith('Name') &&
          headerLine.contains('Url');
      if (!isStdioTable && !isHttpTable) { i++; continue; }

      final colStarts = detectColumnStarts(headerLine);
      final authIdx = isStdioTable ? 6 : 4;
      i++;

      while (i < lines.length) {
        final line = lines[i];
        if (line.trim().isEmpty) { i++; break; }
        final cols = splitByColumns(line, colStarts);
        if (cols.isEmpty || cols[0].isEmpty) { i++; continue; }
        final name = cols[0];
        final auth = authIdx < cols.length ? cols[authIdx] : '';
        if (auth.isNotEmpty) authMap[name] = auth;
        i++;
      }
    }
    return authMap;
  }

  /// 从 header 行检测各列的起始字符位置
  static List<int> detectColumnStarts(String headerLine) {
    final starts = <int>[0];
    bool inSpace = false;
    for (var i = 0; i < headerLine.length; i++) {
      if (headerLine[i] == ' ') {
        inSpace = true;
      } else if (inSpace) {
        if (i >= 2 && headerLine[i - 1] == ' ' && headerLine[i - 2] == ' ') {
          starts.add(i);
        }
        inSpace = false;
      }
    }
    return starts;
  }

  /// 按列位置拆分行内容
  static List<String> splitByColumns(String line, List<int> colStarts) {
    final result = <String>[];
    for (var c = 0; c < colStarts.length; c++) {
      final start = colStarts[c];
      final end = (c + 1 < colStarts.length) ? colStarts[c + 1] : line.length;
      if (start >= line.length) {
        result.add('');
      } else {
        result.add(
            line.substring(start, end.clamp(start, line.length)).trim());
      }
    }
    return result;
  }

  // ── 通用工具 ───────────────────────────────────────────────────────

  static Map<String, String> parseInlineTable(String raw) {
    final result = <String, String>{};
    final pairRegex = RegExp(r'"([^"]+)"\s*=\s*"([^"]*)"');
    for (final match in pairRegex.allMatches(raw)) {
      result[match.group(1)!] = match.group(2)!;
    }
    return result;
  }

  static Map<String, String> stringMapFrom(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue.toString()),
      );
    }
    return {};
  }

  static String escapeTomlString(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
