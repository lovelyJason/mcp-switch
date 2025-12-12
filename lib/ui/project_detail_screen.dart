import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/editor_type.dart';
import '../../models/mcp_profile.dart';
import '../../services/config_service.dart';
import 'mcp_server_edit_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final EditorType editorType;
  final McpProfile projectProfile;

  const ProjectDetailScreen({
    super.key,
    required this.editorType,
    required this.projectProfile,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  // Local state of mcpServers map
  late Map<String, dynamic> _mcpServers;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  void _loadServers() {
    final content = widget.projectProfile.content;
    if (content['mcpServers'] is Map) {
      _mcpServers = Map<String, dynamic>.from(content['mcpServers']);
    } else {
      _mcpServers = {};
    }
  }

  Future<void> _saveChanges() async {
    // Construct new content preserving other keys if any (though currently we just use mcpServers)
    // IMPORTANT: In ConfigService logic, we might need to be careful not to lose other project keys if they existed in file.
    // However, ConfigService logic currently 'updates' mcpServers key in the project map.
    
    final newContent = Map<String, dynamic>.from(widget.projectProfile.content);
    newContent['mcpServers'] = _mcpServers;

    final updatedProfile = McpProfile(
      id: widget.projectProfile.id,
      name: widget.projectProfile.name,
      description: widget.projectProfile.description,
      content: newContent,
    );

    await Provider.of<ConfigService>(context, listen: false)
        .saveProfile(widget.editorType, updatedProfile);
        
    setState(() {}); // Refresh UI
  }

  void _addServer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => McpServerEditScreen(
          editorType: widget.editorType,
          onSave: (name, config) {
            setState(() {
              _mcpServers[name] = config;
            });
            _saveChanges();
          },
        ),
      ),
    );
  }

  void _editServer(String name, Map<String, dynamic> config) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => McpServerEditScreen(
          editorType: widget.editorType,
          initialData: {'name': name, 'config': config},
          isPathReadOnly: true, // Server name is the key, usually editable but let's allow rename?
          // If we allow rename, we must remove old key and add new key.
          // McpServerEditScreen passes 'name' and 'config'.
          onSave: (newName, newConfig) {
            setState(() {
              if (newName != name) {
                _mcpServers.remove(name);
              }
              _mcpServers[newName] = newConfig;
            });
            _saveChanges();
          },
        ),
      ),
    );
  }

  void _deleteServer(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Server?'),
        content: Text('Remove "$name" from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _mcpServers.remove(name);
              });
              _saveChanges();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Top Bar Customization
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Project Config',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.projectProfile.name, // The path
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Menlo', // Monospace for path
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _addServer,
                    icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28),
                    tooltip: 'Add MCP Server to Project',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Server List
            Expanded(
              child: _mcpServers.isEmpty
                  ? Center(
                      child: Text(
                        'No MCP Servers in this project',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: _mcpServers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final name = _mcpServers.keys.elementAt(index);
                        final config = _mcpServers[name];
                        return _buildServerCard(name, config);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(String name, dynamic config) {
    final cmd = config is Map ? config['command'] ?? '?' : '?';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'M',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Command: $cmd',
          style: TextStyle(fontFamily: 'Menlo', fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20, color: Colors.grey),
              onPressed: () => _editServer(name, config is Map ? Map<String, dynamic>.from(config) : {}),
            ),
             IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
              onPressed: () => _deleteServer(name),
            ),
          ],
        ),
      ),
    );
  }
}
