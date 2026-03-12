import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../l10n/s.dart';

class ConfigConflictBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const ConfigConflictBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.amber.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.get('config_conflict_banner'),
              style: const TextStyle(fontSize: 13, color: Colors.amber),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(12),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfigConflictDiff extends StatelessWidget {
  final String localContent;
  final String savedContent;
  final String filePath;
  final bool isDark;
  final VoidCallback onUseLocal;
  final VoidCallback onUseSaved;

  const ConfigConflictDiff({
    super.key,
    required this.localContent,
    required this.savedContent,
    required this.filePath,
    required this.isDark,
    required this.onUseLocal,
    required this.onUseSaved,
  });

  @override
  Widget build(BuildContext context) {
    final localLines = localContent.isEmpty ? ['(empty)'] : localContent.split('\n');
    final savedLines = savedContent.isEmpty ? ['(empty)'] : savedContent.split('\n');
    final localDiff = _diffLineIndices(localLines, savedLines);
    final savedDiff = _diffLineIndices(savedLines, localLines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              S.get('provider_config_preview'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              filePath,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildPanel(
              title: S.get('config_conflict_local_file'),
              lines: localLines,
              diffIndices: localDiff,
              onUse: onUseLocal,
              accentColor: Colors.orange,
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildPanel(
              title: S.get('config_conflict_saved_data'),
              lines: savedLines,
              diffIndices: savedDiff,
              onUse: onUseSaved,
              accentColor: const Color(0xFF5B9BD5),
            )),
          ],
        ),
      ],
    );
  }

  /// LCS 回溯，返回 [lines] 中与 [otherLines] 不同的行索引集合
  static Set<int> _diffLineIndices(List<String> lines, List<String> otherLines) {
    final m = lines.length, n = otherLines.length;
    final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        dp[i][j] = lines[i - 1].trim() == otherLines[j - 1].trim()
            ? dp[i - 1][j - 1] + 1
            : max(dp[i - 1][j], dp[i][j - 1]);
      }
    }
    final matched = <int>{};
    var i = m, j = n;
    while (i > 0 && j > 0) {
      if (lines[i - 1].trim() == otherLines[j - 1].trim()) {
        matched.add(i - 1);
        i--; j--;
      } else if (dp[i - 1][j] >= dp[i][j - 1]) {
        i--;
      } else {
        j--;
      }
    }
    return {for (var k = 0; k < m; k++) if (!matched.contains(k)) k};
  }

  Widget _buildPanel({
    required String title,
    required List<String> lines,
    required Set<int> diffIndices,
    required VoidCallback onUse,
    required Color accentColor,
  }) {
    final bgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F5);
    final normalColor = isDark ? Colors.grey.shade300 : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(8),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < lines.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                      color: diffIndices.contains(i)
                          ? accentColor.withValues(alpha: 0.10)
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Menlo',
                                height: 1.5,
                                color: diffIndices.contains(i)
                                    ? accentColor.withValues(alpha: 0.6)
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              lines[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Menlo',
                                height: 1.5,
                                fontWeight: diffIndices.contains(i)
                                    ? FontWeight.w600 : FontWeight.normal,
                                color: diffIndices.contains(i)
                                    ? accentColor : normalColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onUse,
            icon: Icon(Icons.check_circle_outline, size: 16, color: accentColor),
            label: Text(S.get('config_conflict_use_this')),
            style: OutlinedButton.styleFrom(
              foregroundColor: accentColor,
              side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
}
