import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uuid/uuid.dart';
import '../../models/editor_type.dart';
import '../../models/mcp_profile.dart';
import '../../services/config_service.dart';

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
  final _argsController = TextEditingController(); // Multi-line for list
  final _jsonController = TextEditingController();
  final _figmaTokenController = TextEditingController();

  // Presets
  final List<Map<String, dynamic>> _presets = [
    {
      'name': 'Figma',
      'icon': 'assets/icons/figma.svg',
      'config': {
        'command': 'npx',
        'args': ['-y', 'figma-developer-mcp', '--stdio'],
      },
    },
    {
      'name': 'Context7',
      'icon': 'assets/icons/context7.svg',
      'config': {
        'command': 'npx',
        'args': ['-y', 'context7-mcp'],
      },
    },
    {
      'name': 'chrome-devtools',
      'icon': null,
      'config': {
        'command': 'npx',
        'args': ['-y', 'chrome-devtools-mcp@latest'],
      },
    },
    {
      'name': '自定义配置',
      'icon': null,
      'config': {'command': '', 'args': []},
    },
  ];

  bool _isUpdating = false;
  String _selectedPresetName = '自定义配置';

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _initFromData(widget.initialData!);
    } else if (widget.profile != null) {
      _initFromProfile();
    } else {
      // Init empty JSON structure
      _updateJsonFromForm();
    }
  }

  void _initFromData(Map<String, dynamic> data) {
    if (data.containsKey('name')) {
      _nameController.text = data['name'];
    }

    final config = data['config'] ?? {};
    _commandController.text = config['command'] ?? '';
    final args = config['args'];
    if (args is List) {
      _argsController.text = args.join('\n');
    }
    _jsonController.text = const JsonEncoder.withIndent('  ').convert(config);
  }

  void _initFromProfile() {
    _nameController.text = widget.profile!.name;
    
    // Extract server config from profile content
    final content = widget.profile!.content;
    Map<String, dynamic> serverConfig = {};

    if (content['mcpServers'] != null &&
        content['mcpServers'][widget.profile!.name] != null) {
      serverConfig = content['mcpServers'][widget.profile!.name];
    } else {
      // Fallback or potentially different structure
      serverConfig = content;
    }

    _commandController.text = serverConfig['command'] ?? '';
    final args = serverConfig['args'];
    if (args is List) {
      _argsController.text = args.join('\n');
    }

    // Pretty print JSON
    _jsonController.text = const JsonEncoder.withIndent(
      '  ',
    ).convert(serverConfig);
  }


  @override
  void dispose() {
    _nameController.dispose();
    _commandController.dispose();
    _argsController.dispose();
    _jsonController.dispose();
    _figmaTokenController.dispose();
    super.dispose();
  }

  // Sync Logic: Form -> Preview
  void _updateJsonFromForm() {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final argsList = _argsController.text
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();

      final Map<String, dynamic> currentConfig = {
        'command': _commandController.text,
        'args': argsList,
      };

      if (widget.editorType == EditorType.codex) {
        final pName = _nameController.text.isEmpty
            ? 'server'
            : _nameController.text;
        _jsonController.text = _generateToml(pName, currentConfig);
      } else {
        // Try to preserve existing keys in JSON (like env)
        try {
          if (_jsonController.text.isNotEmpty) {
            final existing = jsonDecode(_jsonController.text);
            if (existing is Map<String, dynamic>) {
              // Preserve extra keys but do NOT overwrite keys managed by form
              existing.remove('command');
              existing.remove('args');
              currentConfig.addAll(existing);
            }
          }
        } catch (_) {}

        _jsonController.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(currentConfig);
      }
    } catch (e) {
      print('Sync Error: $e');
    } finally {
      _isUpdating = false;
    }
  }
  
  // Sync Logic: Preview -> Form
  void _updateFormFromJson() {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      final text = _jsonController.text;
      if (text.isEmpty) return;
      
      Map<String, dynamic> data = {};
      if (widget.editorType == EditorType.codex) {
        data = _parseToml(text);
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
      
      if (widget.editorType == EditorType.codex) {
        final data = _parseToml(text);
        final pName = _nameController.text.isEmpty
            ? 'server'
            : _nameController.text;
        _jsonController.text = _generateToml(pName, data);
      } else {
        final dynamic json = jsonDecode(text);
        final prettyString = const JsonEncoder.withIndent('  ').convert(json);
        _jsonController.text = prettyString;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('格式错误，无法格式化')));
    }
  }

  void _onPresetSelected(Map<String, dynamic> preset) {
    if (preset['name'] == '自定义配置') {
      _nameController.clear();
      _commandController.clear();
      _argsController.clear();
    } else {
      _nameController.text = preset['name'];
      final config = preset['config'] as Map;
      _commandController.text = config['command'] ?? '';
      final args = config['args'] as List;
      _argsController.text = args.map((e) => e.toString()).join('\n');
    }

    _selectedPresetName = preset['name'];
    
    // Clear token if switching to Figma freshly
    if (_selectedPresetName == 'Figma') {
      _figmaTokenController.clear();
    }
    
    _updateJsonFromForm();
    setState(() {});
  }

  void _updateFigmaArgs(String token) {
    // ["-y", "figma-developer-mcp", "--figma-api-key=xxx", "--stdio"]
    final currentArgs = _argsController.text.trimmed().split('\n');
    final newArgs = <String>[];

    // Keep everything except old key
    for (var arg in currentArgs) {
      if (arg.trim().isEmpty) continue;
      if (!arg.startsWith('--figma-api-key=')) {
        newArgs.add(arg);
      }
    }

    // Insert new key if token exists
    if (token.isNotEmpty) {
      // Try to insert before --stdio if possible
      final stdioIndex = newArgs.indexOf('--stdio');
      if (stdioIndex != -1) {
        newArgs.insert(stdioIndex, '--figma-api-key=$token');
      } else {
        // Or just append if --stdio not found
        newArgs.add('--figma-api-key=$token');
      }
    }

    _argsController.text = newArgs.join('\n');
    _updateJsonFromForm();
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.profile != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            _buildHeader(isEditMode),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Only show presets in Add Mode
                      if (!isEditMode) ...[
                        _buildSectionTitle('预设 MCP 服务器'),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _presets
                                .map((preset) => _buildPresetChip(preset))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      _buildSectionTitle('基本信息'),
                      const SizedBox(height: 12),
                      _buildLabel('MCP名称', 'Name'),
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration(
                          widget.isPathReadOnly
                              ? '不可编辑'
                              : '请输入名称 (e.g. figma-mcp)',
                        ),
                        readOnly: widget.isPathReadOnly,
                        enabled: !widget.isPathReadOnly,
                        onChanged: (_) => _updateJsonFromForm(),
                        validator: (v) => v?.isEmpty == true ? '请输入名称' : null,
                      ),

                      if (_selectedPresetName == 'Figma') ...[
                        const SizedBox(height: 12),
                        _buildLabel('Access Token', 'Figma API Key'),
                        TextFormField(
                          controller: _figmaTokenController,
                          decoration: _inputDecoration('e.g. figd_...'),
                          onChanged: _updateFigmaArgs,
                        ),
                      ],

                      const SizedBox(height: 24),
                      _buildSectionTitle('MCP 配置详情'),

                      const SizedBox(height: 12),
                      _buildLabel('执行指令', 'command'),
                      TextFormField(
                        controller: _commandController,
                        decoration: _inputDecoration('e.g. npx, node, python'),
                        onChanged: (_) => _updateJsonFromForm(),
                      ),

                      const SizedBox(height: 12),
                      _buildLabel('参数列表 (每行一个)', 'args'),
                      TextFormField(
                        controller: _argsController,
                        maxLines: 4,
                        minLines: 2,
                        decoration: _inputDecoration('e.g. -y\n@input/server'),
                        onChanged: (_) => _updateJsonFromForm(),
                      ),

                      const SizedBox(height: 32),
                      Row(
                        children: [
                          _buildSectionTitle(
                            '配置预览 ${widget.editorType == EditorType.codex ? "(TOML)" : "(JSON)"}',
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _formatJson,
                            icon: const Icon(Icons.auto_fix_high, size: 16),
                            label: const Text(
                              '格式化',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black54,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: TextFormField(
                          controller: _jsonController,
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
                            if (widget.editorType == EditorType.codex)
                              return null;
                            try {
                              jsonDecode(v);
                              return null;
                            } catch (e) {
                              return '无效的 JSON 格式';
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            _buildBottomBar(context, isEditMode),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isEditMode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 24, right: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.withOpacity(0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back,
                size: 20,
                color: textColor,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 16),
          if (_getEditorIconPath(widget.editorType) != null) ...[
            SvgPicture.asset(
              _getEditorIconPath(widget.editorType)!,
              width: 24,
              height: 24,
              colorFilter:
                  (widget.editorType == EditorType.claude ||
                      widget.editorType == EditorType.codex)
                  ? const ColorFilter.mode(Color(0xFFd97757), BlendMode.srcIn)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            isEditMode
                ? '编辑 ${widget.editorType.label} MCP 服务器'
                : '添加 ${widget.editorType.label} MCP 服务器',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isEditMode) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: const Color(0xFF007AFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.save_outlined, size: 20),
            label: Text(
              isEditMode ? '保存' : '添加',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(Map<String, dynamic> preset) {
    final isSelected = _selectedPresetName == preset['name'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => _onPresetSelected(preset),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withOpacity(0.1)
              : (isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.blue
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preset['icon'] != null) ...[
              SvgPicture.asset(
                preset['icon'],
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              preset['name'],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.blue
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildLabel(String label, String placeholder) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
          children: [
            if (placeholder.isNotEmpty)
              TextSpan(
                text: '  $placeholder',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
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
        if (widget.editorType == EditorType.codex) {
          serverConfig = _parseToml(jsonText);
        } else {
          serverConfig = jsonDecode(jsonText);
        }
      }

      // Custom Save Callback (for nested usage)
      if (widget.onSave != null) {
        widget.onSave!(name, serverConfig);
        Navigator.of(context).pop();
        return;
      }

      // Construct structure: { 'mcpServers': { 'name': { ...config... } } }
      final fullContent = {
        'mcpServers': {name: serverConfig},
      };
      
      final newProfile = McpProfile(
        id: widget.profile?.id ?? const Uuid().v4(),
        name: name,
        description: 'Configured via MCP Switch',
        content: fullContent,
      );

      final configService = Provider.of<ConfigService>(context, listen: false);

      // Special handling for Claude: "Add" means add to Global Config
      if (widget.editorType == EditorType.claude && widget.profile == null) {
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
          // Update existing Global Profile
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

          configService.saveProfile(widget.editorType, updatedProfile);
        } else {
          // Create new Global Profile if not exists
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
          configService.saveProfile(widget.editorType, newProfile);
        }
      } else {
        // Standard behavior (Edit existing or Add new for other editors)
        // If editing, widget.profile is not null, so this block is for standard add/edit

        if (widget.profile != null) {
          // EDIT MODE - We might be editing a single server inside a profile
          // But wait, naming collision?
          // The simple logic we had before was:
          // Construct structure: { 'mcpServers': { 'name': { ...config... } } }
          // This REPLACEs the entire content if we are not careful?
          // No, saveProfile in ConfigService calls:
          // _profiles[editor]![index] = profile;
          // This REPLACES the profile object.

          // If we are editing "Global Configuration" profile via this screen,
          // widget.profile would be passed.
          // BUT McpServerEditScreen is usually passed a profile that represents ONE SERVER?
          // NO. McpProfile in our model represents a FILE (or Section).

          // If we are editing a single server within Global Profile, we should have passed
          // the Global Profile to this screen?
          // But McpServerEditScreen UI is for ONE SERVER.

          // If we are in "Edit Mode" (widget.profile != null), we are editing `widget.profile`.
          // But `widget.profile` might contain multiple servers.
          // Our UI only edits ONE server configuration (name, command, args).

          // If `widget.profile` was passed, we assume we are editing specifically THIS server
          // represented by `widget.profile`.
          // But our McpProfile structure is: { mcpServers: { s1: ..., s2: ... } }

          // If we are editing, we probably passed a "Temporary Profile" or the actual Profile?
          // In ProjectCard, we call:
          // McpServerEditScreen(..., initialData: {'name': name, 'config': config}, onSave: ...)
          // So for ProjectCard edits, we use `onSave` callback and do manual update.

          // The DEFAULT save logic here is only reached if `onSave` is null.
          // This happens when clicking the "Add" button in MainWindow title bar.
          // In that case, for OTHER editors (e.g. Cursor), we want to create a new entry?
          // Or append to main file?

          // For Cursor/Windsurf, we want to Append to the main config file.
          // Just like Claude Global.

          // Let's generalize: "Add" means "Append to Main Config".

          // For now, I will stick to fixing CLAUDE.

          final fullContent = {
            'mcpServers': {name: serverConfig},
          };

          final newProfile = McpProfile(
            id: widget.profile?.id ?? const Uuid().v4(),
            name: name,
            description: 'Configured via MCP Switch',
            content: fullContent,
          );
          configService.saveProfile(widget.editorType, newProfile);
        } else {
          // ADD MODE (Non-Claude)
          // We create a new profile.
          // Is that what we want?
          // For Codex, it creates a new [mcp_servers.name] section.
          // ConfigService._syncCombinedConfig merges all profiles.
          // So creating a new Profile for "Project A" or "Server A" works fine.
          // It results in multiple profiles in the list.

          final fullContent = {
            'mcpServers': {name: serverConfig},
          };

          final newProfile = McpProfile(
            id: const Uuid().v4(), // New ID
            name: name,
            description: 'Configured via MCP Switch',
            content: fullContent,
          );
          configService.saveProfile(widget.editorType, newProfile);
        }
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  // --- HELPERS ---
  String _generateToml(String name, Map<String, dynamic> config) {
    final buffer = StringBuffer();
    // Quote name if it contains spaces or non-alphanumeric chars
    final safeName = name.contains(RegExp(r'[^a-zA-Z0-9_\-]'))
        ? '"$name"'
        : name;
    buffer.writeln('[mcp_servers.$safeName]');
    
    buffer.writeln('command = "${config['command'] ?? ''}"');
    final args = config['args'];
    if (args is List && args.isNotEmpty) {
      buffer.writeln('args = [');
      for (var i = 0; i < args.length; i++) {
        final arg = args[i];
        final suffix = (i == args.length - 1) ? '' : ',';
        buffer.writeln('  "$arg"$suffix');
      }
      buffer.writeln(']');
    } else {
      buffer.writeln('args = []');
    }
    return buffer.toString();
  }

  Map<String, dynamic> _parseToml(String text) {
    String? command;
    List<String> args = [];
    bool inArgs = false;

    final lines = text.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('command')) {
        final match = RegExp(r'command\s*=\s*"(.*)"').firstMatch(line);
        if (match != null) command = match.group(1);
      }
      if (line.startsWith('args')) {
        if (line.contains('[')) {
          final inlineMatch = RegExp(r'\[(.*)\]').firstMatch(line);
          if (inlineMatch != null && !line.endsWith('[')) {
            final raw = inlineMatch.group(1)!;
            if (raw.trim().isNotEmpty) {
              args = raw
                  .split(',')
                  .map((e) => e.trim().replaceAll('"', ''))
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
            continue;
          }
          inArgs = true;
        }
      }
      if (inArgs) {
        if (line.trim() == ']') inArgs = false;
        final match = RegExp(r'"(.*)"').firstMatch(line);
        if (match != null) args.add(match.group(1)!);
      }
    }
    return {'command': command ?? '', 'args': args};
  }
  String? _getEditorIconPath(EditorType type) {
    switch (type) {
      case EditorType.cursor:
        return 'assets/icons/cursor.svg';
      case EditorType.windsurf:
        return 'assets/icons/windsurf.svg';
      case EditorType.claude:
        return 'assets/icons/claude.svg';
      case EditorType.codex:
        return 'assets/icons/claude.svg';
      case EditorType.antigravity:
        return 'assets/icons/antigravity.svg';
      case EditorType.gemini:
        return 'assets/icons/gemini.svg';
      default:
        return null;
    }
  }
}

extension StringExtension on String {
  String trimmed() => trim(); // Helper compatibility
}
