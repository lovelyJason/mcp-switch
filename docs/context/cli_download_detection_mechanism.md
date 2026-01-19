# CLI 工具下载与检测机制

> 本文档记录 MCP Switch 应用中 CLI 工具（如 Claude Code CLI）的下载、安装、检测机制的完整流程设计。
> 后续添加其他工具（如 Codex CLI 等）时可参考本文档。

---

## 一、整体架构

### 1.1 核心流程

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           用户打开应用                                    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              检测函数1: findClaudeExePath()                              │
│              职责: 查找可执行文件是否存在                                  │
│              返回: String? (路径或null)                                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              检测函数2: isClaudeInPath()                                 │
│              职责: 检测命令是否在 PATH 环境变量中                          │
│              返回: bool                                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              组合函数: checkClaudeInstallStatus()                        │
│              职责: 组合上述两个函数的结果                                  │
│              返回: ClaudeInstallStatus 对象                              │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         根据状态显示对应 UI                               │
├─────────────────────────────────────────────────────────────────────────┤
│  状态1: 未安装 (!isInstalled)                                            │
│  → 显示 ClaudeNotInstalledBanner (橙色, 提供下载按钮)                     │
├─────────────────────────────────────────────────────────────────────────┤
│  状态2: 已安装但 PATH 未配置 (needsPathSetup)                             │
│  → 显示 ClaudePathNotConfiguredBanner (蓝色, 提供配置按钮)                │
├─────────────────────────────────────────────────────────────────────────┤
│  状态3: 完全就绪 (isReady)                                               │
│  → 不显示任何 Banner, 正常使用功能                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 状态模型

```dart
/// CLI 工具安装状态
class ClaudeInstallStatus {
  /// 可执行文件的实际路径（null 表示未找到）
  final String? exePath;

  /// PATH 环境变量中是否能找到该命令
  final bool inPath;

  /// 是否已安装（文件存在）
  bool get isInstalled => exePath != null;

  /// 是否需要配置 PATH（已安装但 PATH 中没有）
  bool get needsPathSetup => isInstalled && !inPath;

  /// 是否完全就绪（已安装且 PATH 已配置）
  bool get isReady => isInstalled && inPath;
}
```

---

## 二、检测函数详解

### 2.1 检测函数1: findClaudeExePath()

**职责**：查找 CLI 可执行文件是否存在（不依赖 PATH 环境变量）

**检测路径优先级**（Windows）：
1. YAML 配置文件中定义的 `detect_paths` 列表
2. `%USERPROFILE%\.local\bin\claude.exe`（官方安装器默认位置）
3. 递归搜索 `%USERPROFILE%\.claude\` 目录

**检测路径优先级**（macOS/Linux）：
1. `~/.claude/local/bin/claude`（官方安装路径）
2. `which claude` 命令结果

```dart
/// 【检测函数1】查找 Claude CLI 可执行文件的实际路径
static Future<String?> findClaudeExePath() async {
  if (Platform.isWindows) {
    // 1. 检查配置的路径
    for (final relPath in PlatformCommandsConfig.claudeDetectPaths) {
      final fullPath = p.join(userHome, relPath);
      if (File(fullPath).existsSync()) return fullPath;
    }

    // 2. 检查 .local\bin 目录
    final localBinPath = p.join(userHome, '.local', 'bin', 'claude.exe');
    if (File(localBinPath).existsSync()) return localBinPath;

    // 3. 递归搜索 .claude 目录
    final claudeDir = Directory(p.join(userHome, '.claude'));
    if (claudeDir.existsSync()) {
      return await _findClaudeExeInDir(claudeDir);
    }

    return null;
  } else {
    // macOS/Linux
    final defaultPath = p.join(userHome, '.claude', 'local', 'bin', 'claude');
    if (File(defaultPath).existsSync()) return defaultPath;

    final whichResult = await Process.run('which', ['claude']);
    if (whichResult.exitCode == 0) {
      return (whichResult.stdout as String).trim();
    }

    return null;
  }
}
```

### 2.2 检测函数2: isClaudeInPath()

**职责**：检测命令是否在 PATH 环境变量中（仅检测 PATH，不检查文件是否存在）

```dart
/// 【检测函数2】检测 Claude CLI 是否在 PATH 环境变量中
static Future<bool> isClaudeInPath() async {
  try {
    if (Platform.isWindows) {
      // Windows: 使用 where 命令
      final whereResult = await Process.run('where', ['claude'], runInShell: true);
      return whereResult.exitCode == 0;
    } else {
      // macOS/Linux: 使用 which 命令
      final whichResult = await Process.run('which', ['claude']);
      return whichResult.exitCode == 0;
    }
  } catch (e) {
    return false;
  }
}
```

### 2.3 组合函数: checkClaudeInstallStatus()

**职责**：组合调用上述两个函数，返回完整状态

```dart
/// 【组合函数】检测 Claude CLI 完整安装状态
static Future<ClaudeInstallStatus> checkClaudeInstallStatus() async {
  // 1. 查找可执行文件路径
  String? exePath = await findClaudeExePath();

  // 2. 检测是否在 PATH 中
  bool inPath = await isClaudeInPath();

  // 3. 如果 PATH 中有但 exePath 为空，从 PATH 获取路径
  if (inPath && exePath == null) {
    // 从 where/which 结果获取路径...
  }

  return ClaudeInstallStatus(exePath: exePath, inPath: inPath);
}
```

---

## 三、UI 组件

### 3.1 未安装 Banner (ClaudeNotInstalledBanner)

**文件位置**：`lib/ui/components/claude_not_installed_banner.dart`

**外观**：橙色警告风格

**功能**：
- 显示"Claude Code CLI 未安装"提示
- 提供"一键安装"按钮
- 提供"查看文档"链接
- 提供"复制命令"按钮（手动安装备选）
- 显示实时安装日志

**安装流程**：
```
点击安装按钮
    │
    ▼
检测当前状态 (checkClaudeInstallStatus)
    │
    ├─→ 已完全就绪 → 直接完成
    │
    ├─→ 已安装但 PATH 未配置 → 自动配置 PATH → 完成
    │
    └─→ 未安装 → 执行安装脚本
                    │
                    ▼
              安装完成后再次检测
                    │
                    ├─→ 需要配置 PATH → 自动配置
                    │
                    └─→ 完全就绪 → 完成
```

### 3.2 PATH 未配置 Banner (ClaudePathNotConfiguredBanner)

**文件位置**：`lib/ui/components/claude_path_not_configured_banner.dart`

**外观**：蓝色信息风格

**功能**：
- 显示"Claude CLI 环境变量未配置"提示
- 显示 Claude 可执行文件的实际路径
- 提供"配置环境变量"按钮
- 配置成功/失败显示 Toast 通知

---

## 四、PATH 环境变量配置

### 4.1 Windows PATH 配置 (setx)

**原理**：使用 `setx` 命令将路径写入用户级注册表 `HKCU\Environment\PATH`

```dart
static Future<List<String>> setupClaudePath(String claudeExePath) async {
  final claudeBinDir = p.dirname(claudeExePath);

  // 1. 读取当前用户 PATH
  final regResult = await Process.run(
    'reg',
    ['query', 'HKCU\\Environment', '/v', 'PATH'],
    runInShell: true,
  );

  String userPath = '';
  if (regResult.exitCode == 0) {
    // 解析注册表输出
    final match = RegExp(r'PATH\s+REG_\w+\s+(.+)').firstMatch(regResult.stdout);
    if (match != null) userPath = match.group(1)?.trim() ?? '';
  }

  // 2. 用 setx 设置新的 PATH
  final newPath = userPath.isEmpty ? claudeBinDir : '$userPath;$claudeBinDir';
  final setxResult = await Process.run('setx', ['PATH', newPath], runInShell: true);

  return setxResult.exitCode == 0 ? ['✅ PATH 已更新'] : ['❌ 设置失败'];
}
```

**setx 特性**：
- 写入注册表，永久生效
- CMD 和 PowerShell 都能识别
- 不会弹出任何 GUI 窗口
- 需要重启终端/应用才能在当前进程看到变化
- 在「系统属性 → 环境变量」GUI 中可以看到更新后的值

### 4.2 macOS/Linux PATH 配置

macOS/Linux 通常不需要额外配置 PATH，因为：
1. 官方安装脚本会自动处理 shell 配置文件
2. `~/.claude/local/bin` 目录下有软链接

如需手动配置，需要修改 shell 配置文件（`.bashrc`、`.zshrc` 等）。

---

## 五、安装命令配置系统

### 5.1 配置文件位置

- 内置默认配置：`assets/config/platform_commands.yaml`
- 用户自定义配置：`~/.mcp-switch/config/platform_commands.yaml`

### 5.2 配置结构

```yaml
claude_code_download:
  windows:
    use_shell: cmd              # 可选 powershell 或 cmd
    run_in_shell: true

    # 检测路径列表（相对于用户主目录）
    detect_paths:
      - ".claude\\local\\bin\\claude.exe"
      - ".local\\bin\\claude.exe"

    # Shell 配置
    cmd:
      shell: cmd
      shell_args: ["/c"]
      install_script: "curl -fsSL https://claude.ai/install.cmd -o ..."
      pre_script: |            # 安装前执行（如设置代理）
        set ALL_PROXY=http://127.0.0.1:7890
      post_script: |           # 安装后执行（如配置 PATH）
        setx PATH "%PATH%;%USERPROFILE%\.local\bin"

    powershell:
      shell: powershell
      shell_args: ["-NoProfile", "-Command"]
      install_script: "irm https://claude.ai/install.ps1 | iex"

  macos:
    use_shell: zsh
    shells:
      - name: zsh
        install_script: "curl -fsSL https://claude.ai/install.sh | sh"
```

---

## 六、主窗口集成

### 6.1 状态变量

```dart
class _MainWindowState extends State<MainWindow> {
  // Claude CLI 安装状态
  ClaudeInstallStatus? _claudeStatus;
  bool _checkingClaude = true;
  bool _isInstallingClaude = false;

  // 便捷 getter
  bool get _isClaudeInstalled => _claudeStatus?.isInstalled ?? true;
  bool get _needsPathSetup => _claudeStatus?.needsPathSetup ?? false;
  bool get _isClaudeReady => _claudeStatus?.isReady ?? true;
}
```

### 6.2 初始化检测

```dart
@override
void initState() {
  super.initState();
  _checkClaudeStatus();
}

Future<void> _checkClaudeStatus() async {
  final status = await PlatformUtils.checkClaudeInstallStatus();
  if (mounted) {
    setState(() {
      _claudeStatus = status;
      _checkingClaude = false;
    });
  }
}
```

### 6.3 条件渲染 Banner

```dart
// Claude 未安装 Banner
if (_selectedEditor == EditorType.claude &&
    !_checkingClaude &&
    !_isClaudeInstalled)
  ClaudeNotInstalledBanner(
    onInstallComplete: () => _checkClaudeStatus(),
    onInstallStateChanged: (isInstalling) {
      setState(() => _isInstallingClaude = isInstalling);
    },
  ),

// Claude 已安装但 PATH 未配置 Banner
if (_selectedEditor == EditorType.claude &&
    !_checkingClaude &&
    _isClaudeInstalled &&
    _needsPathSetup &&
    _claudeStatus?.exePath != null)
  ClaudePathNotConfiguredBanner(
    claudeExePath: _claudeStatus!.exePath!,
    onConfigureComplete: () => _checkClaudeStatus(),
  ),
```

---

## 七、国际化文案

| Key | 中文 | English |
|-----|------|---------|
| `claude_not_installed_title` | Claude Code CLI 未安装 | Claude Code CLI Not Installed |
| `claude_not_installed_message` | 检测到系统中未安装 Claude Code CLI... | Claude Code CLI is not detected... |
| `claude_install_button` | 一键安装 | Install Now |
| `claude_installing` | 正在安装... | Installing... |
| `claude_install_docs` | 查看文档 | View Docs |
| `claude_path_not_configured_title` | Claude CLI 环境变量未配置 | Claude CLI PATH Not Configured |
| `claude_path_not_configured_message` | 检测到 Claude CLI 已安装，但未添加到系统 PATH... | Claude CLI is installed but not added to PATH... |
| `claude_path_configure_button` | 配置环境变量 | Configure PATH |
| `claude_path_configuring` | 正在配置... | Configuring... |
| `claude_path_configured_success` | 环境变量配置成功！请重启软件使配置生效 | PATH configured successfully! Please restart... |
| `claude_path_configured_failed` | 环境变量配置失败 | Failed to configure PATH |
| `claude_path_already_configured` | 环境变量已配置 | PATH is already configured |

---

## 八、扩展其他工具

### 8.1 添加新工具的步骤

1. **创建状态类**：参考 `ClaudeInstallStatus`，创建 `XxxInstallStatus`

2. **实现检测函数**：
   - `findXxxExePath()` - 查找可执行文件
   - `isXxxInPath()` - 检测 PATH
   - `checkXxxInstallStatus()` - 组合函数

3. **创建 UI 组件**：
   - `XxxNotInstalledBanner` - 未安装提示
   - `XxxPathNotConfiguredBanner` - PATH 未配置提示

4. **添加配置项**：在 `platform_commands.yaml` 中添加对应配置块

5. **添加国际化文案**：在 `zh.json` 和 `en.json` 中添加相关文案

6. **集成到主窗口**：添加状态变量和条件渲染逻辑

### 8.2 通用检测函数模板

```dart
/// 【检测函数1】查找 {ToolName} 可执行文件路径
static Future<String?> find{ToolName}ExePath() async {
  // 1. 检查配置的路径
  // 2. 检查默认安装路径
  // 3. 递归搜索常见目录
  // 4. 使用 where/which 命令
}

/// 【检测函数2】检测 {ToolName} 是否在 PATH 中
static Future<bool> is{ToolName}InPath() async {
  // Windows: where {command}
  // macOS/Linux: which {command}
}

/// 【组合函数】检测 {ToolName} 完整安装状态
static Future<{ToolName}InstallStatus> check{ToolName}InstallStatus() async {
  final exePath = await find{ToolName}ExePath();
  final inPath = await is{ToolName}InPath();
  return {ToolName}InstallStatus(exePath: exePath, inPath: inPath);
}
```

---

## 九、已知问题与注意事项

### 9.1 Windows setx 限制

- `setx` 写入的 PATH 最大长度为 **1024 字符**
- 超过限制会导致 PATH 被截断
- 建议：仅在必要时使用，避免重复添加

### 9.2 进程 PATH 刷新

- `setx` 只修改注册表，不影响当前进程的 `Platform.environment['PATH']`
- 需要重启应用或终端才能看到新的 PATH
- 可以在 Toast 中提示用户"请重启软件使配置生效"

### 9.3 PowerShell 脚本执行

- 复杂脚本（含 try/catch、多行代码块）需要写入临时 `.ps1` 文件执行
- 必须添加 UTF-8 BOM 才能正确显示中文
- 使用 `-ExecutionPolicy Bypass` 绕过脚本执行策略

---

*文档创建时间：2026-01-18*
*适用版本：MCP Switch v1.x*