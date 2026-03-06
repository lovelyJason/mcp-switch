
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/editor_type.dart';
import '../../../models/mcp_profile.dart';
import '../../../services/config_service.dart';
import '../../../services/plugin_mcp_service.dart';
import '../../../services/gemini_extension_mcp_service.dart';
import '../../../services/cursor_workspace_service.dart';
import '../../components/cursor_workspace_card.dart';
import '../../components/profile_card.dart';
import '../../components/project_card.dart';
import '../../components/plugin_mcp_card.dart';
import '../../components/gemini_extension_mcp_card.dart';
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
  final GeminiExtensionMcpService _geminiExtensionMcpService = GeminiExtensionMcpService();
  bool _projectSortDescending = true; // 默认倒序排列
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cursor workspace 列表
  List<CursorWorkspace>? _cursorWorkspaces;
  bool _loadingWorkspaces = false;

  @override
  void initState() {
    super.initState();
    _loadEditorData(widget.editorType);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(ConfigListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editorType != oldWidget.editorType) {
      _loadEditorData(widget.editorType);
    }
  }

  void _loadEditorData(EditorType type) {
    if (type == EditorType.claude) {
      _pluginMcpService.loadPluginMcpServers();
    }
    if (type == EditorType.gemini) {
      _geminiExtensionMcpService.loadExtensionMcpServers();
    }
    if (type == EditorType.cursor) {
      _loadCursorWorkspaces();
    }
  }

  Future<void> _loadCursorWorkspaces() async {
    if (_loadingWorkspaces) return;
    setState(() => _loadingWorkspaces = true);
    final workspaces = await CursorWorkspaceService.instance.getWorkspaces();
    if (mounted) {
      setState(() {
        _cursorWorkspaces = workspaces;
        _loadingWorkspaces = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        final profiles = configService.getProfiles(widget.editorType);
        final activeId = configService.getActiveProfileId(widget.editorType);

        // Gemini 有 Extension MCPs，不能在 profiles.isEmpty 时直接返回
        if (profiles.isEmpty && widget.editorType != EditorType.gemini) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  '暂无配置',
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
                      Expanded(
                        child: const Text(
                          '通过claude mcp的cli添加的mcp默认是项目级别的，MCP Switch支持UI添加和终端命令添加两种方式\n'
                          '切记：Claude Code 如果要启用和禁用 MCP，一定要在对应项目中进行开关操作，全局配置中切换状态无效',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
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
                              _buildProjectSectionHeader(),
                            ...() {
                              var filtered = _searchQuery.isEmpty
                                  ? projectProfiles
                                  : projectProfiles.where((p) =>
                                      p.name.toLowerCase().contains(_searchQuery)).toList();
                              if (_projectSortDescending) {
                                filtered = filtered.reversed.toList();
                              }
                              return filtered.map(
                                (profile) => ProjectCard(
                                  profile: profile,
                                  onDelete: () =>
                                      _confirmDelete(context, configService, profile),
                                  globalMcpServers: globalProfile?.content['mcpServers'] is Map
                                      ? Map<String, dynamic>.from(globalProfile!.content['mcpServers'])
                                      : null,
                                ),
                              );
                            }(),
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

        if (widget.editorType == EditorType.gemini) {
          return ListenableBuilder(
            listenable: _geminiExtensionMcpService,
            builder: (context, child) {
              return ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  children: [
                    if (_geminiExtensionMcpService.mcpServers.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Extension MCPs @ ~/.gemini/extensions/',
                        tooltip: '来自已安装的 Gemini CLI 扩展',
                      ),
                      GeminiExtensionMcpCard(
                        mcpServers: _geminiExtensionMcpService.mcpServers,
                      ),
                    ],
                    if (profiles.isNotEmpty) ...[
                      _buildSectionHeader('MCP Servers @ ~/.gemini/settings.json'),
                      ...profiles.map((profile) => ProfileCard(
                        profile: profile,
                        isActive: profile.id == activeId,
                        onSelect: () => configService.toggleServerStatus(
                            widget.editorType, profile.id),
                        onDelete: () =>
                            _confirmDelete(context, configService, profile),
                        onEdit: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => McpServerEditScreen(
                                editorType: widget.editorType,
                                profile: profile,
                              ),
                            ),
                          );
                        },
                      )),
                    ],
                    if (_geminiExtensionMcpService.mcpServers.isEmpty &&
                        profiles.isEmpty)
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.inbox_outlined,
                                size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              '暂无配置',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        }

        if (widget.editorType == EditorType.cursor) {
          return _buildCursorView(profiles, activeId, configService);
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

  Widget _buildCursorView(
    List<McpProfile> profiles,
    String? activeId,
    ConfigService configService,
  ) {
    final serverNames = profiles.map((p) => p.name).toList();

    return Column(
      children: [
        _buildCursorDisabledTip(),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                // 全局 MCP 配置
                _buildSectionHeader(
                  'MCP Servers @ ~/.cursor/mcp.json',
                  tooltip: S.get('cursor_global_mcp_tooltip'),
                ),
                ...profiles.map((profile) {
                  final isActive = profile.id == activeId;
                  return ProfileCard(
                    profile: profile,
                    isActive: isActive,
                    onSelect: () =>
                        configService.toggleServerStatus(widget.editorType, profile.id),
                    onDelete: () => _confirmDelete(context, configService, profile),
                    onEdit: () {
                      Toast.show(
                        context,
                        message: S.get('cursor_edit_in_client'),
                        type: ToastType.info,
                      );
                    },
                  );
                }),

                // Workspace 项目级配置
                if (CursorWorkspaceService.instance.shouldUseSqlite &&
                    _cursorWorkspaces != null &&
                    _cursorWorkspaces!.isNotEmpty) ...[
                  _buildSectionHeader(
                    S.get('cursor_workspace_section'),
                    tooltip: S.get('cursor_workspace_tooltip'),
                  ),
                  ..._cursorWorkspaces!.map((ws) => CursorWorkspaceCard(
                    workspace: ws,
                    globalServerNames: serverNames,
                  )),
                ],

                if (_loadingWorkspaces)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCursorDisabledTip() {
    final cursorWs = CursorWorkspaceService.instance;
    final mechanism = cursorWs.disabledMechanism;
    if (mechanism == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final version = cursorWs.cursorVersion ?? '';
    final versionSuffix = version.isNotEmpty ? ' (Cursor v$version)' : '';

    final isSqlite = mechanism == 'sqlite_workspace';
    final tipText = isSqlite
        ? '${S.get('cursor_disabled_via_sqlite_sync')}$versionSuffix'
        : '${S.get('cursor_disabled_via_json')}$versionSuffix';
    final tipColor = isSqlite ? Colors.green : Colors.blue;
    final tipIcon = isSqlite ? Icons.check_circle_outline : Icons.info_outline;

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: tipColor.withOpacity(isDark ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tipColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tipIcon, size: 16, color: tipColor.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tipText,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? tipColor.shade300 : tipColor.shade900,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSectionHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          Text(
            S.get('project_config_section'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: S.get('project_config_tooltip'),
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
          const Spacer(),
          SizedBox(
            width: 180,
            height: 30,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: S.get('project_search_hint'),
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, size: 16, color: Colors.grey.shade400),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: Icon(Icons.close, size: 14, color: Colors.grey.shade500),
                      )
                    : null,
                suffixIconConstraints: const BoxConstraints(minWidth: 28),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _projectSortDescending ? '当前：最新在前' : '当前：最早在前',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() {
                  _projectSortDescending = !_projectSortDescending;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _projectSortDescending
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 16,
                  color: Colors.orange.shade300,
                ),
              ),
            ),
          ),
        ],
      ),
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
