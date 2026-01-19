# Windows PATH 环境变量继承问题

## 问题背景

在 MCP Switch 的 Windows 版本中，用户安装 Node.js 后点击"一键安装 Codex/Gemini"按钮时，会报错：
```
npm: 无法将'npm'项识别为 cmdlet、函数、脚本文件或可运行程序的名称
```

即使用户已经安装了 Node.js，并且在系统 PATH 中可以正常使用 `npm` 命令。

## 根本原因

### 1. Windows 进程环境变量继承机制

Windows 进程在启动时会从父进程继承环境变量，这是一个**一次性的快照**：

```
系统启动 → Explorer.exe 继承系统 PATH → MCP Switch 继承 Explorer 的 PATH
                                              ↓
                              此时 PATH 是应用启动时的值，不会动态更新
```

当用户在 MCP Switch 运行期间安装 Node.js 时：
- 系统 PATH 已更新（包含 `C:\Program Files\nodejs\`）
- 但 MCP Switch 进程中的 `Platform.environment['PATH']` 仍然是**旧值**
- 即使用户重启 MCP Switch，如果从任务栏/开始菜单启动，可能仍继承旧的 Explorer 环境

### 2. Dart 的 Platform.environment 是静态快照

```dart
// 这是进程启动时的快照，不会动态更新
final path = Platform.environment['PATH'];
```

### 3. Windows PATH 大小写不敏感

Windows 文件系统和环境变量名大小写不敏感，但 Dart 的 `Map` 是大小写敏感的：

```dart
// 可能存在的情况
environment['PATH']  // null
environment['Path']  // 有值

// 路径比较也要注意
'C:\Program Files\nodejs'.contains('C:\PROGRAM FILES\NODEJS')  // false!
```

## 解决方案

### 使用 PowerShell API 读取最新 PATH

通过 `[Environment]::GetEnvironmentVariable` API 可以读取**注册表中最新的 PATH**，而不是当前进程继承的旧值：

```dart
// 读取系统 PATH（Machine 级别）
final machineResult = await Process.run(
  'powershell',
  ['-NoProfile', '-Command', "[Environment]::GetEnvironmentVariable('Path', 'Machine')"],
  runInShell: true,
);

// 读取用户 PATH（User 级别）
final userResult = await Process.run(
  'powershell',
  ['-NoProfile', '-Command', "[Environment]::GetEnvironmentVariable('Path', 'User')"],
  runInShell: true,
);
```

### 合并时使用大小写不敏感比较

```dart
final paths = <String>[];
final pathsLower = <String>{}; // 用于去重（小写）

for (final p in userPath.split(';')) {
  final trimmed = p.trim();
  if (trimmed.isNotEmpty) {
    final lower = trimmed.toLowerCase();
    if (!pathsLower.contains(lower)) {
      paths.add(trimmed);
      pathsLower.add(lower);
    }
  }
}
```

### 传递给子进程时替换 PATH

```dart
final env = Map<String, String>.from(Platform.environment);

// 删除旧的 PATH（可能是 Path 或 PATH）
env.removeWhere((key, value) => key.toLowerCase() == 'path');

// 设置新的 PATH
env['PATH'] = latestPath;

// 使用更新后的环境变量启动子进程
await Process.start('npm', ['install', '-g', '@openai/codex'], environment: env);
```

## 关键代码位置

- [platform_utils.dart](../../lib/utils/platform_utils.dart) - `getWindowsLatestPath()`, `getUpdatedEnvironment()`

## 第二个坑：额外环境变量覆盖 PATH

### 问题现象

日志显示 PATH 已正确设置（包含 nodejs），但最终检查时又不包含了：

```
💡 [getUpdatedEnvironment] 已设置新 PATH: 607 字符
💡 [getUpdatedEnvironment] ✅ 更新后 PATH 包含 nodejs
🐛 [getUpdatedEnvironment] 合并了 100 个额外环境变量   <-- 问题在这里！
🐛 [Codex安装] 找到环境变量 key=PATH, 长度=832        <-- 607 变成 832 了
💡 [Codex安装] PATH 包含 nodejs: false               <-- nodejs 没了！
```

### 根本原因

`PlatformCommandsConfig.xxxEnvironment` 包含了 `Platform.environment` 的完整副本（包括旧的 PATH）。当使用 `env.addAll(extraEnv)` 合并时，旧的 PATH 会**覆盖**我们刚设置的新 PATH。

```dart
// 错误写法
env.addAll(extraEnv);  // extraEnv 中的 PATH 会覆盖我们的新 PATH！

// 正确写法
for (final entry in extraEnv.entries) {
  if (entry.key.toLowerCase() == 'path') {
    continue;  // 跳过 PATH，不让它覆盖
  }
  env[entry.key] = entry.value;
}
```

### 教训

合并环境变量时，必须**保护**关键变量不被覆盖。特别是 PATH 这种我们刚从注册表读取并设置的变量。

## 指导思想

### 1. 不要假设环境变量是最新的

在 Windows 上执行依赖外部工具（npm, node, python 等）的操作时，**始终从注册表重新读取 PATH**。

### 2. Windows 特殊处理

```dart
if (Platform.isWindows) {
  // Windows 需要特殊处理
  // 1. 从注册表读取最新 PATH
  // 2. 大小写不敏感比较
  // 3. 合并系统 PATH 和用户 PATH
}
```

### 3. 调试日志很重要

在涉及环境变量的操作中，添加详细日志：
- PATH 读取来源（注册表 vs 进程继承）
- PATH 长度和项数
- 关键路径是否存在（如 nodejs）

### 4. 缓存策略

可以缓存读取的 PATH（避免频繁调用 PowerShell），但要：
- 设置合理的过期时间（如 5 分钟）
- 提供手动清除缓存的方法
- 在安装新软件后主动清除缓存

## 相关问题排查清单

当 Windows 上出现"找不到命令"类错误时：

1. ☐ 确认命令确实已安装（在系统终端中可用）
2. ☐ 检查系统 PATH 是否包含该命令的目录
3. ☐ 检查 MCP Switch 中读取的 PATH 是否是最新的
4. ☐ 检查 PATH 合并逻辑是否正确（大小写）
5. ☐ 检查传递给子进程的 environment 是否正确

## 完整问题总结表

| 坑 | 现象 | 根因 | 解决方案 | 耗时 |
|----|------|------|----------|------|
| **坑1** | npm 命令找不到 | `Platform.environment` 是启动时快照 | 用 PowerShell 从注册表读取最新 PATH | 2h |
| **坑2** | 大小写不敏感去重失败 | `List.contains()` 大小写敏感 | 用 `Set<String>` 存小写路径去重 | 30min |
| **坑3** | 设置好的 PATH 又丢了 | `env.addAll(extraEnv)` 覆盖了 PATH | 合并时跳过 PATH 相关 key | 1h |

## 黄金法则：Windows 环境变量处理

```dart
// ❌ 错误：直接使用 Platform.environment
final path = Platform.environment['PATH'];  // 可能是旧值！

// ✅ 正确：从注册表读取最新值
final path = await getWindowsLatestPath();  // 始终最新

// ❌ 错误：大小写敏感比较
if (paths.contains(newPath)) { ... }  // Windows 路径大小写不敏感！

// ✅ 正确：小写比较
if (pathsLower.contains(newPath.toLowerCase())) { ... }

// ❌ 错误：直接合并环境变量
env.addAll(extraEnv);  // 会覆盖 PATH！

// ✅ 正确：保护关键变量
for (final entry in extraEnv.entries) {
  if (entry.key.toLowerCase() == 'path') continue;
  env[entry.key] = entry.value;
}
```

## 核心教训

1. **Windows 和 macOS/Linux 完全不同** - 不要假设跨平台代码能直接工作
2. **环境变量是静态快照** - 进程启动后不会自动更新
3. **大小写敏感是隐形杀手** - Windows 不敏感，但 Dart Map/List 敏感
4. **合并操作要小心** - `addAll` 会覆盖已有值
5. **日志是救命稻草** - 没有详细日志根本找不到问题

## 检查清单（新功能必看）

开发涉及 Windows 子进程/外部命令的功能时：

- [ ] 是否需要从注册表读取最新 PATH？
- [ ] 路径比较是否使用了 `toLowerCase()`？
- [ ] 合并环境变量时是否保护了关键变量？
- [ ] 是否添加了足够的调试日志？
- [ ] 是否在 Windows 真机上测试过？

## 参考资料

- [Windows Environment Variables](https://docs.microsoft.com/en-us/windows/win32/procthread/environment-variables)
- [.NET Environment.GetEnvironmentVariable](https://docs.microsoft.com/en-us/dotnet/api/system.environment.getenvironmentvariable)
