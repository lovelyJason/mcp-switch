/// 已安装的市场信息
class InstalledMarketplace {
  final String name;
  final String source;
  final String repo;
  final String installLocation;
  final DateTime lastUpdated;
  final bool hasReadme;

  InstalledMarketplace({
    required this.name,
    required this.source,
    required this.repo,
    required this.installLocation,
    required this.lastUpdated,
    this.hasReadme = false,
  });

  /// 判断是否是官方市场
  bool get isOfficial => repo.startsWith('anthropics/');

  /// 获取 README.md 路径
  String get readmePath => '$installLocation/README.md';

  /// 获取翻译后的 README 路径
  String get translatedReadmePath => '$installLocation/README-zh.md';
}
