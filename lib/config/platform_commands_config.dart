import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import '../utils/platform_utils.dart';

/// 平台命令配置加载器
///
/// 加载顺序：
/// 1. 首先检查用户目录 ~/.mcp-switch/config/platform_commands.yaml
/// 2. 如果不存在，从 assets 复制默认配置到用户目录
/// 3. 读取用户目录的配置文件
///
/// 用户可以修改 ~/.mcp-switch/config/platform_commands.yaml 来自定义：
/// - pre_hooks: 安装前执行的命令（如设置代理）
/// - post_hooks: 安装后执行的命令
/// - install_script: 自定义安装脚本
/// - environment: 自定义环境变量
class PlatformCommandsConfig {
  static Map<String, dynamic> _config = {};
  static bool _initialized = false;

  /// 用户配置文件路径
  static String get userConfigPath {
    return '${PlatformUtils.appDataDir}/config/platform_commands.yaml';
  }

  /// 初始化配置
  /// 如果用户目录没有配置文件，从 assets 复制一份
  static Future<void> init() async {
    if (_initialized) return;

    final userConfigFile = File(userConfigPath);

    // 如果用户配置不存在，从 assets 复制
    if (!userConfigFile.existsSync()) {
      await _copyDefaultConfig(userConfigFile);
    }

    // 读取用户配置
    try {
      final yamlString = await userConfigFile.readAsString();
      final yamlDoc = loadYaml(yamlString);
      final parsed = _yamlToMap(yamlDoc);
      _config = parsed is Map<String, dynamic> ? parsed : {};
    } catch (e) {
      // 如果读取失败，尝试从 assets 重新加载
      print('读取用户配置失败: $e，使用默认配置');
      await _loadFromAssets();
    }

    _initialized = true;
  }

  /// 从 assets 复制默认配置到用户目录
  static Future<void> _copyDefaultConfig(File targetFile) async {
    try {
      // 确保目录存在
      final dir = targetFile.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      // 从 assets 读取默认配置
      final defaultYaml = await rootBundle.loadString('assets/config/platform_commands.yaml');

      // 写入用户目录
      await targetFile.writeAsString(defaultYaml);
      print('已复制默认配置到: ${targetFile.path}');
    } catch (e) {
      print('复制默认配置失败: $e');
    }
  }

  /// 从 assets 加载配置（备用方案）
  static Future<void> _loadFromAssets() async {
    try {
      final yamlString = await rootBundle.loadString('assets/config/platform_commands.yaml');
      final yamlDoc = loadYaml(yamlString);
      final parsed = _yamlToMap(yamlDoc);
      _config = parsed is Map<String, dynamic> ? parsed : {};
    } catch (e) {
      print('从 assets 加载配置失败: $e');
      _config = {};
    }
  }

  /// 将 YAML 数据转换为 Dart 原生类型
  /// YamlMap -> Map<String, dynamic>
  /// YamlList -> List<dynamic>
  /// 其他类型保持原样
  static dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries.map((e) => MapEntry(e.key.toString(), _yamlToMap(e.value))),
      );
    } else if (yaml is YamlList) {
      return yaml.map((e) => _yamlToMap(e)).toList();
    } else if (yaml is Map) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries.map((e) => MapEntry(e.key.toString(), _yamlToMap(e.value))),
      );
    }
    return yaml;
  }

  /// 获取当前平台的配置（顶层）
  /// 带容错处理，配置损坏时返回空 Map
  static Map<String, dynamic> get _platformConfig {
    try {
      final claudeConfig = _config['claude_code_download'];
      if (claudeConfig is! Map<String, dynamic>) return {};

      if (Platform.isWindows) {
        final win = claudeConfig['windows'];
        return win is Map<String, dynamic> ? win : {};
      } else if (Platform.isMacOS) {
        final mac = claudeConfig['macos'];
        return mac is Map<String, dynamic> ? mac : {};
      } else {
        final linux = claudeConfig['linux'];
        return linux is Map<String, dynamic> ? linux : {};
      }
    } catch (_) {
      return {};
    }
  }

  /// 获取 Codex 当前平台的配置（顶层）
  static Map<String, dynamic> get _codexPlatformConfig {
    try {
      final codexConfig = _config['codex_download'];
      if (codexConfig is! Map<String, dynamic>) return {};

      if (Platform.isWindows) {
        final win = codexConfig['windows'];
        return win is Map<String, dynamic> ? win : {};
      } else if (Platform.isMacOS) {
        final mac = codexConfig['macos'];
        return mac is Map<String, dynamic> ? mac : {};
      } else {
        final linux = codexConfig['linux'];
        return linux is Map<String, dynamic> ? linux : {};
      }
    } catch (_) {
      return {};
    }
  }

  /// 获取 Gemini 当前平台的配置（顶层）
  static Map<String, dynamic> get _geminiPlatformConfig {
    try {
      final geminiConfig = _config['gemini_download'];
      if (geminiConfig is! Map<String, dynamic>) return {};

      if (Platform.isWindows) {
        final win = geminiConfig['windows'];
        return win is Map<String, dynamic> ? win : {};
      } else if (Platform.isMacOS) {
        final mac = geminiConfig['macos'];
        return mac is Map<String, dynamic> ? mac : {};
      } else {
        final linux = geminiConfig['linux'];
        return linux is Map<String, dynamic> ? linux : {};
      }
    } catch (_) {
      return {};
    }
  }

  /// 获取当前选择的 Shell 类型
  /// - Windows: powershell 或 cmd
  /// - macOS: bash 或 zsh（默认 zsh，Catalina 后默认 shell）
  /// - Linux: bash 或 zsh（默认 bash）
  static String get _selectedShell {
    final useShell = _platformConfig['use_shell'] as String?;
    if (useShell != null) return useShell;

    // 默认值
    if (Platform.isWindows) return 'powershell';
    if (Platform.isMacOS) return 'zsh';
    return 'bash';
  }

  /// 获取当前生效的 Shell 配置
  /// 根据 use_shell 选择对应的子配置
  /// 支持新格式（shells 数组）和旧格式（直接子配置）
  static Map<String, dynamic> get _shellConfig {
    try {
      final shellType = _selectedShell;

      // 新格式：shells 数组
      final shells = _platformConfig['shells'];
      if (shells is List) {
        for (final shell in shells) {
          if (shell is Map && shell['name'] == shellType) {
            return Map<String, dynamic>.from(shell);
          }
        }
      }

      // 旧格式：直接子配置
      final shellConfig = _platformConfig[shellType];
      return shellConfig is Map<String, dynamic> ? shellConfig : _platformConfig;
    } catch (_) {
      return {};
    }
  }

  /// 获取当前平台所有可用的 Shell 配置列表
  /// 返回 [{name, display_name, shell, install_script, pre_script, ...}]
  static List<Map<String, dynamic>> get allShellConfigs {
    try {
      final shells = _platformConfig['shells'];
      if (shells is List) {
        return shells
            .whereType<Map>()
            .map((s) => Map<String, dynamic>.from(s))
            .toList();
      }

      // 旧格式兼容：尝试提取已知的 shell 配置
      final result = <Map<String, dynamic>>[];
      if (Platform.isWindows) {
        for (final name in ['powershell', 'cmd']) {
          final config = _platformConfig[name];
          if (config is Map<String, dynamic>) {
            result.add({...config, 'name': name, 'display_name': name});
          }
        }
      } else {
        for (final name in ['bash', 'zsh']) {
          final config = _platformConfig[name];
          if (config is Map<String, dynamic>) {
            result.add({...config, 'name': name, 'display_name': name});
          }
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// 根据 shell 名称获取完整安装命令
  /// 用于复制到剪贴板
  static String getFullCommandForShell(String shellName) {
    try {
      Map<String, dynamic>? shellConfig;

      // 在 shells 数组中查找
      final shells = _platformConfig['shells'];
      if (shells is List) {
        for (final shell in shells) {
          if (shell is Map && shell['name'] == shellName) {
            shellConfig = Map<String, dynamic>.from(shell);
            break;
          }
        }
      }

      // 旧格式
      shellConfig ??= _platformConfig[shellName] as Map<String, dynamic>?;

      if (shellConfig == null) return '';

      final preScript = (shellConfig['pre_script'] as String?)?.trim() ?? '';
      final installScript = (shellConfig['install_script'] as String?) ??
          _platformConfig['install_script'] as String? ??
          '';

      if (preScript.isEmpty) return installScript;
      return '$preScript\n$installScript';
    } catch (_) {
      return '';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Claude CLI 配置 Getters
  // ═══════════════════════════════════════════════════════════════════════════

  /// 获取 Shell 程序
  /// 带容错处理
  static String get claudeShell {
    try {
      final shell = _shellConfig['shell'];
      if (shell is String && shell.isNotEmpty) return shell;
    } catch (_) {}
    return Platform.isWindows ? 'powershell' : 'bash';
  }

  /// 获取 Shell 参数
  /// 带容错处理，配置损坏时返回默认值
  static List<String> get claudeShellArgs {
    try {
      final args = _shellConfig['shell_args'];
      if (args is List) {
        return args.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // 忽略错误，使用默认值
    }
    // 默认参数
    if (Platform.isWindows) {
      return _selectedShell == 'cmd' ? ['/c'] : ['-NoProfile', '-Command'];
    }
    return ['-c'];
  }

  /// 是否在 Shell 中运行
  /// 优先从 Shell 子配置读取，回退到平台顶层配置
  static bool get claudeRunInShell {
    try {
      // 先查 Shell 子配置
      final shellValue = _shellConfig['run_in_shell'];
      if (shellValue is bool) return shellValue;
      // 再查平台顶层配置
      final platformValue = _platformConfig['run_in_shell'];
      if (platformValue is bool) return platformValue;
    } catch (_) {}
    return Platform.isWindows;
  }

  /// 获取安装前脚本
  /// 优先读取 pre_script（多行字符串），回退到 pre_hooks（数组，兼容旧格式）
  static String get claudePreScript {
    try {
      // 1. 优先读取 pre_script（新格式，多行字符串）
      final shellScript = _shellConfig['pre_script'];
      if (shellScript is String && shellScript.trim().isNotEmpty) {
        return shellScript.trim();
      }
      final platformScript = _platformConfig['pre_script'];
      if (platformScript is String && platformScript.trim().isNotEmpty) {
        return platformScript.trim();
      }

      // 2. 回退到 pre_hooks（旧格式，数组）
      final shellHooks = _shellConfig['pre_hooks'];
      if (shellHooks is List && shellHooks.isNotEmpty) {
        return _hooksToScript(shellHooks);
      }
      final platformHooks = _platformConfig['pre_hooks'];
      if (platformHooks is List && platformHooks.isNotEmpty) {
        return _hooksToScript(platformHooks);
      }
    } catch (_) {}
    return '';
  }

  /// 将 hooks 数组转换为脚本（用换行符连接）
  static String _hooksToScript(List hooks) {
    return hooks.map((e) => e.toString()).join('\n');
  }

  /// 获取安装脚本
  /// 优先从 Shell 子配置读取，回退到平台顶层配置
  static String get claudeInstallScript {
    try {
      // 先查 Shell 子配置
      final shellScript = _shellConfig['install_script'];
      if (shellScript is String && shellScript.isNotEmpty) return shellScript;
      // 再查平台顶层配置
      final platformScript = _platformConfig['install_script'];
      if (platformScript is String && platformScript.isNotEmpty) return platformScript;
    } catch (_) {}
    return _defaultInstallScript;
  }

  /// 默认安装脚本
  static String get _defaultInstallScript {
    if (Platform.isWindows) {
      return _selectedShell == 'cmd'
          ? 'curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd'
          : 'irm https://claude.ai/install.ps1 | iex';
    }
    return 'curl -fsSL https://claude.ai/install.sh | sh';
  }

  /// 获取完整的安装命令（包含 pre_script）
  /// PowerShell: 写入临时 .ps1 文件执行（支持 try/catch 等复杂语法）
  /// 其他: 直接拼接脚本
  static String get claudeFullInstallCommand {
    final preScript = claudePreScript;
    final installScript = claudeInstallScript;

    if (preScript.isEmpty) {
      return installScript;
    }

    // CMD 或 Unix: 用换行符拼接
    return '$preScript\n$installScript';
  }

  /// 获取完整的安装脚本内容（用于写入临时文件）
  /// 包含 pre_script + install_script + post_script
  static String get claudeFullInstallScript {
    final preScript = claudePreScript;
    final installScript = claudeInstallScript;
    final postScript = claudePostScript;

    final parts = <String>[];
    if (preScript.isNotEmpty) parts.add(preScript);
    parts.add(installScript);
    if (postScript.isNotEmpty) parts.add(postScript);

    return parts.join('\n');
  }

  /// 是否需要使用临时脚本文件执行
  /// - PowerShell: try/catch 等复杂语法不能通过 -Command 参数直接执行
  /// - CMD: 多行脚本中 set 的环境变量不会传递给后续命令，必须用临时 .cmd 文件
  static bool get needsTempScriptFile {
    if (!Platform.isWindows) return false;
    final preScript = claudePreScript;

    if (_selectedShell == 'powershell') {
      // PowerShell: 复杂语法需要临时文件
      return preScript.contains('try') ||
          preScript.contains('catch') ||
          preScript.contains('finally') ||
          preScript.contains('{') ||
          preScript.split('\n').length > 3;
    } else if (_selectedShell == 'cmd') {
      // CMD: 只要有 pre_script 就需要临时文件（set 环境变量问题）
      return preScript.isNotEmpty;
    }
    return false;
  }

  /// 获取用于显示的安装命令（不含 ScriptBlock 包裹，更易读）
  static String get claudeDisplayCommand {
    final preScript = claudePreScript;
    final installScript = claudeInstallScript;

    if (preScript.isEmpty) {
      return installScript;
    }

    return '$preScript\n$installScript';
  }

  /// 获取安装后脚本
  /// 优先读取 post_script（多行字符串），回退到 post_hooks（数组，兼容旧格式）
  static String get claudePostScript {
    try {
      // 1. 优先读取 post_script（新格式，多行字符串）
      final shellScript = _shellConfig['post_script'];
      if (shellScript is String && shellScript.trim().isNotEmpty) {
        return shellScript.trim();
      }
      final platformScript = _platformConfig['post_script'];
      if (platformScript is String && platformScript.trim().isNotEmpty) {
        return platformScript.trim();
      }

      // 2. 回退到 post_hooks（旧格式，数组）
      final shellHooks = _shellConfig['post_hooks'];
      if (shellHooks is List && shellHooks.isNotEmpty) {
        return _hooksToScript(shellHooks);
      }
      final platformHooks = _platformConfig['post_hooks'];
      if (platformHooks is List && platformHooks.isNotEmpty) {
        return _hooksToScript(platformHooks);
      }
    } catch (_) {}
    return '';
  }

  /// 获取安装后钩子（兼容旧 API）
  /// 优先从 Shell 子配置读取，回退到平台顶层配置
  static List<String> get claudePostHooks {
    try {
      // 先查 Shell 子配置
      final shellHooks = _shellConfig['post_hooks'];
      if (shellHooks is List && shellHooks.isNotEmpty) {
        return shellHooks.map((e) => e.toString()).toList();
      }
      // 再查平台顶层配置
      final platformHooks = _platformConfig['post_hooks'];
      if (platformHooks is List) {
        return platformHooks.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  /// 获取检测路径
  /// 带容错处理，配置损坏时返回默认路径
  static List<String> get claudeDetectPaths {
    try {
      final paths = _platformConfig['detect_paths'];
      if (paths is List && paths.isNotEmpty) {
        return paths.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    // 默认路径
    if (Platform.isWindows) {
      return [
        '.claude\\local\\bin\\claude.exe',
        '.claude\\bin\\claude.exe',
        'AppData\\Local\\Programs\\claude\\claude.exe',
      ];
    }
    return ['.claude/local/bin/claude'];
  }

  /// 获取环境变量
  /// 带容错处理
  static Map<String, String> get claudeEnvironment {
    final env = Map<String, String>.from(Platform.environment);

    try {
      final configEnv = _platformConfig['environment'];
      if (configEnv is Map) {
        for (final entry in configEnv.entries) {
          var value = entry.value.toString();
          // 展开环境变量引用
          value = _expandEnvVars(value);
          env[entry.key.toString()] = value;
        }
      }
    } catch (_) {
      // 忽略错误，使用系统环境变量
    }

    return env;
  }

  /// 展开环境变量引用（如 ${PATH}、${HOME}、${USER}）
  static String _expandEnvVars(String value) {
    return value.replaceAllMapped(
      RegExp(r'\$\{(\w+)\}|\$(\w+)'),
      (match) {
        final varName = match.group(1) ?? match.group(2);
        return Platform.environment[varName] ?? '';
      },
    );
  }

  /// 重新加载配置（用户修改配置后调用）
  static Future<void> reload() async {
    _initialized = false;
    _config = {};
    await init();
  }

  /// 强制从 assets 重新加载配置（开发调试用）
  /// 会删除用户配置并从 assets 重新复制
  static Future<void> forceReloadFromAssets() async {
    final userConfigFile = File(userConfigPath);

    // 删除现有用户配置
    if (userConfigFile.existsSync()) {
      await userConfigFile.delete();
      print('已删除用户配置: ${userConfigFile.path}');
    }

    // 重新初始化（会从 assets 复制）
    _initialized = false;
    _config = {};
    await init();

    print('已从 assets 重新加载配置');
  }

  /// 打开配置文件所在目录
  static Future<void> openConfigFolder() async {
    final configFile = File(userConfigPath);
    if (configFile.existsSync()) {
      await PlatformUtils.openInFileManager(userConfigPath);
    } else {
      // 确保配置存在
      await init();
      await PlatformUtils.openInFileManager(userConfigPath);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Codex CLI 配置 Getters
  // ═══════════════════════════════════════════════════════════════════════════

  /// Codex 当前选择的 Shell 类型
  static String get _codexSelectedShell {
    final useShell = _codexPlatformConfig['use_shell'] as String?;
    if (useShell != null) return useShell;
    if (Platform.isWindows) return 'powershell';
    if (Platform.isMacOS) return 'zsh';
    return 'bash';
  }

  /// Codex 当前生效的 Shell 配置
  static Map<String, dynamic> get _codexShellConfig {
    try {
      final shellType = _codexSelectedShell;
      final shells = _codexPlatformConfig['shells'];
      if (shells is List) {
        for (final shell in shells) {
          if (shell is Map && shell['name'] == shellType) {
            return Map<String, dynamic>.from(shell);
          }
        }
      }
      final shellConfig = _codexPlatformConfig[shellType];
      return shellConfig is Map<String, dynamic> ? shellConfig : _codexPlatformConfig;
    } catch (_) {
      return {};
    }
  }

  /// Codex Shell 程序
  static String get codexShell {
    try {
      final shell = _codexShellConfig['shell'];
      if (shell is String && shell.isNotEmpty) return shell;
    } catch (_) {}
    return Platform.isWindows ? 'powershell' : 'bash';
  }

  /// Codex Shell 参数
  static List<String> get codexShellArgs {
    try {
      final args = _codexShellConfig['shell_args'];
      if (args is List) {
        return args.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    if (Platform.isWindows) {
      return _codexSelectedShell == 'cmd' ? ['/c'] : ['-NoProfile', '-Command'];
    }
    return ['-c'];
  }

  /// Codex 是否在 Shell 中运行
  static bool get codexRunInShell {
    try {
      final shellValue = _codexShellConfig['run_in_shell'];
      if (shellValue is bool) return shellValue;
      final platformValue = _codexPlatformConfig['run_in_shell'];
      if (platformValue is bool) return platformValue;
    } catch (_) {}
    return Platform.isWindows;
  }

  /// Codex 安装前脚本
  static String get codexPreScript {
    try {
      final shellScript = _codexShellConfig['pre_script'];
      if (shellScript is String && shellScript.trim().isNotEmpty) {
        return shellScript.trim();
      }
      final platformScript = _codexPlatformConfig['pre_script'];
      if (platformScript is String && platformScript.trim().isNotEmpty) {
        return platformScript.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Codex 安装脚本
  static String get codexInstallScript {
    try {
      final shellScript = _codexShellConfig['install_script'];
      if (shellScript is String && shellScript.isNotEmpty) return shellScript;
      final platformScript = _codexPlatformConfig['install_script'];
      if (platformScript is String && platformScript.isNotEmpty) return platformScript;
    } catch (_) {}
    return _defaultCodexInstallScript;
  }

  /// Codex 默认安装脚本
  static String get _defaultCodexInstallScript {
    // Codex 通过 npm 安装
    return 'npm install -g @openai/codex';
  }

  /// Codex 安装后脚本
  static String get codexPostScript {
    try {
      final shellScript = _codexShellConfig['post_script'];
      if (shellScript is String && shellScript.trim().isNotEmpty) {
        return shellScript.trim();
      }
      final platformScript = _codexPlatformConfig['post_script'];
      if (platformScript is String && platformScript.trim().isNotEmpty) {
        return platformScript.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Codex 完整安装命令
  static String get codexFullInstallCommand {
    final preScript = codexPreScript;
    final installScript = codexInstallScript;
    if (preScript.isEmpty) return installScript;
    return '$preScript\n$installScript';
  }

  /// Codex 完整安装脚本（包含 pre + install + post）
  static String get codexFullInstallScript {
    final preScript = codexPreScript;
    final installScript = codexInstallScript;
    final postScript = codexPostScript;

    final parts = <String>[];
    if (preScript.isNotEmpty) parts.add(preScript);
    parts.add(installScript);
    if (postScript.isNotEmpty) parts.add(postScript);

    return parts.join('\n');
  }

  /// Codex 是否需要临时脚本文件
  static bool get codexNeedsTempScriptFile {
    if (!Platform.isWindows) return false;
    final preScript = codexPreScript;

    if (_codexSelectedShell == 'powershell') {
      return preScript.contains('try') ||
          preScript.contains('catch') ||
          preScript.contains('finally') ||
          preScript.contains('{') ||
          preScript.split('\n').length > 3;
    } else if (_codexSelectedShell == 'cmd') {
      return preScript.isNotEmpty;
    }
    return false;
  }

  /// Codex 显示命令（用于 UI）
  static String get codexDisplayCommand {
    final preScript = codexPreScript;
    final installScript = codexInstallScript;
    if (preScript.isEmpty) return installScript;
    return '$preScript\n$installScript';
  }

  /// Codex 检测路径
  static List<String> get codexDetectPaths {
    try {
      final paths = _codexPlatformConfig['detect_paths'];
      if (paths is List && paths.isNotEmpty) {
        return paths.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    // 默认路径（npm 全局安装）
    if (Platform.isWindows) {
      return [
        'AppData\\Roaming\\npm\\codex.cmd',
        'AppData\\Roaming\\npm\\codex',
      ];
    }
    return [
      '.npm-global/bin/codex',
      '.nvm/versions/node/*/bin/codex',
    ];
  }

  /// Codex 环境变量
  static Map<String, String> get codexEnvironment {
    final env = Map<String, String>.from(Platform.environment);

    try {
      final configEnv = _codexPlatformConfig['environment'];
      if (configEnv is Map) {
        for (final entry in configEnv.entries) {
          var value = entry.value.toString();
          value = _expandEnvVars(value);
          env[entry.key.toString()] = value;
        }
      }
    } catch (_) {}

    return env;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Gemini CLI 配置 Getters
  // ═══════════════════════════════════════════════════════════════════════════

  /// Gemini 当前选择的 Shell 类型
  static String get _geminiSelectedShell {
    final useShell = _geminiPlatformConfig['use_shell'] as String?;
    if (useShell != null) return useShell;
    if (Platform.isWindows) return 'powershell';
    if (Platform.isMacOS) return 'zsh';
    return 'bash';
  }

  /// Gemini 当前生效的 Shell 配置
  static Map<String, dynamic> get _geminiShellConfig {
    try {
      final shellType = _geminiSelectedShell;
      final shells = _geminiPlatformConfig['shells'];
      if (shells is List) {
        for (final shell in shells) {
          if (shell is Map && shell['name'] == shellType) {
            return Map<String, dynamic>.from(shell);
          }
        }
      }
      final shellConfig = _geminiPlatformConfig[shellType];
      return shellConfig is Map<String, dynamic> ? shellConfig : _geminiPlatformConfig;
    } catch (_) {
      return {};
    }
  }

  /// Gemini Shell 程序
  static String get geminiShell {
    try {
      final shell = _geminiShellConfig['shell'];
      if (shell is String && shell.isNotEmpty) return shell;
    } catch (_) {}
    return Platform.isWindows ? 'powershell' : 'bash';
  }

  /// Gemini Shell 参数
  static List<String> get geminiShellArgs {
    try {
      final args = _geminiShellConfig['shell_args'];
      if (args is List) {
        return args.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    if (Platform.isWindows) {
      return _geminiSelectedShell == 'cmd' ? ['/c'] : ['-NoProfile', '-Command'];
    }
    return ['-c'];
  }

  /// Gemini 是否在 Shell 中运行
  static bool get geminiRunInShell {
    try {
      final shellValue = _geminiShellConfig['run_in_shell'];
      if (shellValue is bool) return shellValue;
      final platformValue = _geminiPlatformConfig['run_in_shell'];
      if (platformValue is bool) return platformValue;
    } catch (_) {}
    return Platform.isWindows;
  }

  /// Gemini 安装前脚本
  static String get geminiPreScript {
    try {
      final shellScript = _geminiShellConfig['pre_script'];
      if (shellScript is String && shellScript.trim().isNotEmpty) {
        return shellScript.trim();
      }
      final platformScript = _geminiPlatformConfig['pre_script'];
      if (platformScript is String && platformScript.trim().isNotEmpty) {
        return platformScript.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Gemini 安装脚本
  static String get geminiInstallScript {
    try {
      final shellScript = _geminiShellConfig['install_script'];
      if (shellScript is String && shellScript.isNotEmpty) return shellScript;
      final platformScript = _geminiPlatformConfig['install_script'];
      if (platformScript is String && platformScript.isNotEmpty) return platformScript;
    } catch (_) {}
    return _defaultGeminiInstallScript;
  }

  /// Gemini 默认安装脚本
  static String get _defaultGeminiInstallScript {
    return 'npm install -g @google/gemini-cli';
  }

  /// Gemini 安装后脚本
  static String get geminiPostScript {
    try {
      final shellScript = _geminiShellConfig['post_script'];
      if (shellScript is String && shellScript.trim().isNotEmpty) {
        return shellScript.trim();
      }
      final platformScript = _geminiPlatformConfig['post_script'];
      if (platformScript is String && platformScript.trim().isNotEmpty) {
        return platformScript.trim();
      }
    } catch (_) {}
    return '';
  }

  /// Gemini 完整安装命令
  static String get geminiFullInstallCommand {
    final preScript = geminiPreScript;
    final installScript = geminiInstallScript;
    if (preScript.isEmpty) return installScript;
    return '$preScript\n$installScript';
  }

  /// Gemini 完整安装脚本（包含 pre + install + post）
  static String get geminiFullInstallScript {
    final preScript = geminiPreScript;
    final installScript = geminiInstallScript;
    final postScript = geminiPostScript;

    final parts = <String>[];
    if (preScript.isNotEmpty) parts.add(preScript);
    parts.add(installScript);
    if (postScript.isNotEmpty) parts.add(postScript);

    return parts.join('\n');
  }

  /// Gemini 是否需要临时脚本文件
  static bool get geminiNeedsTempScriptFile {
    if (!Platform.isWindows) return false;
    final preScript = geminiPreScript;

    if (_geminiSelectedShell == 'powershell') {
      return preScript.contains('try') ||
          preScript.contains('catch') ||
          preScript.contains('finally') ||
          preScript.contains('{') ||
          preScript.split('\n').length > 3;
    } else if (_geminiSelectedShell == 'cmd') {
      return preScript.isNotEmpty;
    }
    return false;
  }

  /// Gemini 显示命令（用于 UI）
  static String get geminiDisplayCommand {
    final preScript = geminiPreScript;
    final installScript = geminiInstallScript;
    if (preScript.isEmpty) return installScript;
    return '$preScript\n$installScript';
  }

  /// Gemini 检测路径
  static List<String> get geminiDetectPaths {
    try {
      final paths = _geminiPlatformConfig['detect_paths'];
      if (paths is List && paths.isNotEmpty) {
        return paths.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    // 默认路径（npm 全局安装）
    if (Platform.isWindows) {
      return [
        'AppData\\Roaming\\npm\\gemini.cmd',
        'AppData\\Roaming\\npm\\gemini',
      ];
    }
    return [
      '.npm-global/bin/gemini',
    ];
  }

  /// Gemini 环境变量
  static Map<String, String> get geminiEnvironment {
    final env = Map<String, String>.from(Platform.environment);

    try {
      final configEnv = _geminiPlatformConfig['environment'];
      if (configEnv is Map) {
        for (final entry in configEnv.entries) {
          var value = entry.value.toString();
          value = _expandEnvVars(value);
          env[entry.key.toString()] = value;
        }
      }
    } catch (_) {}

    return env;
  }
}
