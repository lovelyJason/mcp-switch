import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

/// 供应商预设数据模型
class ProviderPreset {
  final String id;
  final String name;
  final String description;
  final String baseUrl;
  final String? website;
  final String? icon;
  final bool isOfficial;

  const ProviderPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.baseUrl,
    this.website,
    this.icon,
    this.isOfficial = false,
  });

  factory ProviderPreset.fromMap(Map<String, dynamic> map) {
    return ProviderPreset(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      baseUrl: map['base_url'] as String? ?? '',
      website: map['website'] as String?,
      icon: map['icon'] as String?,
      isOfficial: map['is_official'] as bool? ?? false,
    );
  }
}

/// 供应商预设配置加载器
///
/// 从 assets/config/provider_presets.yaml 读取，结构类似 McpPresetsConfig。
/// 只读内置资源，更新预设需要发版。
class ProviderPresetsConfig {
  static Map<String, List<ProviderPreset>> _presets = {};
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      final yamlString =
          await rootBundle.loadString('assets/config/provider_presets.yaml');
      final yamlDoc = loadYaml(yamlString);
      final parsed = _yamlToMap(yamlDoc) as Map<String, dynamic>;

      final presetsMap = parsed['presets'] as Map<String, dynamic>? ?? {};
      _presets = presetsMap.map((editorType, list) {
        final items = (list as List).cast<Map<String, dynamic>>();
        return MapEntry(
          editorType,
          items.map(ProviderPreset.fromMap).toList(),
        );
      });
    } catch (e) {
      // 加载失败时用空预设，不影响基本功能
      _presets = {};
    }

    _initialized = true;
  }

  /// 获取指定编辑器类型的预设列表（不含自定义占位）
  static List<ProviderPreset> presetsFor(String editorType) {
    return _presets[editorType] ?? [];
  }

  static dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries.map((e) => MapEntry(e.key.toString(), _yamlToMap(e.value))),
      );
    } else if (yaml is YamlList) {
      return yaml.map(_yamlToMap).toList();
    }
    return yaml;
  }
}
