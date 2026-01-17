
import 'package:json_annotation/json_annotation.dart';
import 'registry_item.dart';

part 'mcp_config_v2.g.dart';

/// 编辑器档案 (Editor Profile)
///
/// 描述特定编辑器（如 Windsurf, Claude）当前激活了哪些服务。
/// 它是一个“引用列表”，本身不存储服务配置，只存储 ID。
/// 此注解，告诉编译器帮我自动生成这个类的JSON处理代码：运行flutter pub run build_runner build
@JsonSerializable()
class Profile {
  /// 当前激活的服务 ID 列表
  /// 对应 Registry 中的 Key。
  /// 例如: ["context7-remote", "figma-helper"]
  @JsonKey(name: 'active_ids')
  final List<String> activeIds;

  Profile({
    this.activeIds = const [],
  });

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}

/// V2 全局配置根对象 (Root Config)
///
/// 对应配置文件 `~/.mcp-switch/config.json` 的完整结构。
/// 包含版本号、注释、资源注册表和编辑器档案。
class McpConfigV2 {
  /// 配置文件版本号
  /// 固定为 "2.0" 以区别于 V1。
  final String version;

  /// 文件头部注释，用于警示用户不要手动修改
  /// 例如: "MCP Switch Internal Database..."
  final String? comment;

  /// 资源注册表 (Registry)
  /// 核心数据源：存储所有已添加的 MCP 服务。
  /// Key: 服务唯一ID (String)
  /// Value: 服务详情 (RegistryItem)
  final Map<String, RegistryItem> registry;

  /// 档案列表 (Profiles)
  /// 存储各编辑器的激活状态。
  /// Key: 编辑器标识 (如 "windsurf", "claude")
  /// Value: 档案对象 (Profile)
  final Map<String, Profile> profiles;

  McpConfigV2({
    this.version = '2.0',
    this.comment,
    this.registry = const {},
    this.profiles = const {},
  });

  factory McpConfigV2.fromJson(Map<String, dynamic> json) {
    // 手动解析 registry Map，因为 RegistryItem 需要从 Key (ID) 初始化
    final registryMap = <String, RegistryItem>{};
    if (json['registry'] != null) {
      (json['registry'] as Map<String, dynamic>).forEach((key, value) {
        registryMap[key] =
            RegistryItem.fromJson(key, value as Map<String, dynamic>);
      });
    }

    final profilesMap = <String, Profile>{};
    if (json['profiles'] != null) {
      (json['profiles'] as Map<String, dynamic>).forEach((key, value) {
        profilesMap[key] = Profile.fromJson(value as Map<String, dynamic>);
      });
    }

    return McpConfigV2(
      version: json['version'] as String? ?? '2.0',
      comment: json['comment'] as String?,
      registry: registryMap,
      profiles: profilesMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      if (comment != null) 'comment': comment,
      'registry': registry.map((k, v) => MapEntry(k, v.toJson())),
      'profiles': profiles.map((k, v) => MapEntry(k, v.toJson())),
    };
  }
}
