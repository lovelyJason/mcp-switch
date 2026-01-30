
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/editor_type.dart';
import '../../../models/mcp_profile.dart';
import '../../../services/config_service.dart';
import '../../../services/plugin_mcp_service.dart';
import '../../components/profile_card.dart';
import '../../components/project_card.dart';
import '../../components/plugin_mcp_card.dart';
import '../../components/custom_dialog.dart';
import '../../components/custom_toast.dart';
import '../../../l10n/s.dart';
import 'mcp_server_edit_screen.dart';

class ConfigListScreen extends StatefulWidget {
  final EditorType editorType;

  const ConfigListScreen({super.key, required this.editorType});

  @override
  State<ConfigListScreen> createState() => _ConfigListScreenState();
}

class _ConfigListScreenState extends State<ConfigListScreen> {
  final PluginMcpService _pluginMcpService = PluginMcpService();

  @override
  void initState() {
    super.initState();
    // Claude Code 才加载插件 MCP
    if (widget.editorType == EditorType.claude) {
      _pluginMcpService.loadPluginMcpServers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        final profiles = configService.getProfiles(widget.editorType);
        final activeId = configService.getActiveProfileId(widget.editorType);

        if (profiles.isEmpty) {
          String message = '暂无配置';
          IconData icon = Icons.inbox_outlined;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (widget.editorType == EditorType.claude) {
          McpProfile? globalProfile;
          try {
            globalProfile = profiles.firstWhere(
              (p) => p.content['isGlobal'] == true,
            );
          } catch (_) {}

          final projectProfiles = profiles
              .where((p) => p.content['isGlobal'] != true)
              .toList();

          return Column(
            children: [
              if (profiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '通过claude mcp的cli添加的mcp默认是项目级别的，MCP Switch支持UI添加和终端命令添加两种方式',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: ListenableBuilder(
                    listenable: _pluginMcpService,
                    builder: (context, child) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        children: [
                          if (globalProfile != null) ...[
                            _buildSectionHeader('全域配置 @ ~/.claude.json'),
                            ProjectCard(
                              profile: globalProfile,
                              onDelete: () => _confirmDelete(
                                context,
                                configService,
                                globalProfile!,
                              ),
                            ),
                          ],
                          // 插件 MCP 区域
                          if (_pluginMcpService.mcpServers.isNotEmpty) ...[
                            _buildSectionHeader(
                              '插件 MCP @ ~/.claude/plugins/',
                              tooltip: '来自已安装的 Claude Code 插件（Marketplace）',
                            ),
                            PluginMcpCard(
                              mcpServers: _pluginMcpService.mcpServers,
                            ),
                          ],
                          if (projectProfiles.isNotEmpty) ...[
                            if (globalProfile != null ||
                                _pluginMcpService.mcpServers.isNotEmpty)
                              _buildSectionHeader(
                                S.get('project_config_section'),
                                tooltip: S.get('project_config_tooltip'),
                              ),
                            ...projectProfiles.map(
                              (profile) => ProjectCard(
                                profile: profile,
                                onDelete: () =>
                                    _confirmDelete(context, configService, profile),
                                // 传递全局 MCP 配置，用于显示继承的 MCP
                                globalMcpServers: globalProfile?.content['mcpServers'] is Map
                                    ? Map<String, dynamic>.from(globalProfile!.content['mcpServers'])
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        }

        return ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 20),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isActive = profile.id == activeId;
              return ProfileCard(
                profile: profile,
                isActive: isActive,
                onSelect: () =>
                    configService.toggleServerStatus(widget.editorType, profile.id),
                onDelete: () => _confirmDelete(context, configService, profile),
                onEdit: () {
                  if (widget.editorType == EditorType.cursor) {
                    Toast.show(
                      context,
                      message: 'Cursor 请前往客户端界面进行编辑',
                      type: ToastType.info,
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => McpServerEditScreen(
                        editorType: widget.editorType,
                        profile: profile,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, {String? tooltip}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          if (tooltip != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: tooltip,
              preferBelow: false,
              verticalOffset: 16,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.5,
              ),
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    ConfigService service,
    McpProfile profile,
  ) {
    CustomConfirmDialog.show(
      context,
      title: S.get('delete'),
      content: '${S.get('delete_confirm')}\n\n${profile.name}',
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.redAccent,
      onConfirm: () {
        service.deleteProfile(widget.editorType, profile.id);
      },
    );
  }
}
