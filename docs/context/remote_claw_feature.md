# Remote Claw（远程审批）功能设计文档

## 概述

Remote Claw 是 MCP Switch 的远程审批功能，让用户在不安装第三方工具的前提下，当 Claude Code 执行操作请求权限或向用户提问时，能通过 Telegram Bot 或钉钉机器人将消息推送到手机端，实现远程同意、拒绝或选择答案。

## 设计思想

### 核心理念

**"本地拦截 + 远程决策"** — Claude Code 的 Hook 拦截每次权限请求或询问，转发到 mcp-switch 内嵌的本地 HTTP 服务（`0.0.0.0:8099`，监听所有网卡），服务推送消息到手机，Hook 脚本轮询等待用户决策后返回结果给 Claude Code。

### 为什么不使用 OpenClaw/Lobster

1. **安全隐患**：第三方工具对本地权限的访问存在不可控风险
2. **精简可控**：自研方案只包含必要功能，代码完全在自己手里
3. **无公网依赖**：本地服务 + Telegram/钉钉推送，不需要公网 IP 或域名
4. **与 mcp-switch 集成**：统一在一个应用内管理，不需要安装额外进程

---

## 两种拦截场景

### 场景一：权限请求（PermissionRequest）

**触发**：Claude Code 执行 Bash、Write、Edit、Read 等工具时，请求用户授权。

**Hook 类型**：`PermissionRequest`

**Hook 响应格式**：
```json
// 同意
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","message":"Approved via MCP Switch Remote Claw"}}}

// 本次会话全部同意（对应 Claude Code "Yes, allow all edits this session"）
{"decision":"allow_and_dont_ask_again"}

// 拒绝
{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied via MCP Switch Remote Claw"}}}
```

**超时**：Hook 脚本最多等待 300 秒，超时后自动拒绝。

**操作按钮**（UI 桌面端 / Telegram / 钉钉）：
| 按钮 | 说明 |
|------|------|
| ✅ 同意 | `allow` — 允许本次操作 |
| 🔁 本次全部同意 | `allowSession` — 本次会话所有同类工具不再询问 |
| ❌ 拒绝 | `deny` — 拒绝本次操作 |

---

### 场景二：AskUserQuestion（多 Tab 问题询问）

**触发**：Claude Code 调用 `AskUserQuestion` 工具向用户提问（多选题），展示为多个 Tab（每个 Tab 是一个独立问题）。

**Hook 类型**：`PreToolUse`，matcher 为 `AskUserQuestion`

**Hook 响应格式**：
```json
// 返回用户选择的答案（多问题时用换行拼接所有答案）
{"answer":"用户选择的选项文本\n第二问题的选项文本"}
```

**超时**：`timeout: 86400`（1天），Hook 脚本无限等待，用户必须选择才能继续。

**数据结构**（Claude Code 传入的 `tool_input`）：
```json
{
  "questions": [
    {
      "question": "问题文本",
      "header": "Tab 标题",
      "options": [
        {"label": "选项A", "description": "..."},
        {"label": "选项B", "description": "..."}
      ],
      "multiSelect": false
    },
    {
      "question": "第二个问题文本",
      "header": "第二个 Tab 标题",
      "options": [...]
    }
  ]
}
```

**多问题处理逻辑**：
- 桌面端 UI：分步显示，显示"问题 1/2 · header"进度，选完一个自动跳下一个，全部选完才 resolve
- 钉钉：一次发所有问题的选项按钮（格式 `Q1: 选项`），每点一个记录对应问题答案，全部问题回答完才 resolve
- Telegram：同钉钉逻辑，callback_data 格式为 `answer:requestId:qi:optIndex`

**最终答案格式**：所有问题答案按顺序用 `\n` 拼接，作为 `answer` 字段返回给 Hook。

---

## 整体数据流

### 权限请求流程
```
Claude Code 要执行操作（Bash/Write/Edit/...）
    ↓ PermissionRequest Hook 触发
~/.claude/hooks/remote-claw.sh
    ↓ POST /hook/permission
RemoteClawService (0.0.0.0:8099)
    ├── 返回 request_id
    ├── 推送到 Telegram Bot（长轮询接收用户回复）
    └── 推送到钉钉机器人（ActionCard 按钮回调）
    ↓ Hook 脚本每 2 秒轮询 /decision/:id
用户手机点击 ✅同意 / 🔁本次全部 / ❌拒绝
    ↓ 决策写入内存队列
Hook 脚本获取到 resolved 状态
    ↓ 输出 allow/allowSession/deny JSON 到 stdout
Claude Code 继续执行 or 取消
```

### AskUserQuestion 流程
```
Claude Code 调用 AskUserQuestion
    ↓ PreToolUse Hook 触发（matcher: AskUserQuestion）
~/.claude/hooks/remote-claw.sh
    ↓ POST /hook/permission（同一接口，hook_event_name 区分）
RemoteClawService
    ├── 返回 request_id
    ├── 推送到 Telegram / 钉钉（显示问题和选项按钮）
    └── 桌面端显示问题卡片（分步选择）
用户逐一回答每个 question 的选项
    ↓ 每个答案存入 questionAnswers[index]
    ↓ 全部回答完 → resolvedAnswer = answers.join('\n')
    ↓ decision = allow
Hook 脚本获取到 resolved，读取 answer 字段
    ↓ 输出 {"answer": "..."} 到 stdout
Claude Code 收到答案，继续执行
```

**超时降级**（PermissionRequest，300 秒无操作）：
- Hook 脚本自动输出 deny JSON

**AskUserQuestion 无超时**：
- Hook 脚本对 PreToolUse 类型无限等待（settings.json timeout=86400）

**服务不可用降级**：
- Hook 脚本检查 `/health` 失败 → `exit 0` → Claude Code 显示原生弹窗

---

## 文件结构

```
lib/
├── models/
│   └── permission_request.dart          # 权限请求数据模型
│       ├── AskQuestion                  # 单个问题结构（question/header/options/multiSelect）
│       ├── PermissionRequest            # 主模型
│       └── PermissionDecision           # 枚举（pending/allow/allowSession/deny/externallyHandled）
├── services/
│   ├── remote_claw_service.dart         # 核心服务：HTTP Server + 决策队列 + Hook 管理
│   └── channels/
│       ├── telegram_channel.dart        # Telegram Bot：长轮询推送 + 多问题键盘
│       └── dingtalk_channel.dart        # 钉钉机器人：ActionCard + HMAC-SHA256 加签
└── ui/pages/remote_claw/
    ├── remote_claw_screen.dart          # 配置主页面
    └── widgets/
        ├── pending_request_card.dart    # 待审批/询问请求卡片（StatefulWidget，支持分步问答）
        └── channel_config_section.dart  # Telegram/钉钉配置区域

~/.claude/hooks/remote-claw.sh          # Hook 脚本（由 mcp-switch 自动生成安装）
~/.claude/settings.json                 # Claude Code 配置（自动写入两种 Hook）
```

---

## 核心数据模型

### PermissionRequest

```dart
class AskQuestion {
  final String question;   // 问题文本
  final String header;     // Tab 标题
  final List<String> options;  // 选项标签列表（从 options[].label 提取）
  final bool multiSelect;
}

class PermissionRequest {
  // 基本字段
  final String id, sessionId, toolName, cwd;
  final Map<String, dynamic> toolInput;
  final DateTime createdAt;
  final String hookEventName;  // 'PermissionRequest' | 'PreToolUse'

  // AskUserQuestion 专用
  final List<AskQuestion> askQuestions;   // 所有问题
  final List<String?> questionAnswers;    // 每个问题对应的答案
  String? resolvedAnswer;                 // 最终答案（resolve 时写入）

  PermissionDecision decision;
  DateTime? lastPolledAt;

  // 关键 getter
  bool get isAskFollowup => toolName == 'AskUserQuestion';
  bool get allAnswered => questionAnswers.every((a) => a != null);
  int get nextUnansweredIndex;  // 第一个未回答的 index，-1 表示全部完成
  String get finalAnswer => questionAnswers.join('\n');  // 给 Hook 的最终答案
  String? get answer => resolvedAnswer;  // badge 显示用
  String get commandSummary;  // AskUserQuestion 时拼接所有问题文本
  String get projectName;     // cwd 最后一段

  // 回答指定问题
  bool setQuestionAnswer(int index, String answer);  // 返回是否全部已回答
}
```

---

## 核心模块设计

### RemoteClawService

继承 `ChangeNotifier`，在 `main.dart` 初始化后注入 `MultiProvider`。

**HTTP 端点：**

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/hook/permission` | 接收 Claude Code Hook 请求，返回 `request_id` |
| GET  | `/decision/:id` | Hook 脚本轮询，返回 `pending` 或 `{resolved, decision, answer?}` |
| POST | `/action/allow/:id` | 手动同意 |
| POST | `/action/allow-session/:id` | 手动「本次全部同意」 |
| POST | `/action/deny/:id` | 手动拒绝 |
| POST | `/action/answer/:id` | 回填答案（JSON body `{answer: "..."}`) |
| GET  | `/action/answer/:id` | 回填答案（钉钉 GET + `?answer=encoded`） |
| POST | `/callback/telegram` | Telegram Webhook 预留入口 |
| POST | `/callback/dingtalk` | 钉钉机器人回调 |
| GET  | `/health` | 健康检查 |

**多问题答案格式（GET /action/answer/:id）：**
- 单问题：`?answer=选项文本`
- 多问题：`?answer=qi:选项文本`（qi 为 question index）
- Service 解析后调用 `request.setQuestionAnswer(qi, text)`，全部回答完后才 resolve

**决策生命周期：**
```
请求进入 → decision = pending
权限请求：用户操作 → decision = allow / allowSession / deny
询问：逐问题回答 → 全部完成 → resolvedAnswer = finalAnswer → decision = allow
Hook 脚本 GET /decision → 状态变为 resolved → 请求从队列移除
```

**外部处理检测（ExternallyHandled）：**
- `lastPolledAt` 记录最近一次 Hook 轮询时间
- 曾被轮询后超过 8 秒无新轮询 → Hook 已退出 → 标记为 `externallyHandled`
- 从未轮询超过 15 秒 → 标记为 `externallyHandled`

### TelegramChannel

**权限请求消息：**
- `InlineKeyboard`：`✅ 同意` / `🔁 本次全部同意` / `❌ 拒绝`
- callback_data：`allow:requestId` / `allowSession:requestId` / `deny:requestId`

**AskUserQuestion 消息：**
- 单问题：消息体显示问题文本，键盘每行一个选项
- 多问题：消息体列出所有问题（`Q1 · header: ...`），键盘每个选项前缀 `Q1: `
- callback_data（多问题）：`answer:requestId:qi:optIndex`
- callback_data（单问题）：`answer:requestId:optIndex`

**选项缓存**：`_optionsCache: Map<String, List<List<String>>>`（requestId → 每个 question 的 options list）

**长轮询**：`getUpdates`，`allowed_updates: ["callback_query"]`，间隔 2 秒

### DingtalkChannel

**权限请求消息**（ActionCard）：
- 正文：工具名 + 项目名 + 命令摘要 + 时间戳（`YYYY-MM-DD HH:mm:ss`）+ ID
- 按钮：`✅ 同意` → `GET /action/allow/:id`，`🔁 本次全部同意` → `GET /action/allow-session/:id`，`❌ 拒绝` → `GET /action/deny/:id`

**AskUserQuestion 消息**（ActionCard）：
- 正文：列出所有问题文本 + 时间戳 + ID
- 按钮：每个 question 的每个选项一个按钮，格式 `Q1: 选项`
- actionURL：`GET /action/answer/:id?answer=qi:选项文本`（URI encoded）
- 按钮数量上限：20 个（超出截断）

---

## Hook 脚本逻辑

脚本路径：`~/.claude/hooks/remote-claw.sh`

```bash
# 核心逻辑
1. 从 stdin 读取 Claude Code 传入的 JSON
2. 检测 hook_event_name（PermissionRequest / PreToolUse）
3. curl /health 检查服务可用性，不可用则 exit 0（降级显示原生弹窗）
4. curl POST /hook/permission，获取 request_id
5. 进入无限轮询循环（每 2 秒 GET /decision/:id）

# PermissionRequest 类型：
#   - 超过 300 秒无回应 → 自动输出 deny JSON 退出
#   - 获得 allow → 输出 allow JSON
#   - 获得 allowSession → 输出 {"decision":"allow_and_dont_ask_again"}
#   - 获得 deny → 输出 deny JSON

# PreToolUse/AskUserQuestion 类型：
#   - 无超时，无限等待
#   - 获得 resolved → 读取 answer 字段 → 输出 {"answer":"..."} 退出
```

`~/.claude/settings.json` 中写入的 Hook 配置：
```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/remote-claw.sh", "timeout": 600}]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/remote-claw.sh", "timeout": 86400}]
      }
    ]
  }
}
```

---

## UI 功能说明

### 待审批请求卡片（`PendingRequestCard`）

`StatefulWidget`，内部维护 `_currentQuestionIndex`（当前显示的问题索引）。

**权限请求卡片：**
| 状态 | `decision` 值 | 卡片表现 |
|------|--------------|---------|
| 等待中 | `pending` | 正常亮度，底部显示 ✅同意 / 🔁本次全部 / ❌拒绝 按钮 |
| 已同意 | `allow` | 60% 透明度，底部显示绿色「✓ 已同意」徽章 |
| 本次全部同意 | `allowSession` | 60% 透明度，底部显示橙色「🔁 本次全部同意」徽章 |
| 已拒绝 | `deny` | 60% 透明度，底部显示红色「✗ 已拒绝」徽章 |
| 外部处理 | `externallyHandled` | 60% 透明度，底部显示灰色「已由其他渠道处理」徽章 |

**AskUserQuestion 卡片（❓）：**
- 命令预览区显示所有问题文本（换行分隔）
- 超过 120 字符显示橙色边框 + "点击查看完整内容 ↕"，点击展开 `AlertDialog`（SelectableText 可复制）
- 多问题时显示进度"问题 1/2 · header"
- 当前问题文本 + 选项按钮（OutlinedButton，橙色）
- 选完一个自动跳下一问题，全部选完触发 `onAnswer(finalAnswer)` 并 resolve
- resolve 后显示绿色「✓ 已回答: 答案文本」徽章

**长内容展开对话框**：
- 触发条件：`commandSummary.length > 120`
- 展示：`AlertDialog` + `SingleChildScrollView` + `SelectableText`（可复制）

---

## 配置持久化

Remote Claw 配置通过 `ConfigService` 存入 SharedPreferences：

| Key | 类型 | 说明 |
|-----|------|------|
| `rc_telegram_enabled` | bool | Telegram 是否启用 |
| `rc_telegram_bot_token` | String | Bot Token（敏感） |
| `rc_telegram_chat_id` | String | Chat ID |
| `rc_dingtalk_enabled` | bool | 钉钉是否启用 |
| `rc_dingtalk_webhook_url` | String | Webhook URL（含 access_token，敏感） |
| `rc_dingtalk_secret` | String | 加签密钥（敏感） |
| `rc_port` | int | 本地服务端口，默认 8099 |
| `rc_auto_start` | bool | 应用启动时自动启动服务 |
| `rc_callback_host` | String | 钉钉按钮回调地址，空则用 127.0.0.1 |
| `rc_use_local_callback` | bool | 是否附加电脑端 localhost 按钮（已移除，保留键兼容性） |

---

## 架构决策记录（ADR）

### ADR-1：HTTP Server 绑定地址从 127.0.0.1 改为 0.0.0.0

**背景**：初始实现将 Server 绑定在 `127.0.0.1`（loopback only）。当用户使用 Tailscale 组网后，钉钉消息中的回调 URL 形如 `http://100.111.x.x:8099/action/allow/...`，手机无法连接（`ERR_CONNECTION_REFUSED`）。

**决策**：改为 `InternetAddress.anyIPv4`（`0.0.0.0`），监听所有网卡，包括 loopback、Tailscale 虚拟网卡、局域网网卡。

### ADR-2：利用 _sharedServer 静态字段跨热重启优雅复用端口

**决策**：将 `HttpServer` 实例提升为静态字段 `_sharedServer`，热重启时直接复用存活的 Socket，避免 `Address already in use` 错误。

### ADR-3：AskUserQuestion 走 PermissionRequest Hook，仅通知不拦截

**背景**：经过多次踩坑验证：

1. **PreToolUse Hook 方案（已废弃）**：最初用 `PreToolUse` + matcher `AskUserQuestion` 拦截，Hook 返回 `{"answer":"..."}` 给 Claude Code。问题是 PreToolUse Hook 独占控制权，VSCode 插件的原生弹窗就不会弹出来了，用户只能在一个渠道操作。

2. **PermissionRequest Hook + 拦截答案方案（已废弃）**：`AskUserQuestion` 实际上**也会触发 PermissionRequest Hook**（`tool_name = AskUserQuestion`），尝试在这个 Hook 里等待 MCP Switch 决策并返回 `{"answer":"..."}`。但这条路走不通：`PermissionRequest` Hook 的响应格式固定为 `hookSpecificOutput`，Claude Code **不会从此 Hook 读取 `answer` 字段**。

3. **最终方案：仅通知，不拦截**：Hook 脚本检测到 `tool_name = AskUserQuestion` 时，同步发送通知给 MCP Switch（`--max-time 2`），然后立即 `exit 0` 放行。MCP Switch 服务端收到后直接标记为 `externallyHandled`，推钉钉/Telegram 纯文本通知（无操作按钮），同时在 UI 显示通知卡片（60 秒后自动消失）。VSCode 插件正常弹原生多 Tab 弹窗处理答案。

**关键踩坑**：
- 不能用 `curl ... &` 后台发请求再 `exit 0`，bash 脚本退出后子进程会被杀死，请求发不出去。必须同步发（加 `--max-time` 超时保证不阻塞）。
- 钉钉 ActionCard 的 `btns` 字段**不能为空数组**，否则消息发送失败。AskUserQuestion 改用 `msgtype: markdown` 纯文本通知，绕开这个限制。
- MCP Switch UI 的请求列表默认只过滤 `pending` 状态，`externallyHandled` 的 AskUserQuestion 通知卡片需要单独加入过滤条件才能显示。

**决策**：
- `settings.json`：只注册 `PermissionRequest` hook，不需要 `PreToolUse`
- Hook 脚本：检测 `tool_name = AskUserQuestion` → 同步发通知 → `exit 0`
- 服务端：AskUserQuestion 进来直接标记 `externallyHandled`，推通知，不等决策
- 钉钉：发 markdown 纯文本，提示"请在 Claude Code 客户端选择答案"
- Telegram：发纯文本，无 inline keyboard
- UI：显示灰色"已在其他端处理"徽章，60 秒后自动从列表移除

### ADR-4：多问题分步回答 UI，Other 自定义输入

**背景**：`AskUserQuestion` 可以包含多个 questions（多 Tab），每个 question 独立，都需要用户回答。

**决策（本地 UI PendingRequestCard）**：
- `StatefulWidget`，`_currentQuestionIndex` 维护当前显示的问题索引
- 选完一个自动跳下一个未回答的问题（`nextUnansweredIndex`）
- 支持返回上一题按钮，已选答案高亮绿色
- 每个问题底部加"其他（自定义输入）"按钮，展开 TextField 输入自定义答案
- 全部选完触发 `onAnswer(finalAnswer)`，`finalAnswer = questionAnswers.join('\n')`
- `_otherControllers`（Map<int, TextEditingController>）按问题索引独立管理，dispose 时正确清理

> ⚠️ 注意：由于 AskUserQuestion 改为"仅通知"模式，MCP Switch 客户端的问答 UI 虽然保留，但实际上用户的选择不会反馈给 Claude Code。UI 仅作为参考展示，真正的答案由 VSCode 插件处理。

### ADR-5：移除钉钉/Telegram 中的"电脑端"按钮

**背景**：v1.5.0 及之前版本在钉钉消息中额外附加了「✅ 同意（电脑端）」「❌ 拒绝（电脑端）」按钮（localhost 回调），导致按钮太多，体验差。

**决策**：移除电脑端按钮，统一使用配置的 `hostAddress` 回调。提示用户使用手机操作或通过桌面 UI 操作。`localHostAddress` 参数从 `DingtalkChannel` 构造函数中保留但不再使用。

---

## 已知限制与未来扩展

| 限制 | 说明 | 扩展方向 |
|------|------|---------|
| 钉钉按钮需可访问地址 | 手机端需填 Tailscale IP 才能从外网点击 | ✅ 已实现「回调地址」输入框 |
| Telegram 长轮询 2 秒延迟 | 实时性略差 | 配置公网 HTTPS 后切换 Webhook 模式（入口已预留） |
| 内存队列 | 重启服务后 pending 请求丢失 | 可持久化到 SQLite（低优先级） |
| AskUserQuestion 无法远程回答 | 架构限制：PermissionRequest Hook 不支持传 answer，PreToolUse Hook 会独占弹窗 | 目前只能通知，答案由 VSCode 插件处理 |
| AskUserQuestion 通知卡片不交互 | UI 卡片虽然有选项按钮，但点击不会影响 Claude Code 的实际答案 | 可考虑隐藏选项区域，仅展示问题文本 |
