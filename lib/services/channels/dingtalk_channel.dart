import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../models/permission_request.dart';
import '../logger_service.dart';

/// 钉钉机器人 Channel
/// 使用自定义机器人 Webhook（加签模式）发送 ActionCard 消息
/// 回调通过 HTTP Server /callback/dingtalk 接收（需在钉钉后台配置 outgoing URL）
class DingtalkChannel {
  final String webhookUrl;
  final String secret; // 加签密钥（以 SEC 开头）
  final int port;
  final String hostAddress; // 回调地址，手机可访问的 IP 或域名（如 Tailscale IP）
  final String? localHostAddress; // 本机回调地址，非 null 时会在卡片中额外附加本机按钮

  DingtalkChannel({
    required this.webhookUrl,
    required this.secret,
    this.port = 8099,
    this.hostAddress = '127.0.0.1',
    this.localHostAddress,
  });

  // ──────────────────────────────────────────
  // 推送权限请求消息
  // ──────────────────────────────────────────

  Future<void> sendPermissionRequest(PermissionRequest request) async {
    final message = request.isAskFollowup
        ? _buildAskFollowupNotify(request)
        : _buildActionCard(request);
    await _send(message);
  }

  Map<String, dynamic> _buildActionCard(PermissionRequest request) {
    final emoji = _toolEmoji(request.toolName);
    const title = 'Claude Code 请求授权';

    final timeStr = _formatTime(request.createdAt);
    final text = '''
## 🔔 Claude Code 请求授权

$emoji **工具**: ${request.toolName}

📁 **项目**: ${request.projectName}

${request.commandSummary.isNotEmpty ? '💻 **命令**: `${request.commandSummary}`\n\n' : ''}🕐 **时间**: $timeStr　🆔 **ID**: ${request.id.substring(0, 8)}
''';

    final btns = <Map<String, String>>[
      {
        'title': '✅ 同意',
        'actionURL': 'http://$hostAddress:$port/action/allow/${request.id}',
      },
      {
        'title': '🔁 本次全部同意',
        'actionURL': 'http://$hostAddress:$port/action/allow-session/${request.id}',
      },
      {
        'title': '❌ 拒绝',
        'actionURL': 'http://$hostAddress:$port/action/deny/${request.id}',
      },
    ];

    return {
      'msgtype': 'actionCard',
      'actionCard': {
        'title': title,
        'text': text,
        'btns': btns,
        'btnOrientation': '1',
      },
    };
  }

  /// AskUserQuestion：仅通知，不带操作按钮（答案由 VSCode 插件处理）
  Map<String, dynamic> _buildAskFollowupNotify(PermissionRequest request) {
    final timeStr = _formatTime(request.createdAt);
    final questions = request.askQuestions;

    final sb = StringBuffer();
    sb.writeln('## ❓ Claude Code 询问\n');
    sb.writeln('📁 **项目**: ${request.projectName}\n');
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (questions.length > 1) {
        sb.writeln('**问题 ${i + 1}${q.header.isNotEmpty ? ' · ${q.header}' : ''}**: ${q.question}\n');
      } else {
        sb.writeln('💬 **问题**: ${q.question}\n');
      }
    }
    sb.writeln('🕐 **时间**: $timeStr');
    sb.writeln('\n> 请在 Claude Code 客户端选择答案');

    return {
      'msgtype': 'markdown',
      'markdown': {
        'title': 'Claude Code 询问',
        'text': sb.toString(),
      },
    };
  }

  // ──────────────────────────────────────────
  // HTTP 发送
  // ──────────────────────────────────────────

  Future<void> _send(Map<String, dynamic> body) async {
    try {
      final url = _buildSignedUrl();
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final errcode = json['errcode'] as int? ?? -1;
      if (errcode != 0) {
        LoggerService.warning('DingtalkChannel: Send failed: ${json['errmsg']}');
      }
    } catch (e) {
      LoggerService.error('DingtalkChannel: HTTP error', e);
    }
  }

  /// 构建加签 URL
  String _buildSignedUrl() {
    if (secret.isEmpty) return webhookUrl;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stringToSign = '$timestamp\n$secret';
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(stringToSign));
    final sign = Uri.encodeComponent(base64.encode(digest.bytes));

    final separator = webhookUrl.contains('?') ? '&' : '?';
    return '$webhookUrl${separator}timestamp=$timestamp&sign=$sign';
  }

  // ──────────────────────────────────────────
  // 工具
  // ──────────────────────────────────────────

  String _formatTime(DateTime dt) {
    final mon = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${dt.year}-$mon-$day $h:$m:$s';
  }

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
