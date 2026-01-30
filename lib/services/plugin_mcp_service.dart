import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 已安装插件信息
class InstalledPlugin {
  final String name; // e.g., "Notion"
  final String marketplace; // e.g., "claude-plugins-official"
  final String version;
  final String installPath;
  final DateTime? installedAt;
  final DateTime? lastUpdated;

  InstalledPlugin({
    required this.name,
    required this.marketplace,
    required this.version,
    required this.installPath,
    this.installedAt,
    this.lastUpdated,
  });

  /// 完整标识符 (e.g., "Notion@claude-plugins-official")
  String get fullId => '$name@$marketplace';
}

/// 插件 MCP 服务器信息
class PluginMcpServer {
  final String name; // MCP 服务器名称
  final String type; // http, sse, stdio
  final String? url; // http/sse 的 URL
  final String? command; // stdio 的命令
  final List<String>? args; // stdio 的参数
  final InstalledPlugin plugin; // 所属插件

  PluginMcpServer({
    required this.name,
    required this.type,
    this.url,
    this.command,
    this.args,
    required this.plugin,
  });

  /// 显示的连接信息
  String get connectionInfo {
    if (type == 'http' || type == 'sse') {
      return url ?? '';
    } else if (type == 'stdio' && command != null) {
      return '$command ${args?.join(' ') ?? ''}';
    }
    return '';
  }
}

/// 插件 MCP 服务
/// 读取 ~/.claude/plugins/installed_plugins.json 和各插件的 .mcp.json
class PluginMcpService extends ChangeNotifier {
  List<PluginMcpServer> _mcpServers = [];
  bool _isLoading = false;
  String? _error;

  List<PluginMcpServer> get mcpServers => _mcpServers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 获取 Claude 插件目录路径
  static String get pluginsDir {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/.claude/plugins';
  }

  /// 获取 installed_plugins.json 路径
  static String get installedPluginsPath => '$pluginsDir/installed_plugins.json';

  /// 加载所有插件的 MCP 配置
  Future<void> loadPluginMcpServers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final installedPlugins = await _loadInstalledPlugins();
      final servers = <PluginMcpServer>[];

      for (final plugin in installedPlugins) {
        final mcpServersFromPlugin = await _loadMcpFromPlugin(plugin);
        servers.addAll(mcpServersFromPlugin);
      }

      _mcpServers = servers;
      _error = null;
    } catch (e) {
      _error = '加载插件 MCP 失败: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 读取 installed_plugins.json
  Future<List<InstalledPlugin>> _loadInstalledPlugins() async {
    final file = File(installedPluginsPath);
    if (!file.existsSync()) {
      return [];
    }

    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    final pluginsMap = json['plugins'] as Map<String, dynamic>? ?? {};

    final plugins = <InstalledPlugin>[];

    for (final entry in pluginsMap.entries) {
      // entry.key = "Notion@claude-plugins-official"
      final parts = entry.key.split('@');
      if (parts.length != 2) continue;

      final name = parts[0];
      final marketplace = parts[1];

      // entry.value 是一个数组，取第一个（通常只有一个）
      final installations = entry.value as List?;
      if (installations == null || installations.isEmpty) continue;

      final installation = installations[0] as Map<String, dynamic>;
      final installPath = installation['installPath'] as String?;
      if (installPath == null) continue;

      plugins.add(InstalledPlugin(
        name: name,
        marketplace: marketplace,
        version: installation['version']?.toString() ?? 'unknown',
        installPath: installPath,
        installedAt: _parseDateTime(installation['installedAt']),
        lastUpdated: _parseDateTime(installation['lastUpdated']),
      ));
    }

    return plugins;
  }

  /// 从插件目录加载 .mcp.json
  Future<List<PluginMcpServer>> _loadMcpFromPlugin(InstalledPlugin plugin) async {
    final mcpJsonPath = '${plugin.installPath}/.mcp.json';
    final file = File(mcpJsonPath);

    if (!file.existsSync()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final mcpServersMap = json['mcpServers'] as Map<String, dynamic>? ?? {};

      final servers = <PluginMcpServer>[];

      for (final entry in mcpServersMap.entries) {
        final serverName = entry.key;
        final serverConfig = entry.value as Map<String, dynamic>;

        final type = serverConfig['type']?.toString() ?? 'stdio';
        final url = serverConfig['url']?.toString();
        final command = serverConfig['command']?.toString();
        final argsList = serverConfig['args'];
        final args = argsList is List
            ? argsList.map((e) => e.toString()).toList()
            : null;

        servers.add(PluginMcpServer(
          name: serverName,
          type: type,
          url: url,
          command: command,
          args: args,
          plugin: plugin,
        ));
      }

      return servers;
    } catch (e) {
      debugPrint('加载 ${plugin.fullId} 的 .mcp.json 失败: $e');
      return [];
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }
}
