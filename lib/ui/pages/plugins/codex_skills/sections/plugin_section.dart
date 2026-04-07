part of '../../codex_skills_screen.dart';

// ─── Marketplace Plugins section (mixed into _CodexSkillsScreenState) ─────────

extension _PluginSectionExt on _CodexSkillsScreenState {
  // ── CLI check button ────────────────────────────────────────────────────────
  Widget _buildCliCheckButton() {
    if (_checkingCommand) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
      );
    }
    final IconData icon;
    final Color? color;
    if (_commandInstalled == null) {
      icon = Icons.terminal;
      color = null;
    } else if (_commandInstalled!) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else {
      icon = Icons.error_outline;
      color = Colors.red;
    }
    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: () {
        if (_commandInstalled == false) {
          _showCliInstallDialog();
        } else {
          _checkCliInstalled();
        }
      },
      tooltip: S.get('codex_check_cli'),
    );
  }

  void _showCliInstallDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) => _CliInstallDialog(
        isDark: isDark,
        command: _CodexSkillsScreenState._cliCommand,
        installCommand: _CodexSkillsScreenState._cliInstallCommand,
        parentContext: context,
      ),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
    );
  }

  // ── Marketplace section ─────────────────────────────────────────────────────
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
        else if (_groupedPlugins.isEmpty)
          _buildEmptyCard(S.get('codex_no_marketplace_plugins'))
        else
          _buildGroupedPlugins(isDark),
      ],
    );
  }

  Widget _buildGroupedPlugins(bool isDark) {
    final entries = _groupedPlugins.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          _PluginGroupSection(
            groupName: entries[i].key,
            plugins: entries[i].value,
            isDark: isDark,
          ),
          if (i < entries.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

// ─── Plugin group (by marketplace) ──────────────────────────────────────────

class _PluginGroupSection extends StatelessWidget {
  const _PluginGroupSection({
    required this.groupName,
    required this.plugins,
    required this.isDark,
  });

  final String groupName;
  final List<CodexPlugin> plugins;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final installedCount = plugins.where((p) => p.isInstalled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // group header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.purple.withValues(alpha: 0.1)
                : Colors.purple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: Colors.purple.withValues(alpha: 0.5), width: 3),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.storefront, size: 16, color: Colors.purple.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                groupName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.purple.shade200 : Colors.purple.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${plugins.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              if (installedCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$installedCount ${S.get('codex_plugin_installed')}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // plugin list
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            const perRow = 3;
            final w = (constraints.maxWidth - spacing * (perRow - 1)) / perRow;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: plugins
                  .map((p) => _CodexPluginCard(plugin: p, isDark: isDark, width: w))
                  .toList(),
            );
          },
        ),
      ],
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
      child: HoverCard(
        borderColor: color.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(color),
              const SizedBox(height: 8),
              _buildDescription(),
              const SizedBox(height: 8),
              _buildFooter(context, color),
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
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    if (plugin.isInstalled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 10, color: Colors.green),
            const SizedBox(width: 2),
            Text(
              S.get('codex_plugin_installed'),
              style: const TextStyle(
                fontSize: 9,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        S.get('codex_plugin_available'),
        style: TextStyle(
          fontSize: 9,
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
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

  Widget _buildFooter(BuildContext context, Color color) {
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
        if (!plugin.isInstalled)
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.download_rounded, size: 16, color: color),
              tooltip: S.get('codex_plugin_install'),
              onPressed: () => _installViaTerminal(context),
            ),
          ),
      ],
    );
  }

  void _installViaTerminal(BuildContext context) {
    if (plugin.marketplace == 'openai-curated') {
      Toast.show(
        context,
        message: S.get('codex_official_plugin_install_hint'),
        type: ToastType.info,
        duration: const Duration(seconds: 5),
      );
      return;
    }

    final terminalService = context.read<TerminalService>();
    terminalService.setFloatingTerminal(true);
    terminalService.openTerminalPanel();
    Future.delayed(const Duration(milliseconds: 500), () {
      final cmd = 'osk plugin install ${plugin.name}@${plugin.marketplace} -t codex';
      terminalService.sendCommand(cmd);
    });
  }
}

// ─── CLI install dialog ─────────────────────────────────────────────────────

class _CliInstallDialog extends StatelessWidget {
  const _CliInstallDialog({
    required this.isDark,
    required this.command,
    required this.installCommand,
    required this.parentContext,
  });

  final bool isDark;
  final String command;
  final String installCommand;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final descColor = isDark ? Colors.white70 : Colors.black54;
    final cmdBg = isDark ? Colors.grey.shade800 : Colors.grey.shade100;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('codex_cli_install_title')
                    .replaceAll('{cmd}', command),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                S.get('codex_cli_install_desc')
                    .replaceAll('{cmd}', command),
                style: TextStyle(
                  fontSize: 14,
                  color: descColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cmdBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  installCommand,
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'Menlo',
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Text(S.get('cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: installCommand),
                      );
                      Navigator.of(context).pop();
                      Toast.show(
                        parentContext,
                        message: S.get('copied'),
                        type: ToastType.success,
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(S.get('codex_cli_copy_command')),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
