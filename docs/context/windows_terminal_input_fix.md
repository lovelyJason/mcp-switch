# Windows Terminal 输入问题修复

## 问题描述

在 Windows 平台上，MCP Switch 内置终端（使用 `xterm.dart` + `flutter_pty`）无法输入字符，只有回车键有反应。

## 根本原因

1. **焦点问题**：`TerminalView` 没有正确获得键盘焦点
2. **键盘模式**：默认的键盘处理模式在 Windows 桌面应用上不适用
3. **字体问题**：使用了 macOS 专属字体 `Menlo`，Windows 上没有

## 解决方案

### 1. 设置 `hardwareKeyboardOnly: true`

桌面应用（Windows/macOS/Linux）应该只使用硬件键盘，不需要虚拟键盘支持：

```dart
TerminalView(
  // Windows 桌面应用只使用硬件键盘
  hardwareKeyboardOnly: Platform.isWindows || Platform.isMacOS || Platform.isLinux,
  // ...
)
```

### 2. 显式管理焦点

添加 `FocusNode` 并在终端面板打开后请求焦点：

```dart
class _GlobalTerminalPanelState extends State<GlobalTerminalPanel> {
  final FocusNode _terminalFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 初始化后请求焦点
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _terminalFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _terminalFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      focusNode: _terminalFocusNode,
      autofocus: true,
      // ...
    );
  }
}
```

### 3. 跨平台字体

使用平台相关的等宽字体：

```dart
textStyle: TerminalStyle(
  // Windows 用 Consolas，macOS 用 Menlo
  fontFamily: Platform.isWindows ? 'Consolas' : 'Menlo',
  fontSize: 13,
),
```

## 相关文件

- `lib/ui/components/global_terminal_panel.dart` - 全局终端面板
- `lib/services/terminal_service.dart` - 终端服务

## 已知限制

- `flutter_pty` 在 Windows **Debug 模式**下可能有问题，建议用 Release 模式测试
- 参考：[flutter_pty GitHub Issues](https://github.com/TerminalStudio/flutter_pty/issues)

## 关键代码片段

```dart
// global_terminal_panel.dart
import 'dart:io';

class _GlobalTerminalPanelState extends State<GlobalTerminalPanel> {
  final FocusNode _terminalFocusNode = FocusNode();

  // ... initState 中延迟请求焦点 ...

  @override
  Widget build(BuildContext context) {
    return TerminalView(
      service.terminal,
      controller: service.terminalController,
      focusNode: _terminalFocusNode,
      autofocus: true,
      backgroundOpacity: 0,
      hardwareKeyboardOnly: Platform.isWindows || Platform.isMacOS || Platform.isLinux,
      textStyle: TerminalStyle(
        fontFamily: Platform.isWindows ? 'Consolas' : 'Menlo',
        fontSize: 13,
      ),
      theme: TerminalThemes.defaultTheme,
    );
  }
}
```
