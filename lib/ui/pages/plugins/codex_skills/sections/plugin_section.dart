part of '../../codex_skills_screen.dart';

// ─── Marketplace Plugins section (mixed into _CodexSkillsScreenState) ─────────

extension _PluginSectionExt on _CodexSkillsScreenState {
  // ── build section ──────────────────────────────────────────────────────────
  Widget _buildMarketplacePluginsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          S.get('codex_marketplace_plugins'),
          Icons.extension_outlined,
          Colors.purple,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            S.get('codex_marketplace_plugins_hint'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_loadingPlugins)
          const Center(child: CircularProgressIndicator())
        else if (_marketplacePlugins.isEmpty)
          _buildEmptyCard(S.get('codex_no_marketplace_plugins'))
        else
          _buildPluginCards(isDark),
      ],
    );
  }

  Widget _buildPluginCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const perRow = 3;
        final w = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _marketplacePlugins
              .map((p) => _CodexPluginCard(plugin: p, isDark: isDark, width: w))
              .toList(),
        );
      },
    );
  }
}

// ─── Plugin card ───────────────────────────────────────────────────────────────
class _CodexPluginCard extends StatelessWidget {
  const _CodexPluginCard({
    required this.plugin,
    required this.isDark,
    required this.width,
  });

  final CodexPlugin plugin;
  final bool isDark;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = plugin.brandColor;

    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(color),
              const SizedBox(height: 8),
              _buildDescription(),
              const SizedBox(height: 8),
              _buildFooter(color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.extension, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            plugin.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (plugin.isInstalled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              S.get('codex_plugin_installed'),
              style: const TextStyle(
                fontSize: 9,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      plugin.shortDescription,
      style: TextStyle(
        fontSize: 11,
        color: Colors.grey.withValues(alpha: 0.8),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildFooter(Color color) {
    return Row(
      children: [
        if (plugin.category != null && plugin.category!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              plugin.category!,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (plugin.version != null) ...[
          const SizedBox(width: 6),
          Text(
            S.get('codex_plugin_version').replaceAll('{version}', plugin.version!),
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.withValues(alpha: 0.6),
            ),
          ),
        ],
        const Spacer(),
        Text(
          plugin.marketplace,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.withValues(alpha: 0.5),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
