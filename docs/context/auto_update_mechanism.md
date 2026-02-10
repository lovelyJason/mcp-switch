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

### 3.4 macOS 自动更新流程

```
performAutoUpdate(zipUrl)
    │
    ▼
1. 下载 ZIP 文件到临时目录
    │
    ▼
2. 解压到 {tempDir}/update_extract/
    │
    ▼
3. 查找 "MCP Switch.app" 文件夹
    │
    ▼
4. 获取当前应用路径（向上遍历找到 .app 目录）
    │
    ▼
5. 创建替换脚本 update_script.sh:
   ┌─────────────────────────────────────┐
   │  sleep 2                            │
   │  rm -rf "{当前应用路径}"              │
   │  mv "{新应用路径}" "{当前应用路径}"    │
   │  open "{当前应用路径}"                │
   └─────────────────────────────────────┘
    │
    ▼
6. 以 detached 模式执行脚本，然后 exit(0)
```

---

## 四、Provider 集成

### 4.1 注册 (main.dart)

```dart
// Initialize Update Service（自动检测更新）
final updateService = UpdateService();
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

## 六、国际化文案

| Key | 中文 | English |
|-----|------|---------|
| `check_for_updates` | 检查更新 | Check for Updates |
| `current_latest` | 当前已是最新版本 | Already up to date |
| `new_version_available` | 发现新版本: {version} | New version available: {version} |
| `downloading_update` | 正在下载更新... | Downloading update... |
| `update_downloaded` | 更新已准备就绪 | Update ready |
| `install_restart` | 安装并重启 | Install & Restart |
| `update_failed` | 更新失败 | Update failed |
| `later` | 稍后 | Later |
| `skip_version` | 跳过此版本 | Skip This Version |

---

## 七、关键文件

| 文件 | 说明 |
|------|------|
| `lib/services/update_service.dart` | 更新检测核心服务（UpdateService + UpdateInfo） |
| `lib/main.dart` | 服务初始化和 Provider 注册 |
| `lib/ui/pages/settings/settings_screen.dart` | 手动检测按钮和更新对话框 UI |
| `lib/l10n/locales/zh.json` | 中文国际化文案 |
| `lib/l10n/locales/en.json` | 英文国际化文案 |

---

## 八、已知限制与注意事项

### 8.1 平台限制
- 自动更新（下载 ZIP → 替换 → 重启）仅支持 **macOS**
- Windows 用户会跳转到 GitHub Release 页面手动下载

### 8.2 网络要求
- 需要能访问 `api.github.com`，国内可能需要代理
- API 请求超时时间为 10 秒

### 8.3 GitHub API 限制
- 未认证请求限制：60 次/小时
- 24 小时检测一次不会触发限流

### 8.4 自动更新安全性
- 替换脚本使用 `sleep 2` 等待应用完全退出
- 脚本以 detached 模式运行，不依赖父进程
- 替换后自动打开新版本应用

---

*文档创建时间：2026-02-10*
*适用版本：MCP Switch v1.x*
