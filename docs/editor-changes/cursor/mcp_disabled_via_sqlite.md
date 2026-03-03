# [2025-Q3] MCP 禁用状态迁移至 SQLite 数据库

**影响版本**: Cursor 近期版本（具体版本号待确认）

## 变更内容

Cursor 将 MCP 服务的启用/禁用状态从 `mcp.json` 迁移到了 **workspace 级别**的 SQLite 数据库中，实现了 per-workspace 的 MCP 开关控制。

### 两个文件的职责分工

| 文件 | 职责 | 格式 |
|------|------|------|
| `~/.cursor/mcp.json` | 声明 MCP 服务器的配置（URL、命令、参数等） | JSON |
| `~/Library/Application Support/Cursor/User/workspaceStorage/<workspace-id>/state.vscdb` | 控制每个 workspace 中哪些 MCP 服务被禁用 | SQLite |

### 数据库详情

- **文件路径**: `~/Library/Application Support/Cursor/User/workspaceStorage/<workspace-id>/state.vscdb`
- **存储 Key**: `cursor/disabledMcpServers`
- **值格式**: JSON 数组
  - `[]` — 没有禁用任何 MCP 服务
  - `["user-Figma", "user-chrome-devtools"]` — 禁用了指定的 MCP 服务

### 优先级规则

```
mcp.json 中的 "disabled": true/false  →  初始默认值（低优先级）
state.vscdb 中的 disabledMcpServers   →  实际生效值（高优先级）
```

一旦 workspace 数据库中有了记录，就以数据库为准，`mcp.json` 中的 `disabled` 字段不再生效。

## 对 MCP Switch 的影响

1. **读取禁用状态**: 不能仅依赖 `mcp.json` 中的 `disabled` 字段，需同时读取 SQLite 数据库
2. **切换启用/禁用**: Cursor UI 中点击 MCP 开关时，改的是 workspace 的 SQLite 数据库，而非 `mcp.json`
3. **Per-workspace**: 不同项目可以有不同的 MCP 启用/禁用配置，MCP Switch 如需精确控制，需要识别 workspace
4. **写入 `mcp.json` 的 `disabled` 字段**: 仅作为"默认初始值"有意义，不能保证实际运行时生效

## 兼容方案（已实现方案 B + C）

- ~~方案 A: 仅操作 `mcp.json`~~
- **方案 B（已实现）**: 全局开关同时操作 `mcp.json` + 所有 workspace 的 SQLite 数据库
- **方案 C（已实现）**: workspace 项目级开关，独立操控每个项目的 disabled 状态

## 外部写入 SQLite 的限制

Cursor 是单进程多窗口架构（Electron），`state.vscdb` 的值在**主进程内存中缓存**：

- **Cursor → MCP Switch**（正向）：实时生效，MCP Switch 每次读取都从 SQLite 获取最新值
- **MCP Switch → Cursor**（反向）：写入 SQLite 成功，但 Cursor 不监听外部变更。**必须完全退出 Cursor（⌘Q）后重新打开才能生效**，仅关闭单个窗口无效（主进程仍在运行）

## workspace-id 定位

- 项目列表数据源：`~/.cursor/projects/` 目录
- 目录名格式：路径中 `/` → `-`，`.` → `-`（如 `/Users/jasonhuang/projects/my/mcp-switch` → `Users-jasonhuang-projects-my-mcp-switch`）
- 匹配 `workspaceStorage` 中的 `workspace.json` 获取对应 `state.vscdb` 路径
