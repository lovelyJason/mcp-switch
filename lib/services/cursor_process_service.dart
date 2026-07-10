import 'dart:io';

import '../utils/platform_utils.dart';
import 'logger_service.dart';

/// Cursor 进程检测与启停
class CursorProcessService {
  CursorProcessService._();
  static final instance = CursorProcessService._();

  static const _cursorAppPath = '/Applications/Cursor.app';
  static const _processNameHints = [
    'cursor',
    'cursor helper',
    'cursorless',
    'uiviewservice',
  ];

  String get defaultAppPath => _cursorAppPath;

  bool get isCursorInstalled {
    if (!Platform.isMacOS) return false;
    return Directory(_cursorAppPath).existsSync();
  }

  Future<bool> isCursorRunning() async {
    if (!Platform.isMacOS) return false;
    try {
      final result = await PlatformUtils.runCommand(
        "pgrep -if 'Cursor.app|/Cursor.app/Contents/MacOS/Cursor' 2>/dev/null || true",
      );
      final out = (result.stdout as String).trim();
      return out.isNotEmpty;
    } catch (e) {
      LoggerService.error('CursorProcessService: isCursorRunning failed', e);
      return false;
    }
  }

  Future<int> killCursorAndWait({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (!Platform.isMacOS) return 0;

    var killed = 0;
    try {
      await PlatformUtils.runCommand(
        "osascript -e 'tell application \"Cursor\" to quit' 2>/dev/null || true",
      );
    } catch (e) {
      LoggerService.error('CursorProcessService: osascript quit failed', e);
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await isCursorRunning()) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (await isCursorRunning()) {
      killed += await _forceKillCursorProcesses();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    return killed;
  }

  Future<int> _forceKillCursorProcesses() async {
    var count = 0;
    for (final hint in _processNameHints) {
      try {
        final result = await PlatformUtils.runCommand(
          "pkill -if '$hint' 2>/dev/null || true",
        );
        if (result.exitCode == 0) count++;
      } catch (_) {}
    }
    try {
      await PlatformUtils.runCommand(
        "pkill -if '/Applications/Cursor.app' 2>/dev/null || true",
      );
    } catch (_) {}
    return count;
  }

  Future<void> startCursor({String? appPath}) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Cursor account switch is only supported on macOS');
    }
    final path = appPath ?? _cursorAppPath;
    if (!Directory(path).existsSync()) {
      throw StateError('Cursor.app not found at $path');
    }
    await PlatformUtils.runCommand("open -a '$path'");
  }
}
