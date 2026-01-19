/// 本地已安装的 Antigravity Skill
class AntigravitySkill {
  final String name;
  final String path;
  final String? description;
  final bool hasSkillMd;
  final SkillScope scope;

  AntigravitySkill({
    required this.name,
    required this.path,
    this.description,
    this.hasSkillMd = false,
    required this.scope,
  });
}

/// Skill 作用域
enum SkillScope {
  /// 全局 Skills (~/.gemini/antigravity/skills/)
  global,
  /// 工作区 Skills (<workspace>/.agent/skills/)
  workspace,
}
