import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../l10n/s.dart';
import '../../../services/gemini_context_service.dart';
import 'gemini_context_edit_screen.dart';

class GeminiPromptsScreen extends StatefulWidget {
  const GeminiPromptsScreen({super.key});

  @override
  State<GeminiPromptsScreen> createState() => _GeminiPromptsScreenState();
}

class _GeminiPromptsScreenState extends State<GeminiPromptsScreen> {
  final GeminiContextService _service = GeminiContextService();

  @override
  void initState() {
    super.initState();
    _service.load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
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
            _buildHeader(context, isDark, textColor),
            Expanded(
              child: ListenableBuilder(
                listenable: _service,
                builder: (context, _) {
                  if (_service.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_service.contextFiles.isEmpty) {
                    return _buildEmpty(isDark);
                  }
                  return _buildList(isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color textColor) {
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
              tooltip: S.get('cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gemini Context',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Text(
                  'GEMINI.md & Extension context files',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notes, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '未找到 context 文件',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            '~/.gemini/GEMINI.md 或各 extension 的 context 文件不存在',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildList(bool isDark) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: _service.contextFiles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _ContextFileCard(
            file: _service.contextFiles[index],
            isDark: isDark,
            onEdited: () => _service.load(),
          );
        },
      ),
    );
  }
}

class _ContextFileCard extends StatefulWidget {
  final GeminiContextFile file;
  final bool isDark;
  final VoidCallback? onEdited;

  const _ContextFileCard({
    required this.file,
    required this.isDark,
    this.onEdited,
  });

  @override
  State<_ContextFileCard> createState() => _ContextFileCardState();
}

class _ContextFileCardState extends State<_ContextFileCard> {
  bool _expanded = false;
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = widget.isDark ? Colors.white10 : Colors.grey.shade200;
    final sourceColor =
        widget.file.isGlobal ? Colors.blue : Colors.purple.shade300;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovering
                ? Colors.blue.withValues(alpha: 0.4)
                : borderColor,
          ),
          boxShadow: [
            if (!widget.isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：点击展开/收起
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 文件图标
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: sourceColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: sourceColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.file.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sourceColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.file.isGlobal
                                      ? 'Global'
                                      : widget.file.sourceName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: sourceColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.file.filePath
                                .replaceAll(Platform.environment['HOME'] ?? '', '~'),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Menlo',
                              color: widget.isDark
                                  ? Colors.white38
                                  : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // 复制按钮
                    if (_isHovering)
                      IconButton(
                        icon: const Icon(Icons.copy_outlined, size: 16),
                        color: Colors.grey.shade500,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: '复制内容',
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: widget.file.content));
                          ScaffoldMessenger.of(context).clearSnackBars();
                        },
                      ),
                    // 编辑按钮（仅全局 GEMINI.md）
                    if (_isHovering && widget.file.isGlobal)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        color: Colors.orange,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        tooltip: '编辑',
                        onPressed: () async {
                          final refreshed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (_) => GeminiContextEditScreen(
                                file: widget.file,
                              ),
                            ),
                          );
                          if (refreshed == true) {
                            widget.onEdited?.call();
                          }
                        },
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            ),
            // 展开内容
            if (_expanded) ...[
              Divider(
                height: 1,
                color: widget.isDark ? Colors.white10 : Colors.grey.shade100,
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  widget.file.content.isEmpty ? '（文件为空）' : widget.file.content,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Menlo',
                    height: 1.6,
                    color: widget.isDark
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
