import 'dart:io';
import 'dart:convert';
import '../models/skills/installed_plugin.dart';
import '../models/skills/installed_marketplace.dart';
import '../models/skills/community_skill.dart';
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
      pluginsMap.forEach((key, value) {
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
          final scope =
              parts.length > 1 ? parts[1] : (item['scope'] ?? 'unknown');

          // 获取启用状态，默认为 true
          final isEnabled = enabledPlugins[key] ?? true;

          plugins.add(InstalledPlugin(
            name: key,
            scope: scope,
            version: item['version'] ?? 'unknown',
            installPath: item['installPath'] ?? '',
            installedAt:
                DateTime.tryParse(item['installedAt'] ?? '') ?? DateTime.now(),
            lastUpdated:
                DateTime.tryParse(item['lastUpdated'] ?? '') ?? DateTime.now(),
            isEnabled: isEnabled,
          ));
        }
      });

      return plugins;
    } catch (e) {
      return [];
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
}
