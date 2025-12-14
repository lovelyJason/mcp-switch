import 'package:uuid/uuid.dart';

class ClaudePrompt {
  final String id;
  String title;
  String? description; // Optional description
  String content;
  bool isActive;
  final DateTime updatedAt;

  ClaudePrompt({
    required this.id,
    required this.title,
    this.description,
    required this.content,
    this.isActive = false,
    required this.updatedAt,
  });

  factory ClaudePrompt.fromJson(Map<String, dynamic> json) {
    return ClaudePrompt(
      id: json['id'] ?? const Uuid().v4(),
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      content: json['content'] ?? '',
      isActive: json['isActive'] ?? false,
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      'content': content,
      'isActive': isActive,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
  
  ClaudePrompt copyWith({
    String? title,
    String? description,
    String? content,
    bool? isActive,
  }) {
    return ClaudePrompt(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      content: content ?? this.content,
      isActive: isActive ?? this.isActive,
      updatedAt: DateTime.now(),
    );
  }
}
