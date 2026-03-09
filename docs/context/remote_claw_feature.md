# Remote Claw（远程审批）功能设计文档

## 概述

Remote Claw 是 MCP Switch 的远程审批功能，让用户在不安装第三方工具的前提下，当 Claude Code 执行操作请求权限时，能通过 Telegram Bot 或钉钉机器人将审批消息推送到手机端，实现远程同意或拒绝。

## 设计思想

### 核心理念

**"本地拦截 + 远程决策"** — Claude Code 的 PermissionRequest Hook 拦截每次权限请求，转发到 mcp-switch 内嵌的本地 HTTP 服务（`0.0.0.0:8099`，监听所有网卡），服务推送消息到手机，Hook 脚本轮询等待用户决策后返回结果给 Claude Code。

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
RemoteClawService (0.0.0.0:8099，监听所有网卡)
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

- **消息格式**：ActionCard，按钮 URL 直接指向本地服务 `/action/allow/:id` 和 `/action/deny/:id`
- **加签**：HMAC-SHA256，`timestamp\n{secret}` 签名，Base64 + URL encode，附加到 Webhook URL query string
- **hostAddress 参数**：actionURL 使用 `hostAddress` 而非硬编码 `127.0.0.1`，默认值为 `127.0.0.1`
  - 用户可在 UI「回调地址」输入框填入 Tailscale IP（`100.x.x.x`）后，手机从任意网段点击按钮均可生效
  - `hostAddress` 由 `RemoteClawService._callbackHost` 传入
- **localHostAddress 参数**（v1.5.1 新增）：当非 null 时，在 ActionCard 中额外追加「✅ 同意（电脑端）」「❌ 拒绝（电脑端）」两个按钮，使用 `localhost` 作为回调地址
  - 解决电脑端钉钉点击 Tailscale IP 链接报错的问题（Tailscale IP 回调地址电脑本机无法直连）
  - 由 `RemoteClawService._useLocalCallback` 控制，为 `true` 时传入 `'localhost'`，否则传 `null`

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
| `rc_use_local_callback` | bool | 是否在消息中附加电脑端 localhost 按钮，默认 true |

**对应 ConfigService 方法：**
- `saveRemoteClawConfig(...)` — 批量保存渠道配置
- `saveRemoteClawAutoStart(bool)` — 单独保存自动启动状态
- `saveRemoteClawCallbackHost(String)` — 单独保存回调地址
- `saveRemoteClawServerConfig({port, callbackHost, useLocalCallback?})` — 保存服务器配置（含可选的 localhost 开关）

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
- **本机走 localhost 开关**（v1.5.1 新增）：直接显示在服务卡片内，默认开启。开启后钉钉消息中额外附加「电脑端」按钮，使用 `localhost` 回调，解决电脑端钉钉点击 Tailscale IP 链接报错的问题
- **启动/停止**：同时更新 `rc_auto_start` 持久化，下次启动 app 自动恢复服务状态

### 通知渠道卡片（`ChannelConfigSection`）

- **Telegram**：开关 + 展开配置（Bot Token + Chat ID）；当前开关打开时 toast 提示「功能开发中」，不允许启用
- **钉钉机器人**：开关 + 展开配置（Webhook URL + 加签密钥）；启用时 Webhook URL 必填
- **保存按钮**：校验通过后调 `RemoteClawService.updateDingtalkConfig()` + `ConfigService.saveRemoteClawConfig()`

### 待审批请求卡片（`PendingRequestCard`）

桌面端会列出所有 pending 请求，并在其他渠道（Claude 本体弹窗、钉钉、Telegram）已审批后实时更新卡片状态。

**状态说明：**

| 状态 | `decision` 值 | 卡片表现 |
|------|--------------|---------|
| 等待中 | `pending` | 正常亮度，底部显示「✅ 同意」「❌ 拒绝」操作按钮 |
| 已同意 | `allow` | 60% 透明度（`AnimatedOpacity`），底部显示绿色「✓ 已同意」徽章 |
| 已拒绝 | `deny` | 60% 透明度，底部显示红色「✗ 已拒绝」徽章 |

**实现原理：**

```
用户在 Claude 本体 / 钉钉 / Telegram 审批
  ↓ POST /action/allow/:id 或 /action/deny/:id
RemoteClawService._applyDecision(id, decision)
  ↓ 更新 PermissionRequest.decision 字段
  ↓ notifyListeners()
Consumer<RemoteClawService>
  ↓ 触发 PendingRequestCard rebuild
  ↓ _isResolved = true → 显示已审批徽章，隐藏操作按钮
```

**注意**：请求在 `_pendingRequests` 中保留，直到 Hook 脚本 `GET /decision/:id` 轮询到 resolved 后才被移除。因此卡片在已审批状态下仍可见（带透明度），而不是立即消失，给用户明确的视觉反馈。

**关键 getter：**
```dart
bool get _isResolved => widget.request.decision != PermissionDecision.pending;
bool get _isAllowed  => widget.request.decision == PermissionDecision.allow;
```

---

## 已知限制与未来扩展

| 限制 | 说明 | 扩展方向 |
|------|------|---------|
| 钉钉按钮需可访问地址 | 手机端需填 Tailscale IP 才能从外网点击 | ✅ 已实现「回调地址」输入框，用户填 Tailscale IP 即可 |
| 电脑端钉钉点 Tailscale IP 失败 | Tailscale IP 是对外暴露的虚拟 IP，本机浏览器/钉钉访问自身 Tailscale IP 可能因路由策略失败 | ✅ 已通过「本机走 localhost」开关 + 额外「电脑端」按钮解决 |
| Telegram 长轮询 2 秒延迟 | 实时性略差 | 配置公网 HTTPS 后切换 Webhook 模式（入口已预留） |
| Telegram 推送未完整实现 | 当前开关打开时提示「开发中」 | 补充 TelegramChannel 审批流（UI 侧拦截已就绪，服务层待完善） |
| 内存队列 | 重启服务后 pending 请求丢失 | 可持久化到 SQLite（低优先级） |

---

## 架构决策记录（ADR）

### ADR-1：HTTP Server 绑定地址从 127.0.0.1 改为 0.0.0.0

**背景**：初始实现将 Server 绑定在 `127.0.0.1`（loopback only）。当用户使用 Tailscale 组网后，钉钉消息中的回调 URL 形如 `http://100.111.x.x:8099/action/allow/...`，但服务并未监听 Tailscale 网卡（`utun` 系列），导致手机和电脑端钉钉均无法连接（`ERR_CONNECTION_REFUSED`）。

**决策**：改为 `InternetAddress.anyIPv4`（即 `0.0.0.0`），监听所有网卡，包括：
- `127.0.0.1`（loopback）
- Tailscale 虚拟网卡（`100.x.x.x`）
- 局域网网卡（`192.168.x.x`）

**影响**：服务监听范围扩大。因为这是只在本机运行的工具服务，且只处理本地 Hook 请求，安全风险可接受。CORS 头同步改为 `Access-Control-Allow-Origin: *`。

---

### ADR-2：电脑端审批走 localhost 而非 Tailscale IP

**背景**：Claude Code、MCP Switch、钉钉桌面版三者运行在同一台 Mac 上。但当用户配置的「回调地址」为 Tailscale IP 时，电脑端钉钉点击按钮会通过 Tailscale IP 访问本机服务，可能因 Tailscale 路由策略或 Clash TUN 模式导致连接失败。

**决策**：在 `DingtalkChannel` 中增加 `localHostAddress` 可选参数。当非 null 时，ActionCard 额外追加「✅ 同意（电脑端）」「❌ 拒绝（电脑端）」两个按钮，使用 `localhost` 作为回调地址。由此：
- 手机端：点击「✅ 同意」→ 走 Tailscale IP，通过 Tailscale 网络回调本机
- 电脑端：点击「✅ 同意（电脑端）」→ 走 `localhost`，无需经过任何网络

**开关**：UI 上提供「本机走 localhost」开关（默认开启），对应 `RemoteClawService._useLocalCallback` 和 `rc_use_local_callback` 持久化键。

---

### ADR-3：利用 _sharedServer 静态字段跨热重启优雅复用端口

**背景**：Flutter 开发过程中高频使用热重启（Hot Restart，`R` 键）。热重启会重新执行 `main()` 组装 Widget 树并创建新的 `RemoteClawService` 实例。然而，底层的 Dart VM 进程并没有被杀死，所以**静态字段和挂载在其上的 Socket 资源也会一直存活，并持续监听 `8099` 端口**。如果新实例盲目调用 `shelf_io.serve` 重新绑定 IP 和端口，会立即抛出致命错误：
```
SocketException: Failed to create server socket (OS Error: Address already in use, errno = 48)
```

**曾用方案与隐患（已弃用）**：
早期我们使用了「强行关闭重绑」或「系统层用 `lsof | kill -9` 强杀残留」甚至 `_sharedServer.close(force: false)` 来试图释放端口。这些方式的副作用非常明显：
1. `close(force: false)` 等待连接自然回落，会导致热重启在有长连接（如长轮询）时长时间阻塞挂死。
2. `lsof | kill -9` 会滥用系统层面的进程清理，甚至容易引发前台终端由于 Zsh job control 问题而收到 `SIGTTIN` 导致 Flutter 进程 Suspended 的各类连锁反应。

**最终决策（最佳实践）**：
我们采用服务器框架处理热重载的最标准做法：**无缝复用存留的 Socket 监听**。
将 `HttpServer` 实例提升为静态字段 `_sharedServer`：
```dart
static HttpServer? _sharedServer;

Future<void> start() async {
  if (_isRunning) return;
  try {
    _rebuildChannels();
    
    // 如果没有被初始过，才真正去建立系统底层的 TCP 监听
    if (_sharedServer == null) {
      final router = _buildRouter();
      final handler = const Pipeline()
          .addMiddleware(_corsMiddleware())
          .addHandler(router.call);
      _sharedServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      LoggerService.info('RemoteClaw: HTTP server started on 0.0.0.0:$_port');
    } else {
      // 从 Hot Restart 重启醒来，什么都不用干，Server及其底层的Socket还在！
      LoggerService.info('RemoteClaw: Hot-restart detected, reusing existing server on port $_port');
    }

    _isRunning = true;
    _lastError = null;
    // ...
}
```

**效果**：热重启后，新诞生的 `RemoteClawService` 实例可以直接“认领”依然存活的静态 `_sharedServer`，完全不需要执行代价昂贵的 `close` 操作或申请端口绑定。整个复用过程瞬间完成，不仅 100% 杜绝了 `errno = 48` 错误，还保障了原有长连接通讯不被暴力阻断，提升了整个进程在开发模式下的稳定性。
