import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import '../models/codex_plugin.dart';
import '../utils/platform_utils.dart';

/// Codex 插件数据源：
///   1. 官方 marketplace.json
///   2. osk 注册的 marketplace repos
///   3. 已安装状态由 config.toml 中的 `[plugins."name@marketplace"]` 判定
class CodexPluginsService {
  String get _home => PlatformUtils.userHome;

  /// 按 marketplace 分组返回插件（含可用 + 已安装）
  Future<Map<String, List<CodexPlugin>>> loadGroupedPlugins() async {
    final installedSet = await _loadInstalledPluginNames();
    final groups = <String, List<CodexPlugin>>{};

    await _loadOfficialPlugins(groups, installedSet);
    await _loadOskRepoPlugins(groups, installedSet);

    for (final list in groups.values) {
      list.sort((a, b) {
        if (a.isInstalled != b.isInstalled) return a.isInstalled ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });
    }
    return groups;
  }

  Future<List<CodexPlugin>> loadMarketplacePlugins() async {
    final grouped = await loadGroupedPlugins();
    return grouped.values.expand((list) => list).toList();
  }

  /// 从 config.toml 解析已安装的 plugin 名称集合
  /// 匹配 [plugins."<name>@<marketplace>"] 行
  Future<Set<String>> _loadInstalledPluginNames() async {
    final installed = <String>{};
    final configFile = File(
      PlatformUtils.joinPath(_home, '.codex', 'config.toml'),
    );
    if (!await configFile.exists()) return installed;

    try {
      final content = await configFile.readAsString();
      final pattern = RegExp(r'^\[plugins\."([^"]+)"\]', multiLine: true);
      for (final match in pattern.allMatches(content)) {
        final entry = match.group(1) ?? '';
        final atIdx = entry.indexOf('@');
        if (atIdx > 0) {
          installed.add(entry.substring(0, atIdx));
        }
      }
    } catch (_) {}
    return installed;
  }

  /// 来源 1：官方 marketplace.json
  Future<void> _loadOfficialPlugins(
    Map<String, List<CodexPlugin>> groups,
    Set<String> installed,
  ) async {
    final mpFile = File(p.join(
      _home, '.codex', '.tmp', 'plugins', '.agents', 'plugins', 'marketplace.json',
    ));
    if (!await mpFile.exists()) return;

    try {
      final data = jsonDecode(await mpFile.readAsString()) as Map<String, dynamic>;
      final displayName = ((data['interface'] as Map<String, dynamic>?)?['displayName'] as String?) ?? 'OpenAI Curated';
      final plugins = data['plugins'] as List<dynamic>? ?? [];

      final list = <CodexPlugin>[];
      for (final p in plugins) {
        if (p is! Map<String, dynamic>) continue;
        final name = p['name'] as String? ?? '';
        if (name.isEmpty) continue;
        final category = p['category'] as String?;
        list.add(CodexPlugin(
          name: name,
          displayName: _toDisplayName(name),
          shortDescription: category ?? '',
          category: category,
          marketplace: 'openai-curated',
          pluginDir: '',
          isInstalled: installed.contains(name),
        ));
      }
      if (list.isNotEmpty) {
        groups[displayName] = list;
      }
    } catch (_) {}
  }

  /// 来源 2：osk 注册的 marketplace repos
  Future<void> _loadOskRepoPlugins(
    Map<String, List<CodexPlugin>> groups,
    Set<String> installed,
  ) async {
    final reposDir = Directory(PlatformUtils.joinPath(_home, '.osk', 'repos'));
    if (!await reposDir.exists()) return;

    final entries = await reposDir.list().toList();
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final repoName = PlatformUtils.basename(entry.path);
      if (repoName.startsWith('.')) continue;

      final pluginsDir = Directory(PlatformUtils.joinPath(entry.path, 'plugins'));
      if (!await pluginsDir.exists()) continue;

      final pluginEntries = await pluginsDir.list().toList();
      final list = <CodexPlugin>[];
      for (final pEntry in pluginEntries) {
        if (pEntry is! Directory) continue;
        final pluginName = PlatformUtils.basename(pEntry.path);
        if (pluginName.startsWith('.')) continue;

        final plugin = await _loadPluginManifest(pEntry, repoName, pluginName, installed);
        if (plugin != null) {
          list.add(plugin);
        }
      }

      if (list.isNotEmpty) {
        groups[repoName] = list;
      }
    }
  }

  /// 从 plugin 目录读取 manifest（.codex-plugin/plugin.json → plugin.json 兜底）
  Future<CodexPlugin?> _loadPluginManifest(
    Directory pluginDir,
    String marketplace,
    String pluginName,
    Set<String> installed,
  ) async {
    File manifestFile = File(
      PlatformUtils.joinPath(pluginDir.path, '.codex-plugin', 'plugin.json'),
    );
    if (!await manifestFile.exists()) {
      manifestFile = File(PlatformUtils.joinPath(pluginDir.path, 'plugin.json'));
    }
    if (!await manifestFile.exists()) return null;

    try {
      final data = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      final localName = '$marketplace--$pluginName';
      final isInst = installed.contains(localName) || installed.contains(pluginName);
      return CodexPlugin.fromJson(
        data,
        marketplace: marketplace,
        pluginDir: pluginDir.path,
        isInstalled: isInst,
      );
    } catch (_) {
      return null;
    }
  }

  String _toDisplayName(String kebab) =>
      kebab.split('-').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}
