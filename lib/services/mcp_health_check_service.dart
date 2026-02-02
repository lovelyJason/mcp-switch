import 'package:flutter/foundation.dart';
import '../models/mcp_server_health.dart';
import '../utils/platform_utils.dart';

/// MCP 服务器健康检查服务
class McpHealthCheckService extends ChangeNotifier {
  final Map<String, McpServerHealth> _healthStates = {};
  bool _isChecking = false;
  DateTime? _lastCheckTime;
  String? _lastError;

  /// 获取所有健康状态
  Map<String, McpServerHealth> get healthStates => Map.unmodifiable(_healthStates);

  /// 是否正在检测
  bool get isChecking => _isChecking;

  /// 上次检测时间
  DateTime? get lastCheckTime => _lastCheckTime;

  /// 上次错误信息
  String? get lastError => _lastError;

  /// 获取单个服务器的健康状态
  McpServerHealth? getServerHealth(String serverName) {
    return _healthStates[serverName];
  }

  /// 检测所有服务器
  /// [force] 为 true 时忽略缓存时间限制
  Future<void> checkAllServers({bool force = false}) async {
    // 防抖：5 分钟内不重复检测（除非强制）
    if (!force &&
        _lastCheckTime != null &&
        DateTime.now().difference(_lastCheckTime!) < const Duration(minutes: 5)) {
      return;
    }

    if (_isChecking) return;

    _isChecking = true;
    _lastError = null;
    notifyListeners();

    try {
      // 执行 claude mcp list 命令
      final result = await PlatformUtils.runCommand('claude mcp list')
          .timeout(const Duration(seconds: 30));

      if (result.exitCode == 0) {
        _parseTextOutput(result.stdout as String);
        _lastCheckTime = DateTime.now();
      } else {
        final stderr = (result.stderr as String).trim();
        _lastError = stderr.isNotEmpty ? stderr : 'Command failed with exit code ${result.exitCode}';
      }
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// 解析 claude mcp list 的文本输出
  /// 格式示例：
  /// Figma: npx -y figma-developer-mcp ... - ✓ Connected
  /// chrome-devtools: npx chrome-devtools-mcp@latest - ✗ Failed to connect
  void _parseTextOutput(String output) {
    _healthStates.clear();
    final lines = output.split('\n');
    final now = DateTime.now();

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 跳过状态行（如 "Checking MCP server health..."）
      if (trimmed.startsWith('Checking') || trimmed.startsWith('plugin:')) {
        // plugin: 开头的是内置插件，也解析
        if (trimmed.startsWith('plugin:')) {
          _parseMcpLine(trimmed, now);
        }
        continue;
      }

      _parseMcpLine(trimmed, now);
    }
  }

  /// 解析单行 MCP 服务器状态
  void _parseMcpLine(String line, DateTime now) {
    // 匹配格式：serverName: command/url - ✓ Connected / ✗ Failed to connect
    // 使用正则提取
    final connectedMatch = RegExp(r'^(.+?):\s*(.+?)\s*-\s*✓\s*Connected$').firstMatch(line);
    final failedMatch = RegExp(r'^(.+?):\s*(.+?)\s*-\s*✗\s*(.+)$').firstMatch(line);

    if (connectedMatch != null) {
      final serverName = connectedMatch.group(1)!.trim();
      final commandOrUrl = connectedMatch.group(2)!.trim();

      _healthStates[serverName] = McpServerHealth(
        serverName: serverName,
        isHealthy: true,
        commandOrUrl: commandOrUrl,
        lastChecked: now,
      );
    } else if (failedMatch != null) {
      final serverName = failedMatch.group(1)!.trim();
      final commandOrUrl = failedMatch.group(2)!.trim();
      final errorMessage = failedMatch.group(3)!.trim();

      _healthStates[serverName] = McpServerHealth(
        serverName: serverName,
        isHealthy: false,
        commandOrUrl: commandOrUrl,
        errorMessage: errorMessage,
        lastChecked: now,
      );
    }
  }

  /// 清除所有状态
  void clearStates() {
    _healthStates.clear();
    _lastCheckTime = null;
    _lastError = null;
    notifyListeners();
  }
}
