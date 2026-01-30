part of '../../claude_code_skills_screen.dart';

/// 斜线指令搜索弹窗
class _SlashCommandSearchDialog extends StatefulWidget {
  final List<SlashCommand> commands;

  const _SlashCommandSearchDialog({required this.commands});

  @override
  State<_SlashCommandSearchDialog> createState() => _SlashCommandSearchDialogState();
}

class _SlashCommandSearchDialogState extends State<_SlashCommandSearchDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<SlashCommand> _filteredCommands = [];

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.commands;
    // 自动聚焦搜索框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCommands = widget.commands;
      } else {
        // 去掉开头的斜杠再匹配
        final normalizedQuery = query.startsWith('/') ? query.substring(1) : query;
        final lowerQuery = normalizedQuery.toLowerCase();
        _filteredCommands = widget.commands.where((cmd) {
          return cmd.command.toLowerCase().contains(lowerQuery) ||
              cmd.name.toLowerCase().contains(lowerQuery) ||
              (cmd.description?.toLowerCase().contains(lowerQuery) ?? false);
        }).toList();
      }
    });
  }

  void _copyCommand(SlashCommand cmd) {
    Clipboard.setData(ClipboardData(text: cmd.displayCommand));
    Toast.show(
      context,
      message: S.get('command_copied'),
      type: ToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      child: Container(
        width: 500,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              children: [
                Icon(Icons.search, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  S.get('search_slash_commands'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 搜索框
            TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: S.get('search_hint'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 8),
            // 统计信息
            Text(
              S.get('found_commands').replaceAll('{count}', _filteredCommands.length.toString()),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            // 指令列表
            Expanded(
              child: _filteredCommands.isEmpty
                  ? Center(
                      child: Text(
                        S.get('no_matching_commands'),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCommands.length,
                      itemBuilder: (context, index) {
                        final cmd = _filteredCommands[index];
                        return _buildCommandItem(cmd, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandItem(SlashCommand cmd, bool isDark) {
    final isSkill = cmd.type == SlashCommandType.skill;
    final isCommunity = cmd.source == SlashCommandSource.community;
    final typeColor = isSkill ? Colors.teal : Colors.orange;
    final sourceColor = isCommunity ? Colors.purple : Colors.blue;

    return InkWell(
      onTap: () => _copyCommand(cmd),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            // 类型图标
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                isSkill ? Icons.auto_awesome : Icons.terminal,
                size: 14,
                color: typeColor,
              ),
            ),
            const SizedBox(width: 10),
            // 指令信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        cmd.displayCommand,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 来源标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          isCommunity ? 'community' : cmd.pluginName,
                          style: TextStyle(
                            fontSize: 9,
                            color: sourceColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (cmd.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      cmd.description!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // 复制图标
            Icon(
              Icons.content_copy,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
