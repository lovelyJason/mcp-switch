// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registry_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SseConfig _$SseConfigFromJson(Map<String, dynamic> json) => SseConfig(
  endpoint: json['endpoint'] as String,
  headers:
      (json['headers'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$SseConfigToJson(SseConfig instance) => <String, dynamic>{
  'endpoint': instance.endpoint,
  'headers': instance.headers,
};

LocalConfig _$LocalConfigFromJson(Map<String, dynamic> json) => LocalConfig(
  command: json['command'] as String,
  args:
      (json['args'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  env:
      (json['env'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$LocalConfigToJson(LocalConfig instance) =>
    <String, dynamic>{
      'command': instance.command,
      'args': instance.args,
      'env': instance.env,
    };
