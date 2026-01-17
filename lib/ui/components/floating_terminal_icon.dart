import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/terminal_service.dart';

/// 全局悬浮终端图标
/// 需要传入 onTap 回调来打开终端
class FloatingTerminalIcon extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingTerminalIcon({
    super.key,
    required this.onTap,
  });

  @override
  State<FloatingTerminalIcon> createState() => _FloatingTerminalIconState();
}

class _FloatingTerminalIconState extends State<FloatingTerminalIcon> {
  Offset _position = const Offset(20, 200);
  bool _isDragging = false;
  Offset _dragStart = Offset.zero;
  bool _loaded = false;

  static const String _posXKey = 'floating_terminal_pos_x';
  static const String _posYKey = 'floating_terminal_pos_y';

  @override
  void initState() {
    super.initState();
    _loadPosition();
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

    return Consumer<TerminalService>(
      builder: (context, terminalService, _) {
        if (!terminalService.shouldShowFloatingIcon) {
          return const SizedBox.shrink();
        }

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
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(28),
              color: const Color(0xFF1E1E1E),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Stack(
                  children: [
                    // 终端图标
                    Center(
                      child: Icon(
                        Icons.terminal,
                        color: Colors.orange,
                        size: 28,
                      ),
                    ),
                    // 关闭按钮
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          terminalService.setFloatingTerminal(false);
                        },
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 12,
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
        );
      },
    );
  }
}
