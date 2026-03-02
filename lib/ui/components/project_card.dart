import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/mcp_profile.dart';
import '../../models/mcp_server_health.dart';
import '../../models/editor_type.dart';
import '../../services/config_service.dart';
import '../../services/mcp_health_check_service.dart';
import '../../utils/platform_utils.dart';
import '../../services/terminal_service.dart';
import '../pages/mcp_config/mcp_server_edit_screen.dart';
import 'custom_dialog.dart';
import 'custom_toast.dart';
import '../../l10n/s.dart';
import '../../utils/global_keys.dart';
import '../../utils/project_type_detector.dart';

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

  /// 项目级 MCP 健康状态：serverName -> 状态文字（Connected / Failed to connect / Needs authentication）
  final Map<String, String> _mcpHealthMap = {};
  bool _isCheckingHealth = false;
  bool _hasCheckedHealth = false;

  /// 授权操作自动退出定时器（1分钟后自动退出 Claude REPL）
  Timer? _authExitTimer;

  /// 项目类型图标信息
  ProjectIconInfo? _iconInfo;

  /// 判断是否是全局配置
  bool get _isGlobalProfile => widget.profile.content['isGlobal'] == true;

  @override
  void initState() {
    super.initState();
    _detectProjectType();
  }

  @override
  void dispose() {
    _authExitTimer?.cancel();
    super.dispose();
  }

  /// 异步检测项目类型
  Future<void> _detectProjectType() async {
    if (_isGlobalProfile) return;
    final dir = widget.profile.name;
    if (dir.isEmpty) return;
    final info = await ProjectTypeDetector.detect(dir);
    if (mounted) setState(() => _iconInfo = info);
  }

  /// 展开时执行 claude mcp list 获取连接状态
  /// [force] 为 true 时忽略已检查标识，强制重新检查
  Future<void> _checkProjectMcpHealth({bool force = false}) async {
    if (_isCheckingHealth || _isGlobalProfile) return;
    if (_hasCheckedHealth && !force) return;

    // 获取项目目录路径
    final projectDir = widget.profile.name;
    if (projectDir.isEmpty || !Directory(projectDir).existsSync()) return;

    setState(() => _isCheckingHealth = true);

    try {
      final result = await PlatformUtils.runCommand(
        'claude mcp list',
        workingDirectory: projectDir,
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (result.exitCode == 0) {
        _parseMcpListOutput(result.stdout as String);
      }
    } catch (_) {
      // 超时或其他错误，静默处理
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingHealth = false;
          _hasCheckedHealth = true;
        });
      }
    }
  }

  /// 解析 claude mcp list 输出
  void _parseMcpListOutput(String output) {
    _mcpHealthMap.clear();
    final lines = output.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('Checking')) continue;

      // ✓ Connected
      final connectedMatch = RegExp(r'^(.+?):\s*.+?\s*-\s*✓\s*Connected$').firstMatch(trimmed);
      if (connectedMatch != null) {
        _mcpHealthMap[connectedMatch.group(1)!.trim()] = 'Connected';
        continue;
      }

      // ✗ Failed to connect
      final failedMatch = RegExp(r'^(.+?):\s*.+?\s*-\s*✗\s*Failed to connect').firstMatch(trimmed);
      if (failedMatch != null) {
        _mcpHealthMap[failedMatch.group(1)!.trim()] = 'Failed';
        continue;
      }

      // ! Needs authentication
      final authMatch = RegExp(r'^(.+?):\s*.+?\s*-\s*!\s*Needs authentication').firstMatch(trimmed);
      if (authMatch != null) {
        _mcpHealthMap[authMatch.group(1)!.trim()] = 'Needs auth';
        continue;
      }
    }
  }

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

  /// 打开终端面板，cd 到项目目录并执行 claude 进入 REPL 授权
  void _openAuthTerminal() {
    final terminalService = Provider.of<TerminalService>(context, listen: false);
    final projectDir = widget.profile.name;

    // 打开终端面板
    terminalService.openTerminalPanel();

    // 延迟确保终端已初始化，cd + claude 进入 REPL
    Future.delayed(const Duration(milliseconds: 500), () {
      terminalService.sendCommand('cd "$projectDir" && claude');
    });

    // 启动2分钟自动退出定时器，防止 REPL 会话占用
    _authExitTimer?.cancel();
    _authExitTimer = Timer(const Duration(minutes: 2), () {
      // 先用 Escape 退出可能的 TUI 子界面
      terminalService.writeToPty('\x1b');
      Future.delayed(const Duration(milliseconds: 300), () {
        // 发送 /exit 尝试正常退出 REPL
        terminalService.writeToPty('/exit');
        Future.delayed(const Duration(milliseconds: 500), () {
          terminalService.writeToPty('\r');
          Future.delayed(const Duration(milliseconds: 1000), () {
            // Ctrl+C 兜底，确保退出
            terminalService.writeToPty('\x03');
          });
        });
      });
    });

    // 等 REPL 启动后，用 writeToPty 发 /mcp + 回车（TUI 模式必须用 raw bytes）
    Future.delayed(const Duration(milliseconds: 3000), () {
      terminalService.writeToPty('/mcp');
      Future.delayed(const Duration(milliseconds: 800), () {
        terminalService.writeToPty('\r');
        // 用 globalNavigatorKey 的 context 弹 Toast，确保层级在终端面板之上
        final ctx = globalNavigatorKey.currentContext;
        if (ctx != null) {
          Toast.show(
            ctx,
            message: '已进入 /mcp 菜单，请用方向键选择需要授权的 MCP 后回车。操作完成后请 Ctrl+C 退出 Claude 环境，以防会话占用（1分钟后将自动退出）',
            type: ToastType.info,
            duration: const Duration(seconds: 6),
          );
        }
      });
    });
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
            onExpansionChanged: (expanded) {
              if (expanded && !_isGlobalProfile) {
                _checkProjectMcpHealth();
              }
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: _buildProjectIcon(isDark, borderColor),
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
              Stack(
                children: [
                  // 展开内容主体
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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

                      // Add Button + Test Connection Button
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton.icon(
                              onPressed: _addServer,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add MCP Server'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 刷新连接状态按钮（仅项目级配置显示）
                            if (!_isGlobalProfile)
                              TextButton.icon(
                                onPressed: _isCheckingHealth
                                    ? null
                                    : () => _checkProjectMcpHealth(force: true),
                                icon: _isCheckingHealth
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.deepPurple,
                                        ),
                                      )
                                    : const Icon(Icons.refresh, size: 14),
                                label: Text(
                                  _isCheckingHealth ? 'Checking...' : 'Refresh Status',
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.deepPurple,
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            // 测试连接按钮（仅全局配置显示）
                            if (_isGlobalProfile)
                              Consumer<McpHealthCheckService>(
                                builder: (context, healthService, _) {
                                  return TextButton.icon(
                                    onPressed: healthService.isChecking
                                        ? null
                                        : () => healthService.checkAllServers(force: true),
                                    icon: healthService.isChecking
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.deepPurple,
                                            ),
                                          )
                                        : const Icon(Icons.network_check, size: 14),
                                    label: Text(
                                      healthService.isChecking
                                          ? S.get('checking_connection')
                                          : S.get('test_connection'),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.deepPurple,
                                      textStyle: const TextStyle(fontSize: 12),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // loading 蒙层
                  if (_isCheckingHealth && !_isGlobalProfile)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.deepPurple,
                            ),
                          ),
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

  Widget _buildServerItem(String name, dynamic config) {
    final cmd = config is Map ? config['command'] ?? '' : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final healthService = Provider.of<McpHealthCheckService>(context);
    final health = healthService.getServerHealth(name);

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
        leading: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            children: [
              Container(
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
              // 健康状态指示器（右下角）- 仅启用状态的服务器显示
              if (health != null && isEnabled)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _buildHealthIndicator(health),
                ),
            ],
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
            if (_mcpHealthMap.containsKey(name) && _mcpHealthMap[name] != 'Connected') ...[
              const SizedBox(width: 6),
              _buildConnectionStatusTag(_mcpHealthMap[name]!),
              if (_mcpHealthMap[name] == 'Needs auth')
                _buildAuthButton(),
            ],
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
            if (_mcpHealthMap.containsKey(name) && _mcpHealthMap[name] != 'Connected') ...[
              const SizedBox(width: 6),
              _buildConnectionStatusTag(_mcpHealthMap[name]!),
              if (_mcpHealthMap[name] == 'Needs auth')
                _buildAuthButton(),
            ],
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

  /// 构建连接状态标签（Connected / Failed / Needs auth）
  Widget _buildConnectionStatusTag(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'Connected':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        label = 'Connected';
        break;
      case 'Failed':
        bgColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red;
        label = 'Failed';
        break;
      case 'Needs auth':
        bgColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        label = 'Needs auth';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 构建项目图标（根据检测到的项目类型或 favicon 显示）
  Widget _buildProjectIcon(bool isDark, Color borderColor) {
    final info = _iconInfo;
    // 有 favicon 时显示本地图片
    if (info?.faviconPath != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
          border: Border.all(color: borderColor),
        ),
        child: ClipOval(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Image.file(
              File(info!.faviconPath!),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                Icons.folder_open,
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
          ),
        ),
      );
    }

    // 根据项目类型显示对应图标
    final type = info?.type ?? ProjectType.unknown;
    final iconData = ProjectTypeDetector.getIcon(type);
    final iconColor = type == ProjectType.unknown
        ? (isDark ? Colors.white70 : Colors.grey)
        : ProjectTypeDetector.getColor(type);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
        border: Border.all(color: borderColor),
      ),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  /// 构建授权按钮（Needs auth 旁边的小钥匙图标）
  Widget _buildAuthButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: _openAuthTerminal,
        child: Tooltip(
          message: '打开终端授权',
          child: Container(
            padding: const EdgeInsets.all(2),
            child: const Icon(
              Icons.vpn_key,
              size: 12,
              color: Colors.orange,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建健康状态指示器
  Widget _buildHealthIndicator(McpServerHealth health) {
    return GestureDetector(
      onTap: !health.isHealthy ? () => _showHealthErrorDialog(health) : null,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: health.isHealthy ? Colors.green : Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: (health.isHealthy ? Colors.green : Colors.red).withOpacity(0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Icon(
          health.isHealthy ? Icons.check : Icons.close,
          size: 8,
          color: Colors.white,
        ),
      ),
    );
  }

  /// 显示健康检查错误详情弹窗
  void _showHealthErrorDialog(McpServerHealth health) {
    CustomConfirmDialog.show(
      context,
      title: S.get('connection_error'),
      content: '${health.serverName}\n\n${health.errorMessage ?? S.get('unknown_error')}',
      confirmText: S.get('ok'),
      cancelText: '',
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
