import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../l10n/s.dart';

/// AI 模型选项
class AIModelOption {
  final String label;
  final String modelId;
  final Color color;

  const AIModelOption({
    required this.label,
    required this.modelId,
    required this.color,
  });
}

/// 终端 AI 输入弹窗 - 类似 Windsurf 的 Command+I 弹窗
class TerminalAIInputDialog extends StatefulWidget {
  final void Function(String command) onAccept; // 用户接受命令后执行
  final VoidCallback onCancel;
  final String? initialModelId;
  final void Function(String modelId)? onModelChanged;
  final String? apiKey;
  final String? apiBaseUrl;

  const TerminalAIInputDialog({
    super.key,
    required this.onAccept,
    required this.onCancel,
    this.initialModelId,
    this.onModelChanged,
    this.apiKey,
    this.apiBaseUrl,
  });

  /// 可用的 AI 模型列表
  static const List<AIModelOption> availableModels = [
    AIModelOption(
      label: 'Claude Opus 4.5',
      modelId: 'claude-opus-4-5-20251101',
      color: Color(0xFFE87B35), // 橙色
    ),
    AIModelOption(
      label: 'Claude Sonnet 4.5',
      modelId: 'claude-sonnet-4-5-20250929',
      color: Color(0xFF6366F1), // 紫色
    ),
    AIModelOption(
      label: 'Claude Haiku 4.5',
      modelId: 'claude-haiku-4-5-20251001',
      color: Color(0xFF10B981), // 绿色
    ),
  ];

  @override
  State<TerminalAIInputDialog> createState() => _TerminalAIInputDialogState();
}

class _TerminalAIInputDialogState extends State<TerminalAIInputDialog>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late AIModelOption _selectedModel;
  bool _isDropdownOpen = false;
  final GlobalKey _dropdownKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  // AI 响应状态
  bool _isLoading = false;
  String? _aiResponse;
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    if (widget.initialModelId != null) {
      _selectedModel = TerminalAIInputDialog.availableModels.firstWhere(
        (m) => m.modelId == widget.initialModelId,
        orElse: () => TerminalAIInputDialog.availableModels[0],
      );
    } else {
      _selectedModel = TerminalAIInputDialog.availableModels[0];
    }

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _removeOverlay(updateState: false);
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _removeOverlay({bool updateState = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isDropdownOpen = false;
    if (updateState && mounted) {
      setState(() {});
    }
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    final RenderBox? renderBox =
        _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy - 8 - (TerminalAIInputDialog.availableModels.length * 40),
            width: size.width + 40,
            child: Material(
              color: const Color(0xFF3C3C3F),
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: TerminalAIInputDialog.availableModels.map((model) {
                  final isSelected = model.modelId == _selectedModel.modelId;
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedModel = model);
                      widget.onModelChanged?.call(model.modelId);
                      _removeOverlay();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: model.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            model.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Icon(Icons.check, size: 16, color: model.color),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.apiKey == null || widget.apiKey!.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = S.get('api_key_not_configured');
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _aiResponse = null;
      _errorMessage = null;
    });

    try {
      final baseUrl = widget.apiBaseUrl ?? 'https://api.anthropic.com';
      final uri = Uri.parse(_buildApiUrl(baseUrl));

      // 优化的 system prompt：只回答终端相关问题
      final systemPrompt = '''You are a terminal command assistant. You ONLY help with terminal/shell/CLI related questions.

RULES:
1. For terminal/shell/CLI questions: Output ONLY the command, no explanation
2. For NON-terminal questions (programming concepts, general knowledge, etc.): Reply EXACTLY "[NOT_TERMINAL]" with no other text
3. NEVER use markdown
4. Keep response under 50 words

Platform: ${Platform.operatingSystem}''';

      final body = jsonEncode({
        'model': _selectedModel.modelId,
        'max_tokens': 256, // 限制输出长度
        'system': systemPrompt,
        'messages': [
          {'role': 'user', 'content': text}
        ],
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': widget.apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: body,
      );

      if (!mounted) return; // 检查组件是否还在树中

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = data['content'] as List?;
        if (content != null && content.isNotEmpty) {
          final responseText = content[0]['text'] as String? ?? '';
          // 清理 markdown 代码块
          var cleanedResponse = _cleanMarkdown(responseText);
          // 检测非终端问题的拒绝响应，替换为中文提示
          if (cleanedResponse.contains('[NOT_TERMINAL]') ||
              cleanedResponse.toLowerCase().contains('not a terminal') ||
              cleanedResponse.toLowerCase().contains('not terminal-related')) {
            cleanedResponse = S.get('not_terminal_question');
          }
          setState(() {
            _aiResponse = cleanedResponse;
            _isLoading = false;
          });
        }
      } else {
        final errorBody = response.body;
        setState(() {
          _errorMessage = 'API ${response.statusCode}: $errorBody';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 清理 markdown 格式
  String _cleanMarkdown(String text) {
    // 移除 ```bash 或 ``` 代码块
    var cleaned = text.replaceAll(RegExp(r'```\w*\n?'), '');
    cleaned = cleaned.replaceAll('```', '');
    return cleaned.trim();
  }

  String _buildApiUrl(String baseUrl) {
    var url = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (url.endsWith('/v1')) {
      return '$url/messages';
    }
    if (url.contains('/v1/')) {
      return url.endsWith('/messages') ? url : '$url/messages';
    }
    return '$url/v1/messages';
  }

  /// 判断 AI 回复是否看起来像可执行的命令
  /// 命令通常是单行或少数几行，且不包含大段解释文字
  bool _isLikelyCommand(String text) {
    // 拒绝响应不是命令
    if (text == S.get('not_terminal_question')) return false;
    final lines = text.trim().split('\n');
    // 超过 3 行大概率不是命令
    if (lines.length > 3) return false;
    // 包含中文句子（非命令参数）大概率是解释
    final hasChineseExplanation = RegExp(r'[\u4e00-\u9fa5]{4,}').hasMatch(text) &&
        !text.startsWith('echo') && !text.contains('grep');
    if (hasChineseExplanation) return false;
    // 包含问号或以问号结尾大概率是提问
    if (text.contains('？') || text.contains('?')) return false;
    return true;
  }

  void _accept() {
    if (_aiResponse != null) {
      widget.onAccept(_aiResponse!);
    }
  }

  /// 复制到剪贴板
  void _copyToClipboard() {
    if (_aiResponse != null) {
      Clipboard.setData(ClipboardData(text: _aiResponse!));
    }
    widget.onCancel(); // 关闭弹窗
  }

  void _cancel() async {
    await _animationController.reverse();
    widget.onCancel();
  }

  void _retry() {
    setState(() {
      _aiResponse = null;
      _errorMessage = null;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _cancel();
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 输入框区域
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.enter) {
                              final pressedKeys = HardwareKeyboard.instance.logicalKeysPressed;
                              final isShiftPressed = pressedKeys.contains(LogicalKeyboardKey.shiftLeft) ||
                                  pressedKeys.contains(LogicalKeyboardKey.shiftRight);
                              final isCtrlPressed = pressedKeys.contains(LogicalKeyboardKey.controlLeft) ||
                                  pressedKeys.contains(LogicalKeyboardKey.controlRight);
                              final isMetaPressed = pressedKeys.contains(LogicalKeyboardKey.metaLeft) ||
                                  pressedKeys.contains(LogicalKeyboardKey.metaRight);

                              if (!isShiftPressed && !isCtrlPressed && !isMetaPressed) {
                                _submit();
                                return KeyEventResult.handled;
                              }
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: !_isLoading && _aiResponse == null,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            maxLines: 5,
                            minLines: 1,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: S.get('terminal_ai_input_hint'),
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // AI 响应区域
                if (_isLoading)
                  _buildLoadingIndicator(),
                if (_aiResponse != null)
                  _buildResponseSection(),
                if (_errorMessage != null)
                  _buildErrorSection(),

                // 底部工具栏
                _buildBottomToolbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _selectedModel.color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${S.get('ai_thinking')}...',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: _selectedModel.color),
              const SizedBox(width: 6),
              Text(
                S.get('ai_response'),
                style: TextStyle(
                  color: _selectedModel.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _selectedModel.color.withValues(alpha: 0.3)),
            ),
            child: SelectableText(
              _aiResponse!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontFamily: 'Menlo',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          // 模型选择下拉（仅在未加载且无响应时显示）
          if (!_isLoading && _aiResponse == null)
            _buildModelSelector(),
          const Spacer(),

          // 根据状态显示不同按钮
          if (_aiResponse != null) ...[
            // 重试按钮
            TextButton(
              onPressed: _retry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh, size: 14),
                  const SizedBox(width: 4),
                  Text(S.get('retry'), style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 根据回复内容决定显示「执行」还是「复制」
            if (_isLikelyCommand(_aiResponse!)) ...[
              // 执行按钮
              ElevatedButton(
                onPressed: _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedModel.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(S.get('accept'), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.play_arrow, size: 14),
                  ],
                ),
              ),
            ] else ...[
              // 复制按钮（多行文本不适合执行）
              ElevatedButton(
                onPressed: _copyToClipboard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(S.get('copy'), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy, size: 14),
                  ],
                ),
              ),
            ],
          ] else ...[
            // 取消按钮
            TextButton(
              onPressed: _cancel,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.get('cancel'), style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('Esc', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 发送按钮
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedModel.color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _selectedModel.color.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(S.get('send'), style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.send, size: 14),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelSelector() {
    return GestureDetector(
      key: _dropdownKey,
      onTap: _toggleDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isDropdownOpen ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _selectedModel.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedModel.label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(width: 6),
            Icon(
              _isDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
