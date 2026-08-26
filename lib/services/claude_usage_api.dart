import 'dart:convert';

import 'package:http/http.dart' as http;

/// Claude 账号用量（5 小时 / 7 天窗口的使用百分比）
class ClaudeUsage {
  final double fiveHourPercent;
  final DateTime? fiveHourResetsAt;
  final double sevenDayPercent;
  final DateTime? sevenDayResetsAt;

  /// 该用量数据抓取的时间（本地记录，用于展示"上次刷新"）
  final DateTime? fetchedAt;

  const ClaudeUsage({
    required this.fiveHourPercent,
    required this.sevenDayPercent,
    this.fiveHourResetsAt,
    this.sevenDayResetsAt,
    this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'five': fiveHourPercent,
        'fiveResets': fiveHourResetsAt?.toIso8601String(),
        'seven': sevenDayPercent,
        'sevenResets': sevenDayResetsAt?.toIso8601String(),
        'at': (fetchedAt ?? DateTime.now()).toIso8601String(),
      };

  static ClaudeUsage? fromJsonString(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      final d = jsonDecode(s);
      if (d is! Map) return null;
      double num0(dynamic v) => v is num ? v.toDouble() : 0;
      DateTime? dt(dynamic v) => v is String ? DateTime.tryParse(v) : null;
      return ClaudeUsage(
        fiveHourPercent: num0(d['five']),
        fiveHourResetsAt: dt(d['fiveResets']),
        sevenDayPercent: num0(d['seven']),
        sevenDayResetsAt: dt(d['sevenResets']),
        fetchedAt: dt(d['at']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// OAuth 刷新后返回的新 token 对
class RefreshedToken {
  final String accessToken;
  final String? refreshToken;
  final int? expiresInSeconds;
  final int? refreshExpiresInSeconds;
  const RefreshedToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresInSeconds,
    this.refreshExpiresInSeconds,
  });
}

class ClaudeUsageUnauthorized implements Exception {
  const ClaudeUsageUnauthorized();
}

/// 调用 Anthropic OAuth 用量接口 —— 端点/头/字段均来自 Claude Code CLI 2.1.x。
class ClaudeUsageApi {
  static const String _usageUrl = 'https://api.anthropic.com/api/oauth/usage';
  static const String _tokenUrl = 'https://platform.claude.com/v1/oauth/token';
  // Claude Code 公开 OAuth client_id
  static const String _clientId = '9d1c250a-e61b-44d9-88ed-5944d1962f5e';
  static const String _betaHeader = 'oauth-2025-04-20';
  // 需带 claude-cli UA，否则 platform.claude.com 会被 Cloudflare 拦(error 1010)
  static const String _userAgent = 'claude-cli/2.1.197 (external, cli)';

  /// 用 accessToken 拉取用量。401 抛 [ClaudeUsageUnauthorized]（表示需刷新）。
  static Future<ClaudeUsage> fetchUsage(String accessToken) async {
    final resp = await http.get(
      Uri.parse(_usageUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'anthropic-beta': _betaHeader,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
        'User-Agent': _userAgent,
      },
    );
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw const ClaudeUsageUnauthorized();
    }
    if (resp.statusCode != 200) {
      throw Exception('usage http ${resp.statusCode}: ${resp.body}');
    }
    final d = jsonDecode(resp.body);
    double pct(dynamic node) {
      if (node is Map && node['utilization'] is num) {
        return (node['utilization'] as num).toDouble();
      }
      return 0;
    }

    DateTime? reset(dynamic node) {
      if (node is Map && node['resets_at'] is String) {
        return DateTime.tryParse(node['resets_at'] as String);
      }
      return null;
    }

    return ClaudeUsage(
      fiveHourPercent: pct(d['five_hour']),
      fiveHourResetsAt: reset(d['five_hour']),
      sevenDayPercent: pct(d['seven_day']),
      sevenDayResetsAt: reset(d['seven_day']),
    );
  }

  /// 用 refreshToken 换新 token（refreshToken 会轮换，调用方必须回写存储）。
  static Future<RefreshedToken> refresh(String refreshToken) async {
    final resp = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Content-Type': 'application/json',
        'anthropic-beta': _betaHeader,
        'User-Agent': _userAgent,
      },
      body: jsonEncode({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('refresh http ${resp.statusCode}: ${resp.body}');
    }
    final d = jsonDecode(resp.body) as Map<String, dynamic>;
    final at = d['access_token'] as String?;
    if (at == null || at.isEmpty) {
      throw Exception('refresh: no access_token in response');
    }
    int? asInt(dynamic v) => v is num ? v.toInt() : null;
    return RefreshedToken(
      accessToken: at,
      refreshToken: d['refresh_token'] as String?,
      expiresInSeconds: asInt(d['expires_in']),
      refreshExpiresInSeconds: asInt(d['refresh_token_expires_in']),
    );
  }
}
