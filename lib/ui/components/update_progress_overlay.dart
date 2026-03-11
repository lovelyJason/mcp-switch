import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/update_service.dart';
import '../../l10n/s.dart';

class UpdateProgressOverlay extends StatelessWidget {
  /// 是否为调试模式（模拟进度，不依赖 UpdateService）
  final bool isDemo;

  const UpdateProgressOverlay({super.key, this.isDemo = false});

  /// 在当前 context 的 Overlay 上显示更新进度遮罩
  static OverlayEntry show(BuildContext context) {
    final entry = OverlayEntry(
      builder: (_) => const UpdateProgressOverlay(),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  /// 显示调试演示版本
  static void showDemo(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => const UpdateProgressOverlay(isDemo: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDemo) {
      return _DemoOverlay();
    }
    return _RealOverlay();
  }
}

class _RealOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, service, _) {
        return _OverlayContent(
          phase: service.phase,
          progress: service.progress,
          dismissible: false,
        );
      },
    );
  }
}

class _DemoOverlay extends StatefulWidget {
  @override
  State<_DemoOverlay> createState() => _DemoOverlayState();
}

class _DemoOverlayState extends State<_DemoOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final v = _controller.value;
        UpdatePhase phase;
        double progress;
        if (v < 0.1) {
          phase = UpdatePhase.checking;
          progress = 0;
        } else if (v < 0.7) {
          phase = UpdatePhase.downloading;
          progress = (v - 0.1) / 0.6;
        } else if (v < 0.9) {
          phase = UpdatePhase.extracting;
          progress = 1.0;
        } else {
          phase = UpdatePhase.restarting;
          progress = 1.0;
        }
        return _OverlayContent(
          phase: phase,
          progress: progress,
          dismissible: true,
        );
      },
    );
  }
}

class _OverlayContent extends StatelessWidget {
  final UpdatePhase phase;
  final double progress;
  final bool dismissible;

  const _OverlayContent({
    required this.phase,
    required this.progress,
    required this.dismissible,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Center(
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
                _phaseText(phase, progress),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _phaseSubtext(phase),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              if (dismissible) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _phaseIcon(UpdatePhase phase) {
    switch (phase) {
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

  String _phaseText(UpdatePhase phase, double progress) {
    switch (phase) {
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

  String _phaseSubtext(UpdatePhase phase) {
    switch (phase) {
      case UpdatePhase.checking:
        return 'Connecting to GitHub...';
      case UpdatePhase.downloading:
        return 'Please do not close the app';
      case UpdatePhase.extracting:
        return 'Almost done...';
      case UpdatePhase.restarting:
        return 'App will restart shortly';
      case UpdatePhase.error:
        return 'Please try again later';
      case UpdatePhase.idle:
        return '';
    }
  }
}
