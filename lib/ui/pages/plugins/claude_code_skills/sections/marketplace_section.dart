part of '../../claude_code_skills_screen.dart';

// ─── Marketplace section (mixed into _SkillsScreenState) ───────────────────

extension MarketplaceSectionExt on _SkillsScreenState {
  // ============ 市场区域 ============
  Widget buildMarketplacesSection(bool isDark) {
    return Column(
      key: _marketplaceSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitleWithAction(
          S.get('marketplaces'),
          Icons.store,
          Colors.orange,
          actionIcon: Icons.add_circle_outline,
          actionTooltip: S.get('add_marketplace'),
          onAction: _showAddMarketplaceDialog,
        ),
        const SizedBox(height: 12),
        if (_marketplaces.isEmpty)
          buildEmptyCard(S.get('no_marketplaces'))
        else
          _buildMarketplaceCards(isDark),
      ],
    );
  }

  Widget _buildMarketplaceCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children:
              _marketplaces.map((m) => _buildMarketplaceCard(m, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildMarketplaceCard(InstalledMarketplace marketplace, bool isDark, double cardWidth) {
    final isOfficial = marketplace.isOfficial;
    final isAuthor = presetMarketplaces.any((p) => p.name == marketplace.name && p.isAuthor);
    final Color tagColor;
    final IconData tagIcon;
    final String tagText;
    if (isOfficial) {
      tagColor = Colors.blue;
      tagIcon = Icons.verified;
      tagText = S.get('official');
    } else if (isAuthor) {
      tagColor = Colors.deepOrange;
      tagIcon = Icons.favorite;
      tagText = S.get('author_tag');
    } else {
      tagColor = Colors.purple;
      tagIcon = Icons.groups;
      tagText = S.get('community');
    }
    final hint = _getMarketplaceHint(marketplace.name);
    final isHighlighted = _highlightedMarketplace != null &&
        marketplace.name.toLowerCase().contains(_highlightedMarketplace!.toLowerCase());

    return SizedBox(
      width: cardWidth,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: isHighlighted
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        child: InkWell(
          onTap: () => _showMarketplaceDetailDialog(marketplace),
          borderRadius: BorderRadius.circular(10),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: isHighlighted ? Colors.deepPurple : Colors.grey.withValues(alpha: 0.2),
                width: isHighlighted ? 2 : 1,
              ),
            ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(tagIcon, size: 16, color: tagColor),
                    ),
                    if (hint != null) HoverPopover(message: hint, isDark: isDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        marketplace.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tagText,
                        style: TextStyle(
                          fontSize: 9,
                          color: tagColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.link, size: 12, color: Colors.grey.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        marketplace.repo,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.withValues(alpha: 0.8),
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.update, size: 12, color: Colors.grey.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _skillsService.formatDate(marketplace.lastUpdated),
                      style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _updateMarketplace(marketplace.name),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.sync,
                          size: 16,
                          color: Colors.blue.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    if (marketplace.hasReadme)
                      InkWell(
                        onTap: () => _showReadmeDialog(marketplace),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.description_outlined,
                            size: 16,
                            color: Colors.orange.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: () => _openInFinder(marketplace.name),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.folder_open_outlined,
                          size: 16,
                          color: Colors.grey.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _confirmRemoveMarketplace(marketplace),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMarketplace(InstalledMarketplace marketplace) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_remove_marketplace_title'),
      content: S.get('confirm_remove_marketplace_content').replaceAll('{name}', marketplace.name),
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      final terminalService = context.read<TerminalService>();
      terminalService.setFloatingTerminal(true);
      terminalService.openTerminalPanel();
      await Future.delayed(const Duration(milliseconds: 500));
      terminalService.sendCommand('claude plugin marketplace remove ${marketplace.name}');
    }
  }
}
