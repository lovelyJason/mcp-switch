
import 'package:json_annotation/json_annotation.dart';
import 'registry_config.dart';

part 'registry_item.g.dart';

/// 注册表元数据 (Meta Information)
///
/// 存储服务的描述性信息，这些信息不影响功能连接，
/// 仅用于在 UI 上向用户展示。
@JsonSerializable()
class RegistryMeta {
  /// 服务类型
  /// - 'system': 系统预装或本地工具 (Local Tools)
  /// - 'custom': 用户自定义添加的服务 (Custom Added)
  final String type;

  /// 显示名称
  /// 例如: "Context7 Cloud", "Figma Helper"
  final String name;

  /// 图标路径 (Asset Path)
  /// 例如: "assets/icons/cloud.png"
  /// 可选字段，若为空则显示默认图标。
  final String? icon;

  /// 服务的详细描述或备注
  /// 例如: "Context7 提供的远程推理服务，用于处理复杂逻辑"
  final String? description;

  /// 标签列表，用于分类筛选
  /// 例如: ["AI", "Remote", "Design"]
  final List<String> tags;

  RegistryMeta({
    required this.type,
    required this.name,
    this.icon,
    this.description,
    this.tags = const [],
  });

  factory RegistryMeta.fromJson(Map<String, dynamic> json) =>
      _$RegistryMetaFromJson(json);

  Map<String, dynamic> toJson() => _$RegistryMetaToJson(this);
}

/// 注册表项 (Registry Item)
///
/// 这是 V2 架构中的核心数据单元，代表一个独立的 MCP 服务资源。
/// 它包含了“这是什么”(Meta) 和 “怎么连接”(Config)。
class RegistryItem {
  /// 全局唯一标识符 (Unique ID)
  /// 作为 `mcpServers` Map 的 Key。
  /// 例如: "context7-remote", "figma-helper"
  final String id;

  /// 元数据 (Meta)
  /// 包含名称、图标、描述等 UI 展示信息。
  final RegistryMeta meta;

  /// 连接模式 (Connection Mode)
  /// - 'sse': Server-Sent Events (远程)
  /// - 'local': Stdio Process (本地)
  final String mode;

  /// 具体配置信息 (Polymorphic Config)
  /// 根据 [mode] 的不同，可能是 [SseConfig] 或 [LocalConfig]。
  final RegistryConfig config;

  RegistryItem({
    required this.id,
    required this.meta,
    required this.mode,
    required this.config,
  });

  /// 这是一个自定义的 fromJson，因为 config 字段是多态的。
  /// 我们需要先读取 [mode]，然后告诉 RegistryItem 如何解析 [config] 部分。
  factory RegistryItem.fromJson(String id, Map<String, dynamic> json) {
    final mode = json['mode'] as String;
    return RegistryItem(
      id: id,
      meta: RegistryMeta.fromJson(json['meta'] as Map<String, dynamic>),
      mode: mode,
      config: RegistryConfig.fromJson(
          json['config'] as Map<String, dynamic>, mode),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meta': meta.toJson(),
      'mode': mode,
      'config': config.toJson(),
    };
  }
}
