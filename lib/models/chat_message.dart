import 'package:uuid/uuid.dart';

/// 聊天消息角色
enum ChatRole {
  user,
  assistant,
  system,
}

/// 工具调用状态
enum ToolCallStatus {
  pending,
  executing,
  completed,
  failed,
}

/// 工具调用信息
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> input;
  final String? result;
  final ToolCallStatus status;
  final String? error;

  const ToolCall({
    required this.id,
    required this.name,
    required this.input,
    this.result,
    this.status = ToolCallStatus.pending,
    this.error,
  });

  ToolCall copyWith({
    String? id,
    String? name,
    Map<String, dynamic>? input,
    String? result,
    ToolCallStatus? status,
    String? error,
  }) {
    return ToolCall(
      id: id ?? this.id,
      name: name ?? this.name,
      input: input ?? this.input,
      result: result ?? this.result,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'input': input,
        'result': result,
        'status': status.name,
        'error': error,
      };

  factory ToolCall.fromJson(Map<String, dynamic> json) => ToolCall(
        id: json['id'] as String,
        name: json['name'] as String,
        input: Map<String, dynamic>.from(json['input'] as Map),
        result: json['result'] as String?,
        status: ToolCallStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ToolCallStatus.pending,
        ),
        error: json['error'] as String?,
      );
}

/// 聊天消息
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final List<ToolCall>? toolCalls;
  final bool isStreaming;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.toolCalls,
    this.isStreaming = false,
  });

  factory ChatMessage.user(String content) => ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.user,
        content: content,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.assistant(String content, {List<ToolCall>? toolCalls}) =>
      ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.assistant,
        content: content,
        timestamp: DateTime.now(),
        toolCalls: toolCalls,
      );

  factory ChatMessage.system(String content) => ChatMessage(
        id: const Uuid().v4(),
        role: ChatRole.system,
        content: content,
        timestamp: DateTime.now(),
      );

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? content,
    DateTime? timestamp,
    List<ToolCall>? toolCalls,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      toolCalls: toolCalls ?? this.toolCalls,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'toolCalls': toolCalls?.map((t) => t.toJson()).toList(),
        'isStreaming': isStreaming,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: ChatRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => ChatRole.user,
        ),
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        toolCalls: (json['toolCalls'] as List?)
            ?.map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
            .toList(),
        isStreaming: json['isStreaming'] as bool? ?? false,
      );
}
