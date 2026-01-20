import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../config/platform_commands_config.dart';
import '../services/logger_service.dart';

/// Claude CLI 安装状态
class ClaudeInstallStatus {
  /// Claude CLI 可执行文件的实际路径（null 表示未找到）
  final String? exePath;

  /// PATH 环境变量中是否能找到 claude 命令
  final bool inPath;

  const ClaudeInstallStatus({this.exePath, this.inPath = false});

  /// 是否已安装（文件存在）
  bool get isInstalled => exePath != null;

  /// 是否需要配置 PATH（已安装但 PATH 中没有）
  bool get needsPathSetup => isInstalled && !inPath;

  /// 是否完全就绪（已安装且 PATH 已配置）
  bool get isReady => isInstalled && inPath;

  @override
  String toString() => 'ClaudeInstallStatus(exePath: $exePath, inPath: $inPath)';
}

/// Codex CLI 安装状态
class CodexInstallStatus {
  /// Codex CLI 可执行文件的实际路径（null 表示未找到）
  final String? exePath;

  /// PATH 环境变量中是否能找到 codex 命令
  final bool inPath;

  const CodexInstallStatus({this.exePath, this.inPath = false});

  /// 是否已安装（文件存在）
  bool get isInstalled => exePath != null;

  /// 是否需要配置 PATH（已安装但 PATH 中没有）
  bool get needsPathSetup => isInstalled && !inPath;

  /// 是否完全就绪（已安装且 PATH 已配置）
  bool get isReady => isInstalled && inPath;

  @override
  String toString() => 'CodexInstallStatus(exePath: $exePath, inPath: $inPath)';
}

/// Gemini CLI 安装状态
class GeminiInstallStatus {
  /// Gemini CLI 可执行文件的实际路径（null 表示未找到）
  final String? exePath;

  /// PATH 环境变量中是否能找到 gemini 命令
  final bool inPath;

  const GeminiInstallStatus({this.exePath, this.inPath = false});

  /// 是否已安装（文件存在）
  bool get isInstalled => exePath != null;

  /// 是否需要配置 PATH（已安装但 PATH 中没有）
  bool get needsPathSetup => isInstalled && !inPath;

  /// 是否完全就绪（已安装且 PATH 已配置）
  bool get isReady => isInstalled && inPath;

  @override
  String toString() => 'GeminiInstallStatus(exePath: $exePath, inPath: $inPath)';
}

/// 跨平台工具类
/// 统一处理 Windows/macOS/Linux 的路径、命令执行、文件操作等差异
class PlatformUtils {
  /// 缓存的 Windows 最新 PATH（避免重复读取注册表）
  static String? _cachedWindowsPath;
  static DateTime? _lastPathRefresh;

  /// 获取 Windows 最新的 PATH 环境变量
  /// Flutter 应用启动后，系统 PATH 的修改不会自动同步到 Platform.environment
  /// 使用 PowerShell 的 [Environment]::GetEnvironmentVariable 来读取，避免 WOW64 重定向问题
  static Future<String?> getWindowsLatestPath() async {
    if (!Platform.isWindows) return null;

    // 5分钟内使用缓存
    if (_cachedWindowsPath != null && _lastPathRefresh != null) {
      final elapsed = DateTime.now().difference(_lastPathRefresh!);
      if (elapsed.inMinutes < 5) {
        return _cachedWindowsPath;
      }
    }

    try {
      // 分别读取系统 PATH 和用户 PATH
      // 使用简单的单行命令，避免多行字符串解析问题
      final machineResult = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', "[Environment]::GetEnvironmentVariable('Path', 'Machine')"],
        runInShell: true,
      );

      final userResult = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', "[Environment]::GetEnvironmentVariable('Path', 'User')"],
        runInShell: true,
      );

      String systemPath = '';
      String userPath = '';

      if (machineResult.exitCode == 0) {
        systemPath = machineResult.stdout.toString().trim();
      } else {
        LoggerService.warning('[getWindowsLatestPath] 读取系统 PATH 失败: ${machineResult.stderr}');
      }

      if (userResult.exitCode == 0) {
        userPath = userResult.stdout.toString().trim();
      } else {
        LoggerService.warning('[getWindowsLatestPath] 读取用户 PATH 失败: ${userResult.stderr}');
      }

      // 如果两个都失败了，返回 null
      if (systemPath.isEmpty && userPath.isEmpty) {
        LoggerService.error('[getWindowsLatestPath] 无法读取任何 PATH');
        return null;
      }

      // 合并 PATH（用户 PATH 优先，系统 PATH 追加）
      // 注意：Windows 路径大小写不敏感，需要用 toLowerCase 比较去重
      final paths = <String>[];
      final pathsLower = <String>{}; // 用于去重（小写）

      // 先加用户 PATH
      if (userPath.isNotEmpty) {
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
      }

      // 再加系统 PATH（去重）
      if (systemPath.isNotEmpty) {
        for (final p in systemPath.split(';')) {
          final trimmed = p.trim();
          if (trimmed.isNotEmpty) {
            final lower = trimmed.toLowerCase();
            if (!pathsLower.contains(lower)) {
              paths.add(trimmed);
              pathsLower.add(lower);
            }
          }
        }
      }

      _cachedWindowsPath = paths.join(';');
      _lastPathRefresh = DateTime.now();

      return _cachedWindowsPath;
    } catch (e) {
      LoggerService.error('[getWindowsLatestPath] 读取 Windows PATH 失败: $e');
      return null;
    }
  }

  /// 获取合并了最新 PATH 的环境变量（用于 Process.start）
  static Future<Map<String, String>> getUpdatedEnvironment([Map<String, String>? extraEnv]) async {
    final env = Map<String, String>.from(Platform.environment);

    // Windows 上刷新 PATH
    if (Platform.isWindows) {
      final latestPath = await getWindowsLatestPath();
      if (latestPath != null && latestPath.isNotEmpty) {
        // Windows 环境变量名大小写不敏感，但 Dart Map 是敏感的
        // 先删除已存在的（可能是 Path 或 PATH）
        env.removeWhere((key, value) => key.toLowerCase() == 'path');
        // 设置为 PATH（大写，这是更标准的形式）
        env['PATH'] = latestPath;
      }
    }

    // 合并额外的环境变量（但不能覆盖我们刚设置的 PATH！）
    if (extraEnv != null) {
      // 保存我们设置的新 PATH
      final ourPath = env['PATH'];

      // 合并其他环境变量
      for (final entry in extraEnv.entries) {
        // 跳过 PATH 相关的 key，不让它覆盖我们的
        if (entry.key.toLowerCase() == 'path') {
          continue;
        }
        env[entry.key] = entry.value;
      }

      // 确保 PATH 没被覆盖
      if (ourPath != null) {
        env['PATH'] = ourPath;
      }
    }

    return env;
  }

  /// 清除 Windows PATH 缓存（安装新软件后调用）
  static void clearWindowsPathCache() {
    _cachedWindowsPath = null;
    _lastPathRefresh = null;
  }

  /// 获取用户主目录
  /// - Windows: %USERPROFILE% (如 C:\Users\username)
  /// - macOS/Linux: $HOME (如 /Users/username)
  static String get userHome {
    if (Platform.isWindows) {
      // Windows 优先使用 USERPROFILE，备选 HOMEDRIVE + HOMEPATH
      return Platform.environment['USERPROFILE'] ??
          ((Platform.environment['HOMEDRIVE'] ?? '') +
              (Platform.environment['HOMEPATH'] ?? ''));
    }
    return Platform.environment['HOME'] ?? '';
  }

  /// 获取应用数据目录
  /// - 所有平台统一使用用户主目录下的 .mcp-switch
  /// - Windows: %USERPROFILE%\.mcp-switch (如 C:\Users\xxx\.mcp-switch)
  /// - macOS/Linux: ~/.mcp-switch
  static String get appDataDir {
    return p.join(userHome, '.mcp-switch');
  }

  /// 执行 shell 命令（跨平台）
  /// - Windows: 使用 PowerShell
  /// - macOS/Linux: 使用 bash -c，并添加常用 PATH
  static Future<ProcessResult> runCommand(String command) async {
    return Process.run(
      PlatformCommandsConfig.claudeShell,
      [...PlatformCommandsConfig.claudeShellArgs, command],
      runInShell: PlatformCommandsConfig.claudeRunInShell,
      environment: PlatformCommandsConfig.claudeEnvironment,
    );
  }

  /// 在 Finder/Explorer 中打开文件夹并选中文件
  static Future<void> openInFileManager(String path) async {
    try {
      if (Platform.isWindows) {
        final winPath = path.replaceAll('/', '\\');
        await Process.run('explorer', ['/select,', winPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', path]);
      } else {
        final dir = File(path).existsSync() ? File(path).parent.path : path;
        await Process.run('xdg-open', [dir]);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 打开文件夹（不选中特定文件）
  static Future<void> openFolder(String folderPath) async {
    try {
      if (Platform.isWindows) {
        final winPath = folderPath.replaceAll('/', '\\');
        await Process.run('explorer', [winPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [folderPath]);
      } else {
        await Process.run('xdg-open', [folderPath]);
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 打开 URL（使用 url_launcher）
  static Future<bool> openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Claude CLI 相关（配置从 YAML 文件加载）
  // ═══════════════════════════════════════════════════════════════════════════

  /// 检测 Claude CLI 是否已安装
  static Future<bool> isClaudeInstalled() async {
    try {
      if (Platform.isWindows) {
        // 确保配置已初始化
        await PlatformCommandsConfig.init();

        final home = userHome;
        LoggerService.debug('[Claude检测] 用户主目录: $home');

        // 1. 先检查配置的安装路径（更可靠）
        final detectPaths = PlatformCommandsConfig.claudeDetectPaths;
        LoggerService.debug('[Claude检测] 检测路径列表: $detectPaths');

        for (final relPath in detectPaths) {
          final fullPath = p.join(home, relPath);
          final exists = File(fullPath).existsSync();
          LoggerService.debug('[Claude检测] 检查路径: $fullPath -> ${exists ? "存在" : "不存在"}');
          if (exists) {
            return true;
          }
        }

        // 2. 递归搜索 .claude 目录下的 claude.exe
        final claudeDir = Directory(p.join(home, '.claude'));
        LoggerService.debug('[Claude检测] .claude 目录: ${claudeDir.path} -> ${claudeDir.existsSync() ? "存在" : "不存在"}');
        if (claudeDir.existsSync()) {
          final found = await _findClaudeExeInDir(claudeDir);
          LoggerService.debug('[Claude检测] 递归搜索结果: ${found ?? "未找到"}');
          if (found != null) return true;
        }

        // 3. 尝试用 where 命令检测（不依赖当前进程的 PATH）
        final whereResult = await Process.run(
          'where',
          ['claude'],
          runInShell: true,
        );
        LoggerService.debug('[Claude检测] where claude: exitCode=${whereResult.exitCode}, stdout=${whereResult.stdout}');
        if (whereResult.exitCode == 0) return true;

        // 4. 用 PowerShell 的 Get-Command 检测
        final psResult = await Process.run(
          'powershell',
          ['-NoProfile', '-Command', 'Get-Command claude -ErrorAction SilentlyContinue'],
          runInShell: true,
        );
        LoggerService.debug('[Claude检测] Get-Command: exitCode=${psResult.exitCode}, stdout=${psResult.stdout}');
        if (psResult.exitCode == 0 && (psResult.stdout as String).contains('claude')) {
          return true;
        }

        LoggerService.debug('[Claude检测] 所有检测方法都未找到 Claude CLI');
        return false;
      }

      // macOS/Linux
      final result = await runCommand('claude --version');
      return result.exitCode == 0;
    } catch (e) {
      LoggerService.error('[Claude检测] 检测异常', e);
      return false;
    }
  }

  /// 在目录中递归查找 claude.exe（Windows 专用）
  static Future<String?> _findClaudeExeInDir(Directory dir) async {
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final name = p.basename(entity.path).toLowerCase();
          if (name == 'claude.exe') {
            return entity.path;
          }
        }
      }
    } catch (_) {
      // 忽略权限错误等
    }
    return null;
  }

  /// 【检测函数1】查找 Claude CLI 可执行文件的实际路径
  /// 返回: 文件路径（找到）或 null（未找到）
  /// 不依赖 PATH 环境变量，直接检查已知安装路径
  static Future<String?> findClaudeExePath() async {
    await PlatformCommandsConfig.init();

    if (Platform.isWindows) {
      // 1. 检查配置的路径
      for (final relPath in PlatformCommandsConfig.claudeDetectPaths) {
        final fullPath = p.join(userHome, relPath);
        if (File(fullPath).existsSync()) {
          // LoggerService.debug('[findClaudeExePath] 找到: $fullPath');
          return fullPath;
        }
      }

      // 2. 检查 .local\bin 目录（官方安装器默认位置）
      final localBinPath = p.join(userHome, '.local', 'bin', 'claude.exe');
      if (File(localBinPath).existsSync()) {
        // LoggerService.debug('[findClaudeExePath] 找到: $localBinPath');
        return localBinPath;
      }

      // 3. 递归搜索 .claude 目录
      final claudeDir = Directory(p.join(userHome, '.claude'));
      if (claudeDir.existsSync()) {
        final found = await _findClaudeExeInDir(claudeDir);
        if (found != null) {
          // LoggerService.debug('[findClaudeExePath] 递归找到: $found');
          return found;
        }
      }

      // LoggerService.debug('[findClaudeExePath] Windows: 未找到 claude.exe');
      return null;
    } else {
      // macOS/Linux: 检查常见安装路径
      final commonPaths = [
        '/opt/homebrew/bin/claude',           // Homebrew (Apple Silicon)
        '/usr/local/bin/claude',              // Homebrew (Intel) / 手动安装
        p.join(userHome, '.claude', 'local', 'bin', 'claude'), // 官方安装器
      ];

      for (final path in commonPaths) {
        if (File(path).existsSync()) {
          // LoggerService.debug('[findClaudeExePath] 找到: $path');
          return path;
        }
      }

      // 使用用户默认 shell 的交互模式获取完整 PATH（支持各种 shell 配置）
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final whichResult = await Process.run(shell, ['-i', '-c', 'which claude'],
        environment: {'HOME': userHome, 'USER': Platform.environment['USER'] ?? ''},
      );
      if (whichResult.exitCode == 0) {
        final path = (whichResult.stdout as String).trim();
        if (path.isNotEmpty) {
          // LoggerService.debug('[findClaudeExePath] which 找到: $path');
          return path;
        }
      }

      // LoggerService.debug('[findClaudeExePath] macOS/Linux: 未找到 claude');
      return null;
    }
  }

  /// 【检测函数2】检测 Claude CLI 是否在 PATH 环境变量中
  /// 返回: true（在 PATH 中）或 false（不在 PATH 中）
  ///
  /// Windows 特殊处理：
  /// 1. 先用 where 命令检测（当前进程的 PATH）
  /// 2. 如果失败，再检查注册表中的用户 PATH（已配置但当前进程未感知）
  /// 可选参数 claudeBinDir：指定要检查的目录路径
  static Future<bool> isClaudeInPath({String? claudeBinDir}) async {
    try {
      if (Platform.isWindows) {
        // 方法1：使用 where 命令（检测当前进程的 PATH）
        final whereResult = await Process.run('where', ['claude'], runInShell: true);
        if (whereResult.exitCode == 0) {
          // LoggerService.debug('[isClaudeInPath] Windows where: true');
          return true;
        }

        // 方法2：检查注册表中的用户 PATH（setx 修改后，当前进程可能感知不到）
        final regUserPath = await _getWindowsUserPathFromRegistry();
        if (regUserPath != null && regUserPath.isNotEmpty) {
          // LoggerService.debug('[isClaudeInPath] Registry user PATH: $regUserPath');

          // 如果指定了目录，检查是否包含该目录
          if (claudeBinDir != null) {
            final normalizedBinDir = claudeBinDir.toLowerCase().replaceAll('/', '\\');
            final normalizedRegPath = regUserPath.toLowerCase();
            if (normalizedRegPath.contains(normalizedBinDir)) {
              // LoggerService.debug('[isClaudeInPath] Registry PATH contains $claudeBinDir: true');
              return true;
            }
          }

          // 通用检查：是否包含 .local\bin 或 .local/bin
          final lowerPath = regUserPath.toLowerCase();
          if (lowerPath.contains('.local\\bin') || lowerPath.contains('.local/bin')) {
            // LoggerService.debug('[isClaudeInPath] Registry PATH contains .local\\bin: true');
            return true;
          }
        }

        // LoggerService.debug('[isClaudeInPath] Windows: false');
        return false;
      } else {
        // macOS/Linux: 使用用户默认 shell 的交互模式获取完整 PATH
        final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
        final whichResult = await Process.run(shell, ['-i', '-c', 'which claude'],
          environment: {'HOME': userHome, 'USER': Platform.environment['USER'] ?? ''},
        );
        final inPath = whichResult.exitCode == 0;
        // LoggerService.debug('[isClaudeInPath] Unix which: $inPath');
        return inPath;
      }
    } catch (e) {
      LoggerService.error('[isClaudeInPath] 检测异常', e);
      return false;
    }
  }

  /// 从 Windows 注册表获取用户 PATH 环境变量
  static Future<String?> _getWindowsUserPathFromRegistry() async {
    try {
      final regResult = await Process.run(
        'reg',
        ['query', 'HKCU\\Environment', '/v', 'PATH'],
        runInShell: true,
        stdoutEncoding: const SystemEncoding(),
      );

      if (regResult.exitCode == 0) {
        final output = regResult.stdout as String;
        // LoggerService.debug('[_getWindowsUserPathFromRegistry] Raw output:\n$output');

        // Windows reg query 输出格式:
        // HKEY_CURRENT_USER\Environment
        //     PATH    REG_EXPAND_SZ    C:\path1;C:\path2;...
        //
        // 注意：PATH 值可能很长，但都在同一行
        final lines = output.split('\n');
        for (final line in lines) {
          // 查找包含 PATH 和 REG_ 的行
          if (line.contains('PATH') && line.contains('REG_')) {
            // 找到 REG_xxx 后面的内容
            final regTypeMatch = RegExp(r'REG_\w+\s+(.+)', caseSensitive: false).firstMatch(line);
            if (regTypeMatch != null) {
              return regTypeMatch.group(1)?.trim();
            }
          }
        }
      } else {
        // LoggerService.debug('[_getWindowsUserPathFromRegistry] reg query failed: ${regResult.stderr}');
      }
    } catch (e) {
      LoggerService.error('[_getWindowsUserPathFromRegistry] 异常', e);
    }
    return null;
  }

  /// 【组合函数】检测 Claude CLI 完整安装状态
  /// 组合调用 findClaudeExePath() 和 isClaudeInPath()
  /// 返回: ClaudeInstallStatus 对象
  static Future<ClaudeInstallStatus> checkClaudeInstallStatus() async {
    // 1. 查找可执行文件路径
    String? exePath = await findClaudeExePath();

    // 2. 检测是否在 PATH 中
    // 如果通过硬编码的系统路径（/opt/homebrew/bin, /usr/local/bin）找到，直接认为在 PATH 中
    // 因为这些是 macOS 的标准 PATH 路径，GUI app 环境检测 shell 不可靠
    bool inPath = false;
    if (exePath != null && !Platform.isWindows) {
      final standardPaths = ['/opt/homebrew/bin', '/usr/local/bin'];
      final exeDir = p.dirname(exePath);
      if (standardPaths.contains(exeDir)) {
        inPath = true;
        // LoggerService.debug('[checkClaudeInstallStatus] 标准路径，直接认为 inPath=true');
      } else {
        inPath = await isClaudeInPath(claudeBinDir: exeDir);
      }
    } else if (Platform.isWindows) {
      String? claudeBinDir;
      if (exePath != null) {
        claudeBinDir = p.dirname(exePath);
      }
      inPath = await isClaudeInPath(claudeBinDir: claudeBinDir);
    }

    // 3. 如果 PATH 中有但 exePath 为空，从 PATH 获取路径
    if (inPath && exePath == null) {
      if (Platform.isWindows) {
        final whereResult = await Process.run('where', ['claude'], runInShell: true);
        if (whereResult.exitCode == 0) {
          final stdout = (whereResult.stdout as String).trim();
          if (stdout.isNotEmpty) {
            exePath = stdout.split('\n').first.trim();
          }
        }
      } else {
        final whichResult = await Process.run('which', ['claude']);
        if (whichResult.exitCode == 0) {
          exePath = (whichResult.stdout as String).trim();
        }
      }
    }

    // LoggerService.debug('[checkClaudeInstallStatus] exePath=$exePath, inPath=$inPath');
    return ClaudeInstallStatus(exePath: exePath, inPath: inPath);
  }

  /// 设置 Claude CLI 到 PATH 环境变量（Windows）
  /// 返回执行结果的日志
  static Future<List<String>> setupClaudePath(String claudeExePath) async {
    final logs = <String>[];

    if (!Platform.isWindows) {
      logs.add('⚠️ 此功能仅支持 Windows');
      return logs;
    }

    // 获取 claude.exe 所在目录
    final claudeBinDir = p.dirname(claudeExePath);
    logs.add('🔍 Claude CLI 路径: $claudeBinDir');

    // 检查是否已在 PATH 中
    final currentPath = Platform.environment['PATH'] ?? '';
    if (currentPath.toLowerCase().contains(claudeBinDir.toLowerCase())) {
      logs.add('✅ PATH 已包含 Claude CLI 路径');
      return logs;
    }

    logs.add('📝 正在将 Claude CLI 添加到用户 PATH...');

    try {
      // 读取当前用户 PATH
      final regResult = await Process.run(
        'reg',
        ['query', 'HKCU\\Environment', '/v', 'PATH'],
        runInShell: true,
      );

      String userPath = '';
      if (regResult.exitCode == 0) {
        // 解析注册表输出，格式类似：PATH    REG_EXPAND_SZ    C:\Users\xxx\bin;...
        final output = regResult.stdout as String;
        final match = RegExp(r'PATH\s+REG_\w+\s+(.+)', caseSensitive: false).firstMatch(output);
        if (match != null) {
          userPath = match.group(1)?.trim() ?? '';
        }
      }

      // 用 setx 设置新的 PATH
      final newPath = userPath.isEmpty ? claudeBinDir : '$userPath;$claudeBinDir';
      final setxResult = await Process.run(
        'setx',
        ['PATH', newPath],
        runInShell: true,
      );

      if (setxResult.exitCode == 0) {
        logs.add('✅ PATH 已更新');
        logs.add('⚠️ 请重启终端或软件使 PATH 生效');
      } else {
        logs.add('❌ setx 执行失败: ${setxResult.stderr}');
      }
    } catch (e) {
      logs.add('❌ 设置 PATH 出错: $e');
    }

    return logs;
  }

  /// 获取 Claude CLI 版本（如果已安装）
  static Future<String?> getClaudeVersion() async {
    try {
      final result = await runCommand('claude --version');
      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        return output.isNotEmpty ? output : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取 Claude 安装命令（显示给用户看的，易读格式）
  static String getClaudeInstallCommand() {
    return PlatformCommandsConfig.claudeDisplayCommand;
  }

  /// 执行 Claude 安装（返回结果字符串）
  static Future<String> installClaude() async {
    try {
      final result = await Process.run(
        PlatformCommandsConfig.claudeShell,
        [...PlatformCommandsConfig.claudeShellArgs, PlatformCommandsConfig.claudeFullInstallCommand],
        runInShell: PlatformCommandsConfig.claudeRunInShell,
        environment: PlatformCommandsConfig.claudeEnvironment,
      );

      final stdout = (result.stdout as String).trim();
      final stderr = (result.stderr as String).trim();

      if (result.exitCode == 0) {
        return stdout.isNotEmpty ? stdout : '安装完成';
      } else {
        return stderr.isNotEmpty ? stderr : '安装失败 (退出码: ${result.exitCode})';
      }
    } catch (e) {
      return '安装出错: $e';
    }
  }

  /// 执行 Claude 安装（带实时输出回调）
  static Future<int> installClaudeWithOutput(void Function(String line) onOutput) async {
    File? tempScriptFile;

    try {
      Process process;

      // Windows 复杂脚本需要写入临时文件执行
      if (PlatformCommandsConfig.needsTempScriptFile) {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final script = PlatformCommandsConfig.claudeFullInstallScript;
        final shell = PlatformCommandsConfig.claudeShell;

        if (shell == 'powershell') {
          // PowerShell: 创建临时 .ps1 文件
          tempScriptFile = File(p.join(tempDir.path, 'mcp_switch_install_$timestamp.ps1'));

          // 写入 UTF-8 with BOM，PowerShell 才能正确识别中文
          final bom = [0xEF, 0xBB, 0xBF]; // UTF-8 BOM
          final scriptBytes = [...bom, ...utf8.encode(script)];
          await tempScriptFile.writeAsBytes(scriptBytes);

          process = await Process.start(
            'powershell',
            ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', tempScriptFile.path],
            runInShell: true,
            environment: PlatformCommandsConfig.claudeEnvironment,
          );
        } else {
          // CMD: 创建临时 .cmd 文件
          tempScriptFile = File(p.join(tempDir.path, 'mcp_switch_install_$timestamp.cmd'));

          // CMD 脚本：
          // 1. @echo off 关闭回显
          // 2. chcp 65001 设置 UTF-8 编码（支持中文输出）
          // 3. 把用户脚本的 \n 换成 \r\n（Windows 换行符）
          final windowsScript = script.replaceAll('\n', '\r\n');
          final cmdScript = '@echo off\r\nchcp 65001 >nul\r\n$windowsScript';

          // 使用 UTF-8 编码写入（配合 chcp 65001）
          await tempScriptFile.writeAsString(cmdScript, encoding: utf8);

          process = await Process.start(
            'cmd',
            ['/c', tempScriptFile.path],
            runInShell: true,
            environment: PlatformCommandsConfig.claudeEnvironment,
          );
        }
      } else {
        // 普通执行方式
        process = await Process.start(
          PlatformCommandsConfig.claudeShell,
          [...PlatformCommandsConfig.claudeShellArgs, PlatformCommandsConfig.claudeFullInstallCommand],
          runInShell: PlatformCommandsConfig.claudeRunInShell,
          environment: PlatformCommandsConfig.claudeEnvironment,
        );
      }

      // 选择解码器：CMD + chcp 65001 时用 UTF-8，否则用系统编码
      final useUtf8 = Platform.isWindows &&
          PlatformCommandsConfig.claudeShell == 'cmd' &&
          PlatformCommandsConfig.needsTempScriptFile;
      final decoder = useUtf8 ? utf8.decoder : const SystemEncoding().decoder;

      // 监听 stdout
      process.stdout.transform(decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onOutput(line);
          }
        }
      });

      // 监听 stderr
      process.stderr.transform(decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onOutput('[stderr] $line');
          }
        }
      });

      final exitCode = await process.exitCode;

      // 清理临时文件
      if (tempScriptFile != null && tempScriptFile.existsSync()) {
        try {
          await tempScriptFile.delete();
        } catch (_) {}
      }

      return exitCode;
    } catch (e) {
      // 清理临时文件
      if (tempScriptFile != null && tempScriptFile.existsSync()) {
        try {
          await tempScriptFile.delete();
        } catch (_) {}
      }
      onOutput('安装出错: $e');
      return -1;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Codex CLI 相关（配置从 YAML 文件加载）
  // ═══════════════════════════════════════════════════════════════════════════

  /// 【检测函数1】查找 Codex CLI 可执行文件的实际路径
  /// 返回: 文件路径（找到）或 null（未找到）
  ///
  /// Codex CLI 通过 npm install -g @openai/codex 安装
  /// - macOS/Linux: /usr/local/bin/codex 或 ~/.npm-global/bin/codex
  /// - Windows: %APPDATA%\npm\codex.cmd 或用户 npm 全局目录
  static Future<String?> findCodexExePath() async {
    await PlatformCommandsConfig.init();

    if (Platform.isWindows) {
      // 1. 检查 npm 全局安装路径 (AppData\Roaming\npm)
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final npmPath = p.join(appData, 'npm', 'codex.cmd');
        if (File(npmPath).existsSync()) {
          // LoggerService.debug('[findCodexExePath] 找到: $npmPath');
          return npmPath;
        }
      }

      // 2. 检查配置的路径
      for (final relPath in PlatformCommandsConfig.codexDetectPaths) {
        final fullPath = p.join(userHome, relPath);
        if (File(fullPath).existsSync()) {
          // LoggerService.debug('[findCodexExePath] 找到: $fullPath');
          return fullPath;
        }
      }

      // 3. 尝试 where 命令
      final whereResult = await Process.run('where', ['codex'], runInShell: true);
      if (whereResult.exitCode == 0) {
        final stdout = (whereResult.stdout as String).trim();
        if (stdout.isNotEmpty) {
          final path = stdout.split('\n').first.trim();
          // LoggerService.debug('[findCodexExePath] where 找到: $path');
          return path;
        }
      }

      // LoggerService.debug('[findCodexExePath] Windows: 未找到 codex');
      return null;
    } else {
      // macOS/Linux: 检查常见安装路径
      final paths = [
        '/usr/local/bin/codex',
        '/opt/homebrew/bin/codex',
        p.join(userHome, '.npm-global', 'bin', 'codex'),
        // fnm (Fast Node Manager) 默认路径
        p.join(userHome, '.local', 'share', 'fnm', 'aliases', 'default', 'bin', 'codex'),
        // nvm 默认路径
        p.join(userHome, '.nvm', 'current', 'bin', 'codex'),
      ];

      for (final path in paths) {
        if (File(path).existsSync()) {
          // LoggerService.debug('[findCodexExePath] 找到: $path');
          return path;
        }
      }

      // 检查配置的路径
      for (final relPath in PlatformCommandsConfig.codexDetectPaths) {
        final fullPath = p.join(userHome, relPath);
        if (File(fullPath).existsSync()) {
          // LoggerService.debug('[findCodexExePath] 找到: $fullPath');
          return fullPath;
        }
      }

      // 使用用户默认 shell 的交互模式获取完整 PATH（支持 fnm/nvm 等）
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final whichResult = await Process.run(shell, ['-i', '-c', 'which codex'],
        environment: {'HOME': userHome, 'USER': Platform.environment['USER'] ?? ''},
      );
      if (whichResult.exitCode == 0) {
        final path = (whichResult.stdout as String).trim();
        if (path.isNotEmpty) {
          // LoggerService.debug('[findCodexExePath] which 找到: $path');
          return path;
        }
      }

      // LoggerService.debug('[findCodexExePath] macOS/Linux: 未找到 codex');
      return null;
    }
  }

  /// 【检测函数2】检测 Codex CLI 是否在 PATH 环境变量中
  /// 返回: true（在 PATH 中）或 false（不在 PATH 中）
  static Future<bool> isCodexInPath({String? codexBinDir}) async {
    try {
      if (Platform.isWindows) {
        // 方法1：使用 where 命令
        final whereResult = await Process.run('where', ['codex'], runInShell: true);
        if (whereResult.exitCode == 0) {
          // LoggerService.debug('[isCodexInPath] Windows where: true');
          return true;
        }

        // 方法2：检查注册表中的用户 PATH
        final regUserPath = await _getWindowsUserPathFromRegistry();
        if (regUserPath != null && regUserPath.isNotEmpty) {
          if (codexBinDir != null) {
            final normalizedBinDir = codexBinDir.toLowerCase().replaceAll('/', '\\');
            if (regUserPath.toLowerCase().contains(normalizedBinDir)) {
              // LoggerService.debug('[isCodexInPath] Registry PATH contains $codexBinDir: true');
              return true;
            }
          }
          // 检查 npm 全局路径
          if (regUserPath.toLowerCase().contains('npm')) {
            // LoggerService.debug('[isCodexInPath] Registry PATH contains npm: true');
            return true;
          }
        }

        // LoggerService.debug('[isCodexInPath] Windows: false');
        return false;
      } else {
        // macOS/Linux: 使用用户默认 shell 的交互模式获取完整 PATH
        final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
        final whichResult = await Process.run(shell, ['-i', '-c', 'which codex'],
          environment: {'HOME': userHome, 'USER': Platform.environment['USER'] ?? ''},
        );
        final inPath = whichResult.exitCode == 0;
        // LoggerService.debug('[isCodexInPath] Unix which: $inPath');
        return inPath;
      }
    } catch (e) {
      LoggerService.error('[isCodexInPath] 检测异常', e);
      return false;
    }
  }

  /// 【组合函数】检测 Codex CLI 完整安装状态
  static Future<CodexInstallStatus> checkCodexInstallStatus() async {
    // 1. 查找可执行文件路径
    String? exePath = await findCodexExePath();

    // 2. 检测是否在 PATH 中
    // 如果通过硬编码路径找到，直接认为在 PATH 中（GUI app 环境 shell 检测不可靠）
    bool inPath = false;
    if (exePath != null && !Platform.isWindows) {
      // 标准系统路径 + fnm/nvm 路径都认为已配置好
      inPath = true;
      // LoggerService.debug('[checkCodexInstallStatus] 找到路径，直接认为 inPath=true');
    } else if (Platform.isWindows) {
      String? codexBinDir;
      if (exePath != null) {
        codexBinDir = p.dirname(exePath);
      }
      inPath = await isCodexInPath(codexBinDir: codexBinDir);
    }

    // 3. 如果 PATH 中有但 exePath 为空，从 PATH 获取路径
    if (inPath && exePath == null) {
      if (Platform.isWindows) {
        final whereResult = await Process.run('where', ['codex'], runInShell: true);
        if (whereResult.exitCode == 0) {
          final stdout = (whereResult.stdout as String).trim();
          if (stdout.isNotEmpty) {
            exePath = stdout.split('\n').first.trim();
          }
        }
      } else {
        final whichResult = await Process.run('which', ['codex']);
        if (whichResult.exitCode == 0) {
          exePath = (whichResult.stdout as String).trim();
        }
      }
    }

    // LoggerService.debug('[checkCodexInstallStatus] exePath=$exePath, inPath=$inPath');
    return CodexInstallStatus(exePath: exePath, inPath: inPath);
  }

  /// 获取 Codex CLI 版本（如果已安装）
  static Future<String?> getCodexVersion() async {
    try {
      final result = await runCommand('codex --version');
      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        return output.isNotEmpty ? output : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取 Codex 安装命令（显示给用户看的，易读格式）
  static String getCodexInstallCommand() {
    return PlatformCommandsConfig.codexDisplayCommand;
  }

  /// 执行 Codex 安装（带实时输出回调）
  static Future<int> installCodexWithOutput(void Function(String line) onOutput) async {
    File? tempScriptFile;

    try {
      Process process;

      // Windows 上使用最新的 PATH 环境变量（从注册表读取）
      // 解决安装 Node.js 后重启应用仍无法找到 npm 的问题
      clearWindowsPathCache(); // 清除缓存，强制读取最新 PATH
      final environment = await getUpdatedEnvironment(PlatformCommandsConfig.codexEnvironment);

      if (PlatformCommandsConfig.codexNeedsTempScriptFile) {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final script = PlatformCommandsConfig.codexFullInstallScript;
        final shell = PlatformCommandsConfig.codexShell;

        if (shell == 'powershell') {
          tempScriptFile = File(p.join(tempDir.path, 'mcp_switch_codex_install_$timestamp.ps1'));
          final bom = [0xEF, 0xBB, 0xBF];
          final scriptBytes = [...bom, ...utf8.encode(script)];
          await tempScriptFile.writeAsBytes(scriptBytes);

          process = await Process.start(
            'powershell',
            ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', tempScriptFile.path],
            runInShell: true,
            environment: environment,
          );
        } else {
          tempScriptFile = File(p.join(tempDir.path, 'mcp_switch_codex_install_$timestamp.cmd'));
          final windowsScript = script.replaceAll('\n', '\r\n');
          final cmdScript = '@echo off\r\nchcp 65001 >nul\r\n$windowsScript';
          await tempScriptFile.writeAsString(cmdScript, encoding: utf8);

          process = await Process.start(
            'cmd',
            ['/c', tempScriptFile.path],
            runInShell: true,
            environment: environment,
          );
        }
      } else {
        process = await Process.start(
          PlatformCommandsConfig.codexShell,
          [...PlatformCommandsConfig.codexShellArgs, PlatformCommandsConfig.codexFullInstallCommand],
          runInShell: PlatformCommandsConfig.codexRunInShell,
          environment: environment,
        );
      }

      final useUtf8 = Platform.isWindows &&
          PlatformCommandsConfig.codexShell == 'cmd' &&
          PlatformCommandsConfig.codexNeedsTempScriptFile;
      final decoder = useUtf8 ? utf8.decoder : const SystemEncoding().decoder;

      process.stdout.transform(decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onOutput(line);
          }
        }
      });

      process.stderr.transform(decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onOutput('[stderr] $line');
          }
        }
      });

      final exitCode = await process.exitCode;

      if (tempScriptFile != null && tempScriptFile.existsSync()) {
        try {
          await tempScriptFile.delete();
        } catch (_) {}
      }

      return exitCode;
    } catch (e) {
      if (tempScriptFile != null && tempScriptFile.existsSync()) {
        try {
          await tempScriptFile.delete();
        } catch (_) {}
      }
      onOutput('安装出错: $e');
      return -1;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Gemini CLI 相关（配置从 YAML 文件加载）
  // ═══════════════════════════════════════════════════════════════════════════

  /// 【检测函数1】查找 Gemini CLI 可执行文件的实际路径
  /// 返回: 文件路径（找到）或 null（未找到）
  ///
  /// Gemini CLI 通过 npm install -g @google/gemini-cli 安装
  /// - macOS/Linux: /usr/local/bin/gemini 或 ~/.npm-global/bin/gemini
  /// - Windows: %APPDATA%\npm\gemini.cmd 或用户 npm 全局目录
  static Future<String?> findGeminiExePath() async {
    await PlatformCommandsConfig.init();

    if (Platform.isWindows) {
      // 1. 检查 npm 全局安装路径 (AppData\Roaming\npm)
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        final npmPath = p.join(appData, 'npm', 'gemini.cmd');
        if (File(npmPath).existsSync()) {
          // LoggerService.debug('[findGeminiExePath] 找到: $npmPath');
          return npmPath;
        }
      }

      // 2. 检查配置的路径
      for (final relPath in PlatformCommandsConfig.geminiDetectPaths) {
        final fullPath = p.join(userHome, relPath);
        if (File(fullPath).existsSync()) {
          // LoggerService.debug('[findGeminiExePath] 找到: $fullPath');
          return fullPath;
        }
      }

      // 3. 尝试 where 命令
      final whereResult = await Process.run('where', ['gemini'], runInShell: true);
      if (whereResult.exitCode == 0) {
        final stdout = (whereResult.stdout as String).trim();
        if (stdout.isNotEmpty) {
          final path = stdout.split('\n').first.trim();
          // LoggerService.debug('[findGeminiExePath] where 找到: $path');
          return path;
        }
      }

      // LoggerService.debug('[findGeminiExePath] Windows: 未找到 gemini');
      return null;
    } else {
      // macOS/Linux: 检查常见安装路径
      final paths = [
        '/usr/local/bin/gemini',
        '/opt/homebrew/bin/gemini',
        p.join(userHome, '.npm-global', 'bin', 'gemini'),
        // fnm (Fast Node Manager) 默认路径
        p.join(userHome, '.local', 'share', 'fnm', 'aliases', 'default', 'bin', 'gemini'),
        // nvm 默认路径
        p.join(userHome, '.nvm', 'current', 'bin', 'gemini'),
      ];

      for (final path in paths) {
        if (File(path).existsSync()) {
          // LoggerService.debug('[findGeminiExePath] 找到: $path');
          return path;
        }
      }

      // 检查配置的路径
      for (final relPath in PlatformCommandsConfig.geminiDetectPaths) {
        final fullPath = p.join(userHome, relPath);
        if (File(fullPath).existsSync()) {
          // LoggerService.debug('[findGeminiExePath] 找到: $fullPath');
          return fullPath;
        }
      }

      // 使用用户默认 shell 的交互模式获取完整 PATH（支持 fnm/nvm 等）
      final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      final whichResult = await Process.run(shell, ['-i', '-c', 'which gemini'],
        environment: {'HOME': userHome, 'USER': Platform.environment['USER'] ?? ''},
      );
      if (whichResult.exitCode == 0) {
        final path = (whichResult.stdout as String).trim();
        if (path.isNotEmpty) {
          // LoggerService.debug('[findGeminiExePath] which 找到: $path');
          return path;
        }
      }

      // LoggerService.debug('[findGeminiExePath] macOS/Linux: 未找到 gemini');
      return null;
    }
  }

  /// 【检测函数2】检测 Gemini CLI 是否在 PATH 环境变量中
  /// 返回: true（在 PATH 中）或 false（不在 PATH 中）
  static Future<bool> isGeminiInPath({String? geminiBinDir}) async {
    try {
      if (Platform.isWindows) {
        // 方法1：使用 where 命令
        final whereResult = await Process.run('where', ['gemini'], runInShell: true);
        if (whereResult.exitCode == 0) {
          // LoggerService.debug('[isGeminiInPath] Windows where: true');
          return true;
        }

        // 方法2：检查注册表中的用户 PATH
        final regUserPath = await _getWindowsUserPathFromRegistry();
        if (regUserPath != null && regUserPath.isNotEmpty) {
          if (geminiBinDir != null) {
            final normalizedBinDir = geminiBinDir.toLowerCase().replaceAll('/', '\\');
            if (regUserPath.toLowerCase().contains(normalizedBinDir)) {
              // LoggerService.debug('[isGeminiInPath] Registry PATH contains $geminiBinDir: true');
              return true;
            }
          }
          // 检查 npm 全局路径
          if (regUserPath.toLowerCase().contains('npm')) {
            // LoggerService.debug('[isGeminiInPath] Registry PATH contains npm: true');
            return true;
          }
        }

        // LoggerService.debug('[isGeminiInPath] Windows: false');
        return false;
      } else {
        // macOS/Linux: 使用用户默认 shell 的交互模式获取完整 PATH
        final shell = Platform.environment['SHELL'] ?? '/bin/zsh';
        final whichResult = await Process.run(shell, ['-i', '-c', 'which gemini'],
          environment: {'HOME': userHome, 'USER': Platform.environment['USER'] ?? ''},
        );
        final inPath = whichResult.exitCode == 0;
        // LoggerService.debug('[isGeminiInPath] Unix which: $inPath');
        return inPath;
      }
    } catch (e) {
      // LoggerService.error('[isGeminiInPath] 检测异常', e);
      return false;
    }
  }

  /// 【组合函数】检测 Gemini CLI 完整安装状态
  static Future<GeminiInstallStatus> checkGeminiInstallStatus() async {
    // 1. 查找可执行文件路径
    String? exePath = await findGeminiExePath();

    // 2. 检测是否在 PATH 中
    // 如果通过硬编码路径找到，直接认为在 PATH 中（GUI app 环境 shell 检测不可靠）
    bool inPath = false;
    if (exePath != null && !Platform.isWindows) {
      // 标准系统路径 + fnm/nvm 路径都认为已配置好
      inPath = true;
      // LoggerService.debug('[checkGeminiInstallStatus] 找到路径，直接认为 inPath=true');
    } else if (Platform.isWindows) {
      String? geminiBinDir;
      if (exePath != null) {
        geminiBinDir = p.dirname(exePath);
      }
      inPath = await isGeminiInPath(geminiBinDir: geminiBinDir);
    }

    // 3. 如果 PATH 中有但 exePath 为空，从 PATH 获取路径
    if (inPath && exePath == null) {
      if (Platform.isWindows) {
        final whereResult = await Process.run('where', ['gemini'], runInShell: true);
        if (whereResult.exitCode == 0) {
          final stdout = (whereResult.stdout as String).trim();
          if (stdout.isNotEmpty) {
            exePath = stdout.split('\n').first.trim();
          }
        }
      } else {
        final whichResult = await Process.run('which', ['gemini']);
        if (whichResult.exitCode == 0) {
          exePath = (whichResult.stdout as String).trim();
        }
      }
    }

    // LoggerService.debug('[checkGeminiInstallStatus] exePath=$exePath, inPath=$inPath');
    return GeminiInstallStatus(exePath: exePath, inPath: inPath);
  }

  /// 获取 Gemini CLI 版本（如果已安装）
  static Future<String?> getGeminiVersion() async {
    try {
      final result = await runCommand('gemini --version');
      if (result.exitCode == 0) {
        final output = (result.stdout as String).trim();
        return output.isNotEmpty ? output : null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 获取 Gemini 安装命令（显示给用户看的，易读格式）
  static String getGeminiInstallCommand() {
    return PlatformCommandsConfig.geminiDisplayCommand;
  }

  /// 执行 Gemini 安装（带实时输出回调）
  static Future<int> installGeminiWithOutput(void Function(String line) onOutput) async {
    File? tempScriptFile;

    try {
      Process process;

      // Windows 上使用最新的 PATH 环境变量（从注册表读取）
      // 解决安装 Node.js 后重启应用仍无法找到 npm 的问题
      clearWindowsPathCache(); // 清除缓存，强制读取最新 PATH
      final environment = await getUpdatedEnvironment(PlatformCommandsConfig.geminiEnvironment);

      if (PlatformCommandsConfig.geminiNeedsTempScriptFile) {
        final tempDir = Directory.systemTemp;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final script = PlatformCommandsConfig.geminiFullInstallScript;
        final shell = PlatformCommandsConfig.geminiShell;

        if (shell == 'powershell') {
          tempScriptFile = File(p.join(tempDir.path, 'mcp_switch_gemini_install_$timestamp.ps1'));
          final bom = [0xEF, 0xBB, 0xBF];
          final scriptBytes = [...bom, ...utf8.encode(script)];
          await tempScriptFile.writeAsBytes(scriptBytes);

          process = await Process.start(
            'powershell',
            ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', tempScriptFile.path],
            runInShell: true,
            environment: environment,
          );
        } else {
          tempScriptFile = File(p.join(tempDir.path, 'mcp_switch_gemini_install_$timestamp.cmd'));
          final windowsScript = script.replaceAll('\n', '\r\n');
          final cmdScript = '@echo off\r\nchcp 65001 >nul\r\n$windowsScript';
          await tempScriptFile.writeAsString(cmdScript, encoding: utf8);

          process = await Process.start(
            'cmd',
            ['/c', tempScriptFile.path],
            runInShell: true,
            environment: environment,
          );
        }
      } else {
        process = await Process.start(
          PlatformCommandsConfig.geminiShell,
          [...PlatformCommandsConfig.geminiShellArgs, PlatformCommandsConfig.geminiFullInstallCommand],
          runInShell: PlatformCommandsConfig.geminiRunInShell,
          environment: environment,
        );
      }

      final useUtf8 = Platform.isWindows &&
          PlatformCommandsConfig.geminiShell == 'cmd' &&
          PlatformCommandsConfig.geminiNeedsTempScriptFile;
      final decoder = useUtf8 ? utf8.decoder : const SystemEncoding().decoder;

      process.stdout.transform(decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onOutput(line);
          }
        }
      });

      process.stderr.transform(decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            onOutput('[stderr] $line');
          }
        }
      });

      final exitCode = await process.exitCode;

      if (tempScriptFile != null && tempScriptFile.existsSync()) {
        try {
          await tempScriptFile.delete();
        } catch (_) {}
      }

      return exitCode;
    } catch (e) {
      if (tempScriptFile != null && tempScriptFile.existsSync()) {
        try {
          await tempScriptFile.delete();
        } catch (_) {}
      }
      onOutput('安装出错: $e');
      return -1;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 路径工具
  // ═══════════════════════════════════════════════════════════════════════════

  /// 使用 path 包拼接路径（跨平台安全）
  static String joinPath(String part1, [String? part2, String? part3, String? part4, String? part5]) {
    if (part5 != null) return p.join(part1, part2!, part3!, part4!, part5);
    if (part4 != null) return p.join(part1, part2!, part3!, part4);
    if (part3 != null) return p.join(part1, part2!, part3);
    if (part2 != null) return p.join(part1, part2);
    return part1;
  }

  /// 获取路径的目录名
  static String dirname(String path) => p.dirname(path);

  /// 获取路径的文件名
  static String basename(String path) => p.basename(path);

  /// 规范化路径（处理 .. 和 . 等）
  static String normalize(String path) => p.normalize(path);
}
