import 'dart:convert';

/// Claude Code PermissionRequest Hook 的权限请求数据模型
class PermissionRequest {
  final String id;
  final String sessionId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String cwd;
  final DateTime createdAt;
  PermissionDecision decision;

  /// 最近一次被 Hook 脚本轮询的时间（null 表示从未被轮询）
  DateTime? lastPolledAt;

  PermissionRequest({
    required this.id,
    required this.sessionId,
    required this.toolName,
    required this.toolInput,
    required this.cwd,
    required this.createdAt,
    this.decision = PermissionDecision.pending,
  });

  factory PermissionRequest.fromJson(Map<String, dynamic> json) {
    return PermissionRequest(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      toolName: json['tool_name'] as String? ?? '',
      toolInput: (json['tool_input'] as Map<String, dynamic>?) ?? {},
      cwd: json['cwd'] as String? ?? '',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'tool_name': toolName,
        'tool_input': toolInput,
        'cwd': cwd,
        'created_at': createdAt.toIso8601String(),
        'decision': decision.name,
      };

  /// 从 Hook stdin 数据（Claude Code 发来的原始数据）创建
  factory PermissionRequest.fromHookInput(Map<String, dynamic> json, String id) {
    return PermissionRequest(
      id: id,
      sessionId: json['session_id'] as String? ?? '',
      toolName: json['tool_name'] as String? ?? '',
      toolInput: (json['tool_input'] as Map<String, dynamic>?) ?? {},
      cwd: json['cwd'] as String? ?? '',
      createdAt: DateTime.now(),
    );
  }

  /// 简短的命令摘要（用于通知消息）
  String get commandSummary {
    if (toolName == 'Bash') {
      final cmd = toolInput['command'] as String? ?? '';
      return cmd.length > 100 ? '${cmd.substring(0, 100)}...' : cmd;
    }
    if (toolName == 'Write' || toolName == 'Edit') {
      return toolInput['file_path'] as String? ?? '';
    }
    if (toolName == 'Read') {
      return toolInput['file_path'] as String? ?? '';
    }
    // 其他工具：序列化 toolInput 前 100 字符
    final raw = jsonEncode(toolInput);
    return raw.length > 100 ? '${raw.substring(0, 100)}...' : raw;
  }

  /// 项目名（取 cwd 最后一段）
  String get projectName {
    if (cwd.isEmpty) return 'Unknown';
    final parts = cwd.replaceAll('\\', '/').split('/');
    return parts.where((p) => p.isNotEmpty).lastOrNull ?? cwd;
  }
}

enum PermissionDecision {
  pending,
  allow,
  deny,
  /// Hook 脚本已结束（被 VSCode 插件或其他外部渠道处理），本服务未收到决策
  externallyHandled,
}
