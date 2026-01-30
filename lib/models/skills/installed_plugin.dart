/// 已安装的插件信息
class InstalledPlugin {
  final String name;
  final String scope;
  final String version;
  final String installPath;
  final DateTime installedAt;
  final DateTime lastUpdated;
  final bool isEnabled;
  /// 是否已被官方废弃（源目录不存在）
  final bool isDeprecated;

  InstalledPlugin({
    required this.name,
    required this.scope,
    required this.version,
    required this.installPath,
    required this.installedAt,
    required this.lastUpdated,
    this.isEnabled = true,
    this.isDeprecated = false,
  });
}
