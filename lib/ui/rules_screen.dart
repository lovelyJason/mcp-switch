import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/s.dart';
import '../utils/platform_utils.dart';
import 'rule_edit_screen.dart';

import '../../models/editor_type.dart';

class RulesScreen extends StatelessWidget {
  final EditorType editorType;

  const RulesScreen({super.key, required this.editorType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    final home = PlatformUtils.userHome;
    final windsurfRulesPath =
        PlatformUtils.joinPath(home, '.codeium', 'windsurf', 'memories', 'global_rules.md');
    final agGeminiRulesPath = PlatformUtils.joinPath(home, '.gemini', 'GEMINI.md');

    List<Widget> ruleItems = [];

    if (editorType == EditorType.windsurf) {
      ruleItems.add(
        _RuleListItem(
          title: 'Windsurf Global Rules',
          path: windsurfRulesPath,
          file: File(windsurfRulesPath),
          isDark: isDark,
        ),
      );
    } else if (editorType == EditorType.antigravity ||
        editorType == EditorType.gemini) {
      ruleItems.add(
        _RuleListItem(
          title: 'Antigravity & Gemini Global Rules',
          path: agGeminiRulesPath,
          file: File(agGeminiRulesPath),
          isDark: isDark,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                      tooltip: S.get('cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Rules', // Or localized title
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 0,
                ),
                children: ruleItems,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleListItem extends StatefulWidget {
  final String title;
  final String path;
  final File file;
  final bool isDark;

  const _RuleListItem({
    required this.title,
    required this.path,
    required this.file,
    required this.isDark,
  });

  @override
  State<_RuleListItem> createState() => _RuleListItemState();
}

class _RuleListItemState extends State<_RuleListItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = widget.isDark ? Colors.white10 : Colors.grey.shade200;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      RuleEditScreen(file: widget.file, title: widget.title),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Icon(
                    Icons.description_outlined,
                    size: 24,
                    color: widget.isDark
                        ? Colors.white70
                        : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.path,
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontFamily: 'Menlo',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Action
                  if (_isHovering)
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
                              builder: (_) => RuleEditScreen(
                                file: widget.file,
                                title: widget.title,
                              ),
                            ),
                          );
                        },
                        tooltip: S.get('edit'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
