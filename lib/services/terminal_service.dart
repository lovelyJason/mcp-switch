import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:image/image.dart' as img;
import '../utils/platform_utils.dart';
import '../ui/components/windows_shell_selector_dialog.dart' show WindowsShellType;
import 'config_service.dart';

class TerminalService extends ChangeNotifier {
  ConfigService? _configService;

  void setConfigService(ConfigService configService) {
    _configService = configService;
  }

  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController terminalController = TerminalController();
  Pty? _pty;
  bool _isInitialized = false;
  bool _floatingTerminalEnabled = false;
  bool _terminalPanelOpen = false;

  bool get isPtyActive => _pty != null;
  bool get floatingTerminalEnabled => _floatingTerminalEnabled;
  bool get isTerminalPanelOpen => _terminalPanelOpen;

  // 悬浮图标只在 enabled 且终端面板关闭时显示
  bool get shouldShowFloatingIcon => _floatingTerminalEnabled && !_terminalPanelOpen;

  void setFloatingTerminal(bool enabled) {
    _floatingTerminalEnabled = enabled;
    notifyListeners();
  }

  void toggleFloatingTerminal() {
    _floatingTerminalEnabled = !_floatingTerminalEnabled;
    notifyListeners();
  }

  void setDrawerOpen(bool open) {
    _terminalPanelOpen = open;
    notifyListeners();
  }

  void openTerminalPanel() {
    _terminalPanelOpen = true;
    notifyListeners();
  }

  void closeTerminalPanel() {
    _terminalPanelOpen = false;
    notifyListeners();
  }

  TerminalService();

  Future<void> init(Future<bool> Function() hasSeenArtCheck, Future<void> Function() markArtSeenCallback) async {
    // If initialized but PTY is dead (exited), restart it
    if (_isInitialized) {
      if (_pty == null) {
        // Clear screen for fresh start
        terminal.buffer.clear();
        terminal.setCursor(0, 0);
        terminal.write('\x1b[32mMCP Switch Terminal (Restored)\x1b[0m\r\n');
        _startPty();
      }
      return;
    }

    // Initial output
    terminal.write('\x1b[32mMCP Switch Terminal loaded\x1b[0m\r\n');

    // Check persistence for Art
    try {
      final hasSeen = await hasSeenArtCheck();
      if (!hasSeen) {
        try {
          final art = await _generateAsciiArt();
          terminal.write('\x1b[36m$art\x1b[0m\r\n'); // Cyan color
          await markArtSeenCallback();
        } catch (e) {
          terminal.write('Meow!\r\n');
        }
      }
    } catch (e) {
      debugPrint('Terminal Init Logic Error: $e');
    }

    _startPty();
    _isInitialized = true;
  }

  Future<String> _generateAsciiArt() async {
    try {
      final bytes = await rootBundle.load('assets/images/cat.png');
      final image = img.decodeImage(bytes.buffer.asUint8List());
      if (image == null) return '';

      const width = 60;
      final height = (image.height / image.width * width * 0.5).round();
      final resized = img.copyResize(image, width: width, height: height);

      const chars = '@%#*+=-:. ';
      final buffer = StringBuffer();
      
      for (var y = 0; y < resized.height; y++) {
        for (var x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          final luminance = img.getLuminance(pixel);
          final index = (luminance / 255 * (chars.length - 1)).round();
          buffer.write(chars[index]);
        }
        buffer.write('\r\n');
      }
      return buffer.toString();
    } catch (e) {
      return '';
    }
  }

  void _startPty() {
    _startPtyWithShell(null);
  }

  /// 使用指定的 shell 启动 PTY
  /// [shellType] 仅在 Windows 上有效，null 表示使用保存的偏好或默认值
  void _startPtyWithShell(WindowsShellType? shellType) {
    String shell;
    List<String> shellArgs;

    if (Platform.isWindows) {
      // 优先使用传入的 shellType，否则使用保存的偏好
      final effectiveShell = shellType?.name ?? _configService?.windowsShell ?? 'powershell';

      if (effectiveShell == 'cmd') {
        shell = 'cmd.exe';
        shellArgs = [];
      } else {
        shell = 'powershell.exe';
        // -NoExit 保持会话，-Command - 接受标准输入
        shellArgs = ['-NoLogo', '-NoExit'];
      }
      debugPrint('[TerminalService] Using Windows shell: $shell with args: $shellArgs');
    } else {
      shell = Platform.environment['SHELL'] ?? '/bin/zsh';
      shellArgs = ['-l']; // Use login shell to load ~/.zshrc and paths
    }

    // 合并系统环境变量，确保 PATH 等关键变量被继承
    final env = Map<String, String>.from(Platform.environment);
    env['TERM'] = 'xterm-256color';
    env['PROMPT_EOL_MARK'] = '';

    // Windows 额外处理：确保 .local\bin 在 PATH 中
    if (Platform.isWindows) {
      final localBin = '${PlatformUtils.userHome}\\.local\\bin';
      // Windows PATH 变量名大小写不敏感，但 Dart Map 是敏感的
      // 需要同时检查 PATH 和 Path
      final pathKey = env.containsKey('PATH') ? 'PATH' : (env.containsKey('Path') ? 'Path' : 'PATH');
      final currentPath = env[pathKey] ?? '';

      // 调试日志：打印当前 PATH
      debugPrint('[TerminalService] PATH key: $pathKey');
      debugPrint('[TerminalService] PATH length: ${currentPath.length}');
      debugPrint('[TerminalService] PATH contains .local\\bin: ${currentPath.toLowerCase().contains('.local\\bin')}');

      // 检查是否已包含 .local\bin（兼容正斜杠和反斜杠）
      final lowerPath = currentPath.toLowerCase();
      if (!lowerPath.contains('.local\\bin') && !lowerPath.contains('.local/bin')) {
        env[pathKey] = '$localBin;$currentPath';
        debugPrint('[TerminalService] Added $localBin to PATH');
      } else {
        debugPrint('[TerminalService] PATH already contains .local\\bin, skipping');
      }
    }

    _pty = Pty.start(
      shell,
      arguments: shellArgs,
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
      workingDirectory: PlatformUtils.userHome.isNotEmpty ? PlatformUtils.userHome : '.', // Start in user home directory
      environment: env,
    );

    _pty!.output.cast<List<int>>().transform(Utf8Decoder()).listen((data) {
      terminal.write(data);
    });

    terminal.onOutput = (data) {
      _pty!.write(Utf8Encoder().convert(data));
    };
    
    terminal.onResize = (w, h, pw, ph) {
      _pty?.resize(h, w);
    };
    
    _pty!.exitCode.then((code) {
      terminal.write('\r\n[Process exited with code $code]\r\n');
      _pty = null;
      notifyListeners();
    });

    // Windows PowerShell: 启动后注入 PATH 环境变量
    // CMD 不需要，它会正确使用传入的环境变量
    if (Platform.isWindows && shell == 'powershell.exe') {
      final localBin = '${PlatformUtils.userHome}\\.local\\bin';
      // 延迟让 PowerShell 完全启动
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_pty != null) {
          // PowerShell: 静默设置 PATH，然后清屏
          final pathCmd = 'if (Test-Path "$localBin") { \$env:PATH = "$localBin;" + \$env:PATH }; cls\r';
          _pty!.write(Utf8Encoder().convert(pathCmd));
          debugPrint('[TerminalService] Injected PATH for PowerShell');
        }
      });
    }
  }

  int? get ptyPid => _pty?.pid;

  Future<bool> hasActiveForegroundProcess() async {
    if (_pty == null) return false;
    final pid = _pty!.pid;

    try {
      if (Platform.isMacOS || Platform.isLinux) {
        // Run pgrep -P <pid> to find child processes of the shell
        // We look for any child process. Zsh usually has no children when idle.
        final result = await Process.run('pgrep', ['-P', '$pid']);
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          // We have children.
          return true;
        }
      }
      // Windows implementation omitted for now (User on Mac)
    } catch (e) {
      debugPrint('Error checking foreground process: $e');
    }
    return false;
  }

  void write(String input) {
    if (_pty != null) {
      // Direct writing to terminal (local echo) happens via pty echo usually, 
      // but if we want to send command input we write to terminal input which pipes to pty
       terminal.textInput(input);
    }
  }
  
  // Specific method to send commands gracefully (like exit)
  void sendCommand(String command) {
    if (_pty != null) {
      terminal.textInput('$command\r');
    }
  }

  Future<void> kill() async {
    _pty?.kill();
    _pty = null;
  }
  
  @override
  void dispose() {
    // We don't want to dispose the terminal usually unless app closes, 
    // but the service disposal means app closing.
    _pty?.kill();
    super.dispose();
  }
}
