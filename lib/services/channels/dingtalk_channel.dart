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

  DingtalkChannel({
    required this.webhookUrl,
    required this.secret,
    this.port = 8099,
    this.hostAddress = '127.0.0.1',
  });

  // ──────────────────────────────────────────
  // 推送权限请求消息
  // ──────────────────────────────────────────

  Future<void> sendPermissionRequest(PermissionRequest request) async {
    final message = _buildActionCard(request);
    await _send(message);
  }

  Map<String, dynamic> _buildActionCard(PermissionRequest request) {
    final emoji = _toolEmoji(request.toolName);
    final title = 'Claude Code 请求授权';

    final text = '''
## 🔔 Claude Code 请求授权

$emoji **工具**: ${request.toolName}

📁 **项目**: ${request.projectName}

${request.commandSummary.isNotEmpty ? '💻 **命令**: `${request.commandSummary}`\n' : ''}
🆔 **ID**: ${request.id.substring(0, 8)}
''';

    return {
      'msgtype': 'actionCard',
      'actionCard': {
        'title': title,
        'text': text,
        'btns': [
          {
            'title': '✅ 同意',
            'actionURL':
                'http://$hostAddress:$port/action/allow/${request.id}',
          },
          {
            'title': '❌ 拒绝',
            'actionURL':
                'http://$hostAddress:$port/action/deny/${request.id}',
          },
        ],
        'btnOrientation': '1', // 横向排列
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
