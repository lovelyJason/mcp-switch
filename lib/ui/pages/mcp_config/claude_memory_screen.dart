import 'dart:io';
import 'package:flutter/material.dart';
import '../../../l10n/s.dart';
import '../../../utils/platform_utils.dart';
import '../rules/rule_edit_screen.dart';

/// 查看和编辑 Claude Code 项目的 memory 文件列表
/// 路径格式：~/.claude/projects/[dirKey]/memory/*.md
class ClaudeMemoryScreen extends StatefulWidget {
  final String projectPath;
  final String projectName;

  const ClaudeMemoryScreen({
    super.key,
    required this.projectPath,
    required this.projectName,
  });

  @override
  State<ClaudeMemoryScreen> createState() => _ClaudeMemoryScreenState();

  /// 将项目路径转换为 ~/.claude/projects/ 下的目录名
  /// /Users/foo/bar.baz → -Users-foo-bar-baz（/ 和 . 都替换为 -，保留开头的 -）
  static String pathToDirKey(String projectPath) {
    return projectPath.replaceAll('/', '-').replaceAll('.', '-');
  }

  /// 获取项目对应的 memory 目录
  static Directory memoryDir(String projectPath) {
    final dirKey = pathToDirKey(projectPath);
    return Directory('${PlatformUtils.userHome}/.claude/projects/$dirKey/memory');
  }

  /// 检查 memory 目录是否存在且有 md 文件
  static Future<bool> hasMemoryFiles(String projectPath) async {
    final dir = memoryDir(projectPath);
    if (!await dir.exists()) return false;
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.md')) return true;
    }
    return false;
  }
}

class _ClaudeMemoryScreenState extends State<ClaudeMemoryScreen> {
  List<File>? _files;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final dir = ClaudeMemoryScreen.memoryDir(widget.projectPath);
      if (!await dir.exists()) {
        if (mounted) setState(() => _files = []);
        return;
      }
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.md')) {
          files.add(entity);
        }
      }
      files.sort((a, b) => a.path.compareTo(b.path));
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark, textColor),
            Expanded(child: _buildBody(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 24, right: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.memory_outlined, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.get('claude_memory_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  widget.projectName,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: Colors.orange,
            tooltip: S.get('refresh_config'),
            onPressed: () {
              setState(() => _files = null);
              _loadFiles();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_files == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_files!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.note_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              S.get('claude_memory_empty'),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _files!.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: isDark ? Colors.white12 : Colors.grey.shade100,
        indent: 16,
        endIndent: 16,
      ),
      itemBuilder: (context, index) => _buildFileItem(_files![index], isDark),
    );
  }

  Widget _buildFileItem(File file, bool isDark) {
    final name = file.path.split(Platform.pathSeparator).last;
    return ListTile(
      leading: const Icon(Icons.description_outlined, size: 20, color: Colors.orange),
      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      subtitle: FutureBuilder<FileStat>(
        future: file.stat(),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox.shrink();
          final stat = snap.data!;
          final modified = stat.modified;
          final size = stat.size;
          final sizeStr = size < 1024 ? '${size}B' : '${(size / 1024).toStringAsFixed(1)}KB';
          final timeStr = _formatDate(modified);
          return Text(
            '$sizeStr · $timeStr',
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          );
        },
      ),
      trailing: Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RuleEditScreen(file: file, title: name),
          ),
        );
        // 编辑后刷新列表（文件大小/时间可能变化）
        setState(() {});
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}
