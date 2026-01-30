import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mcp_profile.dart';
import '../../models/editor_type.dart';
import '../../services/config_service.dart';
import '../pages/mcp_config/mcp_server_edit_screen.dart';
import 'custom_dialog.dart';
import '../../l10n/s.dart';

class ProjectCard extends StatefulWidget {
  final McpProfile profile;
  final VoidCallback onDelete;
  /// 全局 MCP 服务器配置（用于显示继承的 MCP）
  final Map<String, dynamic>? globalMcpServers;

  const ProjectCard({
    super.key,
    required this.profile,
    required this.onDelete,
    this.globalMcpServers,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isHovering = false;

  /// 判断是否是全局配置
  bool get _isGlobalProfile => widget.profile.content['isGlobal'] == true;

  void _addServer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => McpServerEditScreen(
          editorType: EditorType.claude,
          onSave: (name, config) {
            _updateServer(name, config);
          },
        ),
      ),
    );
  }

  void _editServer(String name, Map<String, dynamic> config) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => McpServerEditScreen(
          editorType: EditorType.claude,
          initialData: {'name': name, 'config': config},
          isPathReadOnly: true, // Allow changing config but maybe keep name fixed or handle rename logic
          onSave: (newName, newConfig) {
             // If name changed, we need to remove old and add new
             if (newName != name) {
               _removeServer(name, save: false);
             }
             _updateServer(newName, newConfig);
          },
        ),
      ),
    );
  }

  void _updateServer(String name, Map<String, dynamic> config) {
    final configService = Provider.of<ConfigService>(context, listen: false);
    
    // Deep copy content
    final content = Map<String, dynamic>.from(widget.profile.content);
    final mcpServers = (content['mcpServers'] is Map) 
        ? Map<String, dynamic>.from(content['mcpServers']) 
        : <String, dynamic>{};
        
    mcpServers[name] = config;
    content['mcpServers'] = mcpServers;

    final updatedProfile = McpProfile(
      id: widget.profile.id,
      name: widget.profile.name,
      description: widget.profile.description,
      content: content,
    );

    configService.saveProfile(EditorType.claude, updatedProfile);
  }

  void _removeServer(String name, {bool save = true}) {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final content = Map<String, dynamic>.from(widget.profile.content);
    final mcpServers = (content['mcpServers'] is Map) 
        ? Map<String, dynamic>.from(content['mcpServers']) 
        : <String, dynamic>{};
        
    mcpServers.remove(name);
    content['mcpServers'] = mcpServers;

    final updatedProfile = McpProfile(
      id: widget.profile.id,
      name: widget.profile.name,
      description: widget.profile.description,
      content: content,
    );

    if (save) {
      configService.saveProfile(EditorType.claude, updatedProfile);
    }
  }

  void _confirmDeleteServer(String name) {
    CustomConfirmDialog.show(
      context,
      title: S.get('delete'),
      content: '${S.get('delete_confirm')}\n\n$name',
      confirmText: S.get('delete'),
      cancelText: S.get('cancel'),
      confirmColor: Colors.redAccent,
      onConfirm: () {
        _removeServer(name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> mcpServers =
        (widget.profile.content['mcpServers'] is Map)
            ? widget.profile.content['mcpServers']
            : {};

    // 获取禁用的继承 MCP 列表
    final List<String> disabledMcpServers =
        (widget.profile.content['disabledMcpServers'] is List)
            ? List<String>.from(widget.profile.content['disabledMcpServers'])
            : [];

    // 全局 MCP（过滤掉项目本身已配置的）
    final Map<String, dynamic> inheritedMcpServers = {};
    if (widget.globalMcpServers != null && !_isGlobalProfile) {
      for (final entry in widget.globalMcpServers!.entries) {
        // 只显示项目中没有配置的全局 MCP
        if (!mcpServers.containsKey(entry.key)) {
          inheritedMcpServers[entry.key] = entry.value;
        }
      }
    }

    final projectServerCount = mcpServers.length;
    final inheritedServerCount = inheritedMcpServers.length;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.grey.withOpacity(0.2);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade100,
                border: Border.all(color: borderColor),
                ),
              child: Icon(
                Icons.folder_open,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.profile.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Menlo',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 全局配置的灯泡提示
                if (_isGlobalProfile) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: S.get('global_mcp_disable_tip'),
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
                      Icons.lightbulb,
                      size: 18,
                      color: Colors.amber.shade600,
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              _isGlobalProfile
                  ? '$projectServerCount servers configured'
                  : '$projectServerCount project + $inheritedServerCount inherited',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            children: [
              // 继承的全局 MCP（仅非全局项目显示）
              if (!_isGlobalProfile && inheritedMcpServers.isNotEmpty) ...[
                _buildSectionDivider('继承自全局配置', isDark),
                ...inheritedMcpServers.keys.map((name) {
                  final config = inheritedMcpServers[name];
                  final isDisabled = disabledMcpServers.contains(name);
                  return _buildInheritedServerItem(
                    name,
                    config,
                    isDisabled: isDisabled,
                    onToggle: (enabled) => _toggleInheritedServer(name, enabled),
                  );
                }),
              ],

              // 项目自有 MCP
              if (!_isGlobalProfile && mcpServers.isNotEmpty && inheritedMcpServers.isNotEmpty)
                _buildSectionDivider('项目配置', isDark),

              if (projectServerCount == 0 && inheritedServerCount == 0)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No servers configured.', style: TextStyle(color: Colors.grey)),
                ),

              ...mcpServers.keys.map((name) {
                final config = mcpServers[name];
                return _buildServerItem(name, config);
              }),

              // Add Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.shade100,
                    ),
                  ),
                ),
                child: TextButton.icon(
                  onPressed: _addServer,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add MCP Server'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerItem(String name, dynamic config) {
    final cmd = config is Map ? config['command'] ?? '' : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    bool isEnabled = true;
    if (config is Map) {
      if (config.containsKey('disabled')) {
        isEnabled = config['disabled'] != true;
      } else if (config.containsKey('enabled')) {
        isEnabled = config['enabled'] == true;
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade50,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 36, right: 24),
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.transparent : Colors.grey.shade300,
            ),
          ),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isEnabled
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isEnabled ? '已启用' : '已禁用',
                style: TextStyle(
                  fontSize: 10,
                  color: isEnabled ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(cmd, style: const TextStyle(fontFamily: 'Menlo', fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
              onPressed: () => _editServer(name, config is Map ? Map<String, dynamic>.from(config) : {}),
            ),
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: isEnabled,
                onChanged: (val) {
                  final newConfig = config is Map
                      ? Map<String, dynamic>.from(config)
                      : <String, dynamic>{};
                  newConfig['disabled'] =
                      !val; // if val is true (enable), disabled=false
                  _updateServer(name, newConfig);
                },
                activeColor: Colors.green,
                inactiveTrackColor: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              onPressed: () => _confirmDeleteServer(name),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建分割线标题
  Widget _buildSectionDivider(String title, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(36, 12, 24, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            title.contains('全局') ? Icons.public : Icons.folder_special,
            size: 14,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建继承的 MCP 服务器项
  Widget _buildInheritedServerItem(
    String name,
    dynamic config, {
    required bool isDisabled,
    required ValueChanged<bool> onToggle,
  }) {
    final cmd = config is Map ? config['command'] ?? '' : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = !isDisabled;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.deepPurple.withOpacity(0.05)
            : Colors.deepPurple.withOpacity(0.02),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.shade50,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 36, right: 24),
        dense: true,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.deepPurple.withOpacity(0.2)
                : Colors.deepPurple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.deepPurple.withOpacity(0.3),
            ),
          ),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            // 继承标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '继承',
                style: TextStyle(
                  fontSize: 9,
                  color: isDark ? Colors.deepPurple.shade200 : Colors.deepPurple,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // 状态标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isEnabled
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isEnabled ? '已启用' : '已禁用',
                style: TextStyle(
                  fontSize: 10,
                  color: isEnabled ? Colors.green : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          cmd.toString(),
          style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
        ),
        trailing: Transform.scale(
          scale: 0.7,
          child: Switch(
            value: isEnabled,
            onChanged: onToggle,
            activeColor: Colors.green,
            inactiveTrackColor: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  /// 切换继承 MCP 的启用状态
  void _toggleInheritedServer(String name, bool enabled) {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final content = Map<String, dynamic>.from(widget.profile.content);

    List<String> disabledMcpServers = (content['disabledMcpServers'] is List)
        ? List<String>.from(content['disabledMcpServers'])
        : [];

    if (enabled) {
      // 启用：从禁用列表中移除
      disabledMcpServers.remove(name);
    } else {
      // 禁用：添加到禁用列表
      if (!disabledMcpServers.contains(name)) {
        disabledMcpServers.add(name);
      }
    }

    content['disabledMcpServers'] = disabledMcpServers;

    final updatedProfile = McpProfile(
      id: widget.profile.id,
      name: widget.profile.name,
      description: widget.profile.description,
      content: content,
    );

    configService.saveProfile(EditorType.claude, updatedProfile);
  }
}
