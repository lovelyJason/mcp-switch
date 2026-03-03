import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import '../models/editor_type.dart';

/// 功能在某个版本区间使用的机制
class FeatureVersionRange {
  final String from;
  final String? to;
  final String mechanism;

  const FeatureVersionRange({
    required this.from,
    this.to,
    required this.mechanism,
  });

  /// 判断给定版本是否落在此区间内 [from, to)
  bool containsVersion(String version) {
    if (_compareVersion(version, from) < 0) return false;
    if (to != null && _compareVersion(version, to!) >= 0) return false;
    return true;
  }
}

class EditorFeature {
  final EditorType editor;
  final String id;
  final String description;
  final String? doc;
  final List<FeatureVersionRange> versions;

  const EditorFeature({
    required this.editor,
    required this.id,
    required this.description,
    this.doc,
    this.versions = const [],
  });

  /// 根据版本号获取当前生效的机制，null 表示该版本不支持此功能
  String? getMechanism(String version) {
    for (final range in versions) {
      if (range.containsVersion(version)) return range.mechanism;
    }
    return null;
  }
}

/// 版本比较：返回 >0 (a>b), 0 (a==b), <0 (a<b)
int _compareVersion(String a, String b) {
  final aParts = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final bParts = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final len = aParts.length > bParts.length ? aParts.length : bParts.length;

  for (var i = 0; i < len; i++) {
    final av = i < aParts.length ? aParts[i] : 0;
    final bv = i < bParts.length ? bParts[i] : 0;
    if (av != bv) return av - bv;
  }
  return 0;
}

/// 从 assets/config/editor_features.yaml 加载的编辑器功能注册表
class EditorFeatures {
  EditorFeatures._();

  static List<EditorFeature> _all = [];
  static bool _initialized = false;

  static List<EditorFeature> get all => _all;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      final yamlString =
          await rootBundle.loadString('assets/config/editor_features.yaml');
      final yamlDoc = loadYaml(yamlString);

      if (yamlDoc is YamlMap) {
        final List<EditorFeature> features = [];

        for (final entry in yamlDoc.entries) {
          final editorName = entry.key.toString();
          final editorType = _parseEditorType(editorName);
          if (editorType == null) continue;

          final items = entry.value;
          if (items is! YamlList) continue;

          for (final item in items) {
            if (item is! YamlMap) continue;

            final List<FeatureVersionRange> versionRanges = [];
            final versions = item['versions'];
            if (versions is YamlList) {
              for (final v in versions) {
                if (v is! YamlMap) continue;
                versionRanges.add(FeatureVersionRange(
                  from: v['from']?.toString() ?? '0.0.0',
                  to: v['to']?.toString(),
                  mechanism: v['mechanism']?.toString() ?? '',
                ));
              }
            }

            features.add(EditorFeature(
              editor: editorType,
              id: item['id']?.toString() ?? '',
              description: item['description']?.toString() ?? '',
              doc: item['doc']?.toString(),
              versions: versionRanges,
            ));
          }
        }

        _all = features;
      }
    } catch (e) {
      print('Failed to load editor_features.yaml: $e');
    }

    _initialized = true;
  }

  static EditorType? _parseEditorType(String name) {
    try {
      return EditorType.values.firstWhere((e) => e.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 获取指定编辑器的所有功能特性
  static List<EditorFeature> forEditor(EditorType editor) {
    return _all.where((f) => f.editor == editor).toList();
  }

  /// 根据编辑器 + id 查找功能特性
  static EditorFeature? find(EditorType editor, String id) {
    try {
      return _all.firstWhere((f) => f.editor == editor && f.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取指定编辑器 + 功能在某版本下的机制
  static String? getMechanism(EditorType editor, String id, String version) {
    return find(editor, id)?.getMechanism(version);
  }
}
