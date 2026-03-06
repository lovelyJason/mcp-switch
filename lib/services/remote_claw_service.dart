import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../models/permission_request.dart';
import '../utils/platform_utils.dart';
import 'logger_service.dart';
import 'channels/telegram_channel.dart';
import 'channels/dingtalk_channel.dart';

/// Remote Claw 服务
/// 职责：
/// 1. 管理内嵌 HTTP Server（localhost:8099）
/// 2. 维护待审批请求队列
/// 3. 将请求推送到 Telegram / 钉钉
/// 4. 接收用户决策并更新状态
class RemoteClawService extends ChangeNotifier {
  static const int kDefaultPort = 8099;

  /// 跨热重启持久持有 server（静态），新实例可接管旧 server
  static HttpServer? _staticServer;

  int _port = kDefaultPort;
  int get port => _port;

  String _callbackHost = '127.0.0.1';
  String get callbackHost => _callbackHost;

  /// 是否在本机通知渠道中使用 localhost 作为回调地址
  /// 开启后，推送给通知渠道（钉钉/Telegram）的消息里，
  /// 会额外附带一个 localhost 回调链接，方便电脑端直接点击
  bool _useLocalCallback = false;
  bool get useLocalCallback => _useLocalCallback;

  void setUseLocalCallback(bool value) {
    _useLocalCallback = value;
    _rebuildChannels();
    notifyListeners();
  }

  void setPort(int port) {
    if (_isRunning) return; // 运行中不允许修改
    _port = port;
    notifyListeners();
  }

  void setCallbackHost(String host) {
    _callbackHost = host.trim().isEmpty ? '127.0.0.1' : host.trim();
    _rebuildChannels();
    notifyListeners();
  }

  Future<bool> get isHookInstalled async {
    final home = PlatformUtils.userHome;
    return File('$home/.claude/hooks/remote-claw.sh').exists();
  }

  // 实例字段指向静态 server，热重启时新实例直接接管
  HttpServer? get _server => _staticServer;
  set _server(HttpServer? s) => _staticServer = s;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String? _lastError;
  String? get lastError => _lastError;

  // 待审批请求队列（内存）
  final Map<String, PermissionRequest> _pendingRequests = {};
  List<PermissionRequest> get pendingRequests =>
      _pendingRequests.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // 渠道
  TelegramChannel? _telegramChannel;
  DingtalkChannel? _dingtalkChannel;

  // 配置
  bool _telegramEnabled = false;
  bool _dingtalkEnabled = false;
  String _telegramBotToken = '';
  String _telegramChatId = '';
  String _dingtalkWebhookUrl = '';
  String _dingtalkSecret = '';

  bool get telegramEnabled => _telegramEnabled;
  bool get dingtalkEnabled => _dingtalkEnabled;
  String get telegramBotToken => _telegramBotToken;
  String get telegramChatId => _telegramChatId;
  String get dingtalkWebhookUrl => _dingtalkWebhookUrl;
  String get dingtalkSecret => _dingtalkSecret;

  // ──────────────────────────────────────────
  // 生命周期
  // ──────────────────────────────────────────

  Future<void> start() async {
    if (_isRunning) return;
    try {
      _rebuildChannels();

      if (_server != null) {
        // 热重启场景：Dart VM 保留了静态 server，直接接管，无需重新绑端口
        LoggerService.info(
            'RemoteClaw: Hot-restart detected, reusing existing server on port $_port');
      } else {
        final router = _buildRouter();
        final handler = const Pipeline()
            .addMiddleware(_corsMiddleware())
            .addHandler(router.call);
        _server = await _bindWithRetry(handler);
        LoggerService.info('RemoteClaw: HTTP server started on 0.0.0.0:$_port');
      }

      _isRunning = true;
      _lastError = null;

      // 启动 Telegram 长轮询
      if (_telegramEnabled && _telegramChannel != null) {
        _telegramChannel!.startPolling(_onTelegramDecision);
      }

      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      _isRunning = false;
      LoggerService.error('RemoteClaw: Failed to start server', e);
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _telegramChannel?.stopPolling();
    _isRunning = false;
    notifyListeners();
    LoggerService.info('RemoteClaw: HTTP server stopped');
  }

  /// 绑端口，若端口被占用（热重启场景旧进程残留）则强杀占用进程后重试一次
  Future<HttpServer> _bindWithRetry(Handler handler) async {
    try {
      return await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 48 || e.osError?.errorCode == 98) {
        // 48 = EADDRINUSE (macOS), 98 = EADDRINUSE (Linux)
        LoggerService.info(
            'RemoteClaw: Port $_port in use, killing occupant and retrying...');
        await Process.run('bash', [
          '-c',
          'lsof -ti tcp:$_port | xargs kill -9 2>/dev/null || true',
        ]);
        await Future.delayed(const Duration(milliseconds: 300));
        return await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      }
      rethrow;
    }
  }

  // ──────────────────────────────────────────
  // 配置更新
  // ──────────────────────────────────────────

  Future<void> updateTelegramConfig({
    required bool enabled,
    required String botToken,
    required String chatId,
  }) async {
    _telegramEnabled = enabled;
    _telegramBotToken = botToken;
    _telegramChatId = chatId;
    if (_isRunning) {
      _telegramChannel?.stopPolling();
      _rebuildChannels();
      if (enabled && _telegramChannel != null) {
        _telegramChannel!.startPolling(_onTelegramDecision);
      }
    }
    notifyListeners();
  }

  Future<void> updateDingtalkConfig({
    required bool enabled,
    required String webhookUrl,
    required String secret,
  }) async {
    _dingtalkEnabled = enabled;
    _dingtalkWebhookUrl = webhookUrl;
    _dingtalkSecret = secret;
    _rebuildChannels();
    notifyListeners();
  }

  void loadConfig({
    bool telegramEnabled = false,
    String telegramBotToken = '',
    String telegramChatId = '',
    bool dingtalkEnabled = false,
    String dingtalkWebhookUrl = '',
    String dingtalkSecret = '',
    String callbackHost = '127.0.0.1',
    bool useLocalCallback = false,
  }) {
    _telegramEnabled = telegramEnabled;
    _telegramBotToken = telegramBotToken;
    _telegramChatId = telegramChatId;
    _dingtalkEnabled = dingtalkEnabled;
    _dingtalkWebhookUrl = dingtalkWebhookUrl;
    _dingtalkSecret = dingtalkSecret;
    _callbackHost = callbackHost.isEmpty ? '127.0.0.1' : callbackHost;
    _useLocalCallback = useLocalCallback;
    _rebuildChannels();
  }

  void _rebuildChannels() {
    _telegramChannel = _telegramEnabled && _telegramBotToken.isNotEmpty
        ? TelegramChannel(
            botToken: _telegramBotToken,
            chatId: _telegramChatId,
          )
        : null;

    _dingtalkChannel = _dingtalkEnabled && _dingtalkWebhookUrl.isNotEmpty
        ? DingtalkChannel(
            webhookUrl: _dingtalkWebhookUrl,
            secret: _dingtalkSecret,
            port: _port,
            hostAddress: _callbackHost,
            localHostAddress: _useLocalCallback ? 'localhost' : null,
          )
        : null;
  }

  // ──────────────────────────────────────────
  // 路由
  // ──────────────────────────────────────────

  Router _buildRouter() {
    final router = Router();

    // 接收 Hook 权限请求
    router.post('/hook/permission', _handlePermissionRequest);

    // Hook 脚本轮询决策结果
    router.get('/decision/<requestId>', _handleGetDecision);

    // 手动审批（来自 UI 或测试）
    router.post('/action/allow/<requestId>', _handleManualAllow);
    router.post('/action/deny/<requestId>', _handleManualDeny);

    // Telegram callback（为 Webhook 模式预留入口，当前使用长轮询）
    router.post('/callback/telegram', _handleTelegramCallback);

    // 钉钉 callback
    router.post('/callback/dingtalk', _handleDingtalkCallback);

    // 健康检查
    router.get('/health', _handleHealth);

    return router;
  }

  // ──────────────────────────────────────────
  // 路由处理器
  // ──────────────────────────────────────────

  Future<Response> _handlePermissionRequest(Request req) async {
    try {
      final body = await req.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final id = const Uuid().v4();
      final request = PermissionRequest.fromHookInput(json, id);

      _pendingRequests[id] = request;
      notifyListeners();

      LoggerService.info('RemoteClaw: New permission request [$id] tool=${request.toolName}');

      // 推送通知
      _pushNotification(request);

      return Response.ok(
        jsonEncode({'request_id': id, 'status': 'pending'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      LoggerService.error('RemoteClaw: Error handling permission request', e);
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<Response> _handleGetDecision(Request req, String requestId) async {
    final request = _pendingRequests[requestId];
    if (request == null) {
      return Response.notFound(
        jsonEncode({'error': 'Request not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    if (request.decision == PermissionDecision.pending) {
      return Response.ok(
        jsonEncode({'status': 'pending'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    // 已有决策：返回结果并清理
    final decision = request.decision;
    _pendingRequests.remove(requestId);
    notifyListeners();

    return Response.ok(
      jsonEncode({
        'status': 'resolved',
        'decision': decision.name,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _handleManualAllow(Request req, String requestId) async {
    return _applyDecision(requestId, PermissionDecision.allow);
  }

  Future<Response> _handleManualDeny(Request req, String requestId) async {
    return _applyDecision(requestId, PermissionDecision.deny);
  }

  Future<Response> _handleTelegramCallback(Request req) async {
    // 预留 Webhook 模式入口，当前长轮询模式不走这里
    // 未来切换 Webhook 时在此处理 Telegram Update
    return Response.ok(jsonEncode({'ok': true}),
        headers: {'Content-Type': 'application/json'});
  }

  Future<Response> _handleDingtalkCallback(Request req) async {
    try {
      final body = await req.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final requestId = json['request_id'] as String?;
      final action = json['action'] as String?;
      if (requestId == null || action == null) {
        return Response.badRequest(body: jsonEncode({'error': 'Missing fields'}));
      }
      final decision = action == 'allow' ? PermissionDecision.allow : PermissionDecision.deny;
      return _applyDecision(requestId, decision);
    } catch (e) {
      return Response.internalServerError(body: jsonEncode({'error': e.toString()}));
    }
  }

  Future<Response> _handleHealth(Request req) async {
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'pending': _pendingRequests.length,
        'telegram': _telegramEnabled,
        'dingtalk': _dingtalkEnabled,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ──────────────────────────────────────────
  // 决策处理
  // ──────────────────────────────────────────

  Response _applyDecision(String requestId, PermissionDecision decision) {
    final request = _pendingRequests[requestId];
    if (request == null) {
      return Response.notFound(
        jsonEncode({'error': 'Request not found or already resolved'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    request.decision = decision;
    notifyListeners();
    LoggerService.info('RemoteClaw: Decision [$requestId] = ${decision.name}');
    return Response.ok(
      jsonEncode({'ok': true, 'decision': decision.name}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// 供 UI 层调用：直接审批
  void approveRequest(String requestId) {
    _applyDecision(requestId, PermissionDecision.allow);
  }

  /// 供 UI 层调用：直接拒绝
  void denyRequest(String requestId) {
    _applyDecision(requestId, PermissionDecision.deny);
  }

  // ──────────────────────────────────────────
  // 推送通知
  // ──────────────────────────────────────────

  void _pushNotification(PermissionRequest request) {
    _telegramChannel?.sendPermissionRequest(request).catchError((e) {
      LoggerService.error('RemoteClaw: Telegram push failed', e);
    });
    _dingtalkChannel?.sendPermissionRequest(request).catchError((e) {
      LoggerService.error('RemoteClaw: DingTalk push failed', e);
    });
  }

  /// Telegram 长轮询收到用户回复的回调
  void _onTelegramDecision(String requestId, PermissionDecision decision) {
    _applyDecision(requestId, decision);
  }

  // ──────────────────────────────────────────
  // Hook 脚本 & settings.json 管理
  // ──────────────────────────────────────────

  /// 生成 Hook 脚本内容
  String generateHookScript() {
    return '#!/bin/bash\n'
        '# Remote Claw Hook - Generated by MCP Switch\n'
        '# 将 Claude Code PermissionRequest 转发到 MCP Switch 远程审批服务\n'
        '\n'
        'SERVER="http://127.0.0.1:$_port"\n'
        r'''TIMEOUT=300  # 等待审批的最大秒数
POLL_INTERVAL=2

# 读取 stdin（Claude Code 传入的 JSON）
INPUT=$(cat)

# 检查服务是否可用，不可用则降级（返回空输出让 Claude Code 显示原生弹窗）
if ! curl -sf "$SERVER/health" > /dev/null 2>&1; then
  exit 0
fi

# 发送权限请求
RESPONSE=$(echo "$INPUT" | curl -sf -X POST "$SERVER/hook/permission" \
  -H "Content-Type: application/json" \
  -d @-)

if [ $? -ne 0 ]; then
  exit 0
fi

REQUEST_ID=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['request_id'])" 2>/dev/null)

if [ -z "$REQUEST_ID" ]; then
  exit 0
fi

# 轮询决策结果
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  DECISION_RESP=$(curl -sf "$SERVER/decision/$REQUEST_ID" 2>/dev/null)
  STATUS=$(echo "$DECISION_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','pending'))" 2>/dev/null)

  if [ "$STATUS" = "resolved" ]; then
    DECISION=$(echo "$DECISION_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('decision','deny'))" 2>/dev/null)
    if [ "$DECISION" = "allow" ]; then
      echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow","message":"Approved via MCP Switch Remote Claw"}}}'
    else
      echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Denied via MCP Switch Remote Claw"}}}'
    fi
    exit 0
  fi

  sleep $POLL_INTERVAL
  ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

# 超时：自动拒绝
echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Timeout: no response from MCP Switch Remote Claw"}}}'
exit 0
''';
  }

  /// 将 Hook 脚本写入 ~/.claude/hooks/remote-claw.sh
  Future<void> installHookScript() async {
    final home = PlatformUtils.userHome;
    final hooksDir = Directory('$home/.claude/hooks');
    if (!await hooksDir.exists()) {
      await hooksDir.create(recursive: true);
    }
    final scriptPath = '${hooksDir.path}/remote-claw.sh';
    final file = File(scriptPath);
    await file.writeAsString(generateHookScript());
    // 赋予执行权限
    await Process.run('chmod', ['+x', scriptPath]);
    LoggerService.info('RemoteClaw: Hook script installed at $scriptPath');
  }

  /// 将 Hook 配置写入 ~/.claude/settings.json
  Future<void> installClaudeSettings() async {
    final home = PlatformUtils.userHome;
    final settingsPath = '$home/.claude/settings.json';
    final file = File(settingsPath);

    Map<String, dynamic> settings = {};
    if (await file.exists()) {
      try {
        settings = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 构建 Hook 配置
    final hookConfig = {
      'matcher': '',
      'hooks': [
        {
          'type': 'command',
          'command': 'bash ~/.claude/hooks/remote-claw.sh',
          'timeout': 600,
        }
      ]
    };

    // 确保 hooks.PermissionRequest 存在
    settings.putIfAbsent('hooks', () => <String, dynamic>{});
    final hooks = settings['hooks'] as Map<String, dynamic>;
    hooks.putIfAbsent('PermissionRequest', () => <dynamic>[]);
    final permHooks = hooks['PermissionRequest'] as List<dynamic>;

    // 检查是否已存在（避免重复写入）
    final alreadyExists = permHooks.any((h) {
      if (h is Map) {
        final hookList = h['hooks'] as List?;
        return hookList?.any((hh) =>
                hh is Map &&
                (hh['command'] as String? ?? '').contains('remote-claw.sh')) ??
            false;
      }
      return false;
    });

    if (!alreadyExists) {
      permHooks.add(hookConfig);
    }

    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(settings));
    LoggerService.info('RemoteClaw: Claude settings.json updated at $settingsPath');
  }

  /// 从 ~/.claude/settings.json 移除 Hook 配置
  Future<void> uninstallClaudeSettings() async {
    final home = PlatformUtils.userHome;
    final settingsPath = '$home/.claude/settings.json';
    final file = File(settingsPath);
    if (!await file.exists()) return;

    try {
      final settings = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final hooks = settings['hooks'] as Map<String, dynamic>?;
      if (hooks == null) return;

      final permHooks = hooks['PermissionRequest'] as List<dynamic>?;
      if (permHooks == null) return;

      permHooks.removeWhere((h) {
        if (h is Map) {
          final hookList = h['hooks'] as List?;
          return hookList?.any((hh) =>
                  hh is Map &&
                  (hh['command'] as String? ?? '').contains('remote-claw.sh')) ??
              false;
        }
        return false;
      });

      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(settings));
      LoggerService.info('RemoteClaw: Hook config removed from settings.json');
    } catch (e) {
      LoggerService.error('RemoteClaw: Failed to uninstall hook', e);
    }
  }

  // ──────────────────────────────────────────
  // 工具方法
  // ──────────────────────────────────────────

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST',
          'Access-Control-Allow-Headers': 'Content-Type',
        });
      };
    };
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
