import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../l10n/s.dart';
import '../../main.dart' show globalNavigatorKey;
import '../../models/chat_message.dart';
import '../../services/ai_chat_service.dart';
import '../../services/config_service.dart';
import '../settings_screen.dart';
import 'custom_toast.dart';

/// 全局 AI 聊天面板 - 侧边滑出样式
class GlobalChatbotPanel extends StatefulWidget {
  final VoidCallback onClose;

  const GlobalChatbotPanel({super.key, required this.onClose});

  @override
  State<GlobalChatbotPanel> createState() => _GlobalChatbotPanelState();
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
    _animationController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _animationController.reverse();
    widget.onClose();
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final aiService = context.read<AiChatService>();
    aiService.sendMessage(text);
    _inputController.clear();
    _focusNode.requestFocus();

    // reverse ListView 中，0 是最新消息（视觉底部），所以滚动到 0
    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollToTop(); // 实际上是滚到视觉底部
    });
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
                      ? SelectableText(
                          message.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        )
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
      child: Row(
        children: [
          Expanded(
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
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade800),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.deepPurple),
                ),
              ),
              maxLines: 3,
              minLines: 1,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Consumer<AiChatService>(
            builder: (context, aiService, _) {
              return IconButton(
                onPressed: hasApiKey && !aiService.isLoading ? _sendMessage : null,
                icon: aiService.isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepPurple.shade300,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: hasApiKey
                            ? Colors.deepPurple.shade300
                            : Colors.grey.shade600,
                      ),
                style: IconButton.styleFrom(
                  backgroundColor: hasApiKey
                      ? Colors.deepPurple.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
        ],
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
