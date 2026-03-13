import 'dart:convert';
import '../../../../config/mcp_presets_config.dart';
import '../../../../models/editor_type.dart';

/// MCP 预设配置工具类
/// 负责生成不同连接类型的配置 JSON/TOML
class McpPresetUtils {
  McpPresetUtils._();

  /// 根据编辑器类型生成远程配置 (http/sse)
  /// 不同编辑器的 MCP 配置语法有细微差别
  static Map<String, dynamic> buildRemoteConfig({
    required EditorType editorType,
    required McpConnectionType connectionConfig,
    required Map<String, String> fieldValues,
  }) {
    switch (editorType) {
      case EditorType.claude:
        return buildClaudeRemoteConfig(connectionConfig, fieldValues);
      case EditorType.codex:
        return buildCodexRemoteConfig(connectionConfig, fieldValues);
      case EditorType.cursor:
      case EditorType.kiro:
        return _buildWithUrlKey('url', connectionConfig, fieldValues);
      case EditorType.windsurf:
      case EditorType.antigravity:
        return _buildWithUrlKey('serverUrl', connectionConfig, fieldValues);
      case EditorType.gemini:
        return _buildWithUrlKey('httpUrl', connectionConfig, fieldValues);
    }
  }

  /// 生成 Claude 远程配置 (http/sse)
  static Map<String, dynamic> buildClaudeRemoteConfig(
    McpConnectionType connectionConfig,
    Map<String, String> fieldValues,
  ) {
    final headers = interpolateHeaders(connectionConfig.headers, fieldValues);

    final config = <String, dynamic>{
      'type': connectionConfig.type,
      'url': connectionConfig.url ?? '',
    };

    if (headers.isNotEmpty) {
      config['headers'] = headers;
    }

    return config;
  }

  /// 根据 URL 字段名生成远程配置
  static Map<String, dynamic> _buildWithUrlKey(
    String urlKey,
    McpConnectionType connectionConfig,
    Map<String, String> fieldValues,
  ) {
    final headers = interpolateHeaders(connectionConfig.headers, fieldValues);
    return {
      'type': connectionConfig.type,
      urlKey: connectionConfig.url ?? '',
      'headers': headers,
    };
  }

  /// 生成 Codex 远程配置
  static Map<String, dynamic> buildCodexRemoteConfig(
    McpConnectionType connectionConfig,
    Map<String, String> fieldValues,
  ) {
    final headers = interpolateHeaders(connectionConfig.headers, fieldValues);
    return {'url': connectionConfig.url ?? '', 'http_headers': headers};
  }

  /// 生成远程 TOML 配置
  static String generateRemoteToml(
    String name,
    McpConnectionType connectionConfig,
    Map<String, String> fieldValues,
  ) {
    final headers = interpolateHeaders(connectionConfig.headers, fieldValues);
    final safeName = name.contains(RegExp(r'[^a-zA-Z0-9_\-]'))
        ? '"$name"'
        : name;
    final buffer = StringBuffer()
      ..writeln('[mcp_servers.$safeName]')
      ..writeln('url = "${connectionConfig.url ?? ''}"');

    if (headers.isNotEmpty) {
      final headersStr = headers.entries
          .map((e) => '"${e.key}" = "${e.value}"')
          .join(', ');
      buffer.writeln('http_headers = { $headersStr }');
    }

    return buffer.toString().trimRight();
  }

  /// 生成本地 TOML 配置
  static String generateLocalToml(String name, Map<String, dynamic> config) {
    final buffer = StringBuffer();
    final safeName = name.contains(RegExp(r'[^a-zA-Z0-9_\-]'))
        ? '"$name"'
        : name;
    buffer.writeln('[mcp_servers.$safeName]');

    final command = config['command']?.toString() ?? '';
    final args = config['args'];

    if (command.isNotEmpty) {
      buffer.writeln('command = "$command"');
    }

    if (args is List && args.isNotEmpty) {
      final argsStr = args.map((a) => '"$a"').join(', ');
      buffer.writeln('args = [$argsStr]');
    }

    final env = config['env'];
    if (env is Map && env.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('[mcp_servers.$safeName.env]');
      for (final entry in env.entries) {
        buffer.writeln('${entry.key} = "${entry.value}"');
      }
    }

    return buffer.toString();
  }

  /// 根据 Codex 配置内容生成对应 TOML（本地或远程）
  static String generateCodexToml(String name, Map<String, dynamic> config) {
    final safeName = name.contains(RegExp(r'[^a-zA-Z0-9_\-]'))
        ? '"$name"'
        : name;
    final buffer = StringBuffer()..writeln('[mcp_servers.$safeName]');

    final url = config['url']?.toString() ?? '';
    if (url.isNotEmpty) {
      buffer.writeln('url = "$url"');

      final headers = config['http_headers'];
      if (headers is Map && headers.isNotEmpty) {
        final headersStr = headers.entries
            .map((e) => '"${e.key}" = "${e.value}"')
            .join(', ');
        buffer.writeln('http_headers = { $headersStr }');
      }
      return buffer.toString().trimRight();
    }

    return generateLocalToml(name, config).trimRight();
  }

  /// 解析 TOML 为 Map
  static Map<String, dynamic> parseToml(String text) {
    final result = <String, dynamic>{};
    String? currentSection;
    final sectionRegex = RegExp(r'^\[mcp_servers\.([^\]]+)\]');
    final envSectionRegex = RegExp(r'^\[mcp_servers\.[^\]]+\.env\]');
    final kvRegex = RegExp(r'^(\w+)\s*=\s*(.+)$');
    final lines = text.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final envMatch = envSectionRegex.firstMatch(line);
      if (envMatch != null) {
        currentSection = 'env';
        result['env'] ??= <String, dynamic>{};
        continue;
      }

      final sectionMatch = sectionRegex.firstMatch(line);
      if (sectionMatch != null) {
        currentSection = 'main';
        continue;
      }

      final kvMatch = kvRegex.firstMatch(line);
      if (kvMatch != null) {
        final key = kvMatch.group(1)!;
        var value = kvMatch.group(2)!.trim();

        if (value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        }

        if (currentSection == 'env') {
          (result['env'] as Map<String, dynamic>)[key] = value;
        } else if (key == 'args') {
          final argsMatch = RegExp(r'\[(.*)\]').firstMatch(value);
          if (argsMatch != null) {
            final argsStr = argsMatch.group(1)!;
            final args = argsStr
                .split(',')
                .map((a) => a.trim().replaceAll('"', ''))
                .where((a) => a.isNotEmpty)
                .toList();
            result['args'] = args;
          }
        } else if (key == 'http_headers') {
          final headersMatch = RegExp(r'\{(.*)\}').firstMatch(value);
          if (headersMatch != null) {
            result['http_headers'] = _parseInlineTable(headersMatch.group(1)!);
          }
        } else {
          result[key] = value;
        }
      }
    }

    return result;
  }

  static Map<String, String> _parseInlineTable(String raw) {
    final result = <String, String>{};
    final pairRegex = RegExp(r'"([^"]+)"\s*=\s*"([^"]*)"');
    for (final match in pairRegex.allMatches(raw)) {
      result[match.group(1)!] = match.group(2)!;
    }
    return result;
  }

  /// 插值替换 headers 中的模板变量
  static Map<String, String> interpolateHeaders(
    Map<String, String> headers,
    Map<String, String> fieldValues,
  ) {
    return headers.map((key, value) {
      var interpolated = value;
      for (final entry in fieldValues.entries) {
        final placeholder = '{{${entry.key}}}';
        final replacement = entry.value.isEmpty
            ? 'YOUR_${entry.key.toUpperCase()}'
            : entry.value;
        interpolated = interpolated.replaceAll(placeholder, replacement);
      }
      return MapEntry(key, interpolated);
    });
  }

  /// 格式化 JSON 为可读格式
  static String formatJson(Map<String, dynamic> config) {
    return const JsonEncoder.withIndent('  ').convert(config);
  }
}
