import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/s.dart'; 
import 'widgets/fresh_markdown_editor.dart';

class RuleEditScreen extends StatefulWidget {
  final File file;
  final String title;

  const RuleEditScreen({super.key, required this.file, required this.title});

  @override
  State<RuleEditScreen> createState() => _RuleEditScreenState();
}

class _RuleEditScreenState extends State<RuleEditScreen> {
  late TextEditingController _contentController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      if (await widget.file.exists()) {
        final content = await widget.file.readAsString();
        if (mounted) {
          setState(() {
            _contentController.text = content;
            _isLoading = false;
          });
        }
      } else {
         if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await widget.file.writeAsString(_contentController.text);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved ${widget.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header matching ClaudePromptEditScreen
            _buildHeader(context),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                          child: FreshMarkdownEditor(
                            controller: _contentController,
                            hintText: 'Enter rules content...',
                            isDark: isDark,
                            height: double.infinity, // Fill available space
                          ),
                        ),
            ),

            // Bottom Bar
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 24, right: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
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
          if (widget.title.contains('Windsurf')) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SvgPicture.asset(
                'assets/icons/windsurf.svg',
                width: 24,
                height: 24,
              ),
            ),
          ],
          if (widget.title.contains('Antigravity') ||
              widget.title.contains('Gemini')) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SvgPicture.asset(
                'assets/icons/antigravity.svg',
                width: 24,
                height: 24,
              ),
            ),
          ],
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          
          if (widget.title.contains('Global Rules')) ...[
            const SizedBox(width: 8),
            _InfoHoverWidget(isDark: isDark, title: widget.title),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
           top: BorderSide(
             color: isDark ? Colors.white12 : Colors.grey.shade100,
           ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
            ),
            child: Text(S.get('cancel')),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: const Color(0xFF007AFF), 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              S.get('save'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoHoverWidget extends StatefulWidget {
  final bool isDark;
  final String title;
  const _InfoHoverWidget({required this.isDark, required this.title});

  @override
  State<_InfoHoverWidget> createState() => _InfoHoverWidgetState();
}

class _InfoHoverWidgetState extends State<_InfoHoverWidget> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isHovering = false;

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 320, // Constrained width
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(0, size.height + 8),
          showWhenUnlinked: false,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: widget.isDark ? const Color(0xFF2C2C2E) : Colors.white,
            child: MouseRegion(
              onEnter: (_) => _isHovering = true,
              onExit: (_) => _removeOverlay(),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white10
                        : Colors.grey.shade200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: widget.title.contains('Windsurf')
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Global Windsurf Rules File',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '全局 Windsurf 规则定义了 Cascade 在所有工作区中的行为方式。使用此文件为 Cascade 提供特定上下文并设定具体指导原则。',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isDark
                                  ? Colors.white70
                                  : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '规则文件示例如下：',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isDark
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.black54
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '1. My build system is Bazel\n'
                              '2. My testing framework is pytest\n'
                              '3. Don\'t modify any files in ...\n'
                              '4. Don\'t use these APIs ...',
                              style: TextStyle(
                                fontFamily: 'Menlo',
                                fontSize: 12,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.isDark
                                    ? Colors.white70
                                    : Colors.black87,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: '需要灵感？查看我们的'),
                                TextSpan(
                                  text: '目录',
                                  style: const TextStyle(
                                    color: Color(0xFF007AFF),
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () async {
                                      final uri = Uri.parse(
                                        'https://windsurf.com/editor/directory',
                                      );
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri);
                                      }
                                    },
                                ),
                                const TextSpan(
                                  text: '，在那里您可以找到预制的规则和最佳实践来帮助您入门。',
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '更新中......',
                            style: TextStyle(
                              fontSize: 14,
                              color: widget.isDark
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _isHovering = false;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isHovering) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) {
          _isHovering = true;
          _showOverlay();
        },
        onExit: (_) {
          _isHovering = false;
          // Delay removal to allow moving mouse into the overlay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!_isHovering) {
              _overlayEntry?.remove();
              _overlayEntry = null;
            }
          });
        },
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
        ),
      ),
    );
  }
}
