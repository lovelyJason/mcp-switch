/// 社区 Skill（来自 ~/.claude/skills/）
class CommunitySkill {
  final String name;
  final String path;
  final String? description;
  final bool hasSkillMd;

  CommunitySkill({
    required this.name,
    required this.path,
    this.description,
    this.hasSkillMd = false,
  });
}
