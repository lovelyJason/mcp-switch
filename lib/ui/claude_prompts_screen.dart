import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/s.dart';
import '../models/claude_prompt.dart';
import '../services/prompt_service.dart';
import 'claude_prompt_edit_screen.dart';
import 'components/custom_dialog.dart';

class ClaudePromptsScreen extends StatelessWidget {
  const ClaudePromptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Container(
              padding: const EdgeInsets.only(
                top: 38,
                left: 24,
                right: 24,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white24
                            : Colors.grey.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, size: 20, color: textColor),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: S.get(
                        'cancel',
                      ), // Reuse 'cancel' (Cancel/Back) or similar
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    S.get('claude_prompt_title'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  // Add Button in Header or keep FAB?
                  // User complained about layout coordination. Putting it in header aligns well.
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.add,
                        size: 20,
                        color: Colors.white,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ClaudePromptEditScreen(),
                        ),
                      ),
                      tooltip: S.get('add_prompt'),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Consumer<PromptService>(
                builder: (context, promptService, child) {
                  final prompts = promptService.prompts;
                  if (prompts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notes,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            S.get('no_prompts'),
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    );
                  }

                  final activePrompt = prompts.cast<ClaudePrompt?>().firstWhere(
                    (p) => p?.isActive == true,
                    orElse: () => null,
                  );
                  final activeName =
                      activePrompt?.title ?? S.get('prompt_none_active');
                  final statusText = S
                      .get('prompt_total_active')
                      .replaceAll('{count}', prompts.length.toString())
                      .replaceAll('{name}', activeName);

                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(
                          left: 24,
                          right: 24,
                          bottom: 24,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 0,
                          ),
                          itemCount: prompts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final prompt = prompts[index];
                            return PromptListItem(
                              prompt: prompt,
                              isDark: isDark,
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PromptListItem extends StatefulWidget {
  final ClaudePrompt prompt;
  final bool isDark;

  const PromptListItem({super.key, required this.prompt, required this.isDark});

  @override
  State<PromptListItem> createState() => _PromptListItemState();
}

class _PromptListItemState extends State<PromptListItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = widget.isDark ? Colors.white10 : Colors.grey.shade200;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (!widget.isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Optional: Can still tap row to edit? User wants explicit Edit button.
              // Let's keep tap to edit for convenience or disable if Edit button handles it.
              // Previously tap to edit.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ClaudePromptEditScreen(prompt: widget.prompt),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Toggle on Left
                  Switch(
                    value: widget.prompt.isActive,
                    onChanged: (val) {
                      Provider.of<PromptService>(
                        context,
                        listen: false,
                      )
                          .toggleActive(widget.prompt.id, val);
                    },
                    activeColor: const Color(
                      0xFF007AFF,
                    ), // Blue matching standard
                  ),
                  const SizedBox(width: 16),
                  
                  // Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.prompt.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.prompt.description?.isNotEmpty ==
                                true) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.prompt.description!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.prompt.content.replaceAll('\n', ' '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                        if (widget.prompt.isActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              S.get('prompt_active_hint'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF007AFF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Hover Actions
                  if (_isHovering) ...[
                    const SizedBox(width: 16),
                    // Edit Button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white10
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: widget.isDark
                            ? Colors.white70
                            : Colors.grey.shade700,
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ClaudePromptEditScreen(prompt: widget.prompt),
                            ),
                          );
                        },
                        tooltip: S.get('edit_prompt'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete Button
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: Colors.redAccent,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      onPressed: () {
                        // Confirm delete
                        CustomConfirmDialog.show(
                          context,
                          title: S.get('delete'),
                          content: S.get('delete_confirm'),
                          confirmText: S.get('delete'),
                          cancelText: S.get('cancel'),
                          confirmColor: Colors.redAccent,
                          onConfirm: () {
                            Provider.of<PromptService>(
                              context,
                              listen: false,
                            ).deletePrompt(widget.prompt.id);
                          },
                        );
                      },
                      tooltip: S.get('delete'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
