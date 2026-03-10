/// Claude Code settings.json 支持的配置键定义
/// 参考: https://code.claude.com/docs/en/settings
class ClaudeConfigSchema {
  ClaudeConfigSchema._();

  /// 根层级支持的键 → (类型, 预设值列表, 描述)
  /// 已被表单管理的键（model, env 内的 token/url 等）由调用方过滤
  static const Map<String, ConfigKeyDef> rootKeys = {
    'model': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '默认使用的 Claude 模型',
      presets: ['claude-sonnet-4-6', 'claude-sonnet-4-5', 'claude-opus-4', 'claude-haiku-3-5'],
    ),
    'language': ConfigKeyDef(
      type: ConfigValueType.string,
      description: 'Claude 回复所使用的语言',
      presets: ['chinese', 'english', 'japanese', 'korean', 'french', 'german', 'spanish'],
    ),
    'outputStyle': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '输出风格：详细解释、简洁、正式或冗长',
      presets: ['Explanatory', 'Concise', 'Formal', 'Verbose'],
    ),
    'cleanupPeriodDays': ConfigKeyDef(
      type: ConfigValueType.number,
      description: '自动清理过期对话的天数',
      presets: ['30', '7', '14', '60', '90'],
    ),
    'includeCoAuthoredBy': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '在 Git 提交中添加 Co-authored-by 标记',
    ),
    'includeGitInstructions': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '在上下文中包含 Git 操作指引',
    ),
    'alwaysThinkingEnabled': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '始终启用扩展思考（extended thinking）',
    ),
    'respectGitignore': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '遵循 .gitignore 规则，不读取被忽略的文件',
    ),
    'enableAllProjectMcpServers': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '自动启用项目配置的所有 MCP 服务器',
    ),
    'showTurnDuration': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '显示每次对话轮次的耗时',
    ),
    'spinnerTipsEnabled': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '等待响应时显示提示信息',
    ),
    'terminalProgressBarEnabled': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '在终端中显示进度条',
    ),
    'prefersReducedMotion': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '减少动画效果，适合对运动敏感的用户',
    ),
    'fastModePerSessionOptIn': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '每次会话单独确认是否启用快速模式',
    ),
    'disableAllHooks': ConfigKeyDef(
      type: ConfigValueType.boolean,
      description: '禁用所有 Hook（PreToolUse / PostToolUse 等）',
    ),
    'autoUpdatesChannel': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '自动更新频道：stable 稳定版 / latest 最新版',
      presets: ['stable', 'latest'],
    ),
    'teammateMode': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '多人协作模式：自动 / 进程内 / tmux',
      presets: ['auto', 'in-process', 'tmux'],
    ),
    'apiKeyHelper': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '自定义获取 API Key 的脚本路径',
    ),
    'plansDirectory': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '存储计划文件的目录路径',
      presets: ['~/.claude/plans', './plans'],
    ),
    'forceLoginMethod': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '强制指定登录方式：claudeai 或 console',
      presets: ['claudeai', 'console'],
    ),
  };

  /// env 层级支持的键 → (类型, 预设值列表, 描述)
  static const Map<String, ConfigKeyDef> envKeys = {
    'ANTHROPIC_AUTH_TOKEN': ConfigKeyDef(
      type: ConfigValueType.string,
      description: 'Anthropic API 认证令牌',
    ),
    'ANTHROPIC_BASE_URL': ConfigKeyDef(
      type: ConfigValueType.string,
      description: 'API 请求的基础 URL，用于代理或自建服务',
    ),
    'CLAUDE_CODE_MAX__OUTPUT_TOKENS': ConfigKeyDef(
      type: ConfigValueType.number,
      description: '单次响应的最大输出 Token 数',
      presets: ['16384', '32768', '64000', '128000'],
    ),
    'MAX_THINKING_TOKENS': ConfigKeyDef(
      type: ConfigValueType.number,
      description: '扩展思考的最大 Token 数',
      presets: ['10000', '31999', '50000'],
    ),
    'CLAUDE_CODE_ENABLE_TELEMETRY': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '启用遥测数据上报（1 启用 / 0 禁用）',
      presets: ['0', '1'],
    ),
    'OTEL_METRICS_EXPORTER': ConfigKeyDef(
      type: ConfigValueType.string,
      description: 'OpenTelemetry 指标导出方式',
      presets: ['otlp', 'console', 'none'],
    ),
    'CLAUDE_CODE_USE_BEDROCK': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '使用 AWS Bedrock 作为后端（1 启用 / 0 禁用）',
      presets: ['0', '1'],
    ),
    'CLAUDE_CODE_USE_VERTEX': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '使用 Google Vertex AI 作为后端（1 启用 / 0 禁用）',
      presets: ['0', '1'],
    ),
    'ANTHROPIC_MODEL': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '通过环境变量覆盖默认模型',
    ),
    'HTTP_PROXY': ConfigKeyDef(
      type: ConfigValueType.string,
      description: 'HTTP 代理地址，如 http://127.0.0.1:7890',
    ),
    'HTTPS_PROXY': ConfigKeyDef(
      type: ConfigValueType.string,
      description: 'HTTPS 代理地址，如 http://127.0.0.1:7890',
    ),
    'DISABLE_PROMPT_CACHING': ConfigKeyDef(
      type: ConfigValueType.string,
      description: '禁用 Prompt 缓存（1 禁用 / 0 启用）',
      presets: ['0', '1'],
    ),
  };

  /// 被表单直接管理的 root 键，结构化编辑中显示但标记为"由表单管理"
  static const formManagedRootKeys = {'model'};

  /// 被表单直接管理的 env 键
  static const formManagedEnvKeys = {
    'ANTHROPIC_AUTH_TOKEN',
    'ANTHROPIC_BASE_URL',
    'CLAUDE_CODE_MAX__OUTPUT_TOKENS',
    'MAX_THINKING_TOKENS',
  };
}

enum ConfigValueType { string, number, boolean }

class ConfigKeyDef {
  final ConfigValueType type;
  final List<String> presets;
  final String description;

  const ConfigKeyDef({
    required this.type,
    this.presets = const [],
    this.description = '',
  });

  String get defaultValue {
    if (presets.isNotEmpty) return presets.first;
    switch (type) {
      case ConfigValueType.boolean:
        return 'true';
      case ConfigValueType.number:
        return '0';
      case ConfigValueType.string:
        return '';
    }
  }
}
