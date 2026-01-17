import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/ai_chat_service.dart';
import '../../services/config_service.dart';

/// 全局悬浮 AI Chatbot 图标
class FloatingChatbotIcon extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingChatbotIcon({
    super.key,
    required this.onTap,
  });

  @override
  State<FloatingChatbotIcon> createState() => _FloatingChatbotIconState();
}

class _FloatingChatbotIconState extends State<FloatingChatbotIcon>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 280);
  bool _isDragging = false;
  Offset _dragStart = Offset.zero;
  bool _loaded = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const String _posXKey = 'floating_chatbot_pos_x';
  static const String _posYKey = 'floating_chatbot_pos_y';

  @override
  void initState() {
    super.initState();
    _loadPosition();

    // 脉冲动画
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_posXKey);
    final y = prefs.getDouble(_posYKey);
    if (x != null && y != null && mounted) {
      setState(() {
        _position = Offset(x, y);
        _loaded = true;
      });
    } else {
      setState(() => _loaded = true);
    }
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_posXKey, _position.dx);
    await prefs.setDouble(_posYKey, _position.dy);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Consumer2<AiChatService, ConfigService>(
      builder: (context, aiService, configService, _) {
        // 如果用户关闭了图标显示，或者面板打开时隐藏图标
        if (!configService.showChatbotIcon || aiService.isPanelOpen) {
          return const SizedBox.shrink();
        }

        // 如果没有配置 API Key，显示提示状态
        final hasApiKey = configService.claudeApiKey?.isNotEmpty == true;

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: (details) {
              _isDragging = true;
              _dragStart = details.globalPosition - _position;
            },
            onPanUpdate: (details) {
              if (_isDragging) {
                setState(() {
                  _position = details.globalPosition - _dragStart;
                });
              }
            },
            onPanEnd: (_) {
              _isDragging = false;
              _savePosition();
            },
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: hasApiKey ? 1.0 : _pulseAnimation.value,
                  child: child,
                );
              },
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(28),
                color: const Color(0xFF1E1E1E),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: hasApiKey ? Colors.deepPurple : Colors.orange,
                      width: 2,
                    ),
                    gradient: hasApiKey
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.deepPurple.shade900,
                              const Color(0xFF1E1E1E),
                            ],
                          )
                        : null,
                  ),
                  child: Stack(
                    children: [
                      // AI 图标
                      Center(
                        child: Icon(
                          Icons.auto_awesome,
                          color: hasApiKey ? Colors.deepPurple.shade200 : Colors.orange,
                          size: 26,
                        ),
                      ),
                      // 未配置提示
                      if (!hasApiKey)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.priority_high,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      // 关闭按钮
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            configService.setShowChatbotIcon(false);
                          },
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
