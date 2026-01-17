// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registry_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegistryMeta _$RegistryMetaFromJson(Map<String, dynamic> json) => RegistryMeta(
  type: json['type'] as String,
  name: json['name'] as String,
  icon: json['icon'] as String?,
  description: json['description'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$RegistryMetaToJson(RegistryMeta instance) =>
    <String, dynamic>{
      'type': instance.type,
      'name': instance.name,
      'icon': instance.icon,
      'description': instance.description,
      'tags': instance.tags,
    };
