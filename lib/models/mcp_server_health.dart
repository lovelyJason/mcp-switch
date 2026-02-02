/// MCP 服务器健康状态
class McpServerHealth {
  final String serverName;
  final bool isHealthy;
  final String? errorMessage;
  final String? commandOrUrl;
  final DateTime lastChecked;

  const McpServerHealth({
    required this.serverName,
    required this.isHealthy,
    this.errorMessage,
    this.commandOrUrl,
    required this.lastChecked,
  });

  McpServerHealth copyWith({
    String? serverName,
    bool? isHealthy,
    String? errorMessage,
    String? commandOrUrl,
    DateTime? lastChecked,
  }) {
    return McpServerHealth(
      serverName: serverName ?? this.serverName,
      isHealthy: isHealthy ?? this.isHealthy,
      errorMessage: errorMessage ?? this.errorMessage,
      commandOrUrl: commandOrUrl ?? this.commandOrUrl,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}
