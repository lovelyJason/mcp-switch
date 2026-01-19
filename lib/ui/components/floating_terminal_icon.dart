import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/terminal_service.dart';

/// 全局悬浮终端图标
/// 需要传入 onTap 回调来打开终端
/// 使用 parentSize 参数传入父容器尺寸以正确限制边界
class FloatingTerminalIcon extends StatefulWidget {
  final VoidCallback onTap;
  final Size? parentSize; // 父容器尺寸，用于边界限制

  const FloatingTerminalIcon({
    super.key,
    required this.onTap,
    this.parentSize,
  });

  @override
  State<FloatingTerminalIcon> createState() => _FloatingTerminalIconState();
}

class _FloatingTerminalIconState extends State<FloatingTerminalIcon> {
  Offset _position = const Offset(20, 200);
  bool _isDragging = false;
  Offset _dragStart = Offset.zero;
  bool _loaded = false;

  // 新的 JSON 存储 key
  static const String _posKey = 'floating_terminal_position';
  // 旧的 key（用于迁移）
  static const String _legacyPosXKey = 'floating_terminal_pos_x';
  static const String _legacyPosYKey = 'floating_terminal_pos_y';

  // 图标尺寸
  static const double _iconSize = 56;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();

    // 先尝试读取新格式 JSON
    final posJson = prefs.getString(_posKey);
    if (posJson != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(posJson);
        final x = (data['x'] as num?)?.toDouble();
        final y = (data['y'] as num?)?.toDouble();
        if (x != null && y != null && mounted) {
          setState(() {
            _position = Offset(x, y);
            _loaded = true;
          });
          return;
        }
      } catch (e) {
        // JSON 解析失败，继续尝试旧格式
      }
    }

    // 兼容旧格式：读取两个 double 值
    final x = prefs.getDouble(_legacyPosXKey);
    final y = prefs.getDouble(_legacyPosYKey);
    if (x != null && y != null && mounted) {
      // 迁移到新格式
      _position = Offset(x, y);
      await _savePosition();
      // 删除旧 key
      await prefs.remove(_legacyPosXKey);
      await prefs.remove(_legacyPosYKey);
      setState(() => _loaded = true);
    } else {
      setState(() => _loaded = true);
    }
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    final posJson = jsonEncode({'x': _position.dx, 'y': _position.dy});
    await prefs.setString(_posKey, posJson);
  }

  /// 限制位置在窗口边界内
  Offset _clampPosition(Offset pos, Size screenSize) {
    // 边距：确保图标完全在窗口内可见
    const double padding = 8.0;

    final double clampedX = pos.dx.clamp(
      padding,  // 左边界
      screenSize.width - _iconSize - padding,  // 右边界
    );
    final double clampedY = pos.dy.clamp(
      padding,  // 顶部边界（留出 macOS 标题栏空间）
      screenSize.height - _iconSize - padding,  // 底部边界
    );

    return Offset(clampedX, clampedY);
  }

  /// 获取有效的容器尺寸
  Size _getContainerSize(BuildContext context) {
    // 优先使用传入的 parentSize
    if (widget.parentSize != null &&
        widget.parentSize!.width > 0 &&
        widget.parentSize!.height > 0) {
      return widget.parentSize!;
    }
    // 否则使用 MediaQuery（可能不准确）
    return MediaQuery.of(context).size;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    // 每次 build 时检查边界（处理窗口尺寸变化的情况）
    final containerSize = _getContainerSize(context);
    final clampedPos = _clampPosition(_position, containerSize);
    if (clampedPos != _position) {
      // 使用 addPostFrameCallback 避免在 build 中调用 setState
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _position = clampedPos);
          _savePosition();
        }
      });
    }

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
                final containerSize = _getContainerSize(context);
                final newPos = details.globalPosition - _dragStart;
                setState(() {
                  _position = _clampPosition(newPos, containerSize);
                });
              }
            },
            onPanEnd: (_) {
              _isDragging = false;
              // 结束时再次确保位置在边界内
              final containerSize = _getContainerSize(context);
              final clampedPos = _clampPosition(_position, containerSize);
              if (clampedPos != _position) {
                setState(() => _position = clampedPos);
              }
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
