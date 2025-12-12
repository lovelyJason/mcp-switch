
import 'package:flutter/material.dart';
import '../../models/mcp_profile.dart';

class ProfileCard extends StatefulWidget {
  final McpProfile profile;
  final bool isActive;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ProfileCard({
    super.key,
    required this.profile,
    required this.isActive,
    required this.onSelect,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final borderColor = widget.isActive 
        ? theme.primaryColor.withOpacity(0.5) 
        : (isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.withOpacity(0.2));
        
    final backgroundColor = widget.isActive 
        ? (isDark
              ? Colors.blue.withOpacity(0.15)
              : Colors.blue.withOpacity(0.05))
        : (isDark ? const Color(0xFF2C2C2E) : Colors.white);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            children: [
              // Drag Handle or Menu Icon
              Icon(Icons.drag_indicator, // Or dots logic
                  color: Colors.grey.withOpacity(0.4),
                  size: 20),
              
              const SizedBox(width: 12),
              
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade100,
                border: Border.all(
                  color: isDark ? Colors.transparent : Colors.grey.shade300,
                ),
                ),
                child: Center(
                  child: widget.profile.name.startsWith('/')
                      ? Icon(
                          Icons.folder_open,
                          color: Colors.grey.shade600,
                          size: 24,
                        )
                      : Text(
                          widget.profile.name.isNotEmpty
                              ? widget.profile.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.profile.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                      // Status Badge

                      const SizedBox(width: 8),
                      // Status Badge
                        Builder(
                          builder: (context) {
                            final mcpServers =
                                widget.profile.content['mcpServers'];
                            final server = (mcpServers is Map)
                                ? mcpServers[widget.profile.name]
                                : null;
                            bool isEnabled = true;
                            if (server is Map) {
                              if (server.containsKey('disabled')) {
                                isEnabled = server['disabled'] != true;
                              } else if (server.containsKey('enabled')) {
                                isEnabled = server['enabled'] == true;
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
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
                            );
                          },
                        ),
                        if (widget.isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '当前使用', // Changed to blue to distinguish
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.profile.description ?? widget.profile.officialLink ?? '未配置说明',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),


            // Actions (Only show on Hover)
            if (_isHovering || widget.isActive)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Builder(
                      builder: (context) {
                        final mcpServers = widget.profile.content['mcpServers'];
                        final server = (mcpServers is Map)
                            ? mcpServers[widget.profile.name]
                            : null;
                        bool isEnabled = true;
                        if (server is Map) {
                          if (server.containsKey('disabled')) {
                            isEnabled = server['disabled'] != true;
                          } else if (server.containsKey('enabled')) {
                            isEnabled = server['enabled'] == true;
                          }
                        }

                      return Transform.scale(
                        scale: 0.8,
                        child: Switch(
                          value: isEnabled,
                          onChanged: (_) => widget.onSelect(),
                          activeColor: Colors.green,
                          inactiveTrackColor: isDark
                              ? Colors.grey.shade800
                              : Colors.grey.shade300,
                          ),
                        );
                      }
                    ),


                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: widget.onEdit,
                      tooltip: 'Edit',
                    ),

                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: widget.onDelete,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
