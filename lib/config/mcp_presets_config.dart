import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import '../l10n/s.dart';

/// MCP 预设配置加载器
///
/// 配置直接从 assets/config/mcp_presets.yaml 读取，跟随项目走
/// 用户可以直接编辑项目中的 YAML 文件来自定义预设
/// 支持导入/导出配置文件
class McpPresetsConfig {
  static Map<String, dynamic> _config = {};
  static bool _initialized = false;
  static String? _lastError;

  /// 获取最后一次加载错误
  static String? get lastError => _lastError;

  /// 初始化配置（从 assets 读取）
  static Future<void> init() async {
    if (_initialized) return;
    _lastError = null;

    try {
      final yamlString =
          await rootBundle.loadString('assets/config/mcp_presets.yaml');
      final yamlDoc = loadYaml(yamlString);
      final parsed = _yamlToMap(yamlDoc);
      _config = parsed is Map<String, dynamic> ? parsed : {};
    } catch (e) {
      _lastError = '加载 MCP 预设配置失败: $e';
      print(_lastError);
      _config = _getDefaultConfig();
    }

    _initialized = true;
  }

  /// 将 YAML 数据转换为 Dart 原生类型
  static dynamic _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries
            .map((e) => MapEntry(e.key.toString(), _yamlToMap(e.value))),
      );
    } else if (yaml is YamlList) {
      return yaml.map((e) => _yamlToMap(e)).toList();
    } else if (yaml is Map) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries
            .map((e) => MapEntry(e.key.toString(), _yamlToMap(e.value))),
      );
    }
    return yaml;
  }

  /// 硬编码默认配置（最后的 fallback）
  static Map<String, dynamic> _getDefaultConfig() {
    return {
      'presets': [
        {
          'id': 'custom',
          'name_key': 'custom_config',
          'icon': null,
          'is_custom': true,
          'connection_types': [
            {
              'type': 'local',
              'recommended': true,
              'config': {'command': '', 'args': []},
            }
          ],
          'form_fields': [],
        }
      ],
      'connection_type_definitions': {
        'local': {
          'label_key': 'connection_type_local',
          'description_key': 'connection_type_local_desc',
          'show_command_args': true,
        },
        'http': {
          'label_key': 'connection_type_http',
          'description_key': 'connection_type_http_desc',
          'show_command_args': false,
        },
        'sse': {
          'label_key': 'connection_type_sse',
          'description_key': 'connection_type_sse_desc',
          'show_command_args': false,
        },
      },
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 预设列表 Getters
  // ═══════════════════════════════════════════════════════════════════════════

  /// 获取所有预设列表
  static List<McpPreset> get presets {
    try {
      final presetsList = _config['presets'];
      if (presetsList is! List) return [_customPreset];

      return presetsList.map((p) => McpPreset.fromMap(p)).toList();
    } catch (e) {
      print('解析预设列表失败: $e');
      return [_customPreset];
    }
  }

  /// 默认的自定义预设
  static McpPreset get _customPreset => McpPreset(
        id: 'custom',
        name: S.get('custom_config'),
        icon: null,
        isCustom: true,
        connectionTypes: [
          McpConnectionType(
            type: 'local',
            recommended: true,
            config: {'command': '', 'args': []},
          )
        ],
        formFields: [],
      );

  /// 根据 ID 获取预设
  static McpPreset? getPresetById(String id) {
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取连接类型定义
  static Map<String, ConnectionTypeDef> get connectionTypeDefinitions {
    try {
      final defs = _config['connection_type_definitions'];
      if (defs is! Map) return _defaultConnectionTypeDefs;

      return defs.map((key, value) {
        return MapEntry(key.toString(), ConnectionTypeDef.fromMap(value));
      });
    } catch (e) {
      print('解析连接类型定义失败: $e');
      return _defaultConnectionTypeDefs;
    }
  }

  static Map<String, ConnectionTypeDef> get _defaultConnectionTypeDefs => {
        'local': ConnectionTypeDef(
          labelKey: 'connection_type_local',
          descriptionKey: 'connection_type_local_desc',
          showCommandArgs: true,
        ),
        'http': ConnectionTypeDef(
          labelKey: 'connection_type_http',
          descriptionKey: 'connection_type_http_desc',
          showCommandArgs: false,
        ),
        'sse': ConnectionTypeDef(
          labelKey: 'connection_type_sse',
          descriptionKey: 'connection_type_sse_desc',
          showCommandArgs: false,
        ),
      };

  // ═══════════════════════════════════════════════════════════════════════════
  // 导入/导出功能
  // ═══════════════════════════════════════════════════════════════════════════

  /// 导出配置到指定路径
  static Future<bool> exportConfig(String targetPath) async {
    try {
      final yamlString =
          await rootBundle.loadString('assets/config/mcp_presets.yaml');
      await File(targetPath).writeAsString(yamlString);
      return true;
    } catch (e) {
      _lastError = '导出配置失败: $e';
      print(_lastError);
      return false;
    }
  }

  /// 从 YAML 字符串导入配置（内存加载，不写文件）
  /// 返回 null 表示成功，返回错误信息表示失败
  static String? importFromString(String yamlString) {
    try {
      final yamlDoc = loadYaml(yamlString);
      final parsed = _yamlToMap(yamlDoc);

      // 验证必要字段
      if (parsed is! Map<String, dynamic>) {
        return 'YAML 格式错误: 根节点必须是对象';
      }
      if (parsed['presets'] is! List) {
        return 'YAML 格式错误: 缺少 presets 列表';
      }

      // 验证通过，直接加载到内存
      _config = parsed;
      return null;
    } on YamlException catch (e) {
      return 'YAML 语法错误: ${e.message}';
    } catch (e) {
      return '导入配置失败: $e';
    }
  }

  /// 从文件路径导入配置
  static Future<String?> importConfig(String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) {
        return '文件不存在: $sourcePath';
      }
      final yamlString = await sourceFile.readAsString();
      return importFromString(yamlString);
    } catch (e) {
      return '导入配置失败: $e';
    }
  }

  /// 验证 YAML 字符串格式
  static String? validateYaml(String yamlString) {
    try {
      final yamlDoc = loadYaml(yamlString);
      final parsed = _yamlToMap(yamlDoc);

      if (parsed is! Map<String, dynamic>) {
        return '根节点必须是对象';
      }
      if (parsed['presets'] is! List) {
        return '缺少 presets 列表';
      }

      // 验证每个预设
      final presets = parsed['presets'] as List;
      for (var i = 0; i < presets.length; i++) {
        final preset = presets[i];
        if (preset is! Map) {
          return '预设 #${i + 1} 格式错误';
        }
        if (preset['id'] == null) {
          return '预设 #${i + 1} 缺少 id 字段';
        }
      }

      return null; // 验证通过
    } on YamlException catch (e) {
      return 'YAML 语法错误: ${e.message}';
    } catch (e) {
      return '验证失败: $e';
    }
  }

  /// 重新加载配置（从 assets）
  static Future<void> reload() async {
    _initialized = false;
    _config = {};
    _lastError = null;
    await init();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 数据模型类
// ═══════════════════════════════════════════════════════════════════════════════

/// MCP 预设
class McpPreset {
  final String id;
  final String? nameKey; // i18n key，用于显示
  final String? name; // 直接字符串，用于显示
  final String? defaultCliName; // CLI 命令中使用的默认名称（只能英文、数字、-、_）
  final String? icon;
  final String? tipsKey; // 灯泡提示 i18n key
  final bool isCustom;
  final List<McpConnectionType> connectionTypes;
  final List<McpFormField> formFields;

  McpPreset({
    required this.id,
    this.nameKey,
    this.name,
    this.defaultCliName,
    this.icon,
    this.tipsKey,
    this.isCustom = false,
    required this.connectionTypes,
    required this.formFields,
  });

  /// 获取显示名称（优先 i18n key）
  String get displayName {
    if (nameKey != null) {
      final translated = S.get(nameKey!);
      // 如果翻译结果等于 key 本身，说明没有翻译，使用 name
      if (translated != nameKey) return translated;
    }
    return name ?? id;
  }

  /// 获取提示信息
  String? get tips {
    if (tipsKey != null) {
      final translated = S.get(tipsKey!);
      if (translated != tipsKey) return translated;
    }
    return null;
  }

  /// 获取推荐的连接类型
  McpConnectionType? get recommendedConnectionType {
    try {
      return connectionTypes.firstWhere((c) => c.recommended);
    } catch (_) {
      return connectionTypes.isNotEmpty ? connectionTypes.first : null;
    }
  }

  factory McpPreset.fromMap(Map<String, dynamic> map) {
    final connectionTypesList = map['connection_types'] as List? ?? [];
    final formFieldsList = map['form_fields'] as List? ?? [];

    return McpPreset(
      id: map['id']?.toString() ?? 'unknown',
      nameKey: map['name_key']?.toString(),
      name: map['name']?.toString(),
      defaultCliName: map['default_cli_name']?.toString(),
      icon: map['icon']?.toString(),
      tipsKey: map['tips_key']?.toString(),
      isCustom: map['is_custom'] == true,
      connectionTypes: connectionTypesList
          .map((c) => McpConnectionType.fromMap(c as Map<String, dynamic>))
          .toList(),
      formFields: formFieldsList
          .map((f) => McpFormField.fromMap(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 连接类型配置
class McpConnectionType {
  final String type; // local, http, sse
  final bool recommended;
  final Map<String, dynamic> config;
  final String? claudeCli; // Claude Code CLI 命令模板

  McpConnectionType({
    required this.type,
    this.recommended = false,
    required this.config,
    this.claudeCli,
  });

  /// 获取 command
  String? get command => config['command']?.toString();

  /// 获取 args
  List<String> get args {
    final argsList = config['args'];
    if (argsList is List) {
      return argsList.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// 获取额外 args（用于 local 模式的模板参数）
  List<String> get extraArgs {
    final extraArgsList = config['extra_args'];
    if (extraArgsList is List) {
      return extraArgsList.map((e) => e.toString()).toList();
    }
    return [];
  }

  /// 获取 URL（用于 http/sse 模式）
  String? get url => config['url']?.toString();

  /// 获取 headers（用于 http/sse 模式）
  Map<String, String> get headers {
    final headersMap = config['headers'];
    if (headersMap is Map) {
      return headersMap.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  factory McpConnectionType.fromMap(Map<String, dynamic> map) {
    return McpConnectionType(
      type: map['type']?.toString() ?? 'local',
      recommended: map['recommended'] == true,
      config: map['config'] as Map<String, dynamic>? ?? {},
      claudeCli: map['claude_cli']?.toString(),
    );
  }

  /// 生成 Claude Code CLI 命令
  /// [name] MCP 名称
  /// [fieldValues] 表单字段值，如 {'api_key': 'xxx', 'figma_token': 'yyy'}
  String? generateClaudeCliCommand(String name, Map<String, String> fieldValues) {
    if (claudeCli == null || claudeCli!.isEmpty) return null;

    var cmd = claudeCli!;
    // 替换 {{name}}
    cmd = cmd.replaceAll('{{name}}', name);
    // 替换所有 {{field_id}}
    for (final entry in fieldValues.entries) {
      cmd = cmd.replaceAll('{{${entry.key}}}', entry.value);
    }
    return cmd;
  }
}

/// 表单字段配置
class McpFormField {
  final String id;
  final String? labelKey;
  final String? subLabelKey;
  final String? placeholder;
  final bool required;
  final String? applyMode; // env, arg, null表示使用extra_args模板
  final String? envKey; // 用于 env 模式
  final String? argKey; // 用于 arg 模式
  final String? argFormat; // equals, space

  McpFormField({
    required this.id,
    this.labelKey,
    this.subLabelKey,
    this.placeholder,
    this.required = false,
    this.applyMode, // 默认 null，由 extra_args 处理
    this.envKey,
    this.argKey,
    this.argFormat,
  });

  /// 获取显示标签
  String get displayLabel {
    if (labelKey != null) {
      final translated = S.get(labelKey!);
      if (translated != labelKey) return translated;
    }
    return id;
  }

  /// 获取副标签
  String get displaySubLabel {
    if (subLabelKey != null) {
      final translated = S.get(subLabelKey!);
      if (translated != subLabelKey) return translated;
    }
    return '';
  }

  factory McpFormField.fromMap(Map<String, dynamic> map) {
    return McpFormField(
      id: map['id']?.toString() ?? '',
      labelKey: map['label_key']?.toString(),
      subLabelKey: map['sub_label_key']?.toString(),
      placeholder: map['placeholder']?.toString(),
      required: map['required'] == true,
      applyMode: map['apply_mode']?.toString(),
      envKey: map['env_key']?.toString(),
      argKey: map['arg_key']?.toString(),
      argFormat: map['arg_format']?.toString(),
    );
  }
}

/// 连接类型定义
class ConnectionTypeDef {
  final String labelKey;
  final String descriptionKey;
  final bool showCommandArgs;

  ConnectionTypeDef({
    required this.labelKey,
    required this.descriptionKey,
    this.showCommandArgs = true,
  });

  String get displayLabel => S.get(labelKey);
  String get displayDescription => S.get(descriptionKey);

  factory ConnectionTypeDef.fromMap(Map<String, dynamic> map) {
    return ConnectionTypeDef(
      labelKey: map['label_key']?.toString() ?? '',
      descriptionKey: map['description_key']?.toString() ?? '',
      showCommandArgs: map['show_command_args'] == true,
    );
  }
}
