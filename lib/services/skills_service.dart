import 'dart:io';
import 'dart:convert';
import '../models/skills/installed_plugin.dart';
import '../models/skills/installed_marketplace.dart';
import '../models/skills/community_skill.dart';
import '../models/skills/slash_command.dart';
import '../utils/platform_utils.dart';

/// Skills 数据服务
/// 负责：JSON 解析、文件读写、数据转换
class SkillsService {
  /// 获取用户目录（跨平台）
  String get _home => PlatformUtils.userHome;

  /// 加载插件启用状态 (从 settings.json)
  Future<Map<String, bool>> _loadEnabledPlugins() async {
    final settingsFile = File(PlatformUtils.joinPath(_home, '.claude', 'settings.json'));
    if (!await settingsFile.exists()) return {};

    try {
      final content = await settingsFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final enabledPlugins = json['enabledPlugins'] as Map<String, dynamic>? ?? {};
      return enabledPlugins.map((key, value) => MapEntry(key, value == true));
    } catch (e) {
      return {};
    }
  }

  /// 加载已安装插件
  Future<List<InstalledPlugin>> loadPlugins() async {
    final pluginsFile = File(PlatformUtils.joinPath(_home, '.claude', 'plugins', 'installed_plugins.json'));

    if (!await pluginsFile.exists()) return [];

    try {
      final content = await pluginsFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final pluginsMap = json['plugins'] as Map<String, dynamic>? ?? {};

      // 加载启用状态
      final enabledPlugins = await _loadEnabledPlugins();

      final plugins = <InstalledPlugin>[];
      for (final entry in pluginsMap.entries) {
        final key = entry.key;
        final value = entry.value;
        // 支持两种格式：数组格式和对象格式
        Map<String, dynamic>? item;
        if (value is List && value.isNotEmpty) {
          item = value[0] as Map<String, dynamic>;
        } else if (value is Map<String, dynamic>) {
          item = value;
        }

        if (item != null) {
          // 解析 scope：从 key 中提取（如 feature-dev@claude-plugins-official）
          final parts = key.split('@');
          final pluginName = parts[0];
          final marketplace =
              parts.length > 1 ? parts[1] : (item['scope'] ?? 'unknown');

          // 获取启用状态，默认为 true
          final isEnabled = enabledPlugins[key] ?? true;

          // 检测是否已废弃（源目录不存在）
          final isDeprecated = await _checkPluginDeprecated(pluginName, marketplace);

          plugins.add(InstalledPlugin(
            name: key,
            scope: marketplace,
            version: item['version'] ?? 'unknown',
            installPath: item['installPath'] ?? '',
            installedAt:
                DateTime.tryParse(item['installedAt'] ?? '') ?? DateTime.now(),
            lastUpdated:
                DateTime.tryParse(item['lastUpdated'] ?? '') ?? DateTime.now(),
            isEnabled: isEnabled,
            isDeprecated: isDeprecated,
          ));
        }
      }

      // 按安装时间倒序排列（最新安装的排前面）
      plugins.sort((a, b) => b.installedAt.compareTo(a.installedAt));
      return plugins;
    } catch (e) {
      return [];
    }
  }

  /// 检测插件是否已被官方废弃
  /// 检查 marketplace.json 中的 source 目录是否存在
  Future<bool> _checkPluginDeprecated(String pluginName, String marketplace) async {
    try {
      // 路径: ~/.claude/plugins/marketplaces/{marketplace}/.claude-plugin/marketplace.json
      final marketplacesPath = PlatformUtils.joinPath(_home, '.claude', 'plugins', 'marketplaces', marketplace);
      final marketplaceJsonPath = PlatformUtils.joinPath(marketplacesPath, '.claude-plugin', 'marketplace.json');

      final marketplaceJsonFile = File(marketplaceJsonPath);
      if (!await marketplaceJsonFile.exists()) {
        // marketplace.json 不存在，无法判断，认为未废弃
        return false;
      }

      final content = await marketplaceJsonFile.readAsString();
      final json = jsonDecode(content);
      final plugins = json['plugins'] as List<dynamic>? ?? [];

      // 查找该插件的配置
      for (final plugin in plugins) {
        if (plugin is Map<String, dynamic> && plugin['name'] == pluginName) {
          final source = plugin['source'] as String?;
          if (source != null) {
            // 检查 source 目录是否存在
            // source 是相对于 marketplace 根目录的路径（与 .claude-plugin 同级）
            // 例如: ./plugins/feature-dev -> ~/.claude/plugins/marketplaces/{marketplace}/plugins/feature-dev
            final sourcePath = PlatformUtils.joinPath(marketplacesPath, source.replaceFirst('./', ''));
            final sourceDir = Directory(sourcePath);
            if (!await sourceDir.exists()) {
              // 源目录不存在，插件已废弃
              return true;
            }
          }
          return false;
        }
      }

      // 在 marketplace.json 中找不到该插件，可能已被移除
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 强力删除废弃插件
  /// 使用 Claude CLI 命令卸载插件，然后手动清理确保删除成功
  /// 返回: (成功, 错误信息)
  Future<(bool, String?)> forceDeleteDeprecatedPlugin(InstalledPlugin plugin) async {
    try {
      final parts = plugin.name.split('@');
      final pluginName = parts[0];
      final marketplace = parts.length > 1 ? parts[1] : '';

      // 1. 先用 Claude CLI 卸载（忽略结果，后续会手动清理）
      await Process.run(
        'claude',
        ['plugin', 'uninstall', plugin.name, '--scope', 'user'],
        runInShell: true,
      );

      // 2. 无论 CLI 是否成功，都尝试手动清理
      // 删除 cache 目录
      final cacheBasePath = PlatformUtils.joinPath(_home, '.claude', 'plugins', 'cache', marketplace);
      final cachePath = PlatformUtils.joinPath(cacheBasePath, pluginName);
      final cacheDir = Directory(cachePath);
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }

      // 3. 重试机制：多次尝试删除 JSON 条目
      // 因为运行中的 Claude CLI 可能会重新写入
      final pluginsFilePath = PlatformUtils.joinPath(_home, '.claude', 'plugins', 'installed_plugins.json');
      final pluginsFile = File(pluginsFilePath);

      bool jsonCleanedSuccessfully = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        if (await pluginsFile.exists()) {
          final content = await pluginsFile.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;
          final pluginsMap = json['plugins'] as Map<String, dynamic>? ?? {};

          if (pluginsMap.containsKey(plugin.name)) {
            pluginsMap.remove(plugin.name);
            json['plugins'] = pluginsMap;

            await pluginsFile.writeAsString(
              const JsonEncoder.withIndent('  ').convert(json),
            );

            // 等待一小段时间，检查是否被重写
            await Future.delayed(const Duration(milliseconds: 200));

            // 验证是否真的删除了
            final verifyContent = await pluginsFile.readAsString();
            final verifyJson = jsonDecode(verifyContent) as Map<String, dynamic>;
            final verifyPlugins = verifyJson['plugins'] as Map<String, dynamic>? ?? {};

            if (!verifyPlugins.containsKey(plugin.name)) {
              jsonCleanedSuccessfully = true;
              break;
            }
          } else {
            jsonCleanedSuccessfully = true;
            break;
          }
        }
      }

      if (!jsonCleanedSuccessfully) {
        return (false, 'claude_cli_conflict');
      }

      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  /// 加载市场列表
  Future<List<InstalledMarketplace>> loadMarketplaces() async {
    final marketplaces = <InstalledMarketplace>[];
    final knownMarketplacesFile =
        File(PlatformUtils.joinPath(_home, '.claude', 'plugins', 'known_marketplaces.json'));

    try {
      if (await knownMarketplacesFile.exists()) {
        // 优先从 known_marketplaces.json 读取详细信息
        final content = await knownMarketplacesFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;

        for (final entry in json.entries) {
          final name = entry.key;
          final value = entry.value;
          if (value is Map<String, dynamic>) {
            final source = value['source'] as Map<String, dynamic>? ?? {};
            final installLocation = value['installLocation'] ??
                PlatformUtils.joinPath(_home, '.claude', 'plugins', 'marketplaces', name);
            // 检查 README.md 是否存在
            final hasReadme =
                await File(PlatformUtils.joinPath(installLocation, 'README.md')).exists();
            marketplaces.add(InstalledMarketplace(
              name: name,
              source: source['source'] ?? 'github',
              repo: source['repo'] ?? '',
              installLocation: installLocation,
              lastUpdated:
                  DateTime.tryParse(value['lastUpdated'] ?? '') ?? DateTime.now(),
              hasReadme: hasReadme,
            ));
          }
        }
      } else {
        // 兼容：如果 known_marketplaces.json 不存在，则从目录读取
        final marketplacesDir =
            Directory(PlatformUtils.joinPath(_home, '.claude', 'plugins', 'marketplaces'));
        if (await marketplacesDir.exists()) {
          final entities = await marketplacesDir.list().toList();
          final names = entities
              .whereType<Directory>()
              .map((e) => PlatformUtils.basename(e.path))
              .where((name) => !name.startsWith('.'))
              .toList();

          for (final name in names) {
            final installLocation = PlatformUtils.joinPath(_home, '.claude', 'plugins', 'marketplaces', name);
            final hasReadme =
                await File(PlatformUtils.joinPath(installLocation, 'README.md')).exists();
            marketplaces.add(InstalledMarketplace(
              name: name,
              source: 'github',
              repo: '', // 无法获取
              installLocation: installLocation,
              lastUpdated: DateTime.now(),
              hasReadme: hasReadme,
            ));
          }
        }
      }

      // 保持 JSON 文件中的原始顺序
      return marketplaces;
    } catch (e) {
      return [];
    }
  }

  /// 加载社区 Skills
  Future<List<CommunitySkill>> loadCommunitySkills() async {
    final communitySkills = <CommunitySkill>[];
    final skillsDir = Directory(PlatformUtils.joinPath(_home, '.claude', 'skills'));

    try {
      if (await skillsDir.exists()) {
        final entities = await skillsDir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final dirName = PlatformUtils.basename(entity.path);
            if (dirName.startsWith('.')) continue;

            // 检查是否有 SKILL.md
            final skillMdFile = File(PlatformUtils.joinPath(entity.path, 'SKILL.md'));
            final hasSkillMd = await skillMdFile.exists();

            String? description;
            if (hasSkillMd) {
              try {
                final content = await skillMdFile.readAsString();
                description = parseSkillDescription(content);
              } catch (_) {}
            }

            communitySkills.add(CommunitySkill(
              name: dirName,
              path: entity.path,
              description: description,
              hasSkillMd: hasSkillMd,
            ));
          }
        }
      }

      communitySkills.sort((a, b) => a.name.compareTo(b.name));
      return communitySkills;
    } catch (e) {
      return [];
    }
  }

  /// 解析 SKILL.md 中的描述
  String? parseSkillDescription(String content) {
    // 尝试解析 description: xxx
    final descMatch =
        RegExp(r'^description:\s*(.+)$', multiLine: true).firstMatch(content);
    if (descMatch != null) {
      return descMatch.group(1)?.trim();
    }
    // 尝试从第一段获取描述
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          !trimmed.startsWith('name:')) {
        return trimmed.length > 80 ? '${trimmed.substring(0, 80)}...' : trimmed;
      }
    }
    return null;
  }

  /// 格式化日期
  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 扫描所有斜线指令（skills + commands）
  /// 包括本地插件和社区 Skills
  Future<List<SlashCommand>> scanSlashCommands(List<InstalledPlugin> plugins) async {
    final commands = <SlashCommand>[];

    // 1. 扫描本地插件的 skills 和 commands
    for (final plugin in plugins) {
      if (!plugin.isEnabled || plugin.isDeprecated) continue;

      final pluginPath = plugin.installPath;
      final parts = plugin.name.split('@');
      final pluginName = parts[0];

      // 扫描 skills 目录
      final skillsDir = Directory(PlatformUtils.joinPath(pluginPath, 'skills'));
      if (await skillsDir.exists()) {
        final skillCommands = await _scanSkillsDirectory(
          skillsDir,
          pluginName,
          SlashCommandSource.plugin,
        );
        commands.addAll(skillCommands);
      }

      // 扫描 commands 目录
      final commandsDir = Directory(PlatformUtils.joinPath(pluginPath, 'commands'));
      if (await commandsDir.exists()) {
        final cmdCommands = await _scanCommandsDirectory(
          commandsDir,
          pluginName,
          SlashCommandSource.plugin,
        );
        commands.addAll(cmdCommands);
      }
    }

    // 2. 扫描社区 Skills (~/.claude/skills)
    final communitySkillsDir = Directory(PlatformUtils.joinPath(_home, '.claude', 'skills'));
    if (await communitySkillsDir.exists()) {
      final entities = await communitySkillsDir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final dirName = PlatformUtils.basename(entity.path);
          if (dirName.startsWith('.')) continue;

          // 检查 SKILL.md
          final skillMdFile = File(PlatformUtils.joinPath(entity.path, 'SKILL.md'));
          if (await skillMdFile.exists()) {
            String? description;
            try {
              final content = await skillMdFile.readAsString();
              description = parseSkillDescription(content);
            } catch (_) {}

            commands.add(SlashCommand(
              command: dirName,
              pluginName: dirName,
              name: dirName,
              description: description,
              type: SlashCommandType.skill,
              source: SlashCommandSource.community,
              filePath: skillMdFile.path,
            ));
          }
        }
      }
    }

    // 按指令名排序
    commands.sort((a, b) => a.command.compareTo(b.command));
    return commands;
  }

  /// 扫描 skills 目录
  Future<List<SlashCommand>> _scanSkillsDirectory(
    Directory dir,
    String pluginName,
    SlashCommandSource source,
  ) async {
    final commands = <SlashCommand>[];

    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final skillName = PlatformUtils.basename(entity.path);
          if (skillName.startsWith('.')) continue;

          // 检查 SKILL.md
          final skillMdFile = File(PlatformUtils.joinPath(entity.path, 'SKILL.md'));
          if (await skillMdFile.exists()) {
            String? description;
            try {
              final content = await skillMdFile.readAsString();
              description = parseSkillDescription(content);
            } catch (_) {}

            commands.add(SlashCommand(
              command: skillName,  // skills 直接用名称，不需要前缀
              pluginName: pluginName,
              name: skillName,
              description: description,
              type: SlashCommandType.skill,
              source: source,
              filePath: skillMdFile.path,
            ));
          }
        }
      }
    } catch (_) {}

    return commands;
  }

  /// 扫描 commands 目录（支持嵌套子目录）
  Future<List<SlashCommand>> _scanCommandsDirectory(
    Directory dir,
    String pluginName,
    SlashCommandSource source, {
    String prefix = '',
  }) async {
    final commands = <SlashCommand>[];

    try {
      final entities = await dir.list().toList();
      for (final entity in entities) {
        final name = PlatformUtils.basename(entity.path);
        if (name.startsWith('.')) continue;

        if (entity is File && name.endsWith('.md')) {
          // 解析 .md 文件
          final cmdName = name.replaceAll('.md', '');
          final fullName = prefix.isEmpty ? cmdName : '$prefix/$cmdName';

          String? description;
          try {
            final content = await entity.readAsString();
            description = _parseCommandDescription(content);
          } catch (_) {}

          commands.add(SlashCommand(
            command: '$pluginName:$fullName',
            pluginName: pluginName,
            name: fullName,
            description: description,
            type: SlashCommandType.command,
            source: source,
            filePath: entity.path,
          ));
        } else if (entity is Directory) {
          // 递归扫描子目录
          final subCommands = await _scanCommandsDirectory(
            entity,
            pluginName,
            source,
            prefix: prefix.isEmpty ? name : '$prefix/$name',
          );
          commands.addAll(subCommands);
        }
      }
    } catch (_) {}

    return commands;
  }

  /// 解析 command .md 文件中的描述
  String? _parseCommandDescription(String content) {
    // 解析 YAML frontmatter 中的 description
    final frontmatterMatch = RegExp(r'^---\s*\n([\s\S]*?)\n---', multiLine: true).firstMatch(content);
    if (frontmatterMatch != null) {
      final frontmatter = frontmatterMatch.group(1) ?? '';
      // 匹配 description: 后面的内容（可能有引号包裹）
      final descMatch = RegExp(r'^description:\s*"?([^"\n]+)"?\s*$', multiLine: true).firstMatch(frontmatter);
      if (descMatch != null) {
        return descMatch.group(1)?.trim();
      }
    }
    return null;
  }
}
