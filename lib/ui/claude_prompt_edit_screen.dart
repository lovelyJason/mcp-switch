import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../l10n/s.dart';
import '../models/claude_prompt.dart';
import '../services/prompt_service.dart';
import 'widgets/fresh_markdown_editor.dart';

// 全局安装claude mcp
// claude mcp add chrome-devtools npx chrome-devtools-mcp@latest --scope user
// sse:
// claude mcp remove shadow-forge -s user
// claude mcp add shadow-forge --transport sse http://localhost:3005/sse -s user

class ClaudePromptEditScreen extends StatefulWidget {
  final ClaudePrompt? prompt;

  const ClaudePromptEditScreen({super.key, this.prompt});

  @override
  State<ClaudePromptEditScreen> createState() => _ClaudePromptEditScreenState();
}

class _ClaudePromptEditScreenState extends State<ClaudePromptEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _contentController;
  // ignore: unused_field
  final FocusNode _contentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.prompt?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.prompt?.description ?? '',
    );
    _contentController = TextEditingController(
      text: widget.prompt?.content ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      // Show error? For now just return
      return;
    }

    final service = Provider.of<PromptService>(context, listen: false);

    if (widget.prompt != null) {
      final updated = widget.prompt!.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        content: _contentController.text,
      );
      service.updatePrompt(updated);
    } else {
      final newPrompt = ClaudePrompt(
        id: const Uuid().v4(),
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        content: _contentController.text,
        updatedAt: DateTime.now(),
        isActive: false,
      );
      service.addPrompt(newPrompt);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(),

            // Title & Description Area (Fixed or minimal scroll)
            // Use Container with constraints or flexible if needed, but standard inputs are small.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  // Row for Title & Description
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.get('prompt_name'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _titleController,
                              style: const TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                hintText: S.get('prompt_name'),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.get('prompt_description'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionController,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: S.get('prompt_description'),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Label for Content
                  Text(
                    S.get('prompt_content'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            // Content Editor - Expanded to fill remaining space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                child: FreshMarkdownEditor(
                  controller: _contentController,
                  hintText: S.get('prompt_content'),
                  isDark: isDark,
                  height: double.infinity, // Let it expand
                ),
              ),
            ),

            // Bottom Bar
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
          const SizedBox(width: 16),
          Text(
            widget.prompt != null ? S.get('edit_prompt') : S.get('add_prompt'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
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
