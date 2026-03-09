import 'package:flutter/material.dart';

import '../../../../l10n/s.dart';
import '../../../../models/permission_request.dart';

class PendingRequestCard extends StatefulWidget {
  const PendingRequestCard({
    super.key,
    required this.request,
    required this.onAllow,
    required this.onAllowSession,
    required this.onDeny,
    this.onAnswer,
  });

  final PermissionRequest request;
  final VoidCallback onAllow;
  final VoidCallback onAllowSession;
  final VoidCallback onDeny;
  /// 当所有 question 都回答完后调用，参数为最终答案字符串（换行拼接）
  final void Function(String answer)? onAnswer;

  @override
  State<PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<PendingRequestCard> {
  /// 当前正在显示的 question 索引
  int _currentQuestionIndex = 0;

  /// 每个问题对应的 Other 输入框 controller（index → controller）
  final Map<int, TextEditingController> _otherControllers = {};

  /// 每个问题是否展开 Other 输入框
  final Map<int, bool> _showOther = {};

  PermissionRequest get request => widget.request;

  bool get _isResolved => request.decision != PermissionDecision.pending;
  bool get _isAllowed => request.decision == PermissionDecision.allow;
  bool get _isAllowedSession => request.decision == PermissionDecision.allowSession;
  bool get _isExternallyHandled => request.decision == PermissionDecision.externallyHandled;

  @override
  void didUpdateWidget(PendingRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _currentQuestionIndex = 0;
      _disposeControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _otherControllers.values) {
      c.dispose();
    }
    _otherControllers.clear();
    _showOther.clear();
  }

  TextEditingController _otherController(int idx) {
    return _otherControllers.putIfAbsent(idx, () => TextEditingController());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedOpacity(
      opacity: _isResolved ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: _isResolved ? 0 : 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              if (request.commandSummary.isNotEmpty) ...[
                const SizedBox(height: 6),
                _buildCommandPreview(context, isDark),
              ],
              const SizedBox(height: 10),
              if (_isResolved)
                _buildResolvedBadge(isDark)
              else if (request.isAskFollowup && request.askQuestions.isNotEmpty)
                _buildQuestionSection(context, isDark)
              else
                _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Text(
          _toolEmoji(request.toolName),
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 6),
        Text(
          request.toolName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            request.projectName,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          _timeAgo(request.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Widget _buildCommandPreview(BuildContext context, bool isDark) {
    final summary = request.commandSummary;
    final isLong = summary.length > 120;

    return GestureDetector(
      onTap: isLong
          ? () => _showFullContentDialog(context, isDark, summary)
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
          border: isLong
              ? Border.all(
                  color: (isDark ? Colors.orange.shade700 : Colors.orange.shade300)
                      .withValues(alpha: 0.5),
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
              maxLines: request.isAskFollowup ? 10 : 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (isLong) ...[
              const SizedBox(height: 4),
              Text(
                '点击查看完整内容 ↕',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.orange.shade400 : Colors.orange.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showFullContentDialog(BuildContext context, bool isDark, String content) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Text(
                _toolEmoji(request.toolName),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.toolName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.grey[200] : Colors.grey[900],
                  height: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: widget.onDeny,
          icon: const Icon(Icons.close, size: 14),
          label: Text(S.get('remote_claw_deny')),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: widget.onAllowSession,
          icon: const Icon(Icons.done_all, size: 14),
          label: Text(S.get('remote_claw_allow_session')),
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: widget.onAllow,
          icon: const Icon(Icons.check, size: 14),
          label: Text(S.get('remote_claw_allow')),
          style: TextButton.styleFrom(
            foregroundColor: Colors.green,
            textStyle: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// AskUserQuestion 的分步问题区域
  Widget _buildQuestionSection(BuildContext context, bool isDark) {
    final questions = request.askQuestions;
    final totalCount = questions.length;
    final idx = _currentQuestionIndex.clamp(0, totalCount - 1);
    final currentQ = questions[idx];
    final currentAnswer = request.questionAnswers.length > idx
        ? request.questionAnswers[idx]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 多问题时显示进度 + 返回按钮
        if (totalCount > 1) ...[
          Row(
            children: [
              if (idx > 0)
                GestureDetector(
                  onTap: () => setState(() => _currentQuestionIndex = idx - 1),
                  child: Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              if (idx > 0) const SizedBox(width: 4),
              Icon(Icons.quiz_outlined, size: 12,
                  color: isDark ? Colors.orange.shade300 : Colors.orange),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '问题 ${idx + 1} / $totalCount${currentQ.header.isNotEmpty ? ' · ${currentQ.header}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.orange.shade300 : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (currentAnswer != null)
                Text(
                  '已选: $currentAnswer',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        // 当前问题文本
        if (currentQ.question.isNotEmpty) ...[
          Text(
            currentQ.question,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
        ],
        // 选项按钮
        if (currentQ.options.isNotEmpty)
          _buildOptionButtons(context, isDark, currentQ, idx, currentAnswer)
        else
          _buildActionButtons(),
      ],
    );
  }

  Widget _buildOptionButtons(
      BuildContext context, bool isDark, AskQuestion q, int questionIdx, String? selectedAnswer) {
    final showOther = _showOther[questionIdx] ?? false;
    final otherController = _otherController(questionIdx);
    // 是否选中了 Other（选中答案不在预设选项列表中）
    final isOtherSelected = selectedAnswer != null && !q.options.contains(selectedAnswer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 预设选项
        ...q.options.map((opt) {
          final isSelected = opt == selectedAnswer;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: OutlinedButton(
              onPressed: () {
                // 选预设选项时收起 Other 输入框
                setState(() => _showOther[questionIdx] = false);
                _onOptionSelected(questionIdx, opt);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: isSelected
                    ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                    : (isDark ? Colors.orange.shade300 : Colors.orange),
                backgroundColor: isSelected
                    ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)
                    : null,
                side: BorderSide(
                  color: isSelected
                      ? (isDark ? Colors.green.shade400 : Colors.green.shade400)
                      : (isDark ? Colors.orange.shade300 : Colors.orange).withValues(alpha: 0.5),
                  width: isSelected ? 1.5 : 1.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
                alignment: Alignment.centerLeft,
              ),
              child: Row(
                children: [
                  if (isSelected) ...[
                    Icon(Icons.check_circle_outline,
                        size: 14,
                        color: isDark ? Colors.green.shade300 : Colors.green.shade700),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: Text(opt)),
                ],
              ),
            ),
          );
        }),

        // Other 按钮 / 输入框
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: showOther || isOtherSelected
              ? _buildOtherInput(isDark, questionIdx, otherController, isOtherSelected, selectedAnswer)
              : OutlinedButton(
                  onPressed: () => setState(() => _showOther[questionIdx] = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    side: BorderSide(
                      color: (isDark ? Colors.grey[600]! : Colors.grey[400]!).withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 13,
                          color: isDark ? Colors.grey[500] : Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(S.get('remote_claw_other')),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildOtherInput(bool isDark, int questionIdx, TextEditingController controller,
      bool isOtherSelected, String? currentAnswer) {
    if (isOtherSelected && controller.text.isEmpty && currentAnswer != null) {
      controller.text = currentAnswer;
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: !isOtherSelected,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[200] : Colors.grey[900],
            ),
            decoration: InputDecoration(
              hintText: S.get('remote_claw_other_hint'),
              hintStyle: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: (isDark ? Colors.orange.shade300 : Colors.orange).withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: isDark ? Colors.orange.shade300 : Colors.orange,
                ),
              ),
            ),
            onSubmitted: (val) => _submitOther(questionIdx, val),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () => _submitOther(questionIdx, controller.text),
          icon: Icon(Icons.check_circle_outline,
              size: 18, color: isDark ? Colors.green.shade300 : Colors.green),
          tooltip: S.get('remote_claw_submit'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
        IconButton(
          onPressed: () {
            controller.clear();
            setState(() => _showOther[questionIdx] = false);
          },
          icon: Icon(Icons.close, size: 16,
              color: isDark ? Colors.grey[500] : Colors.grey[400]),
          tooltip: S.get('cancel'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  void _submitOther(int questionIdx, String val) {
    final text = val.trim();
    if (text.isEmpty) return;
    setState(() => _showOther[questionIdx] = false);
    _onOptionSelected(questionIdx, text);
  }

  void _onOptionSelected(int questionIdx, String answer) {
    final done = request.setQuestionAnswer(questionIdx, answer);
    if (done) {
      widget.onAnswer?.call(request.finalAnswer);
    } else {
      setState(() {
        _currentQuestionIndex = request.nextUnansweredIndex;
      });
    }
    setState(() {});
  }

  Widget _buildResolvedBadge(bool isDark) {
    final Color color;
    final IconData icon;
    final String label;

    if (_isExternallyHandled) {
      color = isDark ? Colors.grey[400]! : Colors.grey[600]!;
      icon = Icons.device_unknown_outlined;
      label = S.get('remote_claw_externally_handled');
    } else if (_isAllowedSession) {
      color = Colors.orange;
      icon = Icons.done_all;
      label = S.get('remote_claw_allow_session');
    } else if (_isAllowed) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      label = request.isAskFollowup && request.answer != null
          ? '${S.get('remote_claw_answered')}: ${request.answer}'
          : S.get('remote_claw_approved');
    } else {
      color = Colors.red;
      icon = Icons.cancel_outlined;
      label = S.get('remote_claw_denied');
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _toolEmoji(String toolName) {
    switch (toolName) {
      case 'Bash':
        return '⚡';
      case 'Write':
        return '✏️';
      case 'Edit':
        return '📝';
      case 'Read':
        return '📖';
      case 'Glob':
      case 'Grep':
        return '🔍';
      case 'AskUserQuestion':
        return '❓';
      default:
        return '🔧';
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
