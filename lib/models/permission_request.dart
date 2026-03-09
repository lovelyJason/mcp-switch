import 'dart:convert';

/// AskUserQuestion 中单个问题的数据结构
class AskQuestion {
  final String question;
  final String header;
  final List<String> options;
  final bool multiSelect;

  const AskQuestion({
    required this.question,
    required this.header,
    required this.options,
    this.multiSelect = false,
  });

  static AskQuestion fromMap(Map<dynamic, dynamic> map) {
    final opts = <String>[];
    final rawOpts = map['options'];
    if (rawOpts is List) {
      for (final o in rawOpts) {
        final label = (o is Map ? o['label'] : o)?.toString() ?? '';
        if (label.isNotEmpty) opts.add(label);
      }
    }
    return AskQuestion(
      question: map['question'] as String? ?? '',
      header: map['header'] as String? ?? '',
      options: opts,
      multiSelect: map['multiSelect'] as bool? ?? false,
    );
  }
}

/// Claude Code Hook 的权限/问询请求数据模型
class PermissionRequest {
  final String id;
  final String sessionId;
  final String toolName;
  final Map<String, dynamic> toolInput;
  final String cwd;
  final DateTime createdAt;

  /// hook_event_name：PermissionRequest | PreToolUse 等
  final String hookEventName;

  /// AskUserQuestion 的所有问题列表（其他类型为空）
  final List<AskQuestion> askQuestions;

  /// 已收集的每个 question 的答案（index 对应 askQuestions）
  final List<String?> questionAnswers;

  /// 最终提交给 Hook 的答案字符串（由 service 层在 resolve 时写入）
  String? resolvedAnswer;

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
    this.hookEventName = 'PermissionRequest',
    List<AskQuestion>? askQuestions,
    List<String?>? questionAnswers,
    this.decision = PermissionDecision.pending,
  })  : askQuestions = askQuestions ?? const [],
        questionAnswers = questionAnswers ?? List.filled(askQuestions?.length ?? 0, null);

  /// 是否为 AskUserQuestion 类型（Claude Code 向用户提问）
  bool get isAskFollowup => toolName == 'AskUserQuestion';

  /// 已提交的最终答案（用于 badge 显示）
  String? get answer => resolvedAnswer;

  /// 所有 question 都已回答
  bool get allAnswered {
    if (askQuestions.isEmpty) return false;
    return questionAnswers.every((a) => a != null);
  }

  /// 第一个未回答的 question 的索引，-1 表示全部已回答
  int get nextUnansweredIndex {
    for (var i = 0; i < questionAnswers.length; i++) {
      if (questionAnswers[i] == null) return i;
    }
    return -1;
  }

  /// 获取最终返回给 Hook 的 answer 字符串（所有答案换行拼接）
  String get finalAnswer {
    return questionAnswers.map((a) => a ?? '').join('\n');
  }

  /// 向指定 question 设置答案，返回是否全部已回答
  bool setQuestionAnswer(int index, String answer) {
    if (index >= 0 && index < questionAnswers.length) {
      questionAnswers[index] = answer;
    }
    return allAnswered;
  }

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
    final toolName = json['tool_name'] as String? ?? '';
    final toolInput = (json['tool_input'] as Map<String, dynamic>?) ?? {};

    // AskUserQuestion: 解析所有 questions
    final askQuestions = <AskQuestion>[];
    if (toolName == 'AskUserQuestion') {
      final questions = toolInput['questions'];
      if (questions is List) {
        for (final q in questions) {
          if (q is Map) {
            askQuestions.add(AskQuestion.fromMap(q));
          }
        }
      }
    }

    return PermissionRequest(
      id: id,
      sessionId: json['session_id'] as String? ?? '',
      toolName: toolName,
      toolInput: toolInput,
      cwd: json['cwd'] as String? ?? '',
      createdAt: DateTime.now(),
      hookEventName: json['hook_event_name'] as String? ?? 'PermissionRequest',
      askQuestions: askQuestions,
      questionAnswers: List.filled(askQuestions.length, null),
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
    if (toolName == 'AskUserQuestion') {
      if (askQuestions.isEmpty) return '';
      // 拼接所有问题文本，用换行分隔
      return askQuestions
          .map((q) => q.question)
          .where((q) => q.isNotEmpty)
          .join('\n\n');
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
  /// 本次会话内所有同类工具调用不再询问（对应 Claude Code 的 "Yes, allow all"）
  allowSession,
  deny,
  /// Hook 脚本已结束（被 VSCode 插件或其他外部渠道处理），本服务未收到决策
  externallyHandled,
}
