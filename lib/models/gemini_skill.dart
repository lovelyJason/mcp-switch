/// 本地已安装的 Gemini Skill（来自 ~/.gemini/skills/）
class GeminiSkill {
  final String name;
  final String path;
  final String? description;
  final bool hasSkillMd;

  GeminiSkill({
    required this.name,
    required this.path,
    this.description,
    this.hasSkillMd = false,
  });
}

/// 本地已安装的 Gemini Extension（来自 ~/.gemini/extensions/）
class GeminiExtension {
  final String name;
  final String path;
  final String? description;
  final String? version;
  final bool hasReadme;

  GeminiExtension({
    required this.name,
    required this.path,
    this.description,
    this.version,
    this.hasReadme = false,
  });

  /// 获取卸载命令
  String get uninstallCommand => 'gemini extension uninstall $name';
}

/// 社区 Extension（来自 GitHub 或官方 Gallery）
class CommunityGeminiExtension {
  final String name;
  final String? description;
  final String? author;
  final String? version;
  final String? githubUrl;
  final String source; // 'github' or 'gallery'

  CommunityGeminiExtension({
    required this.name,
    this.description,
    this.author,
    this.version,
    this.githubUrl,
    this.source = 'github',
  });

  /// 获取安装命令
  String get installCommand {
    if (githubUrl != null && githubUrl!.isNotEmpty) {
      return 'gemini extension install $githubUrl';
    }
    // fallback 到 name，但实际上 Gemini CLI 需要完整 URL
    return 'gemini extension install https://github.com/gemini-cli-extensions/$name';
  }

  /// 是否来自官方 Gallery
  bool get isFromGallery => source == 'gallery';
}
