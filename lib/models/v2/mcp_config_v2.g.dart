// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_config_v2.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  activeIds:
      (json['active_ids'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'active_ids': instance.activeIds,
};
