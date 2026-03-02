import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Gemini extension 信息
class GeminiExtension {
  final String name;
  final String version;
  final String installPath;
  final bool isEnabled;

  GeminiExtension({
    required this.name,
    required this.version,
    required this.installPath,
    required this.isEnabled,
  });
}

/// Gemini Extension MCP 服务器信息
class GeminiExtensionMcpServer {
  final String name;
  final String type;
  final String? url;
  final String? command;
  final List<String>? args;
  final String? cwd;
  final GeminiExtension extension;

  GeminiExtensionMcpServer({
    required this.name,
    required this.type,
    this.url,
    this.command,
    this.args,
    this.cwd,
    required this.extension,
  });

  String get connectionInfo {
    if (type == 'http' || type == 'sse') {
      return url ?? '';
    } else if (command != null) {
      return '$command ${args?.join(' ') ?? ''}'.trim();
    }
    return '';
  }
}

/// 读取 ~/.gemini/extensions/ 下所有扩展的 MCP 配置
class GeminiExtensionMcpService extends ChangeNotifier {
  List<GeminiExtensionMcpServer> _mcpServers = [];
  bool _isLoading = false;
  String? _error;

  List<GeminiExtensionMcpServer> get mcpServers => _mcpServers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  static String get extensionsDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.gemini/extensions';
  }

  static String get enablementPath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.gemini/extensions/extension-enablement.json';
  }

  Future<void> loadExtensionMcpServers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final enabledExtensions = await _loadEnabledExtensions();
      final servers = <GeminiExtensionMcpServer>[];
      final dir = Directory(extensionsDir);

      if (!dir.existsSync()) {
        _mcpServers = [];
        return;
      }

      for (final entry in dir.listSync()) {
        if (entry is! Directory) continue;
        final extName = entry.path.split(Platform.pathSeparator).last;
        // 跳过 extension-enablement.json 所在层（它是文件，不是目录，但防御一下）
        if (extName == 'extension-enablement.json') continue;

        final configFile = File('${entry.path}/gemini-extension.json');
        if (!configFile.existsSync()) continue;

        try {
          final content = await configFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;

          final name = json['name']?.toString() ?? extName;
          final version = json['version']?.toString() ?? '0.0.0';
          final isEnabled = enabledExtensions.contains(name);

          final extension = GeminiExtension(
            name: name,
            version: version,
            installPath: entry.path,
            isEnabled: isEnabled,
          );

          final mcpServersMap =
              json['mcpServers'] as Map<String, dynamic>? ?? {};

          for (final serverEntry in mcpServersMap.entries) {
            final serverName = serverEntry.key;
            final serverConfig =
                serverEntry.value as Map<String, dynamic>? ?? {};

            final type = serverConfig['type']?.toString() ?? 'stdio';
            final url = serverConfig['url']?.toString();
            final rawCommand = serverConfig['command']?.toString();
            final rawCwd = serverConfig['cwd']?.toString();

            final argsList = serverConfig['args'];
            final rawArgs = argsList is List
                ? argsList.map((e) => e.toString()).toList()
                : null;

            // 替换占位符 ${extensionPath} 和 ${/}
            final sep = Platform.pathSeparator;
            String? resolvedCommand =
                rawCommand?.replaceAll('\${extensionPath}', entry.path)
                    .replaceAll('\${/}', sep);
            String? resolvedCwd =
                rawCwd?.replaceAll('\${extensionPath}', entry.path)
                    .replaceAll('\${/}', sep);
            final resolvedArgs = rawArgs
                ?.map((a) => a
                    .replaceAll('\${extensionPath}', entry.path)
                    .replaceAll('\${/}', sep))
                .toList();

            servers.add(GeminiExtensionMcpServer(
              name: serverName,
              type: type,
              url: url,
              command: resolvedCommand,
              args: resolvedArgs,
              cwd: resolvedCwd,
              extension: extension,
            ));
          }
        } catch (e) {
          debugPrint('加载 $extName 的 gemini-extension.json 失败: $e');
        }
      }

      _mcpServers = servers;
      _error = null;
    } catch (e) {
      _error = '加载 Gemini Extension MCP 失败: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 读取启用的 extension 名称集合
  Future<Set<String>> _loadEnabledExtensions() async {
    final file = File(enablementPath);
    if (!file.existsSync()) return {};

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      // key 是 extension name，value 包含 overrides 等信息
      return json.keys.toSet();
    } catch (_) {
      return {};
    }
  }
}
