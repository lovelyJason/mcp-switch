import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/platform_commands_config.dart';
import '../../services/logger_service.dart';
import '../../utils/platform_utils.dart';
import '../../utils/global_keys.dart';
import 'package:provider/provider.dart';
import '../../services/update_service.dart';
import 'custom_toast.dart';
import 'mcp_failed_dialog.dart';
import 'update_progress_overlay.dart';

/// 悬浮 Debug 按钮（仅在 Debug 模式下显示）
/// 用于开发调试功能
class FloatingDebugButton extends StatefulWidget {
  const FloatingDebugButton({super.key});

  @override
  State<FloatingDebugButton> createState() => _FloatingDebugButtonState();
}

class _FloatingDebugButtonState extends State<FloatingDebugButton> {
  // 按钮位置（右下角）
  double _right = 80;
  double _bottom = 20;

  @override
  Widget build(BuildContext context) {
    // 仅在 Debug 模式下显示
    if (kReleaseMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: _right,
      bottom: _bottom,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _right -= details.delta.dx;
            _bottom -= details.delta.dy;
            // 限制范围
            _right = _right.clamp(10.0, MediaQuery.of(context).size.width - 60);
            _bottom = _bottom.clamp(10.0, MediaQuery.of(context).size.height - 60);
          });
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDebugDialog(context),
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.bug_report,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDebugDialog(BuildContext context) {
    // 使用全局 NavigatorKey，因为 Debug 按钮在 Overlay 中，不在 Navigator 树下
    final navigatorContext = globalNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    showDialog(
      context: navigatorContext,
      builder: (context) => const _DebugDialog(),
    );
  }
}

/// Debug 弹窗
class _DebugDialog extends StatefulWidget {
  const _DebugDialog();

  @override
  State<_DebugDialog> createState() => _DebugDialogState();
}

class _DebugDialogState extends State<_DebugDialog> {
  bool _isLoading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 480,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Text('Debug Tools',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (Platform.isWindows) ...[
                        _buildSection(
                          title: 'Claude CLI Detection',
                          children: [
                            _buildDebugButton(
                              icon: Icons.search,
                              label: 'Find Claude.exe',
                              description: '递归搜索 .claude 目录查找 claude.exe',
                              onTap: _findClaudeExe,
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 8),
                            _buildDebugButton(
                              icon: Icons.check_circle,
                              label: 'Check Claude Installed',
                              description: '执行完整的安装检测逻辑',
                              onTap: _checkClaudeInstalled,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildSection(
                        title: 'Platform Commands Config',
                        children: [
                          _buildDebugButton(
                            icon: Icons.refresh,
                            label: 'Force Reload from Assets',
                            description: '删除用户配置，从 assets 重新复制',
                            onTap: _forceReloadConfig,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 8),
                          _buildDebugButton(
                            icon: Icons.folder_open,
                            label: 'Open Config Folder',
                            description: '打开配置文件所在目录',
                            onTap: _openConfigFolder,
                          ),
                          const SizedBox(height: 8),
                          _buildDebugButton(
                            icon: Icons.sync,
                            label: 'Reload Config',
                            description: '重新加载用户配置（不删除）',
                            onTap: _reloadConfig,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'App Storage',
                        children: [
                          _buildDebugButton(
                            icon: Icons.storage,
                            label: 'SharedPreferences Editor',
                            description: '查看和编辑本地存储的键值对',
                            onTap: _openSharedPrefsEditor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'MCP Diagnostic',
                        children: [
                          _buildDebugButton(
                            icon: Icons.link_off,
                            label: 'MCP Connection Diagnostic',
                            description: '选择 MCP 服务器查看连接失败诊断',
                            onTap: _openMcpDiagnostic,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSection(
                        title: 'Update',
                        children: [
                          _buildDebugButton(
                            icon: Icons.system_update_alt,
                            label: 'Update Progress UI Demo',
                            description: '预览更新下载进度遮罩弹窗效果',
                            onTap: _showUpdateDemo,
                          ),
                          const SizedBox(height: 8),
                          _buildDebugButton(
                            icon: Icons.new_releases_outlined,
                            label: 'Fake New Version Banner',
                            description: '伪造新版本，首页显示更新横幅',
                            onTap: _fakeUpdateBanner,
                          ),
                        ],
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _message!.contains('成功') || _message!.contains('完成')
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _message!.contains('成功') || _message!.contains('完成')
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDebugButton({
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 20, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _forceReloadConfig() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await PlatformCommandsConfig.forceReloadFromAssets();
      setState(() {
        _message = '✅ 配置已从 assets 重新加载完成';
      });
      LoggerService.info('Debug: Force reload config from assets');
    } catch (e) {
      setState(() {
        _message = '❌ 加载失败: $e';
      });
      LoggerService.error('Debug: Force reload config failed', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openConfigFolder() async {
    try {
      await PlatformCommandsConfig.openConfigFolder();
      setState(() {
        _message = '📁 已打开配置目录';
      });
    } catch (e) {
      setState(() {
        _message = '❌ 打开失败: $e';
      });
    }
  }

  Future<void> _reloadConfig() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      await PlatformCommandsConfig.reload();
      setState(() {
        _message = '✅ 配置已重新加载';
      });
      LoggerService.info('Debug: Reload config');
    } catch (e) {
      setState(() {
        _message = '❌ 加载失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _findClaudeExe() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final path = await PlatformUtils.findClaudeExePath();
      setState(() {
        if (path != null) {
          _message = '✅ 找到 Claude CLI:\n$path';
        } else {
          _message = '❌ 未找到 claude.exe\n检测路径: ${PlatformCommandsConfig.claudeDetectPaths.join(', ')}';
        }
      });
      LoggerService.info('Debug: Find Claude.exe result: $path');
    } catch (e) {
      setState(() {
        _message = '❌ 搜索失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkClaudeInstalled() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final isInstalled = await PlatformUtils.isClaudeInstalled();
      final version = await PlatformUtils.getClaudeVersion();
      setState(() {
        if (isInstalled) {
          _message = '✅ Claude CLI 已安装${version != null ? '\n版本: $version' : ''}';
        } else {
          _message = '❌ Claude CLI 未安装';
        }
      });
      LoggerService.info('Debug: Check Claude installed: $isInstalled, version: $version');
    } catch (e) {
      setState(() {
        _message = '❌ 检测失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openSharedPrefsEditor() {
    Navigator.of(context).pop();
    showDialog(
      context: globalNavigatorKey.currentContext!,
      builder: (context) => const _SharedPrefsEditorDialog(),
    );
  }

  void _openMcpDiagnostic() {
    Navigator.of(context).pop();
    _showMcpServerPicker();
  }

  void _showUpdateDemo() {
    Navigator.of(context).pop();
    UpdateProgressOverlay.showDemo(globalNavigatorKey.currentContext!);
  }

  void _fakeUpdateBanner() {
    final ctx = globalNavigatorKey.currentContext!;
    final service = Provider.of<UpdateService>(ctx, listen: false);
    if (service.hasUpdate) {
      service.debugClearFakeUpdate();
      setState(() => _message = '已清除伪造更新');
    } else {
      service.debugFakeUpdate();
      Navigator.of(context).pop();
      Toast.show(ctx, message: '已伪造 v99.0.0 新版本，返回首页查看横幅', type: ToastType.info);
    }
  }

  Future<void> _showMcpServerPicker() async {
    final ctx = globalNavigatorKey.currentContext!;
    final servers = await _loadAllMcpServers();
    if (servers.isEmpty) {
      if (ctx.mounted) {
        Toast.show(ctx, message: '未找到任何 MCP 服务器配置', type: ToastType.warning);
      }
      return;
    }
    if (!ctx.mounted) return;
    showDialog(
      context: ctx,
      builder: (context) => _McpServerPickerDialog(servers: servers),
    );
  }

  Future<Map<String, Map<String, dynamic>>> _loadAllMcpServers() async {
    final home = PlatformUtils.userHome;
    final configPath = PlatformUtils.joinPath(home, '.claude.json');
    final file = File(configPath);
    if (!await file.exists()) return {};

    try {
      final content = jsonDecode(await file.readAsString());
      if (content is! Map<String, dynamic>) return {};

      final result = <String, Map<String, dynamic>>{};

      final globalServers = content['mcpServers'];
      if (globalServers is Map) {
        for (final entry in globalServers.entries) {
          if (entry.value is Map) {
            result['[Global] ${entry.key}'] = Map<String, dynamic>.from(
              entry.value,
            );
          }
        }
      }

      final projects = content['projects'];
      if (projects is Map) {
        for (final projEntry in projects.entries) {
          final projConfig = projEntry.value;
          if (projConfig is Map && projConfig['mcpServers'] is Map) {
            final projPath = projEntry.key.toString();
            final shortPath = projPath.split('/').last;
            final projServers = projConfig['mcpServers'] as Map;
            for (final sEntry in projServers.entries) {
              if (sEntry.value is Map) {
                result['[$shortPath] ${sEntry.key}'] =
                    Map<String, dynamic>.from(sEntry.value);
              }
            }
          }
        }
      }

      return result;
    } catch (e) {
      LoggerService.error('Failed to load MCP servers: $e');
      return {};
    }
  }
}

/// SharedPreferences 编辑器弹窗
class _SharedPrefsEditorDialog extends StatefulWidget {
  const _SharedPrefsEditorDialog();

  @override
  State<_SharedPrefsEditorDialog> createState() => _SharedPrefsEditorDialogState();
}

class _SharedPrefsEditorDialogState extends State<_SharedPrefsEditorDialog> {
  Map<String, dynamic> _prefs = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, dynamic> data = {};

      for (final key in keys) {
        final value = prefs.get(key);
        data[key] = value;
      }

      setState(() {
        _prefs = Map.fromEntries(
          data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.storage, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Text('SharedPreferences'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadPrefs,
            tooltip: '刷新',
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Error: $_error'))
                : _prefs.isEmpty
                    ? const Center(child: Text('No data stored'))
                    : ListView.separated(
                        itemCount: _prefs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final key = _prefs.keys.elementAt(index);
                          final value = _prefs[key];
                          return _buildPrefItem(key, value, isDark);
                        },
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildPrefItem(String key, dynamic value, bool isDark) {
    final typeLabel = _getTypeLabel(value);
    final displayValue = _getDisplayValue(value);

    return InkWell(
      onTap: () => _showEditDialog(key, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getTypeColor(value).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                typeLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _getTypeColor(value),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Key 和 Value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 删除按钮
            IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
              onPressed: () => _deleteKey(key),
              tooltip: '删除',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(dynamic value) {
    if (value is bool) return 'BOOL';
    if (value is int) return 'INT';
    if (value is double) return 'DOUBLE';
    if (value is String) {
      if (_isJsonString(value)) return 'JSON';
      return 'STRING';
    }
    if (value is List<String>) return 'LIST';
    return 'UNKNOWN';
  }

  Color _getTypeColor(dynamic value) {
    if (value is bool) return Colors.purple;
    if (value is int) return Colors.blue;
    if (value is double) return Colors.teal;
    if (value is String) {
      if (_isJsonString(value)) return Colors.orange;
      return Colors.green;
    }
    if (value is List<String>) return Colors.indigo;
    return Colors.grey;
  }

  String _getDisplayValue(dynamic value) {
    if (value is bool) return value ? 'true' : 'false';
    if (value is String && _isJsonString(value)) {
      try {
        final decoded = jsonDecode(value);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        return value;
      }
    }
    if (value is List<String>) return '[${value.join(', ')}]';
    return value.toString();
  }

  bool _isJsonString(String value) {
    if (!value.startsWith('{') && !value.startsWith('[')) return false;
    try {
      jsonDecode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteKey(String key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 "$key" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      _loadPrefs();
    }
  }

  Future<void> _showEditDialog(String key, dynamic value) async {
    final result = await showDialog<dynamic>(
      context: context,
      builder: (context) => _PrefEditDialog(prefKey: key, value: value),
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();

      if (value is bool) {
        await prefs.setBool(key, result as bool);
      } else if (value is int) {
        await prefs.setInt(key, result as int);
      } else if (value is double) {
        await prefs.setDouble(key, result as double);
      } else if (value is String) {
        await prefs.setString(key, result as String);
      } else if (value is List<String>) {
        await prefs.setStringList(key, result as List<String>);
      }

      _loadPrefs();
    }
  }
}

/// 单个值的编辑弹窗
class _PrefEditDialog extends StatefulWidget {
  final String prefKey;
  final dynamic value;

  const _PrefEditDialog({required this.prefKey, required this.value});

  @override
  State<_PrefEditDialog> createState() => _PrefEditDialogState();
}

class _PrefEditDialogState extends State<_PrefEditDialog> {
  late TextEditingController _controller;
  bool? _boolValue;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    if (widget.value is bool) {
      _boolValue = widget.value;
      _controller = TextEditingController();
    } else if (widget.value is String && _isJsonString(widget.value)) {
      // 格式化 JSON
      try {
        final decoded = jsonDecode(widget.value);
        _controller = TextEditingController(
          text: const JsonEncoder.withIndent('  ').convert(decoded),
        );
      } catch (_) {
        _controller = TextEditingController(text: widget.value.toString());
      }
    } else if (widget.value is List<String>) {
      _controller = TextEditingController(text: (widget.value as List).join('\n'));
    } else {
      _controller = TextEditingController(text: widget.value.toString());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isJsonString(String value) {
    if (!value.startsWith('{') && !value.startsWith('[')) return false;
    try {
      jsonDecode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isJson = widget.value is String && _isJsonString(widget.value);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('编辑: ${widget.prefKey}'),
      content: SizedBox(
        width: isJson ? 450 : 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.value is bool) ...[
              // 布尔值用下拉框
              DropdownButtonFormField<bool>(
                value: _boolValue,
                decoration: const InputDecoration(
                  labelText: '值',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: true, child: Text('true')),
                  DropdownMenuItem(value: false, child: Text('false')),
                ],
                onChanged: (v) => setState(() => _boolValue = v),
              ),
            ] else if (isJson) ...[
              // JSON 用多行编辑器
              const Text('JSON 编辑器', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(
                    fontFamily: Platform.isWindows ? 'Consolas' : 'Menlo',
                    fontSize: 12,
                  ),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorText!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ),
            ] else if (widget.value is List<String>) ...[
              // List 用多行编辑器（每行一个元素）
              const Text('每行一个元素', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              // 其他类型用单行文本框
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: '值',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                ),
                keyboardType: widget.value is int || widget.value is double
                    ? TextInputType.number
                    : TextInputType.text,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _save() {
    setState(() => _errorText = null);

    dynamic result;

    if (widget.value is bool) {
      result = _boolValue;
    } else if (widget.value is int) {
      final parsed = int.tryParse(_controller.text);
      if (parsed == null) {
        setState(() => _errorText = '请输入有效的整数');
        return;
      }
      result = parsed;
    } else if (widget.value is double) {
      final parsed = double.tryParse(_controller.text);
      if (parsed == null) {
        setState(() => _errorText = '请输入有效的数字');
        return;
      }
      result = parsed;
    } else if (widget.value is String && _isJsonString(widget.value)) {
      // 验证 JSON 格式
      try {
        jsonDecode(_controller.text);
        result = _controller.text;
      } catch (e) {
        setState(() => _errorText = 'JSON 格式错误: $e');
        return;
      }
    } else if (widget.value is List<String>) {
      result = _controller.text.split('\n').where((s) => s.isNotEmpty).toList();
    } else {
      result = _controller.text;
    }

    Navigator.pop(context, result);
  }
}

/// MCP 服务器选择弹窗 → 选中后打开 McpFailedDialog
class _McpServerPickerDialog extends StatelessWidget {
  final Map<String, Map<String, dynamic>> servers;

  const _McpServerPickerDialog({required this.servers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = servers.entries.toList();

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.dns_outlined, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          const Text('选择 MCP 服务器', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final label = entries[index].key;
              final config = entries[index].value;
              final domains = extractDomainsFromConfig(config);
              final subtitle = domains.isNotEmpty
                  ? domains.take(2).join(', ')
                  : (config['command']?.toString() ?? '');

              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(
                  Icons.extension_outlined,
                  size: 18,
                  color: isDark ? Colors.orange.shade300 : Colors.orange,
                ),
                title: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: subtitle.isNotEmpty
                    ? Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right, size: 16),
                onTap: () {
                  Navigator.of(context).pop();
                  final serverName = label.replaceFirst(
                    RegExp(r'^\[.*?\]\s*'),
                    '',
                  );
                  McpFailedDialog.show(
                    globalNavigatorKey.currentContext!,
                    serverName: serverName,
                    config: config,
                  );
                },
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
