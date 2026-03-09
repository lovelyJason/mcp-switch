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
  void Function(String requestId, String answer)? _onAnswer;

  TelegramChannel({required this.botToken, required this.chatId});

  // ──────────────────────────────────────────
  // 推送权限请求消息
  // ──────────────────────────────────────────

  // 缓存 requestId → [[q0 options], [q1 options], ...]，供 callback 查表
  final Map<String, List<List<String>>> _optionsCache = {};

  Future<void> sendPermissionRequest(PermissionRequest request) async {
    // AskUserQuestion：仅通知，不带操作按钮（答案由 VSCode 插件原生弹窗处理）
    if (request.isAskFollowup) {
      final text = _formatAskFollowup(request);
      await _callApi('sendMessage', {
        'chat_id': chatId,
        'text': text,
        'parse_mode': 'HTML',
      });
      return;
    }

    await _callApi('sendMessage', {
      'chat_id': chatId,
      'text': _formatMessage(request),
      'parse_mode': 'HTML',
      'reply_markup': jsonEncode(_buildInlineKeyboard(request.id)),
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

  String _formatAskFollowup(PermissionRequest request) {
    final buffer = StringBuffer();
    buffer.writeln('❓ <b>Claude Code 询问</b>');
    buffer.writeln('');
    buffer.writeln('📁 项目: <code>${_escape(request.projectName)}</code>');
    final questions = request.askQuestions;
    if (questions.length == 1) {
      buffer.writeln('💬 ${_escape(questions[0].question)}');
    } else {
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final header = q.header.isNotEmpty ? ' · ${q.header}' : '';
        buffer.writeln('<b>Q${i + 1}$header</b>: ${_escape(q.question)}');
      }
    }
    buffer.writeln('🆔 ID: <code>${request.id.substring(0, 8)}</code>');
    return buffer.toString().trim();
  }

  Map<String, dynamic> _buildInlineKeyboard(String requestId) {
    return {
      'inline_keyboard': [
        [
          {'text': '✅ 同意', 'callback_data': 'allow:$requestId'},
          {'text': '🔁 本次全部同意', 'callback_data': 'allowSession:$requestId'},
          {'text': '❌ 拒绝', 'callback_data': 'deny:$requestId'},
        ]
      ]
    };
  }

  // ──────────────────────────────────────────
  // 长轮询
  // ──────────────────────────────────────────

  void startPolling(
    void Function(String requestId, PermissionDecision decision) onDecision, {
    void Function(String requestId, String answer)? onAnswer,
  }) {
    if (_polling) return;
    _polling = true;
    _onDecision = onDecision;
    _onAnswer = onAnswer;
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
    // 格式: action:requestId 或 answer:requestId:index
    final parts = callbackData.split(':');
    if (parts.length < 2) return;

    final action = parts[0]; // allow | allowSession | deny | answer

    // 校验 chat_id
    final message = callbackQuery['message'] as Map<String, dynamic>?;
    final chat = message?['chat'] as Map<String, dynamic>?;
    final fromChatId = chat?['id']?.toString() ?? '';
    if (chatId.isNotEmpty && fromChatId != chatId) {
      LoggerService.warning('TelegramChannel: Ignored callback from unknown chat $fromChatId');
      return;
    }

    final callbackQueryId = callbackQuery['id'] as String? ?? '';

    // 格式: answer:requestId:qi:optIndex（多问题）或 answer:requestId:optIndex（单问题兼容）
    if (action == 'answer' && parts.length >= 3) {
      final requestId = parts[1];
      final allOptions = _optionsCache[requestId] ?? [];

      int qi = 0;
      int optIndex = -1;

      if (parts.length == 4) {
        // 多问题格式: answer:requestId:qi:optIndex
        qi = int.tryParse(parts[2]) ?? 0;
        optIndex = int.tryParse(parts[3]) ?? -1;
      } else {
        // 单问题兼容格式: answer:requestId:optIndex
        qi = 0;
        optIndex = int.tryParse(parts[2]) ?? -1;
      }

      final qOptions = qi < allOptions.length ? allOptions[qi] : <String>[];
      if (optIndex >= 0 && optIndex < qOptions.length) {
        final selectedAnswer = qOptions[optIndex];
        _ackCallbackQuery(callbackQueryId, '✅ Q${qi + 1}: $selectedAnswer');
        // 通知 service 层记录该 question 的答案
        _onAnswer?.call(requestId, '$qi:$selectedAnswer');
        // 若所有 question 都已缓存且最后一个已选，清除缓存
        if (qi == allOptions.length - 1) {
          _optionsCache.remove(requestId);
        }
      }
      return;
    }

    final requestId = parts[1];
    final decision = switch (action) {
      'allow' => PermissionDecision.allow,
      'allowSession' => PermissionDecision.allowSession,
      _ => PermissionDecision.deny,
    };
    _onDecision?.call(requestId, decision);
    _ackCallbackQuery(callbackQueryId, switch (decision) {
      PermissionDecision.allow => '✅ 已同意',
      PermissionDecision.allowSession => '🔁 本次全部同意',
      _ => '❌ 已拒绝',
    });
  }

  void _ackCallbackQuery(String callbackQueryId, String text) {
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
