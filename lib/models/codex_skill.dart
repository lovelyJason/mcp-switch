/// 本地已安装的 Codex Skill（来自 ~/.codex/skills/）
class CodexSkill {
  final String name;
  final String path;
  final String? description;
  final bool hasSkillMd;

  CodexSkill({
    required this.name,
    required this.path,
    this.description,
    this.hasSkillMd = false,
  });
}

/// 精选 Skill（来自 GitHub openai/skills 仓库）
class CuratedCodexSkill {
  final String name;
  final String folder; // .curated 或 .experimental
  final String? description;

  CuratedCodexSkill({
    required this.name,
    required this.folder,
    this.description,
  });

  /// 是否为精选（非实验性）
  bool get isCurated => folder == '.curated';

  /// 是否为实验性
  bool get isExperimental => folder == '.experimental';

  /// 获取安装命令
  String get installCommand => '\$skill-installer $name';

  /// 获取 GitHub URL
  String get githubUrl =>
      'https://github.com/openai/skills/tree/main/skills/$folder/$name';
}
