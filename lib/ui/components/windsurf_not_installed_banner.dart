import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/s.dart';
import '../../utils/platform_utils.dart';
import 'custom_toast.dart';

/// Windsurf 未安装提示 Banner
/// 显示在 Windsurf Tab 顶部，当检测到 Windsurf 未安装时显示
class WindsurfNotInstalledBanner extends StatelessWidget {
  const WindsurfNotInstalledBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const windsurfUrl = 'https://windsurf.com';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.shade900.withValues(alpha: 0.3)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.orange.shade700.withValues(alpha: 0.5)
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.get('windsurf_not_installed_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              S.get('windsurf_not_installed_message'),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => PlatformUtils.openUrl(windsurfUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(S.get('windsurf_install_docs')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
