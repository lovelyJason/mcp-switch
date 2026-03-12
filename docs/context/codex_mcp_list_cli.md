# Codex MCP List CLI 集成

## 概述

Codex MCP 列表从 **纯文件解析** 升级为 **文件解析 + CLI 补充** 模式。通过执行 `codex mcp list` 命令获取 Auth 状态等额外信息，同时保持 TOML 文件解析作为主数据源以确保配置完整性。

## 背景

之前 Codex MCP 列表仅通过读取 `~/.codex/config.toml` 文件获取配置，无法得知：
- MCP 是否需要授权登录
- 当前授权状态（已登录/未登录/不支持）

`codex mcp list` 命令输出示例：

```
Name             Command  Args                                   Env  Cwd  Status    Auth
figma-developer  npx      -y figma-developer-mcp ... --stdio     -    -    disabled  Unsupported

Name            Url                        Bearer Token Env Var  Status   Auth
figma-official  https://mcp.figma.com/mcp  -                     enabled  Not logged in
```

## 架构设计

### 为什么不直接用 CLI 替代文件解析？

CLI 输出缺少完整配置数据（如 `env`、`http_headers`、完整 `args` 列表），如果直接用 CLI 结果替代 TOML 解析，在 toggle/save 操作时会丢失这些字段。

**最终方案：TOML 解析为主 + CLI 异步补充 auth 状态**

```
reloadProfiles()
  ├── _parseCodexToml()     → 完整配置数据（command, args, env, headers...）
  └── _enrichCodexAuthStatus() → 异步执行 codex mcp list，仅提取 auth 字段合并
```

### 数据流

1. `reloadProfiles()` 调用 `_parseCodexToml()` 从 `config.toml` 解析完整 MCP 配置
2. 立即异步调用 `_enrichCodexAuthStatus()`
3. `_enrichCodexAuthStatus()` 执行 `codex mcp list`（15 秒超时）
4. 解析 CLI 表格输出，提取 `name → auth` 映射
5. 将 auth 值写入 `profile.content['mcpServers'][name]['auth']`
6. 调用 `notifyListeners()` 触发 UI 刷新

### CLI 表格解析

`codex mcp list` 输出两种表格格式：

| 表格类型 | Header 特征 | 列结构 |
|---------|-----------|--------|
| Stdio | `Name ... Command ...` | Name, Command, Args, Env, Cwd, Status, Auth (index 6) |
| HTTP | `Name ... Url ...` | Name, Url, Bearer Token Env Var, Status, Auth (index 4) |

列分隔检测规则：连续 2 个以上空格视为列分隔，单个空格属于列名的一部分（如 `Bearer Token Env Var` 是一个列名）。

## 涉及文件

| 文件 | 改动 |
|------|------|
| `lib/services/config/config_service.dart` | `_enrichCodexAuthStatus()` — CLI 调用 + auth 合并到 profiles |
| `lib/services/config/codex_config_helper.dart` | `parseAuthFromCli()`、`detectColumnStarts()`、`splitByColumns()` — 纯函数解析 |
| `lib/ui/components/profile_card.dart` | 新增 `onLogin` 回调参数，显示 Auth 状态标签和登录图标 |
| `lib/ui/pages/mcp_config/config_list_screen.dart` | Codex ProfileCard 传入 `onLogin`，新增 `_openCodexMcpLogin()` |

## UI 交互

### Auth 状态标签

在 ProfileCard 名称右侧显示 auth 状态：

| Auth 值 | 显示 | 颜色 |
|---------|------|------|
| `Not logged in` | "Need Auth" + 登录图标 | 橙色 |
| `Unsupported` | 不显示 | - |
| 其他（如 `Logged in`） | 显示原文 | 绿色 |

### 登录操作

点击登录图标 → 打开侧边终端面板 → 自动执行 `codex mcp login <name>`

```dart
void _openCodexMcpLogin(String mcpName) {
  final terminalService = Provider.of<TerminalService>(context, listen: false);
  terminalService.setFloatingTerminal(true);
  terminalService.openTerminalPanel();
  Future.delayed(const Duration(milliseconds: 500), () {
    terminalService.sendCommand('codex mcp login $mcpName');
  });
}
```

## 相关文档

- `docs/context/codex_mcp_tools_query.md`：Codex MCP tools 查询设计，说明为什么 tools 需要走 `codex app-server` + `mcpServerStatus/list`

## 注意事项

- `codex mcp list` 命令耗时约 5-10 秒，因此采用异步加载不阻塞 UI
- CLI 不可用时（未安装 codex、命令超时等）静默忽略，列表仍正常显示
- auth 字段仅存储在内存中的 profile content 里，不会写入 `config.toml`
- `_generateCodexToml()` 不会输出 auth 字段，因此 toggle/save 操作安全
