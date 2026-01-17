# 终端命令执行功能

## 概述

通过 TerminalService 打开侧边终端面板，执行 Claude CLI 命令。适用于需要用户交互或查看执行过程的操作。

## 核心服务

使用 `TerminalService`（通过 Provider 注入）来控制终端面板和执行命令。

## 使用场景

1. **添加市场** - `claude plugin marketplace add <repo>`
2. **更新市场** - `claude plugin marketplace update <name>`
3. **安装插件** - `claude plugin install <plugin>@<marketplace>`

## 核心代码模板

```dart
Future<void> _executeTerminalCommand(String command) async {
  // 获取终端服务
  final terminalService = context.read<TerminalService>();

  // 开启悬浮终端图标
  terminalService.setFloatingTerminal(true);

  // 打开全局终端面板
  terminalService.openTerminalPanel();

  // 稍微延迟让终端初始化
  await Future.delayed(const Duration(milliseconds: 500));

  // 执行命令
  terminalService.sendCommand(command);
}
```

## 实际应用示例

### 1. 添加市场

```dart
Future<void> _addMarketplace(PresetMarketplace marketplace) async {
  final terminalService = context.read<TerminalService>();

  terminalService.setFloatingTerminal(true);
  Navigator.of(context).pop(); // 关闭当前弹窗
  terminalService.openTerminalPanel();

  await Future.delayed(const Duration(milliseconds: 500));
  terminalService.sendCommand('claude plugin marketplace add ${marketplace.repo}');

  widget.onAdded(); // 通知刷新
}
```

### 2. 更新市场

```dart
Future<void> _updateMarketplace(String marketplaceName) async {
  final terminalService = context.read<TerminalService>();

  terminalService.setFloatingTerminal(true);
  terminalService.openTerminalPanel();

  await Future.delayed(const Duration(milliseconds: 500));
  terminalService.sendCommand('claude plugin marketplace update $marketplaceName');
}
```

### 3. 安装插件

```dart
Future<void> _installPlugin(String pluginName) async {
  final terminalService = context.read<TerminalService>();

  terminalService.setFloatingTerminal(true);
  Navigator.of(context).pop(); // 关闭当前弹窗
  terminalService.openTerminalPanel();

  await Future.delayed(const Duration(milliseconds: 500));

  final marketplaceName = widget.marketplace.name;
  terminalService.sendCommand('claude plugin install $pluginName@$marketplaceName');

  widget.onInstalled(); // 通知刷新
}
```

## TerminalService 常用方法

| 方法 | 说明 |
|------|------|
| `setFloatingTerminal(bool)` | 开启/关闭悬浮终端图标 |
| `openTerminalPanel()` | 打开终端侧边面板 |
| `sendCommand(String)` | 发送命令到终端执行 |
| `isTerminalPanelOpen` | 获取终端面板是否打开 |
| `addListener(callback)` | 监听终端状态变化 |
| `removeListener(callback)` | 移除监听器 |

## 依赖

```dart
import 'package:provider/provider.dart';
import '../services/terminal_service.dart';
```

## 注意事项

1. **延迟执行** - 打开终端面板后需要延迟 500ms 等待初始化完成
2. **关闭弹窗** - 如果从弹窗触发，通常需要先关闭弹窗再打开终端
3. **刷新数据** - 命令执行后通过回调通知父组件刷新数据
4. **监听状态** - 可以监听终端关闭事件来自动刷新数据

## 监听终端关闭自动刷新

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _terminalService = context.read<TerminalService>();
    _terminalService!.addListener(_onTerminalStateChanged);
    _wasTerminalOpen = _terminalService!.isTerminalPanelOpen;
  });
}

@override
void dispose() {
  _terminalService?.removeListener(_onTerminalStateChanged);
  super.dispose();
}

void _onTerminalStateChanged() {
  if (!mounted || _terminalService == null) return;

  final isOpen = _terminalService!.isTerminalPanelOpen;

  // 当终端从打开变成关闭时，刷新数据
  if (_wasTerminalOpen && !isOpen) {
    _loadData();
  }
  _wasTerminalOpen = isOpen;
}
```

## Claude CLI 常用命令

| 命令 | 说明 |
|------|------|
| `claude plugin marketplace add <repo>` | 添加市场 |
| `claude plugin marketplace update [name]` | 更新市场（不指定 name 则更新所有） |
| `claude plugin install <plugin>@<marketplace>` | 安装插件 |
| `claude plugin uninstall <plugin>` | 卸载插件 |
| `claude plugin list` | 列出已安装插件 |
| `claude plugin marketplace list` | 列出已添加市场 |
