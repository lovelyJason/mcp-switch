import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/ansi_parser.dart';
import 'terminal_service.dart';

/// MCP OAuth 半自动化服务
///
/// 自动操控终端：进入 claude REPL → /mcp → 打开 TUI 列表
/// 然后提示用户手动选择目标 MCP 并按回车授权
class McpOAuthAutomationService {
  final TerminalService _terminalService;
  final StringBuffer _outputBuffer = StringBuffer();
  TerminalOutputCallback? _listener;
  Timer? _timeout;

  McpOAuthAutomationService(this._terminalService);

  /// 启动半自动化流程：自动进入 /mcp 列表
  /// 返回 true 表示成功打开了 /mcp TUI 列表
  Future<bool> startOAuthFlow(String mcpName) async {
    try {
      _registerListener();

      // 1. 确保终端面板打开
      if (!_terminalService.isTerminalPanelOpen) {
        _terminalService.setFloatingTerminal(true);
        _terminalService.openTerminalPanel();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 2. 发送 claude 并等待 REPL 就绪（或 trust 确认）
      _outputBuffer.clear();
      final enterWait = _waitForPattern(
        ['Do you trust', 'Yes, proceed', '╭', 'Tips:', 'Welcome to Claude'],
        timeout: const Duration(seconds: 15),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      _terminalService.sendCommand('claude');
      final enterResult = await enterWait;

      if (!enterResult) {
        debugPrint('[OAuth] REPL not ready, aborting');
        return false;
      }

      // 2.1 处理 trust 确认
      final bufContent = AnsiParser.strip(_outputBuffer.toString());
      if (bufContent.contains('Do you trust') || bufContent.contains('Yes, proceed')) {
        debugPrint('[OAuth] Trust confirmation detected, pressing Enter');
        _outputBuffer.clear();
        final trustWait = _waitForPattern(
          ['╭', 'Tips:', 'Welcome to Claude'],
          timeout: const Duration(seconds: 15),
        );
        await Future.delayed(const Duration(milliseconds: 200));
        _terminalService.writeToPty('\r');
        final trustResult = await trustWait;
        if (!trustResult) {
          debugPrint('[OAuth] REPL not ready after trust, aborting');
          return false;
        }
      }

      debugPrint('[OAuth] REPL ready, sending /mcp');
      await Future.delayed(const Duration(milliseconds: 500));

      // 3. 分步发送 /mcp
      _outputBuffer.clear();
      _terminalService.writeToPty('/mcp');
      await Future.delayed(const Duration(milliseconds: 800));

      // 按回车确认，等 TUI 列表加载
      _outputBuffer.clear();
      final mcpWait = _waitForPattern(
        ['connected', 'disabled', 'failed', 'authentication', '✓', '✗', '○', '△', 'servers'],
        timeout: const Duration(seconds: 15),
      );
      await Future.delayed(const Duration(milliseconds: 50));
      _terminalService.writeToPty('\r');
      final mcpResult = await mcpWait;

      if (!mcpResult) {
        debugPrint('[OAuth] /mcp TUI did not load');
        return false;
      }

      // 成功！TUI 列表已加载，用户可以手动操作了
      debugPrint('[OAuth] /mcp TUI loaded, user can now navigate to "$mcpName"');
      return true;
    } catch (e) {
      debugPrint('[OAuth] Error: $e');
      return false;
    } finally {
      _cleanup();
    }
  }

  /// 等待终端输出中出现任一模式
  Future<bool> _waitForPattern(
    List<String> patterns, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final completer = Completer<bool>();

    _timeout?.cancel();
    _timeout = Timer(timeout, () {
      if (!completer.isCompleted) {
        final buf = AnsiParser.strip(_outputBuffer.toString());
        final preview = buf.length > 300 ? buf.substring(0, 300) : buf;
        debugPrint('[OAuth] Pattern wait timed out. Looking for: $patterns');
        debugPrint('[OAuth] Buffer preview: $preview');
        completer.complete(false);
      }
    });

    // 先检查已有的 buffer 内容
    final existing = AnsiParser.strip(_outputBuffer.toString());
    if (patterns.any((p) => existing.contains(p))) {
      _timeout?.cancel();
      return true;
    }

    // 持续检查新输出
    late TerminalOutputCallback checker;
    checker = (data) {
      final all = AnsiParser.strip(_outputBuffer.toString());
      if (patterns.any((p) => all.contains(p)) && !completer.isCompleted) {
        completer.complete(true);
        _timeout?.cancel();
      }
    };
    _terminalService.addOutputListener(checker);

    try {
      return await completer.future;
    } finally {
      _terminalService.removeOutputListener(checker);
    }
  }

  void _registerListener() {
    if (_listener != null) {
      _terminalService.removeOutputListener(_listener!);
    }
    _listener = (data) => _outputBuffer.write(data);
    _terminalService.addOutputListener(_listener!);
  }

  void _cleanup() {
    if (_listener != null) {
      _terminalService.removeOutputListener(_listener!);
      _listener = null;
    }
    _timeout?.cancel();
    _outputBuffer.clear();
  }
}
