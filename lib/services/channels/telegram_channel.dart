import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/permission_request.dart';
import '../logger_service.dart';

/// Telegram Bot Channel
/// 采用长轮询（getUpdates）模式，不需要公网 IP
/// 预留 Webhook 模式入口：外部只需将 Telegram callback POST 到 /callback/telegram，
/// 然后调用 onDecision 即可，无需改动本类逻辑
class TelegramChannel {
  final String botToken;
  final String chatId;

  static const String _apiBase = 'https://api.telegram.org';
  static const Duration _pollInterval = Duration(seconds: 2);
  static const int _longPollTimeout = 30; // Telegram long-poll timeout (seconds)

  Timer? _pollTimer;
  int _lastUpdateId = 0;
  bool _polling = false;

  void Function(String requestId, PermissionDecision decision)? _onDecision;

  TelegramChannel({required this.botToken, required this.chatId});

  // ──────────────────────────────────────────
  // 推送权限请求消息
  // ──────────────────────────────────────────

  Future<void> sendPermissionRequest(PermissionRequest request) async {
    final text = _formatMessage(request);
    final keyboard = _buildInlineKeyboard(request.id);

    await _callApi('sendMessage', {
      'chat_id': chatId,
      'text': text,
      'parse_mode': 'HTML',
      'reply_markup': jsonEncode(keyboard),
    });
  }

  String _formatMessage(PermissionRequest request) {
    final emoji = _toolEmoji(request.toolName);
    final buffer = StringBuffer();
    buffer.writeln('🔔 <b>Claude Code 请求授权</b>');
    buffer.writeln('');
    buffer.writeln('$emoji 工具: <code>${_escape(request.toolName)}</code>');
    buffer.writeln('📁 项目: <code>${_escape(request.projectName)}</code>');
    if (request.commandSummary.isNotEmpty) {
      buffer.writeln('💻 命令: <code>${_escape(request.commandSummary)}</code>');
    }
    buffer.writeln('🆔 ID: <code>${request.id.substring(0, 8)}</code>');
    return buffer.toString().trim();
  }

  Map<String, dynamic> _buildInlineKeyboard(String requestId) {
    return {
      'inline_keyboard': [
        [
          {'text': '✅ 同意', 'callback_data': 'allow:$requestId'},
          {'text': '❌ 拒绝', 'callback_data': 'deny:$requestId'},
        ]
      ]
    };
  }

  // ──────────────────────────────────────────
  // 长轮询
  // ──────────────────────────────────────────

  void startPolling(
    void Function(String requestId, PermissionDecision decision) onDecision,
  ) {
    if (_polling) return;
    _polling = true;
    _onDecision = onDecision;
    _poll();
    LoggerService.info('TelegramChannel: Long-polling started');
  }

  void stopPolling() {
    _polling = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    LoggerService.info('TelegramChannel: Long-polling stopped');
  }

  void _poll() {
    if (!_polling) return;
    _pollTimer = Timer(_pollInterval, () async {
      try {
        await _fetchUpdates();
      } catch (e) {
        LoggerService.error('TelegramChannel: Poll error', e);
      }
      if (_polling) _poll();
    });
  }

  Future<void> _fetchUpdates() async {
    final params = {
      'offset': (_lastUpdateId + 1).toString(),
      'timeout': _longPollTimeout.toString(),
      'allowed_updates': '["callback_query"]',
    };

    final data = await _callApi('getUpdates', params, httpMethod: 'GET');
    if (data == null) return;

    final updates = data['result'] as List<dynamic>? ?? [];
    for (final update in updates) {
      final updateId = update['update_id'] as int;
      if (updateId > _lastUpdateId) _lastUpdateId = updateId;

      final callbackQuery = update['callback_query'] as Map<String, dynamic>?;
      if (callbackQuery == null) continue;

      _handleCallbackQuery(callbackQuery);
    }
  }

  void _handleCallbackQuery(Map<String, dynamic> callbackQuery) {
    final callbackData = callbackQuery['data'] as String? ?? '';
    final parts = callbackData.split(':');
    if (parts.length != 2) return;

    final action = parts[0]; // allow | deny
    final requestId = parts[1];

    // 校验 chat_id
    final message = callbackQuery['message'] as Map<String, dynamic>?;
    final chat = message?['chat'] as Map<String, dynamic>?;
    final fromChatId = chat?['id']?.toString() ?? '';
    if (chatId.isNotEmpty && fromChatId != chatId) {
      LoggerService.warning('TelegramChannel: Ignored callback from unknown chat $fromChatId');
      return;
    }

    final decision =
        action == 'allow' ? PermissionDecision.allow : PermissionDecision.deny;
    _onDecision?.call(requestId, decision);

    // 应答 callback query（消除 Telegram loading 动画）
    final callbackQueryId = callbackQuery['id'] as String? ?? '';
    _answerCallbackQuery(callbackQueryId, decision);
  }

  void _answerCallbackQuery(String callbackQueryId, PermissionDecision decision) {
    final text = decision == PermissionDecision.allow ? '✅ 已同意' : '❌ 已拒绝';
    _callApi('answerCallbackQuery', {
      'callback_query_id': callbackQueryId,
      'text': text,
    }).catchError((e) {
      LoggerService.error('TelegramChannel: answerCallbackQuery failed', e);
      return null;
    });
  }

  // ──────────────────────────────────────────
  // HTTP 工具
  // ──────────────────────────────────────────

  Future<Map<String, dynamic>?> _callApi(
    String method,
    Map<String, String> params, {
    String httpMethod = 'POST',
  }) async {
    try {
      final uri = Uri.parse('$_apiBase/bot$botToken/$method');
      HttpClientRequest request;
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      if (httpMethod == 'GET') {
        final uriWithParams = uri.replace(queryParameters: params);
        request = await client.getUrl(uriWithParams);
      } else {
        request = await client.postUrl(uri);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(params));
      }

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['ok'] != true) {
        LoggerService.warning(
            'TelegramChannel: API error [$method]: ${json['description']}');
        return null;
      }
      return json;
    } catch (e) {
      LoggerService.error('TelegramChannel: HTTP error [$method]', e);
      return null;
    }
  }

  // ──────────────────────────────────────────
  // 工具
  // ──────────────────────────────────────────

  String _escape(String text) =>
      text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  String _toolEmoji(String toolName) {
    switch (toolName) {
      case 'Bash':
        return '⚡';
      case 'Write':
        return '✏️';
      case 'Edit':
        return '📝';
      case 'Read':
        return '📖';
      case 'Glob':
      case 'Grep':
        return '🔍';
      default:
        return '🔧';
    }
  }
}
