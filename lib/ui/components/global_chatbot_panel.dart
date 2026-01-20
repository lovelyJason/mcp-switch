import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import '../../l10n/s.dart';
import '../../utils/global_keys.dart';
import '../../models/chat_message.dart';
import '../../services/ai_chat_service.dart';
import '../../services/config_service.dart';
import '../pages/settings/settings_screen.dart';
import 'custom_toast.dart';

/// 全局 AI 聊天面板 - 侧边滑出样式
class GlobalChatbotPanel extends StatefulWidget {
  final VoidCallback onClose;

  const GlobalChatbotPanel({super.key, required this.onClose});

  @override
  State<GlobalChatbotPanel> createState() => _GlobalChatbotPanelState();
}

/// AI 模型选项
class _AIModelOption {
  final String label;
  final String modelId;
  final Color color;

  const _AIModelOption({
    required this.label,
    required this.modelId,
    required this.color,
  });

  static const List<_AIModelOption> availableModels = [
    _AIModelOption(
      label: 'Opus 4.5',
      modelId: 'claude-opus-4-5-20251101',
      color: Color(0xFFE87B35), // 橙色
    ),
    _AIModelOption(
      label: 'Sonnet 4.5',
      modelId: 'claude-sonnet-4-5-20250929',
      color: Color(0xFF6366F1), // 紫色
    ),
    _AIModelOption(
      label: 'Haiku 4.5',
      modelId: 'claude-haiku-4-5-20251001',
      color: Color(0xFF10B981), // 绿色
    ),
  ];
}

class _GlobalChatbotPanelState extends State<GlobalChatbotPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // 记录展开的工具调用 ID
  final Set<String> _expandedToolCalls = {};

  // 待发送的图片列表
  final List<ChatImage> _pendingImages = [];

  // 模型选择器状态
  bool _isModelDropdownOpen = false;
  final GlobalKey _modelDropdownKey = GlobalKey();
  OverlayEntry? _modelOverlayEntry;

  // 加号菜单状态
  bool _isAddMenuOpen = false;
  final GlobalKey _addMenuKey = GlobalKey();
  OverlayEntry? _addMenuOverlayEntry;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  /// 滚动到顶部（因为是 reverse ListView，顶部就是最新消息）
  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _removeModelOverlay(updateState: false);
    _removeAddMenuOverlay(updateState: false);
    _animationController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    _removeModelOverlay(updateState: false);
    _removeAddMenuOverlay(updateState: false);
    await _animationController.reverse();
    widget.onClose();
  }

  // 加号菜单相关方法
  void _removeAddMenuOverlay({bool updateState = true}) {
    _addMenuOverlayEntry?.remove();
    _addMenuOverlayEntry = null;
    _isAddMenuOpen = false;
    if (updateState && mounted) {
      setState(() {});
    }
  }

  void _toggleAddMenu() {
    if (_isAddMenuOpen) {
      _removeAddMenuOverlay();
    } else {
      _showAddMenu();
    }
  }

  void _showAddMenu() {
    final RenderBox? renderBox =
        _addMenuKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);

    _addMenuOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeAddMenuOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy - 8 - 44, // 菜单高度约 44
            width: 120,
            child: Material(
              color: const Color(0xFF3C3C3F),
              elevation: 8,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () {
                  _removeAddMenuOverlay();
                  _pickImage();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        S.get('add_image'),
                        style: TextStyle(
                          color: Colors.grey.shade200,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_addMenuOverlayEntry!);
    setState(() => _isAddMenuOpen = true);
  }

  // 模型选择器相关方法
  void _removeModelOverlay({bool updateState = true}) {
    _modelOverlayEntry?.remove();
    _modelOverlayEntry = null;
    _isModelDropdownOpen = false;
    if (updateState && mounted) {
      setState(() {});
    }
  }

  void _toggleModelDropdown() {
    if (_isModelDropdownOpen) {
      _removeModelOverlay();
    } else {
      _showModelDropdown();
    }
  }

  void _showModelDropdown() {
    final configService = context.read<ConfigService>();
    final RenderBox? renderBox =
        _modelDropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _modelOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeModelOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy - 8 - (_AIModelOption.availableModels.length * 36),
            width: size.width + 20,
            child: Material(
              color: const Color(0xFF3C3C3F),
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _AIModelOption.availableModels.map((model) {
                  final isSelected = model.modelId == configService.chatAiModelId;
                  return InkWell(
                    onTap: () {
                      configService.setChatAiModelId(model.modelId);
                      _removeModelOverlay();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
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
                          const SizedBox(width: 8),
                          Text(
                            model.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (isSelected) ...[
                            const Spacer(),
                            Icon(Icons.check, size: 14, color: model.color),
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

    Overlay.of(context).insert(_modelOverlayEntry!);
    setState(() => _isModelDropdownOpen = true);
  }

  _AIModelOption _getSelectedModel(String modelId) {
    return _AIModelOption.availableModels.firstWhere(
      (m) => m.modelId == modelId,
      orElse: () => _AIModelOption.availableModels[1], // 默认 Sonnet
    );
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    // 如果没有文字也没有图片，不发送
    if (text.isEmpty && _pendingImages.isEmpty) return;

    final aiService = context.read<AiChatService>();
    final configService = context.read<ConfigService>();
    // 发送消息（带图片和模型选择）
    aiService.sendMessage(
      text,
      images: _pendingImages.isNotEmpty ? List.from(_pendingImages) : null,
      modelId: configService.chatAiModelId,
    );
    _inputController.clear();
    setState(() {
      _pendingImages.clear();
    });
    _focusNode.requestFocus();

    // reverse ListView 中，0 是最新消息（视觉底部），所以滚动到 0
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToTop(); // 实际上是滚到视觉底部
    });
  }

  /// 从剪贴板粘贴图片
  Future<void> _pasteImage() async {
    try {
      final imageBytes = await Pasteboard.image;
      if (imageBytes != null && imageBytes.isNotEmpty) {
        _addImageFromBytes(imageBytes, 'image/png');
      }
    } catch (e) {
      debugPrint('粘贴图片失败: $e');
    }
  }

  /// 选择图片文件
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            final bytes = await File(file.path!).readAsBytes();
            final mediaType = _getMediaType(file.extension ?? 'png');
            _addImageFromBytes(bytes, mediaType);
          }
        }
      }
    } catch (e) {
      debugPrint('选择图片失败: $e');
    }
  }

  /// 从字节数据添加图片
  void _addImageFromBytes(Uint8List bytes, String mediaType) {
    // 限制最多 5 张图片
    if (_pendingImages.length >= 5) {
      Toast.show(
        context,
        message: S.get('max_images_reached'),
        type: ToastType.warning,
      );
      return;
    }

    final base64Data = base64Encode(bytes);
    setState(() {
      _pendingImages.add(ChatImage(
        base64Data: base64Data,
        mediaType: mediaType,
      ));
    });
  }

  /// 移除待发送图片
  void _removeImage(int index) {
    setState(() {
      _pendingImages.removeAt(index);
    });
  }

  /// 获取图片 MIME 类型
  String _getMediaType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final configService = context.watch<ConfigService>();
    final hasApiKey = configService.claudeApiKey?.isNotEmpty == true;

    return Stack(
      children: [
        // 半透明背景遮罩
        GestureDetector(
          onTap: _close,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Container(
              color: Colors.black.withOpacity(0.3 * _animationController.value),
            ),
          ),
        ),
        // 聊天面板
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 450,
          child: SlideTransition(
            position: _slideAnimation,
            child: Material(
              elevation: 16,
              child: Container(
                color: const Color(0xFF1E1E1E),
                child: Column(
                  children: [
                    _buildHeader(),
                    if (!hasApiKey) _buildApiKeyWarning(),
                    Expanded(child: _buildMessageList()),
                    _buildInputArea(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFF252526),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            S.get('chatbot'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          // 清空按钮
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white70),
            tooltip: S.get('clear_chat'),
            onPressed: () async {
              final aiService = context.read<AiChatService>();
              await aiService.clearHistory();
            },
          ),
          // 导出按钮
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 18, color: Colors.white70),
            tooltip: S.get('export_chat'),
            onPressed: () async {
              final aiService = context.read<AiChatService>();
              final content = await aiService.exportHistory();
              await Clipboard.setData(ClipboardData(text: content));
              if (mounted) {
                Toast.show(
                  context,
                  message: S.get('copied'),
                  type: ToastType.success,
                );
              }
            },
          ),
          // 关闭按钮
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white70),
            onPressed: _close,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyWarning() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.get('claude_api_key_required'),
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              // 跳转到设置页面 - 使用全局 Navigator Key 因为我们在 Overlay 中
              _close();
              globalNavigatorKey.currentState?.push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(S.get('settings'), style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<AiChatService>(
      builder: (context, aiService, _) {
        final messages = aiService.messages;
        final streamingContent = aiService.streamingContent;

        if (messages.isEmpty && !aiService.isLoading) {
          return _buildEmptyState();
        }

        // 流式输出时滚动到顶部（reverse ListView 中顶部是最新消息）
        if (aiService.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToTop();
          });
        }

        // 构建显示列表：reverse ListView，所以要反转顺序
        // 最新的消息在列表开头（显示在底部）
        final displayMessages = messages.reversed.toList();
        final itemCount = displayMessages.length + (aiService.isLoading ? 1 : 0);

        return ListView.builder(
          key: const PageStorageKey('chatbot_messages'),
          controller: _scrollController,
          reverse: true, // 关键！从底部开始布局
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // index 0 是最底部的内容
            if (aiService.isLoading && index == 0) {
              // 流式输出中，显示正在生成的消息（在最底部）
              return _buildStreamingMessage(streamingContent);
            }
            // 调整索引（如果有流式消息，其他消息索引要减1）
            final msgIndex = aiService.isLoading ? index - 1 : index;
            return _buildMessageBubble(displayMessages[msgIndex]);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            S.get('chatbot_welcome'),
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.get('chatbot_hint'),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingMessage(String streamingContent) {
    // 流式内容正在生成，显示实时内容
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: streamingContent.isEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.deepPurple.shade300,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              S.get('thinking'),
                              style: TextStyle(
                                color: Colors.deepPurple.shade200,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        )
                      : MarkdownBody(
                          data: streamingContent,
                          selectable: false,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            h1: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            code: TextStyle(
                              backgroundColor: Colors.black38,
                              color: Colors.green.shade300,
                              fontSize: 12,
                              fontFamily: 'Menlo',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            tableBorder: TableBorder.all(
                              color: Colors.grey.shade600,
                              width: 1,
                            ),
                            tableHead: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            tableBody: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            tableCellsPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            listBullet: const TextStyle(color: Colors.white),
                            strong: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            em: const TextStyle(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                ),
                // 显示打字光标动画
                if (streamingContent.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 2),
                    child: SizedBox(
                      width: 8,
                      height: 14,
                      child: _TypingCursor(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade700],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 用户消息：显示图片（如果有）
                if (isUser && message.hasImages)
                  _buildMessageImages(message.images!),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Colors.blue.shade700
                        : Colors.grey.shade800,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(isUser ? 12 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 12),
                    ),
                  ),
                  child: isUser
                      ? (message.content.isEmpty
                          ? Text(
                              S.get('image_message'),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : SelectableText(
                              message.content,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ))
                      : MarkdownBody(
                          data: message.content,
                          selectable: true,
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            h1: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            h2: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            h3: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            code: TextStyle(
                              backgroundColor: Colors.black38,
                              color: Colors.green.shade300,
                              fontSize: 12,
                              fontFamily: 'Menlo',
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.black38,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            tableBorder: TableBorder.all(
                              color: Colors.grey.shade600,
                              width: 1,
                            ),
                            tableHead: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            tableBody: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                            tableCellsPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            listBullet: const TextStyle(color: Colors.white),
                            strong: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            em: const TextStyle(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                ),
                // 显示工具调用信息
                if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
                  _buildToolCallsInfo(message.toolCalls!),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/cat.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolCallsInfo(List<ToolCall> toolCalls) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: toolCalls.map((tc) {
          final statusIcon = switch (tc.status) {
            ToolCallStatus.pending => Icons.hourglass_empty,
            ToolCallStatus.executing => Icons.sync,
            ToolCallStatus.completed => Icons.check_circle,
            ToolCallStatus.failed => Icons.error,
          };
          final statusColor = switch (tc.status) {
            ToolCallStatus.pending => Colors.grey,
            ToolCallStatus.executing => Colors.orange,
            ToolCallStatus.completed => Colors.green,
            ToolCallStatus.failed => Colors.red,
          };

          final isExpanded = _expandedToolCalls.contains(tc.id);
          final hasResult = tc.result != null && tc.result!.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 工具调用头部（可点击展开/收起）
              GestureDetector(
                onTap: hasResult
                    ? () {
                        setState(() {
                          if (isExpanded) {
                            _expandedToolCalls.remove(tc.id);
                          } else {
                            _expandedToolCalls.add(tc.id);
                          }
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        tc.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontFamily: 'Menlo',
                        ),
                      ),
                      if (hasResult) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 14,
                          color: statusColor,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 展开后显示命令输出
              if (isExpanded && hasResult)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(maxWidth: 380),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade700),
                  ),
                  child: MarkdownBody(
                    data: tc.result!,
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 11,
                        height: 1.3,
                        fontFamily: 'Menlo',
                      ),
                      code: TextStyle(
                        backgroundColor: Colors.transparent,
                        color: Colors.green.shade300,
                        fontSize: 11,
                        fontFamily: 'Menlo',
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputArea() {
    final configService = context.watch<ConfigService>();
    final hasApiKey = configService.claudeApiKey?.isNotEmpty == true;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF252526),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 待发送图片预览
          if (_pendingImages.isNotEmpty) _buildPendingImages(),
          // 输入框容器 - 内嵌工具栏
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 输入框
                KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) async {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.keyV &&
                        (HardwareKeyboard.instance.isMetaPressed ||
                            HardwareKeyboard.instance.isControlPressed)) {
                      await _pasteImage();
                    }
                  },
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    enabled: hasApiKey,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: hasApiKey
                          ? S.get('chatbot_placeholder')
                          : S.get('claude_api_key_required'),
                      hintStyle: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    maxLines: 4,
                    minLines: 2,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                // 内嵌工具栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Row(
                    children: [
                      // 加号按钮 - 上拉菜单
                      _buildAddMenu(hasApiKey),
                      const SizedBox(width: 8),
                      // 模型选择器
                      _buildModelSelector(configService),
                      const Spacer(),
                      // 发送按钮
                      Consumer<AiChatService>(
                        builder: (context, aiService, _) {
                          final canSend = hasApiKey &&
                              !aiService.isLoading &&
                              (_inputController.text.trim().isNotEmpty ||
                                  _pendingImages.isNotEmpty);
                          return _buildInlineSendButton(aiService.isLoading, canSend);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建加号上拉菜单
  Widget _buildAddMenu(bool enabled) {
    return GestureDetector(
      key: _addMenuKey,
      onTap: enabled ? _toggleAddMenu : null,
      child: Icon(
        Icons.add_circle_outline,
        size: 20,
        color: enabled ? Colors.grey.shade500 : Colors.grey.shade700,
      ),
    );
  }

  Widget _buildInlineSendButton(bool isLoading, bool canSend) {
    return GestureDetector(
      onTap: canSend ? _sendMessage : null,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: canSend ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.grey.shade400,
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                size: 18,
                color: canSend ? Colors.white : Colors.grey.shade600,
              ),
      ),
    );
  }

  /// 构建待发送图片预览
  Widget _buildPendingImages() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _pendingImages.length,
        itemBuilder: (context, index) {
          final img = _pendingImages[index];
          final bytes = base64Decode(img.base64Data);
          return Container(
            margin: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                // 删除按钮
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 构建消息中的图片显示
  Widget _buildMessageImages(List<ChatImage> images) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.end,
        children: images.map((img) {
          final bytes = base64Decode(img.base64Data);
          return GestureDetector(
            onTap: () => _showImageDialog(bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 显示图片大图弹窗
  void _showImageDialog(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 图片
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
              ),
            ),
            // 关闭按钮
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建模型选择器
  Widget _buildModelSelector(ConfigService configService) {
    final selectedModel = _getSelectedModel(configService.chatAiModelId);
    return GestureDetector(
      key: _modelDropdownKey,
      onTap: _toggleModelDropdown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _isModelDropdownOpen ? Colors.white10 : Colors.transparent,
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
                color: selectedModel.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              selectedModel.label,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(width: 4),
            Icon(
              _isModelDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

/// 打字光标动画组件
class _TypingCursor extends StatefulWidget {
  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
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
      builder: (context, child) {
        return Container(
          width: 2,
          height: 14,
          color: Colors.deepPurple.shade300.withOpacity(_controller.value),
        );
      },
    );
  }
}
