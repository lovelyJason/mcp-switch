import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/gemini_skill.dart';
import '../utils/platform_utils.dart';

/// 分页加载结果
class CommunityExtensionsResult {
  final List<CommunityGeminiExtension> extensions;
  final bool hasMore;
  final String source; // 'api', 'scrape', 'fallback'

  CommunityExtensionsResult({
    required this.extensions,
    required this.hasMore,
    required this.source,
  });
}

/// Gemini Skills & Extensions 数据服务
/// 负责：本地 Skills/Extensions 扫描、GitHub 社区 Extensions 获取
class GeminiSkillsService {
  /// 获取用户目录（跨平台）
  String get _home => PlatformUtils.userHome;

  /// 缓存社区 Extensions（全部已加载的）
  static List<CommunityGeminiExtension> _allCachedExtensions = [];
  static DateTime? _lastCommunityFetch;

  /// 分页状态
  static int _currentPage = 1;
  static bool _hasMorePages = true;
  static String _dataSource = 'unknown'; // 'api', 'scrape', 'fallback'
  static const int _pageSize = 11;

  /// 是否还有更多数据
  bool get hasMoreCommunityExtensions => _hasMorePages;

  /// 当前数据来源
  String get communityDataSource => _dataSource;

  /// 加载本地 Skills（扫描 ~/.gemini/skills/）
  Future<List<GeminiSkill>> loadLocalSkills() async {
    final skills = <GeminiSkill>[];
    final skillsDir = Directory(PlatformUtils.joinPath(_home, '.gemini', 'skills'));

    try {
      if (await skillsDir.exists()) {
        final entities = await skillsDir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final dirName = PlatformUtils.basename(entity.path);
            // 跳过隐藏目录
            if (dirName.startsWith('.')) continue;

            // 检查是否有 SKILL.md
            final skillMdFile = File(PlatformUtils.joinPath(entity.path, 'SKILL.md'));
            final hasSkillMd = await skillMdFile.exists();

            String? description;
            if (hasSkillMd) {
              try {
                final content = await skillMdFile.readAsString();
                description = parseDescription(content);
              } catch (_) {}
            }

            skills.add(GeminiSkill(
              name: dirName,
              path: entity.path,
              description: description,
              hasSkillMd: hasSkillMd,
            ));
          }
        }
      }

      skills.sort((a, b) => a.name.compareTo(b.name));
      return skills;
    } catch (e) {
      return [];
    }
  }

  /// 加载本地 Extensions（扫描 ~/.gemini/extensions/）
  Future<List<GeminiExtension>> loadLocalExtensions() async {
    final extensions = <GeminiExtension>[];
    final extensionsDir = Directory(PlatformUtils.joinPath(_home, '.gemini', 'extensions'));

    try {
      if (await extensionsDir.exists()) {
        final entities = await extensionsDir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final dirName = PlatformUtils.basename(entity.path);
            // 跳过隐藏目录
            if (dirName.startsWith('.')) continue;

            // 检查 gemini-extension.json
            final configFile = File(PlatformUtils.joinPath(entity.path, 'gemini-extension.json'));
            String? description;
            String? version;

            if (await configFile.exists()) {
              try {
                final content = await configFile.readAsString();
                final json = jsonDecode(content) as Map<String, dynamic>;
                description = json['description'] as String?;
                version = json['version'] as String?;
              } catch (_) {}
            }

            // 检查 README.md
            final readmeFile = File(PlatformUtils.joinPath(entity.path, 'README.md'));
            final hasReadme = await readmeFile.exists();

            // 如果没有从 JSON 获取描述，尝试从 README 获取
            if (description == null && hasReadme) {
              try {
                final content = await readmeFile.readAsString();
                description = parseDescription(content);
              } catch (_) {}
            }

            extensions.add(GeminiExtension(
              name: dirName,
              path: entity.path,
              description: description,
              version: version,
              hasReadme: hasReadme,
            ));
          }
        }
      }

      extensions.sort((a, b) => a.name.compareTo(b.name));
      return extensions;
    } catch (e) {
      return [];
    }
  }

  /// 获取社区 Extensions（首次加载，带分页）
  /// 返回第一页数据
  Future<CommunityExtensionsResult> loadCommunityExtensions() async {
    // 检查缓存是否有效（5分钟）
    if (_allCachedExtensions.isNotEmpty && _lastCommunityFetch != null) {
      final elapsed = DateTime.now().difference(_lastCommunityFetch!);
      if (elapsed.inMinutes < 5) {
        // 返回缓存的第一页
        final firstPage = _allCachedExtensions.take(_pageSize).toList();
        return CommunityExtensionsResult(
          extensions: firstPage,
          hasMore: _allCachedExtensions.length > _pageSize,
          source: _dataSource,
        );
      }
    }

    // 重置分页状态
    _currentPage = 1;
    _hasMorePages = true;
    _allCachedExtensions = [];

    // 加载第一页
    return _loadCommunityPage(1);
  }

  /// 加载更多社区 Extensions
  Future<CommunityExtensionsResult> loadMoreCommunityExtensions() async {
    if (!_hasMorePages) {
      return CommunityExtensionsResult(
        extensions: [],
        hasMore: false,
        source: _dataSource,
      );
    }

    _currentPage++;
    return _loadCommunityPage(_currentPage);
  }

  /// 加载指定页的数据
  Future<CommunityExtensionsResult> _loadCommunityPage(int page) async {
    try {
      // Step 1: 尝试 GitHub API
      final apiResult = await _tryGitHubApiPaged(page);
      if (apiResult != null) {
        _dataSource = 'api';
        _allCachedExtensions.addAll(apiResult.extensions);
        _hasMorePages = apiResult.hasMore;
        _lastCommunityFetch = DateTime.now();
        return apiResult;
      }

      // Step 2: API 失败，尝试爬虫（只在第一页尝试，爬虫一次获取所有）
      if (page == 1) {
        final scrapeResult = await _tryScrapingGitHubPaged(page);
        if (scrapeResult != null) {
          _dataSource = 'scrape';
          _allCachedExtensions.addAll(scrapeResult.extensions);
          _hasMorePages = scrapeResult.hasMore;
          _lastCommunityFetch = DateTime.now();
          return scrapeResult;
        }
      } else if (_dataSource == 'scrape') {
        // 爬虫模式下继续加载下一页
        final scrapeResult = await _tryScrapingGitHubPaged(page);
        if (scrapeResult != null) {
          _allCachedExtensions.addAll(scrapeResult.extensions);
          _hasMorePages = scrapeResult.hasMore;
          return scrapeResult;
        }
      }

      // API 和爬虫都失败，返回空
      _hasMorePages = false;
      return CommunityExtensionsResult(
        extensions: [],
        hasMore: false,
        source: _dataSource,
      );
    } catch (e) {
      // 如果有缓存，尝试从缓存分页返回
      if (_allCachedExtensions.isNotEmpty) {
        final start = (page - 1) * _pageSize;
        if (start < _allCachedExtensions.length) {
          final pageData = _allCachedExtensions.skip(start).take(_pageSize).toList();
          return CommunityExtensionsResult(
            extensions: pageData,
            hasMore: start + _pageSize < _allCachedExtensions.length,
            source: _dataSource,
          );
        }
      }
      _hasMorePages = false;
      return CommunityExtensionsResult(
        extensions: [],
        hasMore: false,
        source: _dataSource,
      );
    }
  }

  /// GitHub API 分页获取
  Future<CommunityExtensionsResult?> _tryGitHubApiPaged(int page) async {
    try {
      final url = 'https://api.github.com/orgs/gemini-cli-extensions/repos'
          '?per_page=$_pageSize&page=$page&sort=updated&direction=desc';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      // 403 = 限流
      if (response.statusCode == 403) {
        return null;
      }

      if (response.statusCode == 200) {
        final extensions = <CommunityGeminiExtension>[];
        final List<dynamic> repos = jsonDecode(response.body);

        for (final repo in repos) {
          final name = repo['name'] as String;
          if (name.startsWith('.') || name == '.github') continue;

          extensions.add(CommunityGeminiExtension(
            name: name,
            description: repo['description'] as String?,
            author: (repo['owner'] as Map<String, dynamic>?)?['login'] as String?,
            githubUrl: repo['html_url'] as String?,
            source: 'github',
          ));
        }

        // 判断是否有更多：如果返回数量 < pageSize，则没有更多
        final hasMore = repos.length >= _pageSize;

        return CommunityExtensionsResult(
          extensions: extensions,
          hasMore: hasMore,
          source: 'api',
        );
      }
    } catch (_) {}
    return null;
  }

  /// 爬虫静态缓存：GitHub 一页返回很多 repo，我们在本地分页
  static List<CommunityGeminiExtension> _scrapeCache = [];
  static int _scrapeGitHubPage = 1; // GitHub 分页
  static bool _scrapeHasMoreGitHubPages = true;

  /// 爬虫分页获取
  /// GitHub 每页返回约 30 个 repo，我们本地按 _pageSize (11) 分页给 UI
  Future<CommunityExtensionsResult?> _tryScrapingGitHubPaged(int uiPage) async {
    // 计算需要的数据范围
    final startIndex = (uiPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize;

    // 如果缓存数据不够，且 GitHub 还有更多页，继续爬
    while (_scrapeCache.length < endIndex && _scrapeHasMoreGitHubPages) {
      final fetched = await _fetchGitHubReposPage(_scrapeGitHubPage);
      if (fetched == null || fetched.isEmpty) {
        _scrapeHasMoreGitHubPages = false;
        break;
      }
      _scrapeCache.addAll(fetched);
      _scrapeGitHubPage++;

      // GitHub 每页约 30 个，如果返回少于 20 个，可能没有更多了
      if (fetched.length < 20) {
        _scrapeHasMoreGitHubPages = false;
      }
    }

    // 从缓存中取当前 UI 页的数据
    if (startIndex >= _scrapeCache.length) {
      return null; // 没有数据了
    }

    final pageExtensions = _scrapeCache.skip(startIndex).take(_pageSize).toList();
    final hasMore = _scrapeCache.length > endIndex || _scrapeHasMoreGitHubPages;

    return CommunityExtensionsResult(
      extensions: pageExtensions,
      hasMore: hasMore,
      source: 'scrape',
    );
  }

  /// 爬取 GitHub 组织仓库页面的一页
  Future<List<CommunityGeminiExtension>?> _fetchGitHubReposPage(int gitHubPage) async {
    try {
      final url = 'https://github.com/orgs/gemini-cli-extensions/repositories?type=all&page=$gitHubPage';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final html = response.body;
        final extensions = <CommunityGeminiExtension>[];
        final seenNames = <String>{};

        // 匹配仓库链接
        final repoPattern = RegExp(
          r'href="/gemini-cli-extensions/([a-zA-Z0-9_.-]+)"',
          caseSensitive: false,
        );

        for (final match in repoPattern.allMatches(html)) {
          final name = match.group(1);
          if (name == null ||
              name.startsWith('.') ||
              name == '.github' ||
              seenNames.contains(name) ||
              name.contains('/')) continue;

          // 过滤掉非仓库的链接（如 graphs、forks、stargazers 等）
          if (['graphs', 'forks', 'stargazers', 'issues', 'pulls', 'settings', 'actions', 'insights', 'network', 'watchers'].contains(name)) {
            continue;
          }

          seenNames.add(name);
          extensions.add(CommunityGeminiExtension(
            name: name,
            description: null, // 爬虫无法获取描述
            author: 'gemini-cli-extensions',
            githubUrl: 'https://github.com/gemini-cli-extensions/$name',
            source: 'github',
          ));
        }

        return extensions;
      }
    } catch (_) {}
    return null;
  }

  /// 清除缓存并重置分页
  void clearCache() {
    _allCachedExtensions = [];
    _lastCommunityFetch = null;
    _currentPage = 1;
    _hasMorePages = true;
    _dataSource = 'unknown';
    // 重置爬虫缓存
    _scrapeCache = [];
    _scrapeGitHubPage = 1;
    _scrapeHasMoreGitHubPages = true;
  }

  /// 解析 Markdown 文件中的描述
  String? parseDescription(String content) {
    // 尝试解析 frontmatter 中的 description
    final descMatch = RegExp(r'^description:\s*(.+)$', multiLine: true).firstMatch(content);
    if (descMatch != null) {
      return descMatch.group(1)?.trim();
    }
    // 尝试从第一段获取描述
    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.startsWith('#') &&
          !trimmed.startsWith('name:') &&
          !trimmed.startsWith('---')) {
        return trimmed.length > 100 ? '${trimmed.substring(0, 100)}...' : trimmed;
      }
    }
    return null;
  }

  /// 解析版本号
  String? parseVersion(String content) {
    final versionMatch = RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
    return versionMatch?.group(1)?.trim();
  }

  /// 格式化日期
  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
