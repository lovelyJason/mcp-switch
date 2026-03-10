import 'package:flutter/material.dart';

/// Codex config.toml 源码编辑器
/// 纯文本编辑，实时回调变更内容，由父级处理双向同步
class CodexConfigEditor extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onChanged;

  const CodexConfigEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
  });

  @override
  State<CodexConfigEditor> createState() => _CodexConfigEditorState();
}

class _CodexConfigEditorState extends State<CodexConfigEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(CodexConfigEditor old) {
    super.didUpdateWidget(old);
    if (widget.initialText != _controller.text) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: _controller,
        maxLines: null,
        onChanged: widget.onChanged,
        style: TextStyle(
          fontFamily: 'Menlo',
          fontSize: 13,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
          height: 1.5,
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(16),
          border: InputBorder.none,
          hintText: 'model = "gpt-5.1-codex"\nmodel_reasoning_effort = "medium"',
          hintStyle: TextStyle(
            fontFamily: 'Menlo',
            fontSize: 13,
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}
