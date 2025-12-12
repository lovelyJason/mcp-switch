// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

McpProfile _$McpProfileFromJson(Map<String, dynamic> json) => McpProfile(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  officialLink: json['officialLink'] as String?,
  content: json['content'] as Map<String, dynamic>,
);

Map<String, dynamic> _$McpProfileToJson(McpProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'officialLink': instance.officialLink,
      'content': instance.content,
    };
