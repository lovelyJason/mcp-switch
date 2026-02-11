import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/codex_skill.dart';
import '../utils/platform_utils.dart';

/// Codex Skills 数据服务
/// 负责：本地 Skills 扫描、GitHub 精选 Skills 获取
class CodexSkillsService {
  /// 获取用户目录（跨平台）
  String get _home => PlatformUtils.userHome;

  static const _curatedCacheKey = 'codex_curated_skills_cache';

  /// 内存缓存精选 Skills
  static List<CuratedCodexSkill>? _cachedCuratedSkills;
  static DateTime? _lastCuratedFetch;

  /// 加载本地 Skills（扫描 ~/.codex/skills/ 和 ~/.codex/skills/.system/）
  Future<List<CodexSkill>> loadLocalSkills() async {
    final skills = <CodexSkill>[];
    final skillsDir = Directory(
      PlatformUtils.joinPath(_home, '.codex', 'skills'),
    );

    try {
      if (await skillsDir.exists()) {
        await _scanSkillsDir(skillsDir, skills, isSystem: false);

        // 扫描系统内置 Skills（.system 目录）
        final systemDir = Directory(
          PlatformUtils.joinPath(skillsDir.path, '.system'),
        );
        if (await systemDir.exists()) {
          await _scanSkillsDir(systemDir, skills, isSystem: true);
        }
      }

      // 系统 Skills 排前面，各自按名称排序
      skills.sort((a, b) {
        if (a.isSystem != b.isSystem) return a.isSystem ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      return skills;
    } catch (e) {
      return [];
    }
  }

  /// 扫描指定目录下的 Skills
  Future<void> _scanSkillsDir(
    Directory dir,
    List<CodexSkill> skills, {
    required bool isSystem,
  }) async {
    final entities = await dir.list().toList();
    for (final entity in entities) {
      if (entity is Directory) {
        final dirName = PlatformUtils.basename(entity.path);
        if (dirName.startsWith('.')) continue;

        final skillMdFile = File(
          PlatformUtils.joinPath(entity.path, 'SKILL.md'),
        );
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
          isSystem: isSystem,
        ));
      }
    }
  }

  /// 获取精选 Skills（优先内存缓存 → 网络请求 → SharedPreferences 兜底）
  Future<List<CuratedCodexSkill>> loadCuratedSkills({
    bool forceRefresh = false,
  }) async {
    // 非强制刷新时，检查内存缓存（5分钟有效）
    if (!forceRefresh &&
        _cachedCuratedSkills != null &&
        _lastCuratedFetch != null) {
      final elapsed = DateTime.now().difference(_lastCuratedFetch!);
      if (elapsed.inMinutes < 5) {
        return _cachedCuratedSkills!;
      }
    }

    // 尝试从网络获取
    try {
      final skills = <CuratedCodexSkill>[];
      final curatedSkills = await _fetchGitHubFolder('.curated');
      skills.addAll(curatedSkills);
      final experimentalSkills = await _fetchGitHubFolder('.experimental');
      skills.addAll(experimentalSkills);

      // 写入内存缓存
      _cachedCuratedSkills = skills;
      _lastCuratedFetch = DateTime.now();

      // 写入 SharedPreferences 持久化
      await _saveCuratedToPrefs(skills);

      return skills;
    } catch (_) {
      // 网络失败：先看内存缓存
      if (_cachedCuratedSkills != null) return _cachedCuratedSkills!;
      // 再看 SharedPreferences
      return _loadCuratedFromPrefs();
    }
  }

  /// 持久化精选 Skills 到 SharedPreferences
  Future<void> _saveCuratedToPrefs(List<CuratedCodexSkill> skills) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = skills
          .map((s) => {'name': s.name, 'folder': s.folder})
          .toList();
      await prefs.setString(_curatedCacheKey, jsonEncode(list));
    } catch (_) {}
  }

  /// 从 SharedPreferences 读取精选 Skills 缓存
  Future<List<CuratedCodexSkill>> _loadCuratedFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_curatedCacheKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      final skills = list
          .map((e) => CuratedCodexSkill(
                name: e['name'] as String,
                folder: e['folder'] as String,
              ))
          .toList();
      // 回填内存缓存
      _cachedCuratedSkills = skills;
      _lastCuratedFetch = DateTime.now();
      return skills;
    } catch (_) {
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

  /// 清除内存缓存（SharedPreferences 保留作为兜底）
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
