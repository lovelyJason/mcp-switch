import 'dart:io';
import 'package:flutter/material.dart';
import '../models/antigravity_skill.dart';
import '../utils/platform_utils.dart';

/// Antigravity Skills 管理服务
class AntigravitySkillsService extends ChangeNotifier {
  List<AntigravitySkill> _globalSkills = [];
  List<AntigravitySkill> _workspaceSkills = [];

  List<AntigravitySkill> get globalSkills => _globalSkills;
  List<AntigravitySkill> get workspaceSkills => _workspaceSkills;

  /// 全局 Skills 目录路径
  String get globalSkillsPath => '${PlatformUtils.userHome}/.gemini/antigravity/skills';

  /// 加载全局 Skills
  Future<List<AntigravitySkill>> loadGlobalSkills() async {
    _globalSkills = await _loadSkillsFromPath(globalSkillsPath, SkillScope.global);
    notifyListeners();
    return _globalSkills;
  }

  /// 加载工作区 Skills
  Future<List<AntigravitySkill>> loadWorkspaceSkills(String workspacePath) async {
    final skillsPath = '$workspacePath/.agent/skills';
    _workspaceSkills = await _loadSkillsFromPath(skillsPath, SkillScope.workspace);
    notifyListeners();
    return _workspaceSkills;
  }

  /// 从指定路径加载 Skills
  Future<List<AntigravitySkill>> _loadSkillsFromPath(String path, SkillScope scope) async {
    final skills = <AntigravitySkill>[];
    final dir = Directory(path);

    if (!await dir.exists()) {
      return skills;
    }

    try {
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final skillName = entity.path.split(Platform.pathSeparator).last;

          // 跳过隐藏文件夹
          if (skillName.startsWith('.')) continue;

          // 检查是否有 SKILL.md
          final skillMdFile = File('${entity.path}/SKILL.md');
          final hasSkillMd = await skillMdFile.exists();

          // 尝试读取描述
          String? description;
          if (hasSkillMd) {
            try {
              final content = await skillMdFile.readAsString();
              // 提取第一行作为描述（通常是 # 标题）
              final lines = content.split('\n');
              for (final line in lines) {
                final trimmed = line.trim();
                if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
                  description = trimmed.length > 100
                      ? '${trimmed.substring(0, 100)}...'
                      : trimmed;
                  break;
                }
              }
            } catch (e) {
              debugPrint('Error reading SKILL.md: $e');
            }
          }

          skills.add(AntigravitySkill(
            name: skillName,
            path: entity.path,
            description: description,
            hasSkillMd: hasSkillMd,
            scope: scope,
          ));
        }
      }
    } catch (e) {
      debugPrint('Error loading skills from $path: $e');
    }

    // 按名称排序
    skills.sort((a, b) => a.name.compareTo(b.name));
    return skills;
  }

  /// 清除缓存
  void clearCache() {
    _globalSkills = [];
    _workspaceSkills = [];
    notifyListeners();
  }
}
