
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/s.dart';
import 'custom_toast.dart';

class KiroNotInstalledBanner extends StatelessWidget {
  const KiroNotInstalledBanner({super.key});

  Future<void> _launchDocs() async {
    final url = Uri.parse('https://kiro.dev');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _copyUrl(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: 'https://kiro.dev'));
    Toast.show(context, message: 'URL copied', type: ToastType.success);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF9046FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9046FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF9046FF), size: 20),
              const SizedBox(width: 8),
              Text(
                S.get('kiro_not_installed_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: const Color(0xFF9046FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            S.get('kiro_not_installed_message'),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildButton(
                onPressed: _launchDocs,
                icon: Icons.open_in_new,
                label: S.get('kiro_install_docs'),
                isPrimary: true,
              ),
              const SizedBox(width: 12),
              _buildButton(
                onPressed: () => _copyUrl(context),
                icon: Icons.copy,
                label: 'Copy URL',
                isPrimary: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isPrimary,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF9046FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isPrimary ? null : Border.all(color: const Color(0xFF9046FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : const Color(0xFF9046FF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : const Color(0xFF9046FF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
