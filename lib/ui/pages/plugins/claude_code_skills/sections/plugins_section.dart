part of '../../claude_code_skills_screen.dart';

// ─── Local plugins section (mixed into _SkillsScreenState) ─────────────────

extension PluginsSectionExt on _SkillsScreenState {
  // ============ 本地插件区域 ============
  Widget buildPluginsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSectionTitleWithAction(
          S.get('local_plugins'),
          Icons.extension,
          Colors.blue,
          actionIcon: Icons.build_outlined,
          actionTooltip: S.get('fix_enabled_plugins'),
          onAction: _fixEnabledPlugins,
        ),
        const SizedBox(height: 12),
        if (_plugins.isEmpty)
          buildEmptyCard(S.get('no_skills'))
        else
          _buildPluginCards(isDark),
      ],
    );
  }

  Future<void> _fixEnabledPlugins() async {
    final fixedCount = await _skillsService.fixEnabledPlugins();
    if (!mounted) return;
    if (fixedCount > 0) {
      Toast.show(
        context,
        message: S.get('fix_enabled_plugins_success').replaceAll('{count}', '$fixedCount'),
        type: ToastType.success,
        duration: const Duration(seconds: 4),
      );
      await _loadData();
    } else {
      Toast.show(
        context,
        message: S.get('fix_enabled_plugins_ok'),
        type: ToastType.info,
      );
    }
  }

  Widget _buildPluginCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const cardsPerRow = 3;
        final cardWidth = (constraints.maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _plugins.map((plugin) => _buildPluginCard(plugin, isDark, cardWidth)).toList(),
        );
      },
    );
  }

  Widget _buildPluginCard(InstalledPlugin plugin, bool isDark, double cardWidth) {
    final parts = plugin.name.split('@');
    final pluginName = parts[0];
    final marketplace = parts.length > 1 ? parts[1] : '';
    final isEnabled = plugin.isEnabled;
    final isDeprecated = plugin.isDeprecated;

    final borderColor = isDeprecated
        ? Colors.red.withValues(alpha: 0.5)
        : Colors.blue.withValues(alpha: 0.3);

    return SizedBox(
      width: cardWidth,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: HoverCard(
          onTap: () => _showPluginDetailDialog(plugin),
          borderColor: borderColor,
          borderWidth: isDeprecated ? 1.5 : 1,
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
                          color: isDeprecated
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.extension,
                          size: 16,
                          color: isDeprecated ? Colors.red : Colors.blue,
                        ),
                      ),
                      if (isDeprecated) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: S.get('plugin_deprecated_tip'),
                          preferBelow: false,
                          verticalOffset: 14,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.4,
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pluginName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDeprecated ? Colors.red.shade700 : null,
                            decoration: isDeprecated ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          marketplace,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.tag, size: 11, color: Colors.grey.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        plugin.version.length > 10
                            ? '${plugin.version.substring(0, 10)}...'
                            : plugin.version,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.withValues(alpha: 0.8),
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (plugin.scope == 'project') ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: '${plugin.projectPath ?? 'Unknown'}\n${S.get('click_to_convert_user')}',
                          preferBelow: false,
                          verticalOffset: 14,
                          child: InkWell(
                            onTap: () => _convertToUserScope(plugin),
                            borderRadius: BorderRadius.circular(3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                'project',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Icon(Icons.calendar_today, size: 11, color: Colors.grey.withValues(alpha: 0.7)),
                      const SizedBox(width: 3),
                      Text(
                        _skillsService.formatDate(plugin.installedAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => _togglePluginEnabled(plugin),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isEnabled ? Icons.toggle_on : Icons.toggle_off,
                            size: 22,
                            color: isEnabled
                                ? Colors.green.withValues(alpha: 0.8)
                                : Colors.grey.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!isDeprecated)
                        InkWell(
                          onTap: () => _updatePlugin(plugin),
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
                      if (!isDeprecated) const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _confirmUninstallPlugin(plugin),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18,
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
    );
  }

  Future<void> _updatePlugin(InstalledPlugin plugin) async {
    final terminalService = context.read<TerminalService>();
    terminalService.setFloatingTerminal(true);
    terminalService.openTerminalPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    final scopeArg = plugin.scope.isNotEmpty ? '--scope ${plugin.scope}' : '';
    terminalService.sendCommand('claude plugin update ${plugin.name} $scopeArg'.trim());
  }

  Future<void> _togglePluginEnabled(InstalledPlugin plugin) async {
    final terminalService = context.read<TerminalService>();
    final command = plugin.isEnabled
        ? 'claude plugin disable ${plugin.name}'
        : 'claude plugin enable ${plugin.name}';

    terminalService.setFloatingTerminal(true);
    terminalService.openTerminalPanel();
    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand(command);
  }

  Future<void> _confirmUninstallPlugin(InstalledPlugin plugin) async {
    final parts = plugin.name.split('@');
    final pluginName = parts[0];

    if (plugin.isDeprecated) {
      await _confirmForceDeleteDeprecatedPlugin(plugin, pluginName);
      return;
    }

    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('confirm_uninstall_title'),
      content: S.get('confirm_uninstall_content').replaceAll('{name}', pluginName),
      confirmText: S.get('uninstall'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      final terminalService = context.read<TerminalService>();
      terminalService.setFloatingTerminal(true);
      terminalService.openTerminalPanel();
      await Future.delayed(const Duration(milliseconds: 500));
      terminalService.sendCommand('claude plugin uninstall ${plugin.name}');
    }
  }

  Future<void> _confirmForceDeleteDeprecatedPlugin(InstalledPlugin plugin, String pluginName) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('deprecated_plugin_title'),
      content: S.get('deprecated_plugin_content').replaceAll('{name}', pluginName),
      confirmText: S.get('force_delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.red,
    );

    if (confirmed == true && mounted) {
      final (success, errorCode) = await _skillsService.forceDeleteDeprecatedPlugin(plugin);
      if (mounted) {
        if (success) {
          Toast.show(
            context,
            message: S.get('plugin_force_deleted'),
            type: ToastType.success,
          );
          _loadData();
        } else if (errorCode == 'claude_cli_conflict') {
          Toast.show(
            context,
            message: S.get('plugin_delete_cli_conflict'),
            type: ToastType.warning,
            duration: const Duration(seconds: 5),
          );
        } else {
          Toast.show(
            context,
            message: S.get('plugin_force_delete_failed'),
            type: ToastType.error,
          );
        }
      }
    }
  }

  Future<void> _convertToUserScope(InstalledPlugin plugin) async {
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('convert_to_user_scope_title'),
      content: S.get('convert_to_user_scope_content').replaceAll('{name}', plugin.name.split('@').first),
      confirmText: S.get('convert'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.deepPurple,
    );

    if (confirmed == true && mounted) {
      final success = await _skillsService.convertPluginToUserScope(plugin);
      if (mounted) {
        if (success) {
          Toast.show(
            context,
            message: S.get('convert_to_user_scope_success'),
            type: ToastType.success,
          );
          _loadData();
        } else {
          Toast.show(
            context,
            message: S.get('convert_to_user_scope_failed'),
            type: ToastType.error,
          );
        }
      }
    }
  }
}
