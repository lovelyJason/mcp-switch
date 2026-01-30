import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../config/mcp_presets_config.dart';
import '../../../models/editor_type.dart';
import '../../../models/mcp_profile.dart';
import '../../../services/config_service.dart';
import '../../../services/terminal_service.dart';
import '../../../l10n/s.dart';
import '../../components/custom_toast.dart';
import 'edit/mcp_edit_widgets.dart';
import 'edit/mcp_preset_utils.dart';

class McpServerEditScreen extends StatefulWidget {
  final EditorType editorType;
  final McpProfile? profile; // If null, Add mode; else Edit mode

  final void Function(String name, Map<String, dynamic> config)? onSave;
  final Map<String, dynamic>? initialData;
  final bool isPathReadOnly;

  const McpServerEditScreen({
    super.key,
    required this.editorType,
    this.profile,
    this.onSave,
    this.initialData,
    this.isPathReadOnly = false,
  });

  @override
  State<McpServerEditScreen> createState() => _McpServerEditScreenState();
}

class _McpServerEditScreenState extends State<McpServerEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _commandController = TextEditingController();
  final _argsController = TextEditingController();
  final _jsonController = TextEditingController();

  // 动态表单字段 controllers (根据配置生成)
  final Map<String, TextEditingController> _dynamicFieldControllers = {};

  bool _isUpdating = false;
  String _selectedPresetId = 'custom';
  String _selectedConnectionType = 'local'; // local, http, sse

  // Claude 保存方式
  String _claudeSaveMode = 'cli';

  // 当前选择的编辑器类型（支持切换）
  late EditorType _currentEditorType;

  // 草稿缓存 key
  static const _draftNameKey = 'mcp_edit_draft_name';
  static const _draftConnectionTypeKey = 'mcp_edit_draft_connection_type';
  static const _draftJsonKey = 'mcp_edit_draft_json';

  // FocusNode 用于监听失焦保存草稿
  final _jsonFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentEditorType = widget.editorType;
    _initializePresets();

    // 监听 JSON 输入框失焦事件，自动保存草稿
    _jsonFocusNode.addListener(_onJsonFocusChanged);

    if (widget.initialData != null) {
      _initFromData(widget.initialData!);
    } else if (widget.profile != null) {
      _initFromProfile();
    } else {
      // 新建模式：尝试加载草稿
      _loadDraft();
    }
  }

  void _onJsonFocusChanged() {
    // 失焦时保存草稿（仅新建模式）
    if (!_jsonFocusNode.hasFocus && widget.profile == null && widget.initialData == null) {
      _saveDraft();
    }
  }

  /// 加载草稿缓存
  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftName = prefs.getString(_draftNameKey);
    final draftConnectionType = prefs.getString(_draftConnectionTypeKey);
    final draftJson = prefs.getString(_draftJsonKey);

    if (draftName != null || draftJson != null) {
      setState(() {
        if (draftName != null && draftName.isNotEmpty) {
          _nameController.text = draftName;
        }
        if (draftConnectionType != null) {
          _selectedConnectionType = draftConnectionType;
        }
        if (draftJson != null && draftJson.isNotEmpty) {
          _jsonController.text = draftJson;
        } else {
          _updateJsonFromForm();
        }
      });
    } else {
      _updateJsonFromForm();
    }
  }

  /// 保存草稿到缓存
  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftNameKey, _nameController.text);
    await prefs.setString(_draftConnectionTypeKey, _selectedConnectionType);
    await prefs.setString(_draftJsonKey, _jsonController.text);
  }

  /// 清除草稿缓存
  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftNameKey);
    await prefs.remove(_draftConnectionTypeKey);
    await prefs.remove(_draftJsonKey);
  }

  /// 切换编辑器类型
  void _onEditorTypeChanged(EditorType newType) {
    if (newType == _currentEditorType) return;

    setState(() {
      _currentEditorType = newType;
      // 重置表单状态
      _selectedPresetId = 'custom';
      _selectedConnectionType = 'local';
      _nameController.clear();
      _commandController.clear();
      _argsController.clear();
      _jsonController.clear();
      for (final controller in _dynamicFieldControllers.values) {
        controller.clear();
      }
      // 重新生成空配置
      _updateJsonFromForm();
    });
  }

  Future<void> _initializePresets() async {
    // 确保预设配置已加载
    await McpPresetsConfig.init();
    if (mounted) setState(() {});
  }

  void _initFromData(Map<String, dynamic> data) {
    if (data.containsKey('name')) {
      _nameController.text = data['name'];
    }

    final config = data['config'] ?? {};

    // 根据配置内容判断连接类型
    final configType = config['type']?.toString() ?? '';
    if (configType == 'http') {
      _selectedConnectionType = 'http';
    } else if (configType == 'sse') {
      _selectedConnectionType = 'sse';
    } else {
      // stdio 或其他都算 local
      _selectedConnectionType = 'local';
      _commandController.text = config['command'] ?? '';
      final args = config['args'];
      if (args is List) {
        _argsController.text = args.join('\n');
      }
    }

    _jsonController.text = const JsonEncoder.withIndent('  ').convert(config);
  }

  void _initFromProfile() {
    _nameController.text = widget.profile!.name;

    final content = widget.profile!.content;
    Map<String, dynamic> serverConfig = {};

    if (content['mcpServers'] != null &&
        content['mcpServers'][widget.profile!.name] != null) {
      serverConfig = content['mcpServers'][widget.profile!.name];
    } else {
      serverConfig = content;
    }

    // 根据配置内容判断连接类型
    final configType = serverConfig['type']?.toString() ?? '';
    if (configType == 'http') {
      _selectedConnectionType = 'http';
    } else if (configType == 'sse') {
      _selectedConnectionType = 'sse';
    } else {
      // stdio 或其他都算 local
      _selectedConnectionType = 'local';
      _commandController.text = serverConfig['command'] ?? '';
      final args = serverConfig['args'];
      if (args is List) {
        _argsController.text = args.join('\n');
      }
    }

    _jsonController.text =
        const JsonEncoder.withIndent('  ').convert(serverConfig);
  }

  @override
  void dispose() {
    _jsonFocusNode.removeListener(_onJsonFocusChanged);
    _jsonFocusNode.dispose();
    _nameController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _jsonController.dispose();
    for (final controller in _dynamicFieldControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 获取或创建动态字段的 controller
  TextEditingController _getFieldController(String fieldId) {
    return _dynamicFieldControllers.putIfAbsent(
      fieldId,
      () => TextEditingController(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 配置同步逻辑
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateJsonFromForm() {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      // 如果是 http/sse 模式，不要从 command/args 输入框同步
      // 因为 http/sse 模式不需要这些字段
      if (_selectedConnectionType == 'http' || _selectedConnectionType == 'sse') {
        _isUpdating = false;
        return;
      }

      final argsList = _argsController.text
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();

      final Map<String, dynamic> currentConfig = {
        'command': _commandController.text,
        'args': argsList,
      };

      // Claude 的 local 模式需要 type: stdio
      if (_currentEditorType == EditorType.claude) {
        currentConfig['type'] = 'stdio';
      }

      if (_currentEditorType == EditorType.codex) {
        final pName =
            _nameController.text.isEmpty ? 'server' : _nameController.text;
        _jsonController.text = McpPresetUtils.generateLocalToml(pName, currentConfig);
      } else {
        try {
          if (_jsonController.text.isNotEmpty) {
            final existing = jsonDecode(_jsonController.text);
            if (existing is Map<String, dynamic>) {
              existing.remove('command');
              existing.remove('args');
              currentConfig.addAll(existing);
            }
          }
        } catch (_) {}

        _jsonController.text =
            const JsonEncoder.withIndent('  ').convert(currentConfig);
      }
    } catch (e) {
      print('Sync Error: $e');
    } finally {
      _isUpdating = false;
    }
  }

  void _updateFormFromJson() {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final text = _jsonController.text;
      if (text.isEmpty) return;

      Map<String, dynamic> data = {};
      if (_currentEditorType == EditorType.codex) {
        data = McpPresetUtils.parseToml(text);
      } else {
        final decoded = jsonDecode(text);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      }

      if (data.containsKey('command')) {
        _commandController.text = data['command'].toString();
      }
      if (data.containsKey('args') && data['args'] is List) {
        _argsController.text = (data['args'] as List).join('\n');
      }
    } catch (e) {
      // Ignore error while typing
    } finally {
      _isUpdating = false;
    }
  }

  void _formatJson() {
    try {
      final text = _jsonController.text;
      if (text.isEmpty) return;

      if (_currentEditorType == EditorType.codex) {
        final data = McpPresetUtils.parseToml(text);
        final pName =
            _nameController.text.isEmpty ? 'server' : _nameController.text;
        _jsonController.text = McpPresetUtils.generateLocalToml(pName, data);
      } else {
        final dynamic json = jsonDecode(text);
        final prettyString = const JsonEncoder.withIndent('  ').convert(json);
        _jsonController.text = prettyString;
      }
    } catch (e) {
      Toast.show(context, message: S.get('format_error'), type: ToastType.error);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 预设选择逻辑（配置驱动）
  // ═══════════════════════════════════════════════════════════════════════════

  void _onPresetSelected(McpPreset preset) {
    _jsonController.clear();
    _selectedPresetId = preset.id;

    // 清空动态字段
    for (final controller in _dynamicFieldControllers.values) {
      controller.clear();
    }

    if (preset.isCustom) {
      _nameController.clear();
      _commandController.clear();
      _argsController.clear();
      _selectedConnectionType = 'local';
      _updateJsonFromForm();
    } else {
      // 优先使用 defaultCliName（CLI 专用名称），否则用 displayName
      _nameController.text = preset.defaultCliName ?? preset.displayName;

      // 选择推荐的连接类型
      final recommended = preset.recommendedConnectionType;
      if (recommended != null) {
        _selectedConnectionType = recommended.type;
        _applyConnectionTypeConfig(preset, recommended);
      }
    }

    setState(() {});
  }

  void _onConnectionTypeChanged(McpPreset preset, String connectionType) {
    _selectedConnectionType = connectionType;

    // 查找对应的连接配置
    final connectionConfig = preset.connectionTypes.firstWhere(
      (c) => c.type == connectionType,
      orElse: () => preset.connectionTypes.first,
    );

    _applyConnectionTypeConfig(preset, connectionConfig);
    setState(() {});
  }

  void _applyConnectionTypeConfig(
      McpPreset preset, McpConnectionType connectionConfig) {
    // 清空 JSON
    _jsonController.clear();

    if (connectionConfig.type == 'local') {
      // Local 模式：设置 command 和 args
      _commandController.text = connectionConfig.command ?? '';

      // 合并基础 args 和 extra_args（模板参数）
      final allArgs = [...connectionConfig.args];

      // 处理 extra_args 模板变量替换
      if (connectionConfig.extraArgs.isNotEmpty) {
        final fieldValues = <String, String>{};
        for (final field in preset.formFields) {
          fieldValues[field.id] = _getFieldController(field.id).text.trim();
        }

        for (final extraArg in connectionConfig.extraArgs) {
          var interpolated = extraArg;
          for (final entry in fieldValues.entries) {
            final placeholder = '{{${entry.key}}}';
            interpolated = interpolated.replaceAll(placeholder, entry.value);
          }
          allArgs.add(interpolated);
        }
      }

      _argsController.text = allArgs.join('\n');
      _updateJsonFromForm();
    } else {
      // Remote 模式 (http/sse)：生成对应的 JSON
      _commandController.clear();
      _argsController.clear();
      _generateRemoteConfig(preset, connectionConfig);
    }
  }

  void _generateRemoteConfig(
      McpPreset preset, McpConnectionType connectionConfig) {
    final fieldValues = <String, String>{};
    for (final field in preset.formFields) {
      fieldValues[field.id] = _getFieldController(field.id).text.trim();
    }

    final pName = _nameController.text.isEmpty ? 'server' : _nameController.text;

    // Codex 使用 TOML 格式
    if (_currentEditorType == EditorType.codex) {
      _jsonController.text = McpPresetUtils.generateRemoteToml(
        pName, connectionConfig, fieldValues);
      return;
    }

    // 其他编辑器使用统一的远程配置构建方法
    final config = McpPresetUtils.buildRemoteConfig(
      editorType: _currentEditorType,
      connectionConfig: connectionConfig,
      fieldValues: fieldValues,
    );
    _jsonController.text = McpPresetUtils.formatJson(config);
  }

  /// 动态表单字段值变化时更新配置
  void _onDynamicFieldChanged(McpPreset preset, McpFormField field) {
    final value = _getFieldController(field.id).text.trim();

    if (_selectedConnectionType == 'local') {
      // Local 模式：根据 apply_mode 处理
      if (field.applyMode == 'env') {
        _updateEnvField(field.envKey ?? field.id, value);
      } else if (field.applyMode == 'arg') {
        _updateArgField(field, value);
      } else {
        // 没有指定 apply_mode，检查是否有 extra_args 使用此字段
        final connectionConfig = preset.connectionTypes.firstWhere(
          (c) => c.type == _selectedConnectionType,
          orElse: () => preset.connectionTypes.first,
        );
        if (connectionConfig.extraArgs.any((arg) => arg.contains('{{${field.id}}}'))) {
          // extra_args 使用了此字段，重新应用配置
          _applyConnectionTypeConfig(preset, connectionConfig);
        }
      }
    } else {
      // Remote 模式：重新生成配置
      final connectionConfig = preset.connectionTypes.firstWhere(
        (c) => c.type == _selectedConnectionType,
        orElse: () => preset.connectionTypes.first,
      );
      _generateRemoteConfig(preset, connectionConfig);
    }
  }

  void _updateEnvField(String envKey, String value) {
    try {
      final text = _jsonController.text;
      Map<String, dynamic> config = {};

      if (text.isNotEmpty) {
        config = jsonDecode(text);
      }

      config['env'] ??= <String, dynamic>{};
      if (value.isNotEmpty) {
        config['env'][envKey] = value;
      } else {
        (config['env'] as Map).remove(envKey);
      }

      _jsonController.text = const JsonEncoder.withIndent('  ').convert(config);
    } catch (e) {
      final config = {
        'command': _commandController.text,
        'args': _argsController.text
            .trim()
            .split('\n')
            .where((s) => s.isNotEmpty)
            .toList(),
        'env': value.isNotEmpty ? {envKey: value} : {},
      };
      _jsonController.text = const JsonEncoder.withIndent('  ').convert(config);
    }
  }

  void _updateArgField(McpFormField field, String value) {
    final currentArgs = _argsController.text.trim().split('\n');
    final newArgs = <String>[];
    final argKey = field.argKey ?? '--${field.id}';

    // 移除旧的参数
    for (var arg in currentArgs) {
      if (arg.trim().isEmpty) continue;
      if (field.argFormat == 'equals') {
        if (!arg.startsWith('$argKey=')) {
          newArgs.add(arg);
        }
      } else {
        // space 格式：需要移除 --key 和下一行的 value
        if (arg != argKey) {
          newArgs.add(arg);
        }
      }
    }

    // 添加新参数
    if (value.isNotEmpty) {
      if (field.argFormat == 'equals') {
        // 在 --stdio 之前插入（如果存在）
        final stdioIndex = newArgs.indexOf('--stdio');
        if (stdioIndex != -1) {
          newArgs.insert(stdioIndex, '$argKey=$value');
        } else {
          newArgs.add('$argKey=$value');
        }
      } else {
        // space 格式
        newArgs.add(argKey);
        newArgs.add(value);
      }
    }

    _argsController.text = newArgs.join('\n');
    _updateJsonFromForm();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 导入/导出功能
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _importPresets() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['yaml', 'yml'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      final error = await McpPresetsConfig.importConfig(file.path!);

      if (error != null) {
        if (mounted) {
          Toast.show(context, message: error, type: ToastType.error);
        }
      } else {
        if (mounted) {
          Toast.show(
            context,
            message: S.get('import_success'),
            type: ToastType.success,
          );
          setState(() {}); // 刷新预设列表
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('import_failed')}: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<void> _exportPresets() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: S.get('export_presets'),
        fileName: 'mcp_presets.yaml',
        type: FileType.custom,
        allowedExtensions: ['yaml'],
      );

      if (result == null) return;

      final success = await McpPresetsConfig.exportConfig(result);

      if (mounted) {
        if (success) {
          Toast.show(
            context,
            message: S.get('export_success'),
            type: ToastType.success,
          );
        } else {
          Toast.show(
            context,
            message: McpPresetsConfig.lastError ?? S.get('export_failed'),
            type: ToastType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('export_failed')}: $e',
          type: ToastType.error,
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI 构建
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.profile != null || widget.initialData != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            EditHeader(
              editorType: _currentEditorType,
              isEditMode: isEditMode,
              claudeSaveMode: _claudeSaveMode,
              onSaveModeChanged: (mode) => setState(() => _claudeSaveMode = mode),
              onImport: _importPresets,
              onExport: _exportPresets,
              onBack: () => Navigator.of(context).pop(),
              onEditorTypeChanged: _onEditorTypeChanged,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 预设选择（仅新增模式）
                      if (!isEditMode) ...[
                        _buildPresetsSection(),
                        const SizedBox(height: 32),
                      ],

                      // 基本信息
                      _buildBasicInfoSection(),

                      // 连接类型选择（配置驱动）
                      _buildConnectionTypeSection(),

                      // 动态表单字段（配置驱动）
                      _buildDynamicFieldsSection(),

                      // Command/Args（仅 local 模式且非 custom）
                      _buildCommandArgsSection(),

                      // 配置预览
                      _buildPreviewSection(isDark),
                    ],
                  ),
                ),
              ),
            ),
            EditBottomBar(
              isEditMode: isEditMode,
              onCancel: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection() {
    final presets = McpPresetsConfig.presets;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SectionTitle(S.get('preset_mcp')),
            const Spacer(),
            // Smithery 按钮
            TextButton.icon(
              onPressed: () async {
                final uri = Uri.parse('https://smithery.ai/');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              icon: Icon(
                Icons.rocket_launch_outlined,
                size: 14,
                color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
              ),
              label: Text(
                'Smithery',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.deepPurple.shade300 : Colors.deepPurple,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 0,
          runSpacing: 10,
          children: presets
              .map((preset) => PresetChip(
                    preset: preset,
                    isSelected: _selectedPresetId == preset.id,
                    onTap: () => _onPresetSelected(preset),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(S.get('basic_info')),
        const SizedBox(height: 12),
        FieldLabel(label: S.get('mcp_name'), subLabel: S.get('name'), required: true),
        TextFormField(
          controller: _nameController,
          decoration: _inputDecoration(
            widget.isPathReadOnly ? S.get('not_editable') : S.get('mcp_name_hint'),
          ),
          readOnly: widget.isPathReadOnly,
          enabled: !widget.isPathReadOnly,
          onChanged: (_) => _updateJsonFromForm(),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) {
            if (v == null || v.isEmpty) {
              return S.get('name_required');
            }
            // CLI 名称只能包含英文、数字、连字符、下划线
            if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(v)) {
              return S.get('invalid_mcp_name_for_cli');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConnectionTypeSection() {
    // 编辑模式下隐藏连接类型选择器（无法确定原始预设）
    final isEditMode = widget.profile != null || widget.initialData != null;
    if (isEditMode) {
      return const SizedBox.shrink();
    }

    final preset = McpPresetsConfig.getPresetById(_selectedPresetId);
    final connectionDefs = McpPresetsConfig.connectionTypeDefinitions;

    // custom 模式：显示所有连接类型（使用 Radio 样式，与预设模式一致）
    if (preset != null && preset.isCustom) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          FieldLabel(label: S.get('connection_type')),
          const SizedBox(height: 8),
          Row(
            children: ['local', 'http', 'sse']
                .map((type) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: InkWell(
                        onTap: () => _onCustomConnectionTypeChanged(type),
                        borderRadius: BorderRadius.circular(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<String>(
                              value: type,
                              groupValue: _selectedConnectionType,
                              onChanged: (v) => _onCustomConnectionTypeChanged(v ?? 'local'),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 4),
                            Text(connectionDefs[type]?.displayLabel ?? type),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      );
    }

    // 非 custom 预设：根据配置显示连接类型
    if (preset == null || preset.connectionTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        FieldLabel(label: S.get('connection_type')),
        const SizedBox(height: 8),
        Row(
          children: preset.connectionTypes
              .map((connType) => ConnectionTypeRadio(
                    connType: connType,
                    groupValue: _selectedConnectionType,
                    def: connectionDefs[connType.type],
                    onChanged: (type) => _onConnectionTypeChanged(preset, type),
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// 自定义模式切换连接类型
  void _onCustomConnectionTypeChanged(String type) {
    setState(() {
      _selectedConnectionType = type;
      if (type == 'local') {
        _updateJsonFromForm();
      } else {
        // http/sse 模式清空 command/args，生成空的远程配置
        _commandController.clear();
        _argsController.clear();

        // 根据编辑器类型生成不同字段名
        // Windsurf/Antigravity 使用 serverUrl，Gemini 使用 httpUrl，其他使用 url
        Map<String, dynamic> config;
        if (_currentEditorType == EditorType.windsurf ||
            _currentEditorType == EditorType.antigravity) {
          config = {'type': type, 'serverUrl': ''};
        } else if (_currentEditorType == EditorType.gemini) {
          config = {'type': type, 'httpUrl': ''};
        } else {
          // Claude Code 需要 type 字段
          config = {'type': type, 'url': ''};
        }
        _jsonController.text = const JsonEncoder.withIndent('  ').convert(config);
      }
    });
  }

  Widget _buildDynamicFieldsSection() {
    final preset = McpPresetsConfig.getPresetById(_selectedPresetId);
    if (preset == null || preset.formFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: preset.formFields.map((field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            FieldLabel(
              label: field.displayLabel,
              subLabel: field.displaySubLabel,
              required: field.required,
            ),
            TextFormField(
              controller: _getFieldController(field.id),
              decoration: _inputDecoration(field.placeholder ?? ''),
              onChanged: (_) => _onDynamicFieldChanged(preset, field),
              validator: field.required
                  ? (v) => v?.isEmpty == true
                      ? '${field.displayLabel} ${S.get('is_required')}'
                      : null
                  : null,
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCommandArgsSection() {
    // 只有 local 模式才显示 command/args
    if (_selectedConnectionType != 'local') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        SectionTitle(S.get('mcp_detail')),
        const SizedBox(height: 12),
        FieldLabel(label: S.get('command'), subLabel: 'command'),
        TextFormField(
          controller: _commandController,
          decoration: _inputDecoration('e.g. npx, node, python'),
          onChanged: (_) => _updateJsonFromForm(),
        ),
        const SizedBox(height: 12),
        FieldLabel(label: S.get('args'), subLabel: 'args'),
        TextFormField(
          controller: _argsController,
          maxLines: 4,
          minLines: 2,
          decoration: _inputDecoration('e.g. -y\n@input/server'),
          onChanged: (_) => _updateJsonFromForm(),
        ),
      ],
    );
  }

  Widget _buildPreviewSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          children: [
            SectionTitle(
              '${S.get('config_preview')} ${_currentEditorType == EditorType.codex ? "(TOML)" : "(JSON)"}',
            ),
            const SizedBox(width: 6),
            Tooltip(
              richMessage: WidgetSpan(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    S.get('config_preview_tip'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              preferBelow: false,
              verticalOffset: 16,
              waitDuration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Icon(
                Icons.lightbulb_outline,
                size: 16,
                color: isDark ? Colors.white54 : Colors.grey.shade500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _formatJson,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text(
                S.get('format'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.black54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: TextFormField(
            controller: _jsonController,
            focusNode: _jsonFocusNode,
            maxLines: 12,
            minLines: 6,
            style: const TextStyle(
              fontFamily: 'Menlo',
              fontSize: 13,
              height: 1.4,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            onChanged: (_) => _updateFormFromJson(),
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (_currentEditorType == EditorType.codex) return null;
              try {
                jsonDecode(v);
                return null;
              } catch (e) {
                return S.get('invalid_json');
              }
            },
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
        fontSize: 13,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 保存逻辑
  // ═══════════════════════════════════════════════════════════════════════════

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    try {
      final name = _nameController.text.trim();
      final jsonText = _jsonController.text.trim();

      Map<String, dynamic> serverConfig = {};

      if (jsonText.isEmpty) {
        serverConfig = {
          'command': _commandController.text,
          'args': _argsController.text.trim().split('\n'),
        };
      } else {
        if (_currentEditorType == EditorType.codex) {
          serverConfig = McpPresetUtils.parseToml(jsonText);
        } else {
          serverConfig = jsonDecode(jsonText);
        }
      }

      if (widget.onSave != null) {
        widget.onSave!(name, serverConfig);
        _clearDraft(); // 保存成功，清除草稿
        Navigator.of(context).pop();
        return;
      }

      final configService = Provider.of<ConfigService>(context, listen: false);

      if (_currentEditorType == EditorType.claude && widget.profile == null) {
        if (_claudeSaveMode == 'cli') {
          // CLI 模式下校验名称格式：只能包含字母、数字、连字符、下划线
          if (!_isValidCliName(name)) {
            Toast.show(
              context,
              message: S.get('invalid_mcp_name_for_cli'),
              type: ToastType.error,
              duration: const Duration(seconds: 4),
            );
            return;
          }
          _clearDraft(); // 通过 CLI 添加，清除草稿
          _saveViaCli(name, serverConfig);
          return;
        }

        final profiles = configService.getProfiles(EditorType.claude);
        McpProfile? globalProfile;
        try {
          globalProfile = profiles.firstWhere(
            (p) =>
                p.content['isGlobal'] == true ||
                p.name == 'Global Configuration',
          );
        } catch (_) {}

        if (globalProfile != null) {
          final content = Map<String, dynamic>.from(globalProfile.content);
          final mcpServers = (content['mcpServers'] is Map)
              ? Map<String, dynamic>.from(content['mcpServers'])
              : <String, dynamic>{};

          mcpServers[name] = serverConfig;
          content['mcpServers'] = mcpServers;

          final updatedProfile = McpProfile(
            id: globalProfile.id,
            name: globalProfile.name,
            description: globalProfile.description,
            content: content,
          );

          configService.saveProfile(_currentEditorType, updatedProfile);
        } else {
          final fullContent = {
            'mcpServers': {name: serverConfig},
            'isGlobal': true,
          };
          final newProfile = McpProfile(
            id: const Uuid().v4(),
            name: 'Global Configuration',
            description: 'Global User Settings',
            content: fullContent,
          );
          configService.saveProfile(_currentEditorType, newProfile);
        }
      } else {
        final fullContent = {
          'mcpServers': {name: serverConfig},
        };

        final newProfile = McpProfile(
          id: widget.profile?.id ?? const Uuid().v4(),
          name: name,
          description: 'Configured via MCP Switch',
          content: fullContent,
        );
        configService.saveProfile(_currentEditorType, newProfile);
      }

      _clearDraft(); // 保存成功，清除草稿
      Navigator.of(context).pop();
    } catch (e) {
      Toast.show(context, message: 'Error saving: $e', type: ToastType.error);
    }
  }

  /// 校验名称是否符合 CLI 要求（只能包含字母、数字、连字符、下划线）
  bool _isValidCliName(String name) {
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(name);
  }

  Future<void> _saveViaCli(
      String name, Map<String, dynamic> serverConfig) async {
    final terminalService = context.read<TerminalService>();

    // 尝试从配置获取 CLI 命令模板
    String? cliCommand;
    final preset = McpPresetsConfig.getPresetById(_selectedPresetId);
    if (preset != null && !preset.isCustom) {
      // 找到当前连接类型的配置
      final connectionConfig = preset.connectionTypes.firstWhere(
        (c) => c.type == _selectedConnectionType,
        orElse: () => preset.connectionTypes.first,
      );

      // 收集表单字段值
      final fieldValues = <String, String>{};
      for (final field in preset.formFields) {
        fieldValues[field.id] = _getFieldController(field.id).text.trim();
      }

      // 使用配置模板生成命令
      cliCommand = connectionConfig.generateClaudeCliCommand(name, fieldValues);
    }

    // 如果没有配置模板，使用默认生成逻辑
    if (cliCommand == null || cliCommand.isEmpty) {
      final configType = serverConfig['type']?.toString() ?? '';
      final url = serverConfig['url']?.toString() ?? '';

      if (configType == 'http' && url.isNotEmpty) {
        // HTTP 远程类型: claude mcp add --transport http --scope user "name" url
        cliCommand = 'claude mcp add --transport http --scope user "$name" "$url"';
      } else if (configType == 'sse' && url.isNotEmpty) {
        // SSE 远程类型: claude mcp add --transport sse --scope user "name" url
        cliCommand = 'claude mcp add --transport sse --scope user "$name" "$url"';
      } else {
        // stdio 本地类型: claude mcp add --scope user "name" -- command args...
        final command = serverConfig['command'] ?? '';
        final args = serverConfig['args'] as List? ?? [];

        // --scope user 必须放在 -- 之前，否则会被当成子命令参数
        final buffer = StringBuffer('claude mcp add --scope user "$name"');
        if (command.toString().isNotEmpty) {
          buffer.write(' -- "$command"');
          for (final arg in args) {
            final escapedArg = arg.toString().replaceAll('"', '\\"');
            buffer.write(' "$escapedArg"');
          }
        }
        cliCommand = buffer.toString();
      }
    }

    terminalService.setFloatingTerminal(true);
    terminalService.openTerminalPanel();

    await Future.delayed(const Duration(milliseconds: 500));
    terminalService.sendCommand(cliCommand);
  }

}

extension StringExtension on String {
  String trimmed() => trim();
}
