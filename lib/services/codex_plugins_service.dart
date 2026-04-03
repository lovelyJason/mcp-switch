import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../models/codex_plugin.dart';
import '../utils/platform_utils.dart';

/// 扫描来源：
///   1. ~/.codex/plugins/cache/{marketplace}/{plugin}/{local-or-hash}/
///      - 有 .codex-plugin/plugin.json → 读 JSON 清单（local plugin）
///      - 有 agents/*.yaml → 读 YAML 清单（remote/openai plugin）
///   2. ~/plugins/{plugin}/ → home-local plugin，补充未缓存的条目
class CodexPluginsService {
  String get _home => PlatformUtils.userHome;

  Future<List<CodexPlugin>> loadMarketplacePlugins() async {
    final plugins = <CodexPlugin>[];
    final seenNames = <String>{};

    // ── 来源 1：~/.codex/plugins/cache/ ─────────────────────────────────────
    final cacheDir = Directory(
      PlatformUtils.joinPath(_home, '.codex', 'plugins', 'cache'),
    );
    if (await cacheDir.exists()) {
      await _scanCacheDir(cacheDir, plugins, seenNames);
    }

    // ── 来源 2：~/plugins/ ──────────────────────────────────────────────────
    final homePluginsDir = Directory(
      PlatformUtils.joinPath(_home, 'plugins'),
    );
    if (await homePluginsDir.exists()) {
      await _scanHomePluginsDir(homePluginsDir, plugins, seenNames);
    }

    plugins.sort((a, b) {
      if (a.isInstalled != b.isInstalled) return a.isInstalled ? -1 : 1;
      return a.displayName.compareTo(b.displayName);
    });
    return plugins;
  }

  /// 扫描 cache 目录：{marketplace}/{plugin}/{version-or-"local"}/
  Future<void> _scanCacheDir(
    Directory cacheDir,
    List<CodexPlugin> plugins,
    Set<String> seenNames,
  ) async {
    final marketplaceDirs = await cacheDir.list().toList();
    for (final mEntry in marketplaceDirs) {
      if (mEntry is! Directory) continue;
      final marketplaceName = PlatformUtils.basename(mEntry.path);
      if (marketplaceName.startsWith('.')) continue;

      final pluginDirs = await mEntry.list().toList();
      for (final pEntry in pluginDirs) {
        if (pEntry is! Directory) continue;
        final pluginFolderName = PlatformUtils.basename(pEntry.path);
        if (pluginFolderName.startsWith('.')) continue;

        // 取第一个子目录（local / hash）
        final versionDirs = await pEntry.list().toList();
        for (final vEntry in versionDirs) {
          if (vEntry is! Directory) continue;

          final plugin = await _loadFromCacheVersion(
            vEntry,
            marketplaceName: marketplaceName,
            pluginFolderName: pluginFolderName,
          );
          if (plugin != null) {
            seenNames.add(plugin.name);
            plugins.add(plugin);
          }
          break; // 只取第一个版本目录
        }
      }
    }
  }

  /// 从缓存的版本目录读取 plugin（JSON 优先，YAML 兜底）
  Future<CodexPlugin?> _loadFromCacheVersion(
    Directory versionDir, {
    required String marketplaceName,
    required String pluginFolderName,
  }) async {
    // 尝试 .codex-plugin/plugin.json（local plugin）
    final jsonManifest = File(
      PlatformUtils.joinPath(versionDir.path, '.codex-plugin', 'plugin.json'),
    );
    if (await jsonManifest.exists()) {
      try {
        final data = jsonDecode(await jsonManifest.readAsString()) as Map<String, dynamic>;
        return CodexPlugin.fromJson(
          data,
          marketplace: marketplaceName,
          pluginDir: versionDir.path,
          isInstalled: true,
        );
      } catch (_) {}
    }

    // 尝试 agents/*.yaml（remote/openai plugin）
    final agentsDir = Directory(
      PlatformUtils.joinPath(versionDir.path, 'agents'),
    );
    if (await agentsDir.exists()) {
      final yamlFiles = await agentsDir.list().toList();
      for (final yamlEntry in yamlFiles) {
        if (yamlEntry is! File) continue;
        if (!yamlEntry.path.endsWith('.yaml') && !yamlEntry.path.endsWith('.yml')) continue;
        final f = yamlEntry;
        try {
          final plugin = await _loadFromOpenAIYaml(
            f,
            name: pluginFolderName,
            marketplace: marketplaceName,
            pluginDir: versionDir.path,
          );
          if (plugin != null) return plugin;
        } catch (_) {}
      }
    }

    return null;
  }

  /// 解析 agents/openai.yaml 格式
  Future<CodexPlugin?> _loadFromOpenAIYaml(
    File yamlFile, {
    required String name,
    required String marketplace,
    required String pluginDir,
  }) async {
    final content = await yamlFile.readAsString();
    final doc = loadYaml(content) as YamlMap?;
    if (doc == null) return null;

    final iface = doc['interface'] as YamlMap?;
    final displayName = (iface?['display_name'] as String?)?.trim() ??
        _toDisplayName(name);
    final shortDesc =
        (iface?['short_description'] as String?)?.trim() ?? '';

    return CodexPlugin(
      name: name,
      displayName: displayName,
      shortDescription: shortDesc,
      marketplace: marketplace,
      pluginDir: pluginDir,
      isInstalled: true,
    );
  }

  /// 扫描 ~/plugins/ 补充未缓存的 home-local plugin
  Future<void> _scanHomePluginsDir(
    Directory homePluginsDir,
    List<CodexPlugin> plugins,
    Set<String> seenNames,
  ) async {
    final entries = await homePluginsDir.list().toList();
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final name = PlatformUtils.basename(entry.path);
      if (name.startsWith('.')) continue;
      if (seenNames.contains(name)) continue; // cache 中已存在

      final manifestFile = File(
        PlatformUtils.joinPath(entry.path, '.codex-plugin', 'plugin.json'),
      );
      if (!await manifestFile.exists()) continue;

      try {
        final data =
            jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
        plugins.add(CodexPlugin.fromJson(
          data,
          marketplace: 'local',
          pluginDir: entry.path,
          isInstalled: false,
        ));
        seenNames.add(name);
      } catch (_) {}
    }
  }

  String _toDisplayName(String kebab) =>
      kebab.split('-').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}
