# 自动更新检测机制

> 本文档记录 MCP Switch 应用的自动更新检测、版本比较、macOS 自动更新的完整流程设计。

---

## 一、功能特性

| 特性 | 说明 |
|------|------|
| **启动时自动检测** | 延迟 3 秒后检测，避免阻塞启动 |
| **定时后台检测** | 每 24 小时自动检测一次 |
| **智能跳过** | 用户可以选择"跳过此版本"，下次检测不再提示 |
| **版本比较** | 语义化版本比较（1.0.9 > 1.0.8） |
| **macOS 自动更新** | 下载 ZIP → 解压 → 替换 → 重启 |
| **手动检测** | 设置页面保留手动检测按钮 |

---

## 二、整体架构

### 2.1 核心流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         应用启动 (main.dart)                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              UpdateService.init()                                        │
│              1. 检查自动检测开关（SharedPreferences）                      │
│              2. 延迟 3 秒后执行 _checkIfNeeded()                          │
│              3. 启动定时检测 Timer.periodic (24h)                         │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              _checkIfNeeded()                                            │
│              检查距上次检测是否超过 24 小时                                 │
│              → 超过则调用 checkForUpdates(silent: true)                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              checkForUpdates()                                           │
│              1. 请求 GitHub Releases API                                 │
│              2. 解析最新版本号、Release Notes、下载链接                    │
│              3. 与当前版本比较                                            │
│              4. 检查是否为已跳过的版本                                     │
│              5. 更新 _availableUpdate 并 notifyListeners()               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        设置页面 UI 响应                                   │
├─────────────────────────────────────────────────────────────────────────┤
│  有新版本 → 弹出更新对话框                                                │
│  ├── "跳过此版本" → skipVersion() → 持久化跳过记录                        │
│  ├── "稍后" → 关闭对话框                                                 │
│  └── "安装并重启" / "Download"                                           │
│      ├── macOS 且有 ZIP → performAutoUpdate() → 自动更新                  │
│      └── 其他情况 → 打开 GitHub Release 页面                              │
├─────────────────────────────────────────────────────────────────────────┤
│  无新版本 → Toast 提示"当前已是最新版本"                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 数据模型

```dart
/// 更新信息模型
class UpdateInfo {
  final String version;       // 版本号（如 v1.0.9）
  final String notes;         // Release Notes
  final String? downloadUrl;  // macOS ZIP 下载地址
  final String releaseUrl;    // GitHub Release 页面地址

  /// 是否支持自动更新（有 ZIP 下载地址）
  bool get supportsAutoUpdate => downloadUrl != null;
}
```

---

## 三、UpdateService 详解

**文件位置**：`lib/services/update_service.dart`

### 3.1 持久化存储键

| Key | 类型 | 说明 |
|-----|------|------|
| `update_last_check_time` | int | 上次检测时间戳（毫秒） |
| `update_auto_check_enabled` | bool | 自动检测开关（默认 true） |
| `update_skipped_version` | String | 用户选择跳过的版本号 |

### 3.2 核心常量

```dart
static const Duration _checkInterval = Duration(hours: 24);
static const String _repoUrl =
    'https://api.github.com/repos/lovelyJason/mcp-switch/releases/latest';
```

### 3.3 版本比较算法

```dart
/// 标准化版本号：去除 v 前缀和 build number
/// "v1.0.8+3" → "1.0.8"
String _normalizeVersion(String version) {
  return version.replaceAll('v', '').split('+')[0];
}

/// 语义化版本比较
/// 返回 >0 表示 v1 > v2，0 表示相等，<0 表示 v1 < v2
int _compareVersions(String v1, String v2) {
  final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

  final maxLen = max(parts1.length, parts2.length);
  for (var i = 0; i < maxLen; i++) {
    final p1 = i < parts1.length ? parts1[i] : 0;
    final p2 = i < parts2.length ? parts2[i] : 0;
    if (p1 != p2) return p1 - p2;
  }
  return 0;
}
```

### 3.4 代理支持

`UpdateService` 接受可选的 `ConfigService` 注入。如果用户在「设置→高级→全局出站代理」配置了代理地址，`checkForUpdates()` 和 `performAutoUpdate()` 都会通过 `ProxyService` 创建代理 HTTP Client 访问 GitHub，解决国内网络问题。

```dart
UpdateService({ConfigService? configService});

http.Client _createClient() {
  if (_configService != null && _configService.hasProxy) {
    return ProxyService(_configService).createProxiedClient();
  }
  return http.Client();
}
```

### 3.5 更新阶段状态机

```
UpdatePhase: idle → checking → downloading → extracting → restarting
                                                           ↓
                                               error（任意阶段失败）
```

| 阶段 | phase | progress | UI 表现 |
|------|-------|----------|---------|
| 空闲 | `idle` | 0 | 无 |
| 检查中 | `checking` | 0 | 转圈 + "准备下载..." |
| 下载中 | `downloading` | 0~1.0 | 确定进度圆环 + "正在下载更新 xx%" |
| 解压安装 | `extracting` | 1.0 | 转圈 + "正在解压安装..." |
| 即将重启 | `restarting` | 1.0 | 转圈 + "即将重启应用..." |
| 失败 | `error` | - | 错误提示 |

### 3.6 macOS 自动更新原理（5 步详解）

```
performAutoUpdate(zipUrl)
    │
    ▼
步骤 1: 流式下载 ZIP
    │  使用 http.Client.send() 获取 StreamedResponse
    │  逐 chunk 接收数据，实时计算 receivedBytes / totalBytes 更新进度
    │  （不是一次性 http.get 加载到内存，而是边下边写）
    │
    ▼
步骤 2: 写入临时文件
    │  将所有 chunks 拼接后写入 {tempDir}/update.zip
    │
    ▼
步骤 3: 调用系统 unzip 解压
    │  Process.run('unzip', ['-o', zipFile.path, '-d', extractDir.path])
    │  解压到 {tempDir}/update_extract/，里面包含 "MCP Switch.app" 目录
    │
    ▼
步骤 4: 定位当前 .app 路径
    │  Platform.resolvedExecutable 返回：
    │    /Applications/MCP Switch.app/Contents/MacOS/mcp_switch
    │  向上逐层回溯目录，直到找到以 .app 结尾的路径：
    │    /Applications/MCP Switch.app
    │
    ▼
步骤 5: 生成替换脚本 + 自杀重启
    │  生成 update_script.sh:
    │  ┌─────────────────────────────────────────────────┐
    │  │  #!/bin/bash                                    │
    │  │  sleep 2                    # 等当前 app 退出    │
    │  │  rm -rf "{旧 .app 路径}"     # 删掉旧版本         │
    │  │  mv "{新 .app 路径}" "{旧}"  # 新版本移到原位     │
    │  │  open "{.app 路径}"          # 启动新版本         │
    │  └─────────────────────────────────────────────────┘
    │
    │  关键原理：应用不能在运行时替换自身文件，
    │  所以启动一个 detached 子进程执行脚本，
    │  然后立即 exit(0) 杀掉自己。
    │  脚本因为 detached 模式不随父进程退出，
    │  sleep 2 秒后执行替换和重启。
    │
    ▼
    exit(0) → 应用退出 → 2s 后脚本替换 → open 启动新版本
```

**为什么需要 detached + sleep？**
- `detached` 模式使脚本进程独立于当前应用，父进程退出后子进程继续运行
- `sleep 2` 确保旧应用完全退出释放文件锁后，再执行 `rm -rf` 删除和 `mv` 替换
- `open` 命令是 macOS 特有的，等同于双击打开 .app 包

---

## 四、Provider 集成

### 4.1 注册 (main.dart)

```dart
// Initialize Update Service（自动检测更新，传入 configService 以支持代理）
final updateService = UpdateService(configService: configService);
updateService.init();

runApp(
  MultiProvider(
    providers: [
      // ... 其他 providers
      ChangeNotifierProvider.value(value: updateService),
    ],
    child: const McpSwitchApp(),
  ),
);
```

### 4.2 使用 (settings_screen.dart)

```dart
// 手动检测
Future<void> _checkForUpdates() async {
  final updateService = Provider.of<UpdateService>(context, listen: false);
  final update = await updateService.checkForUpdates();
  if (update != null) {
    _showUpdateDialog(update);
  } else {
    Toast.show(context, message: S.get('current_latest'), type: ToastType.success);
  }
}
```

---

## 五、更新对话框

### 5.1 三个操作按钮

| 按钮 | 操作 | 说明 |
|------|------|------|
| 跳过此版本 | `updateService.skipVersion(version)` | 持久化跳过，下次不再提示该版本 |
| 稍后 | `Navigator.pop(ctx)` | 关闭对话框，下次检测仍会提示 |
| 安装并重启 / Download | `performAutoUpdate()` 或 `launchUrl()` | macOS 有 ZIP 时自动更新，否则打开浏览器 |

### 5.2 ZIP 资源匹配规则

```dart
// 查找 macOS ZIP 下载地址
for (var asset in assets) {
  final name = asset['name'].toString().toLowerCase();
  if (name.endsWith('.zip') && name.contains('macos')) {
    downloadUrl = asset['browser_download_url'];
    break;
  }
}
```

GitHub Release 中的 asset 文件名需包含 `macos` 且以 `.zip` 结尾，例如：`mcp-switch-macos-v1.0.9.zip`

---

## 六、更新进度遮罩 UI

点击"安装并重启"后，不再只显示 Toast，而是弹出一个**全屏半透明遮罩 + 居中卡片弹窗**：

- 卡片内有 80px 的 `CircularProgressIndicator`
- **下载阶段**：显示确定进度（0%~100%），圆环中心显示百分比数字
- **其他阶段**：显示不确定进度（转圈），中心显示对应阶段图标
- 下方文字显示阶段名称和副标题提示
- 遮罩不可关闭（`barrierDismissible: false`），防止用户误操作
- 通过 `Consumer<UpdateService>` 监听 `phase` 和 `progress` 实时刷新

### 调试工具箱

Debug 工具箱新增 "Update Progress UI Demo" 按钮，点击后弹出 demo 版遮罩，使用 `AnimationController` 循环模拟各阶段动画，便于开发调试。

---

## 七、国际化文案

| Key | 中文 | English |
|-----|------|---------|
| `check_for_updates` | 检查更新 | Check for Updates |
| `checking_for_updates` | 正在检查更新...（含代理提示） | Checking for updates...（含代理提示） |
| `current_latest` | 当前已是最新版本 | Already up to date |
| `new_version_available` | 发现新版本: {version} | New version available: {version} |
| `downloading_update` | 正在下载更新... | Downloading update... |
| `update_downloading_progress` | 正在下载更新 {percent}% | Downloading update {percent}% |
| `update_extracting` | 正在解压安装... | Extracting and installing... |
| `update_preparing` | 准备下载... | Preparing download... |
| `update_restarting` | 即将重启应用... | Restarting app... |
| `update_downloaded` | 更新已准备就绪 | Update ready |
| `install_restart` | 安装并重启 | Install & Restart |
| `update_failed` | 更新失败 | Update failed |
| `later` | 稍后 | Later |
| `skip_version` | 跳过此版本 | Skip This Version |

---

## 八、关键文件

| 文件 | 说明 |
|------|------|
| `lib/services/update_service.dart` | 更新检测核心服务（UpdateService + UpdateInfo + UpdatePhase） |
| `lib/services/proxy_service.dart` | 代理 HTTP Client 创建（更新时如配了代理自动走代理） |
| `lib/services/config_service.dart` | 代理配置存储（proxyUrl / proxyUsername / proxyPassword） |
| `lib/main.dart` | 服务初始化和 Provider 注册 |
| `lib/ui/pages/settings/settings_screen.dart` | 手动检测按钮、更新对话框、更新进度遮罩 UI |
| `lib/ui/components/update_progress_overlay.dart` | 更新进度遮罩 Demo 版本（调试工具箱用） |
| `lib/ui/components/floating_debug_button.dart` | 调试工具箱（含 Update Progress UI Demo 按钮） |
| `lib/l10n/locales/zh.json` | 中文国际化文案 |
| `lib/l10n/locales/en.json` | 英文国际化文案 |

---

## 九、已知限制与注意事项

### 9.1 平台限制
- 自动更新（下载 ZIP → 替换 → 重启）仅支持 **macOS**
- Windows 用户会跳转到 GitHub Release 页面手动下载

### 9.2 网络要求
- 需要能访问 `api.github.com`，国内可能需要代理
- 检查更新超时 15 秒，下载超时 120 秒
- 如配置了代理（设置→高级→全局出站代理），会自动使用代理访问 GitHub

### 9.3 GitHub API 限制
- 未认证请求限制：60 次/小时
- 24 小时检测一次不会触发限流

### 9.4 自动更新安全性
- 替换脚本使用 `sleep 2` 等待应用完全退出
- 脚本以 detached 模式运行，不依赖父进程
- 替换后自动打开新版本应用
- 无签名验证，依赖 HTTPS 传输安全

---

*文档创建时间：2026-02-10*
*最后更新：2026-03-03（新增代理支持、流式下载进度、更新遮罩 UI）*
*适用版本：MCP Switch v1.x*
