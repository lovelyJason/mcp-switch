import 'package:flutter/material.dart';
import '../../l10n/s.dart';
import '../../utils/platform_utils.dart';
import 'custom_toast.dart';

/// Claude CLI PATH 未配置提示 Banner
/// 当检测到 Claude CLI 已安装但 PATH 环境变量未配置时显示
class ClaudePathNotConfiguredBanner extends StatefulWidget {
  final String claudeExePath;
  final VoidCallback? onConfigureComplete;

  const ClaudePathNotConfiguredBanner({
    super.key,
    required this.claudeExePath,
    this.onConfigureComplete,
  });

  @override
  State<ClaudePathNotConfiguredBanner> createState() =>
      _ClaudePathNotConfiguredBannerState();
}

class _ClaudePathNotConfiguredBannerState
    extends State<ClaudePathNotConfiguredBanner> {
  bool _isConfiguring = false;

  Future<void> _handleConfigure() async {
    setState(() => _isConfiguring = true);

    final logs = await PlatformUtils.setupClaudePath(widget.claudeExePath);

    if (!mounted) return;

    setState(() => _isConfiguring = false);

    // 判断是否成功
    final isSuccess = logs.any((log) => log.contains('✅ PATH 已更新'));
    final isAlreadyConfigured = logs.any((log) => log.contains('✅ PATH 已包含'));

    if (isSuccess || isAlreadyConfigured) {
      // 成功 Toast（使用项目统一的 Toast 组件）
      Toast.show(
        context,
        message: isAlreadyConfigured
            ? S.get('claude_path_already_configured')
            : S.get('claude_path_configured_success'),
        type: ToastType.success,
        duration: const Duration(seconds: 3),
      );

      // 通知父组件
      widget.onConfigureComplete?.call();
    } else {
      // 失败 Toast
      final errorMsg = logs.lastWhere(
        (log) => log.contains('❌'),
        orElse: () => S.get('claude_path_configured_failed'),
      );
      Toast.show(
        context,
        message: errorMsg,
        type: ToastType.error,
        duration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final binDir = PlatformUtils.dirname(widget.claudeExePath);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blue.shade900.withValues(alpha: 0.3)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.blue.shade700.withValues(alpha: 0.5)
              : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.get('claude_path_not_configured_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.get('claude_path_not_configured_message'),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '📍 $binDir',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: ElevatedButton.icon(
              onPressed: _isConfiguring ? null : _handleConfigure,
              icon: _isConfiguring
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white70 : Colors.blue,
                      ),
                    )
                  : const Icon(Icons.settings, size: 18),
              label: Text(
                _isConfiguring
                    ? S.get('claude_path_configuring')
                    : S.get('claude_path_configure_button'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}