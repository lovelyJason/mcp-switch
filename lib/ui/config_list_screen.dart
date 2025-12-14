
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/editor_type.dart';
import '../../models/mcp_profile.dart';
import '../../services/config_service.dart';
import 'components/profile_card.dart';
import 'components/project_card.dart';
import 'components/custom_dialog.dart';
import 'components/custom_toast.dart';
import '../l10n/s.dart';
import 'mcp_server_edit_screen.dart';

class ConfigListScreen extends StatelessWidget {
  final EditorType editorType;

  const ConfigListScreen({super.key, required this.editorType});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        final profiles = configService.getProfiles(editorType);
        final activeId = configService.getActiveProfileId(editorType);

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

        if (editorType == EditorType.claude) {
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
                  child: ListView(
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
                      if (projectProfiles.isNotEmpty) ...[
                        if (globalProfile != null) _buildSectionHeader('项目级配置'),
                        ...projectProfiles.map(
                          (profile) => ProjectCard(
                            profile: profile,
                            onDelete: () =>
                                _confirmDelete(context, configService, profile),
                          ),
                        ),
                      ],
                    ],
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
                    configService.toggleServerStatus(editorType, profile.id),
                onDelete: () => _confirmDelete(context, configService, profile),
                onEdit: () {
                  if (editorType == EditorType.cursor) {
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
                        editorType: editorType,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
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
        service.deleteProfile(editorType, profile.id);
      },
    );
  }
}
