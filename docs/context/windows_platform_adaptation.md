# Windows 平台适配上下文文档

> 本文档记录 MCP Switch 应用的 Windows 平台适配设计、实现细节与关键决策。

## 一、适配目标

1. **跨平台路径处理**：兼容 macOS (`HOME`) 和 Windows (`USERPROFILE`) 环境变量
2. **跨平台命令执行**：兼容 `bash -c` (macOS/Linux) 和 `cmd /c` (Windows)
3. **跨平台文件操作**：兼容 `open -R` (macOS) 和 `explorer /select,` (Windows)
4. **Claude CLI 安装检测**：检测 Claude Code CLI 是否已安装，未安装时显示引导 Banner

---

## 二、设计思想

### 2.1 核心原则

- **单一职责**：所有平台相关逻辑集中到 `PlatformUtils` 工具类
- **最小改动**：业务代码只需替换调用方式，不改变原有逻辑
- **向后兼容**：macOS 功能保持不变，Windows 为增量适配

### 2.2 设计变更说明

**原设计**（计划文档中）：
```
lib/
├── utils/
│   ├── platform_utils.dart      # 平台检测和路径工具
│   └── claude_installer.dart    # Claude 安装器（独立文件）
```

**实际实现**：
```
lib/
├── utils/
│   └── platform_utils.dart      # 平台工具 + Claude 安装功能（合并）
```

**变更原因**：
1. Claude 安装功能与平台检测紧密相关（需要检测平台来决定安装命令）
2. 安装功能代码量小（约 50 行），不值得单独建文件
3. 合并后更易维护，避免循环依赖

---

## 三、文件结构

### 3.1 新增文件

| 文件路径 | 职责 |
|---------|------|
| `lib/utils/platform_utils.dart` | 跨平台工具类（路径、命令、安装检测） |
| `lib/ui/components/claude_not_installed_banner.dart` | Claude 未安装提示横幅组件 |

### 3.2 修改文件

| 文件路径 | 改动内容 |
|---------|---------|
| `lib/main.dart` | 日志输出使用 `PlatformUtils.userHome` |
| `lib/services/config_service.dart` | `_getDefaultPath()` 使用 `PlatformUtils.joinPath()` |
| `lib/services/skills_service.dart` | 所有路径操作改用 `PlatformUtils` |
| `lib/services/terminal_service.dart` | `workingDirectory` 使用 `PlatformUtils.userHome` |
| `lib/services/ai_chat_service.dart` | `_historyPath` 和 `_runTerminalCommand()` 使用 `PlatformUtils` |
| `lib/services/prompt_service.dart` | 配置路径使用 `PlatformUtils.joinPath()` |
| `lib/services/logger_service.dart` | 日志目录使用 `PlatformUtils.userHome` |
| `lib/ui/skills_screen.dart` | 添加 Claude 安装检测 + Banner 集成 |
| `lib/ui/settings_screen.dart` | 文件操作改用 `PlatformUtils` 方法 |
| `lib/ui/rules_screen.dart` | 规则文件路径使用 `PlatformUtils.joinPath()` |
| `lib/ui/skills/dialogs/*.dart` | 打开文件管理器改用 `PlatformUtils.openInFileManager()` |
| `lib/l10n/locales/zh.json` | 添加 Claude 安装相关文案 |
| `lib/l10n/locales/en.json` | 添加 Claude 安装相关文案 |

---

## 四、PlatformUtils API 说明

```dart
class PlatformUtils {
  /// 获取用户主目录（跨平台）
  /// - macOS/Linux: $HOME
  /// - Windows: %USERPROFILE% 或 %HOMEDRIVE%%HOMEPATH%
  static String get userHome;

  /// 获取应用数据目录
  /// - macOS: ~/Library/Application Support
  /// - Windows: %APPDATA%
  /// - Linux: ~/.local/share
  static String get appDataDir;

  /// 执行命令（跨平台）
  /// - macOS/Linux: bash -c "command"
  /// - Windows: cmd /c "command"
  static Future<ProcessResult> runCommand(String command);

  /// 在文件管理器中显示文件
  /// - macOS: open -R "path"
  /// - Windows: explorer /select,"path"
  static Future<void> openInFileManager(String filePath);

  /// 打开文件夹
  /// - macOS: open "path"
  /// - Windows: explorer "path"
  static Future<void> openFolder(String folderPath);

  /// 打开 URL
  /// - macOS: open "url"
  /// - Windows: start "url"
  static Future<void> openUrl(String url);

  /// 检测 Claude CLI 是否已安装
  static Future<bool> isClaudeInstalled();

  /// 获取 Claude CLI 版本
  static Future<String?> getClaudeVersion();

  /// 获取 Claude 安装命令（展示用）
  static String getClaudeInstallCommand();

  /// 执行 Claude 安装
  static Future<String?> installClaude();

  /// 跨平台路径拼接
  static String joinPath(String part1, [String? part2, String? part3, String? part4, String? part5]);

  /// 获取路径的目录部分
  static String dirname(String path);

  /// 获取路径的文件名部分
  static String basename(String path);

  /// 规范化路径
  static String normalize(String path);
}
```

---

## 五、关键技术点

### 5.1 Home 目录获取

```dart
static String get userHome {
  if (Platform.isWindows) {
    // Windows 优先使用 USERPROFILE
    return Platform.environment['USERPROFILE'] ??
        ((Platform.environment['HOMEDRIVE'] ?? '') +
            (Platform.environment['HOMEPATH'] ?? ''));
  }
  // macOS/Linux 使用 HOME
  return Platform.environment['HOME'] ?? '';
}
```

### 5.2 命令执行

```dart
static Future<ProcessResult> runCommand(String command) async {
  if (Platform.isWindows) {
    return Process.run('cmd', ['/c', command],
      runInShell: true,
      environment: Platform.environment
    );
  }
  // macOS/Linux 需要扩展 PATH 以找到 homebrew 安装的命令
  return Process.run('bash', ['-c', command], environment: {
    ...Platform.environment,
    'PATH': '${Platform.environment['PATH']}:/usr/local/bin:/opt/homebrew/bin',
  });
}
```

### 5.3 Claude CLI 安装检测

```dart
static Future<bool> isClaudeInstalled() async {
  try {
    final result = await runCommand('claude --version');
    return result.exitCode == 0;
  } catch (e) {
    return false;
  }
}
```

### 5.4 Claude 安装命令

| 平台 | 安装命令 |
|------|---------|
| macOS/Linux | `curl -fsSL https://claude.ai/install.sh \| sh` |
| Windows (PowerShell) | `irm https://claude.ai/install.ps1 \| iex` |
| Windows (CMD) | `curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd` |

### 5.5 平台命令配置系统

安装命令支持通过 YAML 配置文件自定义，配置文件位置：`~/.mcp-switch/config/platform_commands.yaml`

**配置结构**：
```yaml
claude_code_download:
  windows:
    use_shell: powershell  # 可选 powershell 或 cmd
    run_in_shell: true
    pre_script: |          # 安装前执行的脚本（支持多行）
      $env:ALL_PROXY='http://127.0.0.1:7890'
      Write-Host '代理已设置'
    powershell:
      shell: powershell
      shell_args: ["-NoProfile", "-Command"]
      install_script: "irm https://claude.ai/install.ps1 | iex"
    cmd:
      shell: cmd
      shell_args: ["/c"]
      install_script: "curl -fsSL https://claude.ai/install.cmd -o ..."
  macos:
    use_shell: zsh         # 可选 bash 或 zsh
    install_script: "curl -fsSL https://claude.ai/install.sh | sh"
  linux:
    use_shell: bash
    install_script: "curl -fsSL https://claude.ai/install.sh | sh"
```

### 5.6 PowerShell 复杂脚本执行（重要坑点）

**问题**：PowerShell 的 `-Command` 参数无法正确执行包含 `try/catch`、多行代码块 `{}` 等复杂语法的脚本。

**错误现象**：
- `此时不应有 >。` - 多行脚本解析失败
- `MissingEndCurlyBrace` - 大括号匹配问题
- 中文乱码（如 `娴嬭瘯娣辔`）- 编码问题

**解决方案**：将脚本写入临时 `.ps1` 文件，使用 `-File` 参数执行。

```dart
// 判断是否需要使用临时脚本文件
static bool get needsTempScriptFile {
  if (!Platform.isWindows) return false;
  if (_selectedShell != 'powershell') return false;
  final preScript = claudePreScript;
  // 包含 try/catch/finally 或多行复杂语法时需要用临时文件
  return preScript.contains('try') ||
      preScript.contains('catch') ||
      preScript.contains('finally') ||
      preScript.contains('{') ||
      preScript.split('\n').length > 3;
}

// 执行时创建临时文件
if (PlatformCommandsConfig.needsTempScriptFile) {
  final tempDir = Directory.systemTemp;
  tempScriptFile = File(p.join(tempDir.path, 'mcp_switch_install_xxx.ps1'));

  // 关键：写入 UTF-8 with BOM，PowerShell 才能正确识别中文
  final bom = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
  final scriptBytes = [...bom, ...utf8.encode(script)];
  await tempScriptFile.writeAsBytes(scriptBytes);

  // 使用 -File 参数执行
  process = await Process.start(
    'powershell',
    ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', tempScriptFile.path],
    runInShell: true,
  );
}
```

**关键点**：
1. **UTF-8 BOM**：PowerShell 默认不识别无 BOM 的 UTF-8 文件，必须手动添加 `0xEF 0xBB 0xBF`
2. **ExecutionPolicy Bypass**：绕过脚本执行策略限制
3. **临时文件清理**：执行完成后删除临时 `.ps1` 文件

---

## 六、国际化文案

| Key | 中文 | English |
|-----|------|---------|
| `claude_not_installed_title` | Claude CLI 未安装 | Claude CLI Not Installed |
| `claude_not_installed_message` | 检测到您尚未安装 Claude Code CLI，部分功能需要 CLI 支持 | Claude Code CLI is not installed. Some features require the CLI. |
| `claude_install_button` | 立即安装 | Install Now |
| `claude_installing` | 正在安装... | Installing... |
| `claude_install_docs` | 查看文档 | View Docs |

---

## 七、测试验证

### 7.1 编译验证

```bash
# macOS
flutter build macos --debug  # ✅ 通过

# Windows (待测试)
flutter build windows --debug
```

### 7.2 功能测试清单

- [ ] macOS: 所有现有功能正常
- [ ] Windows: 配置文件路径正确 (`%USERPROFILE%\.cursor\mcp.json`)
- [ ] Windows: 终端命令执行正常
- [ ] Windows: 文件管理器打开正常
- [ ] Claude CLI 检测：已安装时 Banner 不显示
- [ ] Claude CLI 检测：未安装时 Banner 显示
- [ ] Claude CLI 安装：点击安装按钮能执行安装

---

## 八、后续优化

1. **Linux 支持**：当前代码已考虑 Linux，但未完整测试
2. **Git Bash 支持**：Windows 上可能需要检测并支持 Git Bash 环境
3. **WSL 支持**：考虑 Windows Subsystem for Linux 场景
4. **安装进度**：当前安装是阻塞式的，可考虑添加进度显示

---

*文档更新时间：2026-01-18*
