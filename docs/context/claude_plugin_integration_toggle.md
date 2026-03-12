# Claude Code 插件联动开关说明

## 目标

在设置页 `通用` 面板提供一个开关：`应用到 Claude Code 插件`。  
该开关用于让外部 Claude Code 插件侧的供应商选择，跟随 MCP Switch 的 Claude 供应商切换结果。

## UI 位置

- 文件：`lib/ui/pages/settings/settings_screen.dart`
- 文案键：
  - `enable_claude_plugin_integration`
  - `enable_claude_plugin_integration_desc`
- 状态来源：`ConfigService.enableClaudePluginIntegration`

## 持久化与配置文件影响

### 1) 本地持久化（开关本身）

- 文件：SharedPreferences
- 键名：`enable_claude_plugin_integration`
- 作用：记录开关是否开启

### 2) 对 Claude 配置文件的影响

该开关联动的是：

- `~/.claude/config.json`
- 字段：`primaryApiKey`

写入规则：

- 非官方供应商模式：写入 `"primaryApiKey": "any"`
- 官方供应商模式或关闭联动：删除 `primaryApiKey`
- 其他已有字段保持不变（保留合并）

注意：该开关不会直接写入 `~/.claude/settings.json`。  
`settings.json` 仍由 Claude 供应商切换逻辑负责（`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_BASE_URL`、`model` 等）。

## 触发时机

### 1) 用户手动切换开关

- 入口：`ConfigService.setEnableClaudePluginIntegration(bool)`
- 开启时：立即执行 `writeManagedConfig()`，确保 `config.json` 有 `primaryApiKey: "any"`
- 关闭时：立即执行 `clearPrimaryApiKey()`，移除该字段

### 2) Claude 供应商切换时（仅开关开启后）

- 入口：`ProviderSwitchService._writeConfigFile()` / `_clearConfigFile()`
- 逻辑：
  - 切到 Claude 非官方供应商：写入 `primaryApiKey: "any"`
  - 切到 Claude 官方供应商：删除 `primaryApiKey`
  - 取消 Claude 激活：删除 `primaryApiKey`

## 为什么你可能看到 `~/.claude/config.json` 没变化

常见原因：

1. 开关未开启（`enable_claude_plugin_integration = false`）
2. 文件内容本来已是目标状态（例如已经是 `"any"`，再次写入会跳过）
3. 当前操作不是 Claude 供应商切换（切 Codex/Gemini 不触发该文件）
4. 写入异常被保护性捕获，只打印日志，不阻断主流程

## 实现文件清单

- `lib/services/claude_plugin_integration_service.dart`
- `lib/services/config/config_service.dart`
- `lib/services/provider_switch_service.dart`
- `lib/ui/pages/settings/settings_screen.dart`
- `lib/l10n/locales/zh.json`
- `lib/l10n/locales/en.json`
