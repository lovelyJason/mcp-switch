import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xterm/xterm.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:image/image.dart' as img;

class TerminalService extends ChangeNotifier {
  final Terminal terminal = Terminal(maxLines: 10000);
  final TerminalController terminalController = TerminalController();
  Pty? _pty;
  bool _isInitialized = false;

  bool get isPtyActive => _pty != null;

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
    String shell;
    if (Platform.isWindows) {
      shell = Platform.environment['COMSPEC'] ?? 'cmd.exe';
    } else {
      shell = Platform.environment['SHELL'] ?? '/bin/zsh';
    }
    
    _pty = Pty.start(
      shell,
      arguments: Platform.isWindows
          ? []
          : ['-l'], // Use login shell to load ~/.zshrc and paths
      columns: terminal.viewWidth,
      rows: terminal.viewHeight,
      workingDirectory: Platform.environment['HOME'] ?? '.', // Start in HOME
      environment: {
        'TERM': 'xterm-256color',
        'PROMPT_EOL_MARK': '',
      },
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
      terminal.textInput(command + '\r');
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
