
import 'package:json_annotation/json_annotation.dart';

part 'mcp_profile.g.dart';

@JsonSerializable()
class McpProfile {
  final String id;
  String name;
  String? description;
  String? officialLink;
  
  /// The actual JSON content of the MCP configuration.
  /// This could be a full specific server config or the entire mcpServers map.
  /// For now, we treat it as the generated JSON content.
  Map<String, dynamic> content;

  McpProfile({
    required this.id,
    required this.name,
    this.description,
    this.officialLink,
    required this.content,
  });

  factory McpProfile.fromJson(Map<String, dynamic> json) => _$McpProfileFromJson(json);
  Map<String, dynamic> toJson() => _$McpProfileToJson(this);
  
  McpProfile copyWith({
    String? name,
    String? description,
    String? officialLink,
    Map<String, dynamic>? content,
  }) {
    return McpProfile(
      id: this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      officialLink: officialLink ?? this.officialLink,
      content: content ?? this.content,
    );
  }
}
