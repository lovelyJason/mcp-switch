# 全局出站代理功能设计文档

## 概述

全局出站代理为 MCP Switch 提供可选的网络代理配置，用于解决国内访问 GitHub 等外部服务时的网络问题。代理配置存储在本地，各 Service 在需要时**主动**获取代理 Client，而非全局拦截所有请求。

参考项目：cc-switch 的「设置 → 全局出站代理」功能。

---

## 架构设计

```
┌─────────────┐     save      ┌───────────────┐
│  Settings UI │ ──────────── │ ConfigService  │  (SharedPreferences)
│  (Advanced)  │              │  proxy_url     │
└─────────────┘              │  proxy_username│
                              │  proxy_password│
                              └───────┬───────┘
                                      │ read
                              ┌───────▼───────┐
                              │  ProxyService  │
                              │                │
                              │ createProxied  │
                              │   Client()     │
                              └───────┬───────┘
                                      │ http.Client
            ┌─────────────────────────┼─────────────────────────┐
            ▼                         ▼                         ▼
    UpdateService           SkillsService             TranslationEngine
    (GitHub 更新)           (Skills 下载)              (翻译 API)
```

核心特点：**代理是可选的、按需的**，不影响不需要代理的请求。

---

## 数据存储

### ConfigService（SharedPreferences）

| Key | 类型 | 说明 |
|-----|------|------|
| `proxy_url` | String | 代理地址，如 `http://127.0.0.1:7890` 或 `socks5://127.0.0.1:1080` |
| `proxy_username` | String | 可选认证用户名 |
| `proxy_password` | String | 可选认证密码 |

### ConfigService 方法

```dart
// Getters
String get proxyUrl;
String get proxyUsername;
String get proxyPassword;
bool get hasProxy;  // proxyUrl.isNotEmpty

// 保存
Future<void> saveProxyConfig({required String url, String username, String password});

// 清除
Future<void> clearProxyConfig();
```

---

## ProxyService

**文件**：`lib/services/proxy_service.dart`

### 在其他文件中使用代理

```dart
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/proxy_service.dart';

// 方式1：通过 Provider 获取 ConfigService
final configService = Provider.of<ConfigService>(context, listen: false);
final proxyService = ProxyService(configService);
final client = proxyService.createProxiedClient();
final response = await client.get(Uri.parse('https://api.github.com/...'));
client.close();

// 方式2：直接传入 ConfigService 实例（Service 层常用）
class MyService {
  final ConfigService _configService;
  MyService(this._configService);

  Future<void> fetchData() async {
    final proxy = ProxyService(_configService);
    final client = proxy.createProxiedClient();
    try {
      final response = await client.get(Uri.parse('https://...'));
      // 处理响应
    } finally {
      client.close();
    }
  }
}
```

### 支持的代理类型

| Scheme | 说明 | 实现方式 |
|--------|------|----------|
| `http://` | HTTP 代理 | `HttpClient.findProxy` → `IOClient` |
| `https://` | HTTPS 代理 | 同上 |
| `socks5://` | SOCKS5 代理 | `socks5_proxy` 包 → `SocksTCPClient.assignToHttpClient` |
| `socks5h://` | SOCKS5 + DNS 远程解析 | 同上 |

### 其他方法

| 方法 | 说明 |
|------|------|
| `testProxy(url, {username, password})` | 测试代理连通性，访问 `api.github.com`，返回 `ProxyResult` |
| `scanLocalProxies()` | 扫描 8 个常见本地端口（7890/1080/8080 等），返回 `List<ScannedProxy>` |
| `isValidProxyUrl(url)` | 静态方法，校验 URL 格式 |

---

## UI

**文件**：`lib/ui/pages/settings/widgets/proxy_settings_section.dart`

**位置**：设置页 → Advanced Tab → 底部（DeepL API Key 下方）

### 界面结构

- **可折叠卡片**：标题「全局出站代理」 + 描述 + 展开/收起箭头
- **URL 输入框** + 操作按钮行：
  - 扫描（`Icons.search`）— 扫描本地代理端口
  - 测试（`Icons.speed`）— 验证代理连通性
  - 清除（`Icons.close`）— 清空所有字段
  - 保存（橙色 FilledButton）— 保存配置
- **认证行**：用户名 + 密码（带眼睛切换），并排布局

---

## 依赖

- `socks5_proxy: ^2.1.1` — SOCKS5 代理客户端支持

---

## 国际化 Key

| Key | 中文 | 英文 |
|-----|------|------|
| `proxy_title` | 全局出站代理 | Outbound Proxy |
| `proxy_description` | 配置 MCP Switch 访问外部 API 时使用的代理 | Configure proxy for outbound API requests |
| `proxy_detail_desc` | 代理部分网络请求...留空表示直连 | Proxy selected network requests... |
| `proxy_url_hint` | http://127.0.0.1:7890 / socks5://127.0.0.1:1080 | (same) |
| `proxy_username_hint` | 用户名（可选） | Username (optional) |
| `proxy_password_hint` | 密码（可选） | Password (optional) |
| `proxy_save/clear/scan/test` | 保存/清除/扫描/测试 | Save/Clear/Scan/Test |
| `proxy_saved/cleared` | 配置已保存/已清除 | Configuration saved/cleared |
| `proxy_test_success` | 代理连通 ({ms}ms) | Proxy connected ({ms}ms) |
| `proxy_test_failed` | 代理连接失败 | Proxy connection failed |
| `proxy_scan_title/empty` | 发现本地代理/未发现 | Local Proxies Found/No proxies found |
| `proxy_invalid_url` | 代理地址格式不正确 | Invalid proxy URL format |

---

## 后续集成（待实现）

以下 Service 可选择性使用 `ProxyService.createProxiedClient()`：

| Service | 文件 | 用途 |
|---------|------|------|
| UpdateService | `update_service.dart` | GitHub 版本检查/下载 |
| CodexSkillsService | `codex_skills_service.dart` | Codex Skills 列表拉取 |
| GeminiSkillsService | `gemini_skills_service.dart` | Gemini Skills 列表拉取 |
| CustomSkillInstallDialog | `custom_skill_install_dialog.dart` | Skill ZIP 下载 |
| TranslationEngines | `translation_engines.dart` | DeepL/翻译 API |

---

## 文件清单

| 文件 | 变更类型 |
|------|----------|
| `lib/services/config_service.dart` | 修改 — 新增 proxy 配置项 |
| `lib/services/proxy_service.dart` | **新建** — 代理 Client 创建 + 扫描 + 测试 |
| `lib/ui/pages/settings/widgets/proxy_settings_section.dart` | **新建** — 代理设置 UI 组件 |
| `lib/ui/pages/settings/settings_screen.dart` | 修改 — Advanced Tab 引入代理组件 |
| `lib/l10n/locales/zh.json` | 修改 — 新增代理国际化 |
| `lib/l10n/locales/en.json` | 修改 — 新增代理国际化 |
| `pubspec.yaml` | 修改 — 新增 `socks5_proxy` 依赖 |
