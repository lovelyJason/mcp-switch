import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class FreshMarkdownEditor extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool isDark;
  final double height;
  final ScrollController? scrollController;

  const FreshMarkdownEditor({
    super.key,
    required this.controller,
    required this.isDark,
    this.hintText,
    this.height = 300,
    this.scrollController,
  });

  @override
  State<FreshMarkdownEditor> createState() => _FreshMarkdownEditorState();
}

class _FreshMarkdownEditorState extends State<FreshMarkdownEditor> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _isPreview = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  void _insertText(String text, {int selectionOffset = 0, String? wrap}) {
    final textValue = _controller.value.text;
    final selection = _controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) return;

    String newText;
    int newSelectionStart;
    int newSelectionEnd;

    if (wrap != null) {
      final selectedText = textValue.substring(start, end);
      newText = textValue.replaceRange(start, end, '$wrap$selectedText$wrap');
      newSelectionStart = start + wrap.length;
      newSelectionEnd = end + wrap.length;
    } else {
      newText = textValue.replaceRange(start, end, text);
      newSelectionStart = start + text.length + selectionOffset;
      newSelectionEnd = newSelectionStart;
    }

    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: newSelectionStart,
        extentOffset: newSelectionEnd,
      ),
    );
    _focusNode.requestFocus();
  }

  void _toggleLinePrefix(String prefix) {
    if (_controller.text.isEmpty) {
      _controller.text = prefix;
      _controller.selection = TextSelection.collapsed(offset: prefix.length);
      _focusNode.requestFocus();
      return;
    }

    final text = _controller.text;
    final selection = _controller.selection;
    
    if (selection.start < 0) return;

    // Find start of current line
    int lineStart = text.lastIndexOf('\n', selection.start - 1);
    lineStart = (lineStart == -1) ? 0 : lineStart + 1;

    // Check if prefix exists
    if (text.startsWith(prefix, lineStart)) {
      // Remove it
      final newText = text.replaceRange(lineStart, lineStart + prefix.length, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start - prefix.length),
      );
    } else {
      // Insert it
      final newText = text.replaceRange(lineStart, lineStart, prefix);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + prefix.length),
      );
    }
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFF9F9F9);
    final toolbarBG = widget.isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = widget.isDark ? Colors.white10 : Colors.grey.shade200;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Content Area
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: 16,
                bottom: _isPreview ? 16 : 60,
              ), // Space for floating toolbar
              child: _isPreview
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: MarkdownBody(
                        data: _controller.text,
                        styleSheet:
                            MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                              h1: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              h2: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                              h3: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                        selectable: true,
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: null,
                      expands: true,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: widget.isDark ? Colors.white : Colors.black87,
                        fontFamily: 'Menlo',
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hintText,
                        hintStyle: TextStyle(
                          color: widget.isDark
                              ? Colors.white24
                              : Colors.grey.shade400,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
            ),
          ),

          // Floating Toolbar (Left Aligned)
          if (!_isPreview)
            Positioned(
              bottom: 10,
              left: 16,
              child: Container(
                height: 38, // Compact Height
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: toolbarBG,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group 1: Headers
                    _ToolbarGroup(
                      children: [
                        _ToolbarTextBtn(
                          'H1',
                          onTap: () => _toggleLinePrefix('# '),
                          isDark: widget.isDark,
                        ),
                        _ToolbarTextBtn(
                          'H2',
                          onTap: () => _toggleLinePrefix('## '),
                          isDark: widget.isDark,
                        ),
                        _ToolbarTextBtn(
                          'H3',
                          onTap: () => _toggleLinePrefix('### '),
                          isDark: widget.isDark,
                        ),
                      ],
                    ),
                    _VerticalDivider(isDark: widget.isDark),
                    // Group 2: Format
                    _ToolbarGroup(
                      children: [
                        _ToolbarIcon(
                          Icons.format_bold,
                          onTap: () => _insertText('', wrap: '**'),
                          isDark: widget.isDark,
                        ),
                        _ToolbarIcon(
                          Icons.format_italic,
                          onTap: () => _insertText('', wrap: '_'),
                          isDark: widget.isDark,
                        ),
                        _ToolbarIcon(
                          Icons.code,
                          onTap: () => _insertText('', wrap: '`'),
                          isDark: widget.isDark,
                        ),
                      ],
                    ),
                    _VerticalDivider(isDark: widget.isDark),
                    // Group 3: List
                    _ToolbarGroup(
                      children: [
                        _ToolbarIcon(
                          Icons.format_list_bulleted,
                          onTap: () => _toggleLinePrefix('- '),
                          isDark: widget.isDark,
                        ),
                        _ToolbarIcon(
                          Icons.check_box_outlined,
                          onTap: () => _toggleLinePrefix('- [ ] '),
                          isDark: widget.isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Preview Toggle (Top Right)
          Positioned(
            top: 20,
            right: 16,
            child: _PreviewToggle(
              isPreview: _isPreview,
              onTap: () => setState(() => _isPreview = !_isPreview),
              isDark: widget.isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  final List<Widget> children;
  const _ToolbarGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _ToolbarTextBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _ToolbarTextBtn(
    this.label, {
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ), // More compact
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13, // Smaller
            color: isDark ? Colors.white70 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _ToolbarIcon(this.icon, {required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ), // More compact
        child: Icon(
          icon,
          size: 18, // Smaller
          color: isDark ? Colors.white70 : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final bool isDark;
  const _VerticalDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16, // Shorter
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isDark ? Colors.white12 : Colors.grey.shade300,
    );
  }
}

class _PreviewToggle extends StatelessWidget {
  final bool isPreview;
  final VoidCallback onTap;
  final bool isDark;

  const _PreviewToggle({
    required this.isPreview,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPreview
              ? (isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isPreview || isDark
              ? Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isPreview ? Icons.edit_outlined : Icons.visibility_outlined,
              size: 16,
              color: isPreview
                  ? Colors.blue
                  : (isDark ? Colors.white70 : Colors.grey.shade500),
            ),
            if (isPreview) ...[
              const SizedBox(width: 4),
              Text(
                'Edit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
