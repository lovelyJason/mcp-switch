import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';
import '../../l10n/s.dart';
import 'custom_toast.dart';

/// 首页更新横幅：当检测到新版本时显示
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  bool _dismissed = false;
  bool _isUpdating = false;

  Future<void> _onUpdate() async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);

    final service = Provider.of<UpdateService>(context, listen: false);

    try {
      final update = await service.checkForUpdates();
      if (!mounted) return;

      if (update == null) {
        Toast.show(context,
            message: S.get('current_latest'), type: ToastType.success);
        setState(() => _isUpdating = false);
        return;
      }

      if (update.supportsAutoUpdate) {
        _startAutoUpdate(service, update.downloadUrl!);
      } else {
        launchUrl(Uri.parse(update.releaseUrl));
        setState(() => _isUpdating = false);
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context,
            message: '${S.get("update_failed")}: $e', type: ToastType.error);
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _startAutoUpdate(UpdateService service, String zipUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: Consumer<UpdateService>(
          builder: (ctx, svc, _) => _UpdateProgressContent(
            phase: svc.phase,
            progress: svc.progress,
          ),
        ),
      ),
    );

    try {
      await service.performAutoUpdate(zipUrl);
    } catch (e) {
      service.resetPhase();
      if (mounted) {
        Navigator.of(context).pop();
        Toast.show(context,
            message: '${S.get("update_failed")}: $e', type: ToastType.error);
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Consumer<UpdateService>(
      builder: (context, service, _) {
        if (!service.hasUpdate) return const SizedBox.shrink();

        final update = service.availableUpdate!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.25),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.system_update_alt,
                  size: 16,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.get('update_banner_text')
                        .replaceAll('{version}', update.version),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _BannerButton(
                  label: S.get('update_banner_update'),
                  isLoading: _isUpdating,
                  onTap: _onUpdate,
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _dismissed = true),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  const _BannerButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(6),
        ),
        child: isLoading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }
}

/// 更新进度弹窗内容（复用于横幅触发的更新流程）
class _UpdateProgressContent extends StatelessWidget {
  final UpdatePhase phase;
  final double progress;

  const _UpdateProgressContent({
    required this.phase,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: phase == UpdatePhase.downloading
                            ? progress
                            : null,
                        strokeWidth: 4,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.orange.shade600,
                        ),
                      ),
                    ),
                    if (phase == UpdatePhase.downloading)
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade600,
                        ),
                      )
                    else
                      Icon(
                        _phaseIcon(phase),
                        size: 28,
                        color: Colors.orange.shade600,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _phaseText(phase),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _phaseIcon(UpdatePhase p) {
    switch (p) {
      case UpdatePhase.checking:
        return Icons.search;
      case UpdatePhase.downloading:
        return Icons.download;
      case UpdatePhase.extracting:
        return Icons.unarchive_outlined;
      case UpdatePhase.restarting:
        return Icons.restart_alt;
      case UpdatePhase.error:
        return Icons.error_outline;
      case UpdatePhase.idle:
        return Icons.check_circle_outline;
    }
  }

  String _phaseText(UpdatePhase p) {
    switch (p) {
      case UpdatePhase.checking:
        return S.get('update_preparing');
      case UpdatePhase.downloading:
        return S.get('update_downloading_progress')
            .replaceAll('{percent}', '${(progress * 100).toInt()}');
      case UpdatePhase.extracting:
        return S.get('update_extracting');
      case UpdatePhase.restarting:
        return S.get('update_restarting');
      case UpdatePhase.error:
        return S.get('update_failed');
      case UpdatePhase.idle:
        return S.get('current_latest');
    }
  }
}
