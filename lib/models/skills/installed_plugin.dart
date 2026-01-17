/// 已安装的插件信息
class InstalledPlugin {
  final String name;
  final String scope;
  final String version;
  final String installPath;
  final DateTime installedAt;
  final DateTime lastUpdated;
  final bool isEnabled;

  InstalledPlugin({
    required this.name,
    required this.scope,
    required this.version,
    required this.installPath,
    required this.installedAt,
    required this.lastUpdated,
    this.isEnabled = true,
  });
}
