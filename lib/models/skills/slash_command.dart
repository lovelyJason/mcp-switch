/// 斜线指令类型
enum SlashCommandType {
  skill,   // 来自 skills 目录
  command, // 来自 commands 目录
}

/// 斜线指令来源
enum SlashCommandSource {
  plugin,    // 本地插件
  community, // 社区 Skills (~/.claude/skills)
}

/// 斜线指令信息
class SlashCommand {
  /// 完整指令名（如 superpowers:brainstorming）
  final String command;

  /// 插件名或目录名
  final String pluginName;

  /// 指令名（不含插件前缀）
  final String name;

  /// 描述
  final String? description;

  /// 类型
  final SlashCommandType type;

  /// 来源
  final SlashCommandSource source;

  /// 文件路径
  final String filePath;

  SlashCommand({
    required this.command,
    required this.pluginName,
    required this.name,
    this.description,
    required this.type,
    required this.source,
    required this.filePath,
  });

  /// 获取显示用的指令（带斜杠）
  String get displayCommand => '/$command';
}
