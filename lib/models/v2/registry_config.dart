
import 'package:json_annotation/json_annotation.dart';

part 'registry_config.g.dart';

/// 注册表配置基类 (RegistryConfig)
///
/// 这是一个抽象类，用于定义 MCP 服务的核心配置。
/// 根据服务的 [mode]，它会有不同的实现：
/// - [SseConfig]: 对应 `mode: sse`，远程 SSE 服务。
/// - [LocalConfig]: 对应 `mode: local`，本地 Stdio 进程。
abstract class RegistryConfig {
  RegistryConfig();

  /// 根据 [mode] 工厂构造对应的 Config 子类
  factory RegistryConfig.fromJson(Map<String, dynamic> json, String mode) {
    if (mode == 'sse') {
      return SseConfig.fromJson(json);
    } else if (mode == 'local') {
      return LocalConfig.fromJson(json);
    }
    throw FormatException('Unknown mode: $mode');
  }

  Map<String, dynamic> toJson();
}

/// SSE 远程服务配置
///
/// 对应 `docs/architecture/v2_registry_adapter.md` 中的场景 B。
@JsonSerializable()
class SseConfig extends RegistryConfig {
  /// 服务的核心接入点地址 (Endpoint)
  /// 例如: "https://api.context7.com/sse"
  final String endpoint;

  /// 需要透传给 SSE 连接的 HTTP 头
  /// 例如: { "CONTEXT7_API_KEY": "sk-..." }
  final Map<String, String> headers;

  SseConfig({
    required this.endpoint,
    this.headers = const {},
  });

  factory SseConfig.fromJson(Map<String, dynamic> json) =>
      _$SseConfigFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$SseConfigToJson(this);
}

/// 本地进程服务配置 (Stdio / Local)
///
/// 对应 `docs/architecture/v2_registry_adapter.md` 中的场景 A。
@JsonSerializable()
class LocalConfig extends RegistryConfig {
  /// 启动命令，通常是可执行文件
  /// 例如: "npx", "python3", "docker"
  final String command;

  /// 传递给命令的参数列表
  /// 例如: ["-y", "@modelcontextprotocol/server-filesystem", "/Users/me"]
  final List<String> args;

  /// 进程运行时需要的环境变量
  /// 例如: { "API_KEY": "..." }
  final Map<String, String> env;

  LocalConfig({
    required this.command,
    this.args = const [],
    this.env = const {},
  });

  factory LocalConfig.fromJson(Map<String, dynamic> json) =>
      _$LocalConfigFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$LocalConfigToJson(this);
}
