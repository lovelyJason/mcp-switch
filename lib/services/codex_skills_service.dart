import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/codex_skill.dart';
import '../utils/platform_utils.dart';

/// Codex Skills 数据服务
/// 负责：本地 Skills 扫描、GitHub 精选 Skills 获取
class CodexSkillsService {
  /// 获取用户目录（跨平台）
  String get _home => PlatformUtils.userHome;

  /// 缓存精选 Skills
  static List<CuratedCodexSkill>? _cachedCuratedSkills;
  static DateTime? _lastCuratedFetch;

  /// 加载本地 Skills（扫描 ~/.codex/skills/）
  Future<List<CodexSkill>> loadLocalSkills() async {
    final skills = <CodexSkill>[];
    final skillsDir = Directory(PlatformUtils.joinPath(_home, '.codex', 'skills'));

    try {
      if (await skillsDir.exists()) {
        final entities = await skillsDir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final dirName = PlatformUtils.basename(entity.path);
            // 跳过隐藏目录和特殊目录
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

            skills.add(CodexSkill(
              name: dirName,
              path: entity.path,
              description: description,
              hasSkillMd: hasSkillMd,
            ));
          }
        }
      }

      skills.sort((a, b) => a.name.compareTo(b.name));
      return skills;
    } catch (e) {
      return [];
    }
  }

  /// 获取精选 Skills（从 GitHub API）
  /// 缓存 5 分钟
  Future<List<CuratedCodexSkill>> loadCuratedSkills() async {
    // 检查缓存
    if (_cachedCuratedSkills != null && _lastCuratedFetch != null) {
      final elapsed = DateTime.now().difference(_lastCuratedFetch!);
      if (elapsed.inMinutes < 5) {
        return _cachedCuratedSkills!;
      }
    }

    final skills = <CuratedCodexSkill>[];

    try {
      // 获取 .curated 目录
      final curatedSkills = await _fetchGitHubFolder('.curated');
      skills.addAll(curatedSkills);

      // 获取 .experimental 目录
      final experimentalSkills = await _fetchGitHubFolder('.experimental');
      skills.addAll(experimentalSkills);

      // 缓存结果
      _cachedCuratedSkills = skills;
      _lastCuratedFetch = DateTime.now();

      return skills;
    } catch (e) {
      // 如果有缓存，返回缓存
      if (_cachedCuratedSkills != null) {
        return _cachedCuratedSkills!;
      }
      return [];
    }
  }

  /// 从 GitHub API 获取指定目录下的 Skills
  Future<List<CuratedCodexSkill>> _fetchGitHubFolder(String folder) async {
    final skills = <CuratedCodexSkill>[];

    try {
      final url = 'https://api.github.com/repos/openai/skills/contents/skills/$folder';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> items = jsonDecode(response.body);
        for (final item in items) {
          if (item['type'] == 'dir') {
            final name = item['name'] as String;
            // 跳过隐藏目录
            if (name.startsWith('.')) continue;

            skills.add(CuratedCodexSkill(
              name: name,
              folder: folder,
              description: null, // GitHub API 不返回描述，需要单独获取 SKILL.md
            ));
          }
        }
      }
    } catch (_) {
      // 网络错误，返回空列表
    }

    return skills;
  }

  /// 清除缓存
  void clearCache() {
    _cachedCuratedSkills = null;
    _lastCuratedFetch = null;
  }

  /// 解析 SKILL.md 中的描述
  String? parseSkillDescription(String content) {
    // 尝试解析 frontmatter 中的 description
    final descMatch = RegExp(r'^description:\s*(.+)$', multiLine: true).firstMatch(content);
    if (descMatch != null) {
      return descMatch.group(1)?.trim();
    }
    // 尝试从第一段获取描述
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          !trimmed.startsWith('name:') &&
          !trimmed.startsWith('---')) {
        return trimmed.length > 100 ? '${trimmed.substring(0, 100)}...' : trimmed;
      }
    }
    return null;
  }

  /// 格式化日期
  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
