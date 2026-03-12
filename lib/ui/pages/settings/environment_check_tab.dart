import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/s.dart';
import '../../../utils/platform_utils.dart';

/// 工具检测结果
class _ToolCheckResult {
  final String name;
  final String icon;
  final bool isInstalled;
  final String? version;
  final String? path;
  final String? runtimeInfo;
  final String? error;

  const _ToolCheckResult({
    required this.name,
    required this.icon,
    required this.isInstalled,
    this.version,
    this.path,
    this.runtimeInfo,
    this.error,
  });
}

/// 内存缓存
List<_ToolCheckResult>? _cachedResults;

class EnvironmentCheckTab extends StatefulWidget {
  const EnvironmentCheckTab({super.key});

  @override
  State<EnvironmentCheckTab> createState() => _EnvironmentCheckTabState();
}

class _EnvironmentCheckTabState extends State<EnvironmentCheckTab> {
  List<_ToolCheckResult> _results = [];
  bool _isChecking = false;
  final Set<int> _refreshingIndices = {};

  @override
  void initState() {
    super.initState();
    if (_cachedResults != null) {
      _results = _cachedResults!;
    } else {
      _runChecks();
    }
  }

  Future<void> _runChecks() async {
    setState(() => _isChecking = true);

    final tools = <_ToolCheckResult>[];

    // 并行检测所有工具
    final futures = await Future.wait([
      _checkCliTool('Claude Code', 'assets/icons/claude.svg', 'claude'),
      _checkCliTool('Codex', 'assets/icons/chatgpt.svg', 'codex'),
      _checkCliTool('Gemini CLI', 'assets/icons/gemini.svg', 'gemini'),
      _checkAppInstalled(
        'Antigravity',
        'assets/icons/antigravity.svg',
        '/Applications/Antigravity.app',
        'antigravity',
      ),
      _checkAppInstalled(
        'Cursor',
        'assets/icons/cursor.svg',
        '/Applications/Cursor.app',
        'cursor',
      ),
      _checkAppInstalled(
        'Windsurf',
        'assets/icons/windsurf.svg',
        '/Applications/Windsurf.app',
        'windsurf',
      ),
    ]);

    tools.addAll(futures);

    _cachedResults = tools;
    if (mounted) {
      setState(() {
        _results = tools;
        _isChecking = false;
      });
    }
  }

  Future<void> _refreshSingle(int index) async {
    setState(() => _refreshingIndices.add(index));
    final old = _results[index];
    _ToolCheckResult updated;

    final appInfo = _appCheckInfo(old.name);
    if (appInfo != null) {
      updated = await _checkAppInstalled(
        old.name,
        old.icon,
        appInfo.$1,
        appInfo.$2,
      );
    } else {
      final cmd = _nameToCommand(old.name);
      updated = await _checkCliTool(old.name, old.icon, cmd);
    }

    if (mounted) {
      setState(() {
        _results[index] = updated;
        _cachedResults?[index] = updated;
        _refreshingIndices.remove(index);
      });
    }
  }

  /// 返回 (appPath, cliCommand?) 或 null 表示非 App 类型
  (String, String?)? _appCheckInfo(String name) {
    switch (name) {
      case 'Cursor':
        return ('/Applications/Cursor.app', 'cursor');
      case 'Windsurf':
        return ('/Applications/Windsurf.app', 'windsurf');
      case 'Antigravity':
        return ('/Applications/Antigravity.app', 'antigravity');
      default:
        return null;
    }
  }

  String _nameToCommand(String name) {
    switch (name) {
      case 'Claude Code':
        return 'claude';
      case 'Codex':
        return 'codex';
      case 'Gemini CLI':
        return 'gemini';
      case 'Antigravity':
        return 'antigravity';
      default:
        return name.toLowerCase();
    }
  }

  Future<_ToolCheckResult> _checkCliTool(
    String name,
    String icon,
    String command,
  ) async {
    String? version;
    String? path;
    String? error;

    // 先尝试获取版本
    try {
      final result = await PlatformUtils.runCommand('$command --version');
      if (result.exitCode == 0) {
        final v = (result.stdout as String).trim();
        if (v.isNotEmpty) version = v;
      } else {
        final stderr = (result.stderr as String).trim();
        if (stderr.isNotEmpty) error = stderr;
      }
    } catch (e) {
      error = e.toString();
    }

    // 用 which/where 获取路径（即使 --version 失败也能判断是否安装）
    try {
      final whichResult = await PlatformUtils.runCommand(
        Platform.isWindows ? 'where $command' : 'which $command',
      );
      if (whichResult.exitCode == 0) {
        path = (whichResult.stdout as String).trim().split('\n').first;
      }
    } catch (_) {}

    final isInstalled = version != null || path != null;
    final runtimeInfo = name == 'Codex' && path != null
        ? await _detectCodexRuntimeInfo(path)
        : null;
    return _ToolCheckResult(
      name: name,
      icon: icon,
      isInstalled: isInstalled,
      version: version,
      path: path,
      runtimeInfo: runtimeInfo,
      error: isInstalled && version == null ? error : null,
    );
  }

  Future<String?> _detectCodexRuntimeInfo(String executablePath) async {
    final resolvedPath = _resolveExecutablePath(executablePath);
    final manager = _detectNodeManager(executablePath, resolvedPath);
    if (manager == null) return null;

    final nodeVersion =
        _extractNodeVersion(executablePath) ??
        (resolvedPath != null ? _extractNodeVersion(resolvedPath) : null) ??
        await _getCurrentNodeVersion();
    if (nodeVersion == null) return null;

    return 'Node $nodeVersion · $manager';
  }

  String? _resolveExecutablePath(String executablePath) {
    try {
      return File(executablePath).resolveSymbolicLinksSync();
    } catch (_) {
      return null;
    }
  }

  String? _detectNodeManager(String path, [String? resolvedPath]) {
    final candidates = [path, if (resolvedPath != null) resolvedPath];

    for (final candidate in candidates) {
      final normalized = candidate.replaceAll('\\', '/');
      if (normalized.contains('/.local/state/fnm_multishells/') ||
          normalized.contains('/.local/share/fnm/aliases/') ||
          normalized.contains('/.local/share/fnm/node-versions/')) {
        return 'fnm';
      }
    }

    return null;
  }

  String? _extractNodeVersion(String path) {
    final normalized = path.replaceAll('\\', '/');
    final fnmMatch = RegExp(
      r'/\.local/share/fnm/node-versions/(v[^/]+)/installation/',
    ).firstMatch(normalized);
    return fnmMatch?.group(1);
  }

  Future<String?> _getCurrentNodeVersion() async {
    try {
      final result = await PlatformUtils.runCommand('node -v');
      if (result.exitCode != 0) return null;

      final version = (result.stdout as String).trim().split('\n').first;
      return version.isEmpty ? null : version;
    } catch (_) {
      return null;
    }
  }

  Future<_ToolCheckResult> _checkAppInstalled(
    String name,
    String icon,
    String appPath, [
    String? cliCommand,
  ]) async {
    final exists = await Directory(appPath).exists();
    String? version;
    String? error;
    if (exists && cliCommand != null) {
      try {
        final result = await PlatformUtils.runCommand('$cliCommand --version');
        if (result.exitCode == 0) {
          version = (result.stdout as String).trim();
          if (version.isEmpty) version = null;
        } else {
          final stderr = (result.stderr as String).trim();
          if (stderr.isNotEmpty) error = stderr;
        }
      } catch (e) {
        error = e.toString();
      }
    }
    return _ToolCheckResult(
      name: name,
      icon: icon,
      isInstalled: exists,
      version: version,
      path: exists ? appPath : null,
      error: exists && version == null && cliCommand != null ? error : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 标题行
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.get('env_check_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.get('env_check_desc'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: _isChecking ? null : _runChecks,
              icon: _isChecking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 14),
              label: Text(S.get('env_check_refresh')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 工具列表
        if (_isChecking && _results.isEmpty)
          _buildLoadingState(isDark)
        else
          ..._results.asMap().entries.map(
            (e) => _buildToolCard(e.value, isDark, e.key),
          ),
      ],
    );
  }

  /// 分析 stderr 并生成用户友好的诊断提示
  String? _diagnoseError(String toolName, String error) {
    final lower = error.toLowerCase();
    if (lower.contains('invalid regular expression flags') ||
        lower.contains('syntaxerror')) {
      final nodeMatch = RegExp(r'Node\.js\s+v(\d+)').firstMatch(error);
      final nodeVer = nodeMatch?.group(1);
      if (nodeVer != null && int.tryParse(nodeVer) != null && int.parse(nodeVer) < 20) {
        return S.get('env_node_version_too_low')
            .replaceAll('{tool}', toolName)
            .replaceAll('{version}', 'v$nodeVer');
      }
      return S.get('env_node_syntax_error').replaceAll('{tool}', toolName);
    }
    return null;
  }

  void _showErrorDialog(String toolName, String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final diagnosis = _diagnoseError(toolName, error);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade600,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$toolName --version failed',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (diagnosis != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16,
                            color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            diagnosis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: isDark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'Menlo',
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade800,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: Text(S.get('close')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      alignment: Alignment.center,
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 16),
          Text(
            S.get('env_checking'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(_ToolCheckResult result, bool isDark, int index) {
    final isRefreshing = _refreshingIndices.contains(index);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // 图标
          SizedBox(
            width: 28,
            height: 28,
            child: SvgPicture.asset(
              result.icon,
              width: 28,
              height: 28,
              colorFilter: result.icon.contains('claude')
                  ? const ColorFilter.mode(Color(0xFFd97757), BlendMode.srcIn)
                  : (isDark
                        ? ColorFilter.mode(Colors.white70, BlendMode.srcIn)
                        : null),
            ),
          ),
          const SizedBox(width: 14),

          // 名称 + 路径
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (result.path != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    result.path!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontFamily: 'Menlo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (result.runtimeInfo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    result.runtimeInfo!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontFamily: 'Menlo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // 版本号
          if (result.version != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                result.version!,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // 版本检测失败警告图标
          if (result.error != null) ...[
            GestureDetector(
              onTap: () => _showErrorDialog(result.name, result.error!),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: Colors.amber.shade600,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // 状态标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: result.isInstalled
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              result.isInstalled
                  ? S.get('env_installed')
                  : S.get('env_not_installed'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: result.isInstalled ? Colors.green : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 单项刷新按钮
          SizedBox(
            width: 28,
            height: 28,
            child: isRefreshing
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    padding: EdgeInsets.zero,
                    color: _isChecking
                        ? Colors.grey.shade300
                        : Colors.grey.shade500,
                    tooltip: _isChecking ? null : '刷新',
                    onPressed: _isChecking ? null : () => _refreshSingle(index),
                  ),
          ),
        ],
      ),
    );
  }
}
