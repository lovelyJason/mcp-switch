# MCP Tools 查询设计

## 概述

本文总结 MCP tools 展示功能的设计与实现。应用支持三种编辑器的 MCP tools 查询：

| 编辑器 | 查询方式 | 传输协议 |
|--------|----------|----------|
| Codex | `codex app-server` JSON-RPC | NDJSON over stdio |
| Cursor (command 型) | 直接启动 MCP 进程 + `tools/list` | NDJSON over stdio |
| Cursor (url 型) | HTTP POST JSON-RPC | HTTP |

## 一、Codex 路径：`codex app-server` + `mcpServerStatus/list`

### 为什么不用 `codex mcp tools`

在 **2026-03-12** 使用本机 **`codex-cli 0.114.0`** 验证后，结论是：

- **不存在** `codex mcp tools` 子命令
- Codex REPL 里的 `/mcp` 能显示 tools，是因为 Codex 内部有独立的 MCP runtime
- 正确做法是通过 **`codex app-server` 的 JSON-RPC 接口** 查询 MCP runtime 状态

### JSON-RPC 交互流程

```json
{"id":0,"method":"initialize","params":{"clientInfo":{"name":"mcp-switch","version":"1.0.0"}}}
{"method":"initialized"}
{"id":1,"method":"mcpServerStatus/list","params":{"limit":200}}
```

应用只关心 `id = 1` 的响应：

```json
{
  "id": 1,
  "result": {
    "data": [
      {
        "name": "figma-official",
        "authStatus": "logged_in",
        "tools": {
          "mcp__figma-official__get_design_context": {
            "name": "mcp__figma-official__get_design_context"
          }
        }
      }
    ]
  }
}
```

### 缓存策略

- 首次展开任意一个 Codex MCP 的 tools 区块时，触发一次全量查询
- 结果缓存到 `_cache`，后续同页面内其他 MCP 直接命中缓存
- 增加 `_codexBatchFuture` 做并发去重

## 二、Cursor stdio 路径：直接启动 MCP 进程

### 流程

1. 从 `mcp.json` 读取 `command` 和 `args`
2. 用 `_resolveCommand()` 解析完整路径（见下文"PATH 问题"）
3. 启动 MCP 进程
4. 发送 `initialize` → `notifications/initialized` → `tools/list`
5. 解析 JSON-RPC 响应中的 `result.tools[]`

### 通信协议：NDJSON

**关键发现**：`@modelcontextprotocol/sdk` v1.7+ 的 `StdioServerTransport` 使用 **NDJSON**（JSON + `\n`），不再使用 Content-Length 帧。

这意味着：

- **发送端**必须用 `JSON.stringify(msg) + "\n"` 格式
- **接收端**按 `\n` 分割后逐行解析 JSON
- 旧的 `Content-Length: N\r\n\r\nJSON` 帧格式不被这些 MCP server 识别

SDK 源码验证（`@modelcontextprotocol/sdk/dist/esm/shared/stdio.js`）：

```javascript
export function serializeMessage(message) {
    return JSON.stringify(message) + "\n";
}
```

### 兼容策略

为兼容可能仍使用 Content-Length 帧的旧 MCP server，应用采用**先 NDJSON，后回退 Content-Length**的策略：

1. 先用 NDJSON 发送 `initialize`
2. 等待 10 秒
3. 如果超时，用 Content-Length 帧重发 `initialize`
4. 等待 30 秒

## 三、Cursor HTTP 路径：POST JSON-RPC

### 流程

针对 `url` 型 MCP（如 Figma `https://mcp.figma.com/mcp`）：

1. POST `initialize` 到 MCP URL
2. POST `notifications/initialized`
3. POST `tools/list`
4. 解析响应（支持 `application/json` 和 `text/event-stream` SSE 格式）

### OAuth 限制

Figma 等 HTTP MCP 需要 OAuth 授权。未授权时返回 HTTP 401，应用会显示 "OAuth 授权后可查看 tools" 的友好提示。

## 四、Bug 修复历程

### Bug 1：Content-Length 帧格式不被新版 MCP SDK 识别（Playwright 超时）

**现象**：Playwright MCP 始终超时 30 秒无响应。

**根因**：发送端使用 `Content-Length: N\r\n\r\nJSON` 格式，但 Playwright MCP 基于 `@modelcontextprotocol/sdk` v1.7+，只识别 NDJSON（`JSON\n`）格式。服务端根本不解析 Content-Length 帧，所以永远不会回复。

**验证**：Node.js 测试发现用 NDJSON 格式发送后 Playwright 立即响应，返回 22 个 tools。

**修复**：将 `_sendStdio`（Content-Length 帧）改为 `_sendJsonLine`（NDJSON），并保留 `_sendContentLength` 作为超时回退。

### Bug 2：IOSink 缓冲未 flush（所有 stdio MCP 无响应）

**现象**：即使用了 NDJSON 格式，消息仍然没有送到子进程。

**根因**：Dart 的 `IOSink.writeln()` 只写入内存缓冲区，不会立即发送到管道。必须调用 `await sink.flush()` 才能确保数据到达子进程。

原始代码：

```dart
static void _sendJsonLine(IOSink sink, Map<String, dynamic> msg) {
    sink.writeln(jsonEncode(msg));  // 只写入缓冲区！
}
```

**修复**：

```dart
static Future<void> _sendJsonLine(IOSink sink, Map<String, dynamic> msg) async {
    sink.writeln(jsonEncode(msg));
    await sink.flush();  // 确保发送
}
```

同时修复了 `codex app-server` 路径中类似的遗漏（`process.stdin.writeln()` 后未 flush）。

### Bug 3：Notification 消息干扰响应解析（oss-mcp-plus 状态错乱）

**现象**：oss-mcp-plus 启动后立即发送 notification，`_StdioReader.nextMessage()` 把这个 notification 当作 initialize 的响应返回，导致后续通信状态错乱。

**根因**：oss-mcp-plus 在 `connect()` 后通过 `sendLoggingMessage()` 发送：

```json
{"method":"notifications/message","params":{"level":"info","data":["OSS MCP服务器已连接并准备处理请求"]},"jsonrpc":"2.0"}
```

旧的 `nextMessage()` 返回任何包含 `jsonrpc` 字段的消息，不区分 response 和 notification。

**修复**：`nextMessage()` 改为只返回包含 `id`/`result`/`error` 字段的消息（即 response），自动跳过 notification（只有 `method` 没有 `id` 的消息）。

### Bug 4：Figma HTTP 401 未授权（静默失败）

**现象**：Figma MCP 启用状态下点击 tools 永远显示 "No tools found"。

**根因**：Figma MCP（`https://mcp.figma.com/mcp`）需要 OAuth Bearer Token。未授权时返回 HTTP 401，但旧代码不区分 401 和普通失败。

**修复**：`_postJsonRpc` 中检测 HTTP 401/403 并抛出明确错误。`queryToolsViaHttp` catch 中识别 OAuth 相关错误，缓存 `McpTool.authRequired` 标记。UI 层据此显示 "OAuth 授权后可查看 tools"。

### Bug 5：EPIPE 错误日志（进程关闭顺序不当）

**现象**：oss-mcp-plus 查询完成后终端出现 `Error: write EPIPE` 错误堆栈。

**根因**：`_terminateProcess` 先关闭 stdin（`process.stdin.close()`），MCP server 检测到 stdin EOF 后尝试往 stdout 写退出消息，但此时 Flutter 侧已取消了 stdout 订阅（`reader.dispose()`），管道断裂导致 EPIPE。

**修复**：调整 `_terminateProcess` 顺序——先 `SIGTERM` kill 进程，等待短暂时间后再关闭 stdin，避免 MCP server 在管道断裂后尝试写入。

### Bug 6：macOS 下 npx 找不到（PATH 问题）

**现象**：从 Flutter 应用启动的子进程找不到 `npx` 命令，因为 macOS GUI 应用不继承 shell 的 PATH（`.zshrc` 中 fnm/nvm 配置的路径）。

**修复**：增加 `_resolveCommand()` 方法，通过交互式 shell 执行 `which npx` 获取完整路径：

```dart
static Future<String> _resolveCommand(String command) async {
    final result = await PlatformUtils.runCommand('which $command');
    final resolved = result.stdout.toString().trim();
    if (resolved.startsWith('/')) return resolved;
    return command;
}
```

## 五、数据模型

```dart
class McpTool {
  final String name;
  final String? description;
  const McpTool(this.name, [this.description]);

  static const authRequired = McpTool('__auth_required__');
}
```

UI 中 tool chip 支持 `Tooltip` 悬浮显示 `description`。

## 六、UI 集成

### 展示范围

- **已启用** MCP → 可显示 tools 展开入口
- **已禁用** MCP → 不展示 tools 按钮

同时覆盖 Codex 和 Cursor 两种编辑器。

### 组件职责

| 组件 | 职责 |
|------|------|
| `McpToolsSection` | 根据 `editorType` 和 `mcpName` 查询 tools，显示 loading/empty/auth/tool chips |
| `ConfigListScreen` | 展开/收起 tools 区块，在操作后清理缓存 |
| `ProfileCard` | 通过 `descriptionTrailing` 和 `footer` 插槽嵌入 tools 相关 UI |

### 缓存失效时机

在以下操作后清理 tools 缓存（`McpToolsService.clearCache()` + `_toolsExpanded.clear()`）：

- 进入 MCP 配置页
- 启用/禁用 MCP
- 编辑 MCP
- 删除 MCP
- 完成 `codex mcp login`

## 七、涉及文件

| 文件 | 作用 |
|------|------|
| `lib/services/mcp_tools_service.dart` | 三条查询路径实现、缓存管理、进程生命周期 |
| `lib/ui/components/mcp_tools_section.dart` | MCP tools 展示组件（通用，支持 Codex 和 Cursor） |
| `lib/ui/pages/mcp_config/config_list_screen.dart` | 列表页 tools 折叠入口与缓存失效联动 |
| `lib/ui/components/profile_card.dart` | 卡片组件，提供 `descriptionTrailing` 和 `footer` 插槽 |

## 八、注意事项

- tools 结果仅缓存在内存中，不写入配置文件
- Codex 首次查询需启动 `codex app-server`，会比普通内存读取慢
- Cursor stdio 查询需启动 MCP 进程，npx 安装耗时可能较长
- HTTP MCP 需要 OAuth 授权才能查询 tools
- 进程关闭时可能短暂出现 EPIPE，已通过调整 kill 顺序最大程度减少
