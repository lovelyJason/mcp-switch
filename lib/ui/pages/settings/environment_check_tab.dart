import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/s.dart';
import '../../../utils/platform_utils.dart';

/// 工具检测结果
class _ToolCheckResult {
  final String name;
  final String icon; // SVG asset path or empty
  final bool isInstalled;
  final String? version;
  final String? path;

  const _ToolCheckResult({
    required this.name,
    required this.icon,
    required this.isInstalled,
    this.version,
    this.path,
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
      _checkCliTool('Antigravity', 'assets/icons/antigravity.svg', 'antigravity'),
      _checkAppInstalled('Cursor', 'assets/icons/cursor.svg', '/Applications/Cursor.app', 'cursor'),
      _checkAppInstalled('Windsurf', 'assets/icons/windsurf.svg', '/Applications/Windsurf.app', 'windsurf'),
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
    if (old.path?.endsWith('.app') == true || (!old.isInstalled && old.icon.contains('cursor') || old.icon.contains('windsurf'))) {
      // App 类型
      final appPath = old.path ?? (old.icon.contains('cursor')
          ? '/Applications/Cursor.app'
          : '/Applications/Windsurf.app');
      final cliCmd = old.icon.contains('cursor') ? 'cursor' : null;
      updated = await _checkAppInstalled(old.name, old.icon, appPath, cliCmd);
    } else {
      // CLI 类型，根据名字推断命令
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

  String _nameToCommand(String name) {
    switch (name) {
      case 'Claude Code': return 'claude';
      case 'Codex': return 'codex';
      case 'Gemini CLI': return 'gemini';
      case 'Antigravity': return 'antigravity';
      default: return name.toLowerCase();
    }
  }

  Future<_ToolCheckResult> _checkCliTool(
    String name,
    String icon,
    String command,
  ) async {
    try {
      final result = await PlatformUtils.runCommand('$command --version');
      if (result.exitCode == 0) {
        final version = (result.stdout as String).trim();
        // 获取路径
        String? path;
        try {
          final whichResult = await PlatformUtils.runCommand(
            Platform.isWindows ? 'where $command' : 'which $command',
          );
          if (whichResult.exitCode == 0) {
            path = (whichResult.stdout as String).trim().split('\n').first;
          }
        } catch (_) {}

        return _ToolCheckResult(
          name: name,
          icon: icon,
          isInstalled: true,
          version: version.isNotEmpty ? version : null,
          path: path,
        );
      }
    } catch (_) {}

    return _ToolCheckResult(
      name: name,
      icon: icon,
      isInstalled: false,
    );
  }

  Future<_ToolCheckResult> _checkAppInstalled(
    String name,
    String icon,
    String appPath, [
    String? cliCommand,
  ]) async {
    final exists = await Directory(appPath).exists();
    String? version;
    if (exists && cliCommand != null) {
      try {
        final result = await PlatformUtils.runCommand('$cliCommand --version');
        if (result.exitCode == 0) {
          version = (result.stdout as String).trim();
          if (version.isEmpty) version = null;
        }
      } catch (_) {}
    }
    return _ToolCheckResult(
      name: name,
      icon: icon,
      isInstalled: exists,
      version: version,
      path: exists ? appPath : null,
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
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
          ..._results.asMap().entries.map((e) => _buildToolCard(e.value, isDark, e.key)),
      ],
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
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
                  ? const ColorFilter.mode(
                      Color(0xFFd97757), BlendMode.srcIn)
                  : (isDark
                      ? ColorFilter.mode(
                          Colors.white70, BlendMode.srcIn)
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
                    color: _isChecking ? Colors.grey.shade300 : Colors.grey.shade500,
                    tooltip: _isChecking ? null : '刷新',
                    onPressed: _isChecking ? null : () => _refreshSingle(index),
                  ),
          ),
        ],
      ),
    );
  }
}
