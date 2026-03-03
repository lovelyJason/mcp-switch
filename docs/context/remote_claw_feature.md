# Remote Claw（远程审批）功能设计文档

## 概述

Remote Claw 是 MCP Switch 的远程审批功能，让用户在不安装第三方工具的前提下，当 Claude Code 执行操作请求权限时，能通过 Telegram Bot 或钉钉机器人将审批消息推送到手机端，实现远程同意或拒绝。

## 设计思想

### 核心理念

**"本地拦截 + 远程决策"** — Claude Code 的 PermissionRequest Hook 拦截每次权限请求，转发到 mcp-switch 内嵌的本地 HTTP 服务（127.0.0.1:8099），服务推送消息到手机，Hook 脚本轮询等待用户决策后返回结果给 Claude Code。

### 为什么不使用 OpenClaw/Lobster

1. **安全隐患**：第三方工具对本地权限的访问存在不可控风险
2. **精简可控**：自研方案只包含必要功能，代码完全在自己手里
3. **无公网依赖**：本地服务 + Telegram/钉钉推送，不需要公网 IP 或域名
4. **与 mcp-switch 集成**：统一在一个应用内管理，不需要安装额外进程

### 长轮询 vs Webhook

当前使用 **Telegram 长轮询（getUpdates）**：
- Hook 脚本轮询本地服务，本地服务通过 Telegram 长轮询获取用户回复
- 不需要公网可访问的 HTTPS 地址
- 延迟约 2 秒（可接受）

**Webhook 预留入口**（`POST /callback/telegram`）：
- 未来若有公网地址，可切换 Telegram 为 Webhook 模式
- 只需在该端点处理 Telegram Update，无需改动其他逻辑

钉钉通过 ActionCard 消息的按钮 URL 直接回调本地服务（`/action/allow/:id` 或 `/action/deny/:id`），无需长轮询。

---

## 整体数据流

```
Claude Code 要执行操作
    ↓ PermissionRequest Hook 触发
~/.claude/hooks/remote-claw.sh
    ↓ POST /hook/permission
RemoteClawService (127.0.0.1:8099)
    ├── 返回 request_id
    ├── 推送到 Telegram Bot（长轮询接收用户回复）
    └── 推送到钉钉机器人（ActionCard 按钮回调）
    ↓ Hook 脚本每 2 秒轮询 /decision/:id
用户手机点击 ✅同意 / ❌拒绝
    ↓ 决策写入内存队列
Hook 脚本获取到 resolved 状态
    ↓ 输出 allow/deny JSON 到 stdout
Claude Code 继续执行 or 取消
```

**超时降级**（300 秒无操作）：
- Hook 脚本自动输出 deny JSON

**服务不可用降级**：
- Hook 脚本检查 `/health` 失败 → `exit 0` → Claude Code 显示原生弹窗

---

## 文件结构

```
lib/
├── models/
│   └── permission_request.dart          # 权限请求数据模型 + PermissionDecision 枚举
├── services/
│   ├── remote_claw_service.dart         # 核心服务：HTTP Server + 决策队列 + Hook 管理
│   └── channels/
│       ├── telegram_channel.dart        # Telegram Bot：长轮询推送 + Webhook 预留
│       └── dingtalk_channel.dart        # 钉钉机器人：ActionCard + HMAC-SHA256 加签
└── ui/pages/remote_claw/
    ├── remote_claw_screen.dart          # 配置主页面
    └── widgets/
        ├── pending_request_card.dart    # 待审批请求卡片（桌面端本地审批）
        └── channel_config_section.dart  # Telegram/钉钉配置区域

~/.claude/hooks/remote-claw.sh          # Hook 脚本（由 mcp-switch 自动生成安装）
~/.claude/settings.json                 # Claude Code 配置（自动写入 PermissionRequest Hook）
```

---

## 核心模块设计

### RemoteClawService

继承 `ChangeNotifier`，在 `main.dart` 初始化后注入 `MultiProvider`。

**职责：**
1. 管理内嵌 `shelf` HTTP Server（手动启停）
2. 维护内存决策队列 `Map<String, PermissionRequest>`
3. 协调 TelegramChannel / DingtalkChannel 推送
4. 提供 Hook 脚本生成和 `settings.json` 写入/卸载方法

**HTTP 端点：**

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/hook/permission` | 接收 Claude Code Hook 请求，返回 `request_id` |
| GET  | `/decision/:id` | Hook 脚本轮询，返回 `pending` 或 `resolved + decision` |
| POST | `/action/allow/:id` | 手动同意（桌面 UI 或钉钉按钮回调） |
| POST | `/action/deny/:id` | 手动拒绝 |
| POST | `/callback/telegram` | Telegram Webhook 预留入口（当前未启用） |
| POST | `/callback/dingtalk` | 钉钉机器人回调 |
| GET  | `/health` | 健康检查（Hook 脚本启动时探测） |

**决策生命周期：**
```
请求进入 → decision = pending
用户操作 → decision = allow / deny
Hook 脚本 GET /decision → 状态变为 resolved → 请求从队列移除
```

### TelegramChannel

- **推送**：`sendMessage` + `InlineKeyboard`，按钮 callback_data 格式为 `allow:<requestId>` / `deny:<requestId>`
- **长轮询**：`getUpdates`，`allowed_updates: ["callback_query"]`，间隔 2 秒
- **Chat ID 校验**：忽略非预期来源的回调
- **answerCallbackQuery**：点击后立即应答，消除 Telegram loading 动画
- **Webhook 预留**：`RemoteClawService._handleTelegramCallback` 已预留，切换时只需实现该方法内的 Update 解析逻辑

### DingtalkChannel

- **消息格式**：ActionCard，两个按钮 URL 直接指向本地服务 `/action/allow/:id` 和 `/action/deny/:id`
- **加签**：HMAC-SHA256，`timestamp\n{secret}` 签名，Base64 + URL encode，附加到 Webhook URL query string
- **hostAddress 参数**：actionURL 使用 `hostAddress` 而非硬编码 `127.0.0.1`，默认值为 `127.0.0.1`
  - 用户可在 UI「回调地址」输入框填入 Tailscale IP（`100.x.x.x`）后，手机从任意网段点击按钮均可生效
  - `hostAddress` 由 `RemoteClawService._callbackHost` 传入

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
| `rc_callback_host` | String | 钉钉按钮回调地址，空则用 127.0.0.1，填 Tailscale IP 后手机可访问 |

**对应 ConfigService 方法：**
- `saveRemoteClawConfig(...)` — 批量保存渠道配置
- `saveRemoteClawAutoStart(bool)` — 单独保存自动启动状态
- `saveRemoteClawCallbackHost(String)` — 单独保存回调地址

**初始化时序**（`main.dart`）：
```dart
// 1. configService.init() 读取 SharedPreferences 中的 RC 配置（含 callbackHost）
// 2. remoteClawService.loadConfig(..., callbackHost: ...) 将配置注入 Service
// 3. 若 rc_auto_start == true，自动调用 remoteClawService.start()
// 4. 用户也可在 UI 手动点「启动」/「停止」
```

---

## Hook 脚本逻辑

脚本路径：`~/.claude/hooks/remote-claw.sh`，由 `RemoteClawService.installHookScript()` 自动生成并 `chmod +x`。

```
1. 从 stdin 读取 Claude Code 传入的 JSON（session_id, tool_name, tool_input, cwd）
2. curl /health 检查服务可用性，不可用则 exit 0（降级）
3. curl POST /hook/permission，获取 request_id
4. 每 2 秒 curl GET /decision/:id，最长等待 300 秒
5. 获取 resolved 后输出 allow/deny JSON 到 stdout
6. 超时则输出 deny JSON
```

`~/.claude/settings.json` 中写入的 Hook 配置：
```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/remote-claw.sh",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```

`matcher: ""` 匹配所有工具（Bash、Write、Edit 等）。

---

## 依赖新增

```yaml
shelf: ^1.4.2        # 内嵌 HTTP Server
shelf_router: ^1.1.4 # HTTP 路由
crypto: ^3.0.6       # HMAC-SHA256（钉钉加签）
```

---

## UI 功能说明

### 本地服务卡片（`_ServerStatusCard`）

- **端口**：可修改，运行中不允许改，改后如 Hook 已安装则自动重新生成脚本
- **回调地址**：填 Tailscale IP（`100.x.x.x`）或其他可访问地址；失焦/回车自动保存并更新 DingtalkChannel；留空则使用 `127.0.0.1`
- **启动/停止**：同时更新 `rc_auto_start` 持久化，下次启动 app 自动恢复服务状态

### 通知渠道卡片（`ChannelConfigSection`）

- **Telegram**：开关 + 展开配置（Bot Token + Chat ID）；当前开关打开时 toast 提示「功能开发中」，不允许启用
- **钉钉机器人**：开关 + 展开配置（Webhook URL + 加签密钥）；启用时 Webhook URL 必填
- **保存按钮**：校验通过后调 `RemoteClawService.updateDingtalkConfig()` + `ConfigService.saveRemoteClawConfig()`

---

## 已知限制与未来扩展

| 限制 | 说明 | 扩展方向 |
|------|------|---------|
| 钉钉按钮需可访问地址 | 默认 127.0.0.1 只能本机点击，外网需填 Tailscale IP | ✅ 已实现「回调地址」输入框，用户填 Tailscale IP 即可 |
| Telegram 长轮询 2 秒延迟 | 实时性略差 | 配置公网 HTTPS 后切换 Webhook 模式（入口已预留） |
| Telegram 推送未完整实现 | 当前开关打开时提示「开发中」 | 补充 TelegramChannel 审批流（UI 侧拦截已就绪，服务层待完善） |
| 内存队列 | 重启服务后 pending 请求丢失 | 可持久化到 SQLite（低优先级） |
