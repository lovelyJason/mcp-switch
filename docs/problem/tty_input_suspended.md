# 终端 TTY 输入挂起问题 (suspended tty input)

## 问题表现

在使用 `flutter run -d macos` 等终端运行 Flutter 桌面端项目时，当在终端输入比如 `r` (Hot reload) 等字符触发控制台操作时，应用进程会被操作系统强行挂起，并抛出由于 TTY 终端输入冲突导致的挂起错误：
```bash
[23] + 5049 suspended (tty input)  flutter run -d macos
```
这会导致调试服务器完全卡死，应用主体还在 Dock 运行，但终端进程无法接收后续控制面板的命令和触发热重载。

## 问题原因

在 `v1.5.0` 版本引入的改动中，为了修复在某些系统环境（如通过 MacOS 的 Finder 双击启动应用、或者某些非完整环境变量的 LaunchPad 环境中）丢失 `PATH` 系统环境变量的问题，我们调整了执行 Shell 指令的策略（特别是在寻找如 `claude`、`codex` 等可执行文件时）。

代码层面，我们使用了交互式的 Zsh 终端进程，以保证加载完整的 Shell RC 配置文件（如 `.zshrc` 或者包含 nvm/fnm 路径的脚本）:
```dart
Process.run('zsh', ['-i', '-c', 'which claude']);
```

这当中的罪魁祸首在于 `-i` (Interactive 交互模式) 标志。

当代码底层的 Dart 进程（比如服务 `McpHealthCheckService` 中负责定期轮询进行健康检查的后台服务）派生拉起该带 `-i` 参数的 Zsh 时，这个作为后台启动的交互式 Shell 默认会开启 **Job Control (Monitor Mode - 作业控制)** 功能。
在 Unix / Linux 的进程生命周期中，**由于该后台子进程带有交互属性，它会尝试接管、争抢当前所处前台终端的作业控制以及标准输入（`stdin / TTY`）读取权**。
当操作系统的调度察觉后台进程试图染指前台终端输入时，就会发送 `SIGTTIN` 信号。而由于我们的终端正在跑着 `flutter run` 占用它，它就直接把前台输入发生了冲突的 `flutter run` 强制挂起并暂停了。

## 修复方案

我们在 `lib/utils/platform_utils.dart` 中调整了执行方式。如果是使用 Bash 或者是 Zsh 调用交互式终端（`-i`），必须明确追加 `+m` 参数。

`+m` 参数能够显式地关闭交互式 Shell 中的作业控制功能（Disable Monitor Mode）。在此模式下，Shell 仍旧能正常按照交互模式拉取所有环境变量源，但**不会再将自身放入前台进程组、也不会尝试争抢对于键盘（终端）输入的控制权**。

### 代码修复范例

```dart
// ❎ 错误写法 (会导致终端进程抢占挂起)
Process.run('zsh', ['-i', '-c', 'command...']);

// ✅ 正确写法: 追加 '+m'，禁用交互终端的作业控制
final shell = '/bin/zsh';
final shellArgs = ['-i'];

if (shell.contains('zsh') || shell.contains('bash')) {
  shellArgs.add('+m');
}
shellArgs.addAll(['-c', 'command...']);

Process.run(shell, shellArgs);
```
此修改使得派生的所有 Shell 子进程作为静默的环境变量执行器安全执行完毕，不再打断前台应用的 `flutter run` 与热重载操作。
