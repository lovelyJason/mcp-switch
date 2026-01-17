/// 预设的市场信息
class PresetMarketplace {
  final String name;
  final String repo; // GitHub owner/repo 格式
  final String description;
  final bool isOfficial;
  final String? hintKey; // 国际化 hint key
  final String? githubUrl; // GitHub 仓库完整 URL
  final int? fallbackStars; // 备用 star 数（API 失败时显示）

  const PresetMarketplace({
    required this.name,
    required this.repo,
    required this.description,
    required this.isOfficial,
    this.hintKey,
    this.githubUrl,
    this.fallbackStars,
  });

  /// 获取 GitHub API URL 用于获取仓库信息（包括 star 数）
  String get githubApiUrl => 'https://api.github.com/repos/$repo';

  /// 获取 GitHub 仓库 URL
  String get repoUrl => githubUrl ?? 'https://github.com/$repo';
}

/// 预设市场列表
const List<PresetMarketplace> presetMarketplaces = [
  // === 官方 Marketplace ===
  PresetMarketplace(
    name: 'claude-plugins-official',
    repo: 'anthropics/claude-plugins-official',
    description: 'Official Claude plugins',
    isOfficial: true,
    hintKey: 'marketplace_hint_official',
    fallbackStars: 500,
  ),
  PresetMarketplace(
    name: 'anthropic-agent-skills',
    repo: 'anthropics/skills',
    description: 'Agent Skills & Document tools',
    isOfficial: true,
    hintKey: 'marketplace_hint_agent_skills',
    fallbackStars: 800,
  ),
  PresetMarketplace(
    name: 'claude-code-plugins',
    repo: 'anthropics/claude-code',
    description: 'Claude Code built-in plugins',
    isOfficial: true,
    hintKey: 'marketplace_hint_claude_code',
    fallbackStars: 25000,
  ),

  // === 社区高 Star Marketplace ===
  PresetMarketplace(
    name: 'superpowers',
    repo: 'obra/superpowers',
    description: 'Battle-tested skills, commands, hooks and agents',
    isOfficial: false,
    hintKey: 'marketplace_hint_superpowers',
    fallbackStars: 25700,
  ),
  PresetMarketplace(
    name: 'gmickel-claude-marketplace',
    repo: 'gmickel/gmickel-claude-marketplace',
    description: 'Flow-Next workflows, Ralph autonomous mode, multi-model review',
    isOfficial: false,
    hintKey: 'marketplace_hint_gmickel',
    fallbackStars: 358,
  ),
  PresetMarketplace(
    name: 'awesome-claude-code-plugins',
    repo: 'ccplugins/awesome-claude-code-plugins',
    description: 'Curated list of slash commands, subagents, MCP servers',
    isOfficial: false,
    hintKey: 'marketplace_hint_awesome',
    fallbackStars: 343,
  ),
  PresetMarketplace(
    name: 'MadAppGang-claude-code',
    repo: 'MadAppGang/claude-code',
    description: 'Multi-agent coordination and workflow orchestration patterns',
    isOfficial: false,
    hintKey: 'marketplace_hint_madappgang',
    fallbackStars: 200,
  ),
];
