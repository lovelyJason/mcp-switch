import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../constants/claude_config_schema.dart';
import '../../../../l10n/s.dart';

/// Claude settings.json 配置编辑器
/// 支持结构化编辑（带 "+" 按键追加键值对）和源码编辑（Raw JSON）两种模式
class ClaudeConfigEditor extends StatefulWidget {
  final Map<String, dynamic> configData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const ClaudeConfigEditor({
    super.key,
    required this.configData,
    required this.onChanged,
  });

  @override
  State<ClaudeConfigEditor> createState() => _ClaudeConfigEditorState();
}

class _ClaudeConfigEditorState extends State<ClaudeConfigEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _rawController;
  String? _jsonError;
  bool _rawDirty = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _rawController = TextEditingController(text: _formatJson(widget.configData));
    _tabController.addListener(_onTabSwitch);
  }

  @override
  void didUpdateWidget(ClaudeConfigEditor old) {
    super.didUpdateWidget(old);
    if (!_rawDirty) {
      _rawController.text = _formatJson(widget.configData);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabSwitch);
    _tabController.dispose();
    _rawController.dispose();
    super.dispose();
  }

  void _onTabSwitch() {
    if (_tabController.index == 0 && _rawDirty) {
      _tryApplyRaw();
    }
    if (_tabController.index == 1) {
      _rawController.text = _formatJson(widget.configData);
      _rawDirty = false;
      setState(() => _jsonError = null);
    }
  }

  void _tryApplyRaw() {
    try {
      final parsed = jsonDecode(_rawController.text) as Map<String, dynamic>;
      setState(() {
        _jsonError = null;
        _rawDirty = false;
      });
      widget.onChanged(parsed);
    } catch (e) {
      setState(() => _jsonError = e.toString());
    }
  }

  String _formatJson(Map<String, dynamic> data) {
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabBar(isDark),
        const SizedBox(height: 8),
        IndexedStack(
          index: _tabController.index,
          children: [
            _StructuredView(
              configData: widget.configData,
              onChanged: widget.onChanged,
            ),
            _RawJsonView(
              controller: _rawController,
              error: _jsonError,
              onTextChanged: () {
                _rawDirty = true;
                try {
                  final parsed =
                      jsonDecode(_rawController.text) as Map<String, dynamic>;
                  if (mounted) setState(() => _jsonError = null);
                  widget.onChanged(parsed);
                } catch (e) {
                  if (mounted) setState(() => _jsonError = e.toString());
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (i) => setState(() {}),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF3A3A3C) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        labelColor: isDark ? Colors.white : Colors.black87,
        unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.all(2),
        tabs: [
          Tab(text: S.get('config_editor_structured')),
          Tab(text: S.get('config_editor_raw_json')),
        ],
      ),
    );
  }
}

// ── 结构化编辑视图 ──────────────────────────────────────────────────
class _StructuredView extends StatelessWidget {
  final Map<String, dynamic> configData;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _StructuredView({required this.configData, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeColor = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    final envMap = (configData['env'] as Map<String, dynamic>?) ?? {};

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 400),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('{', style: _codeStyle(codeColor)),
            ..._buildRootEntries(context, isDark, codeColor),
            _buildEnvBlock(context, isDark, codeColor, envMap),
            _AddKeyButton(
              level: _Level.root,
              existingKeys: configData.keys.toSet(),
              onAdd: (key, value) => _addRootKey(key, value),
            ),
            Text('}', style: _codeStyle(codeColor)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRootEntries(
    BuildContext context,
    bool isDark,
    Color codeColor,
  ) {
    return configData.entries
        .where((e) => e.key != 'env')
        .map((e) => _KeyValueRow(
              indent: 1,
              keyName: e.key,
              value: e.value,
              codeColor: codeColor,
              isFormManaged: ClaudeConfigSchema.formManagedRootKeys.contains(e.key),
              onDelete: () => _removeKey(e.key),
            ))
        .toList();
  }

  Widget _buildEnvBlock(
    BuildContext context,
    bool isDark,
    Color codeColor,
    Map<String, dynamic> envMap,
  ) {
    if (envMap.isEmpty && !configData.containsKey('env')) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text('"env": {', style: _codeStyle(codeColor)),
        ),
        ...envMap.entries.map((e) => _KeyValueRow(
              indent: 2,
              keyName: e.key,
              value: e.value,
              codeColor: codeColor,
              isFormManaged: ClaudeConfigSchema.formManagedEnvKeys.contains(e.key),
              onDelete: () => _removeEnvKey(e.key),
            )),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: _AddKeyButton(
            level: _Level.env,
            existingKeys: envMap.keys.toSet(),
            onAdd: (key, value) => _addEnvKey(key, value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Text('},', style: _codeStyle(codeColor)),
        ),
      ],
    );
  }

  void _addRootKey(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(configData);
    updated[key] = value;
    onChanged(updated);
  }

  void _addEnvKey(String key, dynamic value) {
    final updated = Map<String, dynamic>.from(configData);
    final env = Map<String, dynamic>.from(
      (updated['env'] as Map<String, dynamic>?) ?? {},
    );
    env[key] = value;
    updated['env'] = env;
    onChanged(updated);
  }

  void _removeKey(String key) {
    final updated = Map<String, dynamic>.from(configData);
    updated.remove(key);
    onChanged(updated);
  }

  void _removeEnvKey(String key) {
    final updated = Map<String, dynamic>.from(configData);
    final env = Map<String, dynamic>.from(
      (updated['env'] as Map<String, dynamic>?) ?? {},
    );
    env.remove(key);
    updated['env'] = env;
    onChanged(updated);
  }

  TextStyle _codeStyle(Color color) {
    return TextStyle(fontFamily: 'Menlo', fontSize: 13, color: color, height: 1.6);
  }
}

// ── 单行键值对显示 ──────────────────────────────────────────────────
class _KeyValueRow extends StatefulWidget {
  final int indent;
  final String keyName;
  final dynamic value;
  final Color codeColor;
  final bool isFormManaged;
  final VoidCallback onDelete;

  const _KeyValueRow({
    required this.indent,
    required this.keyName,
    required this.value,
    required this.codeColor,
    required this.isFormManaged,
    required this.onDelete,
  });

  @override
  State<_KeyValueRow> createState() => _KeyValueRowState();
}

class _KeyValueRowState extends State<_KeyValueRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyColor = isDark ? const Color(0xFF9CDCFE) : const Color(0xFF0451A5);
    final valColor = widget.value is String
        ? (isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515))
        : (isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658));

    final displayValue = widget.value is String
        ? '"${widget.value}"'
        : '${widget.value}';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: EdgeInsets.only(left: widget.indent * 16.0),
        child: Row(
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '"${widget.keyName}"',
                    style: TextStyle(
                      fontFamily: 'Menlo', fontSize: 13, color: keyColor, height: 1.6,
                    ),
                  ),
                  TextSpan(
                    text: ': ',
                    style: TextStyle(
                      fontFamily: 'Menlo', fontSize: 13, color: widget.codeColor, height: 1.6,
                    ),
                  ),
                  TextSpan(
                    text: displayValue,
                    style: TextStyle(
                      fontFamily: 'Menlo', fontSize: 13, color: valColor, height: 1.6,
                    ),
                  ),
                  TextSpan(
                    text: ',',
                    style: TextStyle(
                      fontFamily: 'Menlo', fontSize: 13, color: widget.codeColor, height: 1.6,
                    ),
                  ),
                ]),
              ),
            ),
            if (widget.isFormManaged && _hovered)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: S.get('config_editor_form_managed'),
                  child: Icon(Icons.link, size: 14, color: Colors.grey.shade500),
                ),
              ),
            if (!widget.isFormManaged && _hovered)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: InkWell(
                  onTap: widget.onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 添加键按钮 ──────────────────────────────────────────────────────
enum _Level { root, env }

class _AddKeyButton extends StatelessWidget {
  final _Level level;
  final Set<String> existingKeys;
  final void Function(String key, dynamic value) onAdd;

  const _AddKeyButton({
    required this.level,
    required this.existingKeys,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(left: level == _Level.root ? 16.0 : 0),
      child: InkWell(
        onTap: () => _showAddDialog(context),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 16, color: Colors.orange.shade400),
              const SizedBox(width: 4),
              Text(
                S.get('config_editor_add_field'),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final schema = level == _Level.root
        ? ClaudeConfigSchema.rootKeys
        : ClaudeConfigSchema.envKeys;
    final available = schema.entries
        .where((e) => !existingKeys.contains(e.key))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.get('config_editor_no_more_keys'))),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _AddFieldDialog(
        available: available,
        onConfirm: onAdd,
      ),
    );
  }
}

// ── 添加字段弹窗 ──────────────────────────────────────────────────
class _AddFieldDialog extends StatefulWidget {
  final List<MapEntry<String, ConfigKeyDef>> available;
  final void Function(String key, dynamic value) onConfirm;

  const _AddFieldDialog({required this.available, required this.onConfirm});

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  String? _selectedKey;
  late TextEditingController _valueController;
  ConfigKeyDef? _currentDef;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _onKeySelected(String key) {
    final def = widget.available.firstWhere((e) => e.key == key).value;
    setState(() {
      _selectedKey = key;
      _currentDef = def;
      _valueController.text = def.defaultValue;
    });
  }

  dynamic _parseValue() {
    final text = _valueController.text.trim();
    if (_currentDef == null) return text;
    switch (_currentDef!.type) {
      case ConfigValueType.boolean:
        return text == 'true';
      case ConfigValueType.number:
        return num.tryParse(text) ?? text;
      case ConfigValueType.string:
        return text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.get('config_editor_add_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                S.get('config_editor_select_key'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildKeySelector(isDark),
                ),
              ),
              if (_selectedKey != null) ...[
                const SizedBox(height: 16),
                _buildValueInput(isDark),
              ],
              const SizedBox(height: 20),
              _buildActions(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeySelector(bool isDark) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: widget.available.map((entry) {
        final isSelected = _selectedKey == entry.key;
        final chip = ChoiceChip(
          label: Text(entry.key),
          selected: isSelected,
          onSelected: (_) => _onKeySelected(entry.key),
          selectedColor: const Color(0xFFd97757).withValues(alpha: 0.2),
          backgroundColor: isDark ? const Color(0xFF3A3A3C) : Colors.grey.shade100,
          side: BorderSide(
            color: isSelected
                ? const Color(0xFFd97757)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
          labelStyle: TextStyle(
            fontSize: 12,
            fontFamily: 'Menlo',
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? const Color(0xFFd97757)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        );
        if (entry.value.description.isEmpty) return chip;
        return Tooltip(
          message: entry.value.description,
          waitDuration: const Duration(milliseconds: 400),
          child: chip,
        );
      }).toList(),
    );
  }

  Widget _buildValueInput(bool isDark) {
    final def = _currentDef!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              S.get('config_editor_value'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                def.type.name,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'Menlo',
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (def.type == ConfigValueType.boolean)
          _buildBooleanToggle(isDark)
        else if (def.presets.isNotEmpty)
          _buildPresetDropdown(isDark, def)
        else
          _buildFreeTextInput(isDark),
      ],
    );
  }

  Widget _buildBooleanToggle(bool isDark) {
    final isTrue = _valueController.text.trim() == 'true';
    return Row(
      children: [
        ChoiceChip(
          label: const Text('true'),
          selected: isTrue,
          onSelected: (_) => setState(() => _valueController.text = 'true'),
          selectedColor: Colors.green.withValues(alpha: 0.2),
          side: BorderSide(color: isTrue ? Colors.green : Colors.grey.shade400),
          labelStyle: TextStyle(
            fontSize: 13,
            fontFamily: 'Menlo',
            color: isTrue ? Colors.green : (isDark ? Colors.white70 : Colors.black54),
          ),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('false'),
          selected: !isTrue,
          onSelected: (_) => setState(() => _valueController.text = 'false'),
          selectedColor: Colors.red.withValues(alpha: 0.15),
          side: BorderSide(color: !isTrue ? Colors.red : Colors.grey.shade400),
          labelStyle: TextStyle(
            fontSize: 13,
            fontFamily: 'Menlo',
            color: !isTrue ? Colors.red : (isDark ? Colors.white70 : Colors.black54),
          ),
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildPresetDropdown(bool isDark, ConfigKeyDef def) {
    return Column(
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: def.presets.map((p) {
            final isSelected = _valueController.text.trim() == p;
            return ChoiceChip(
              label: Text(p),
              selected: isSelected,
              onSelected: (_) => setState(() => _valueController.text = p),
              selectedColor: const Color(0xFFd97757).withValues(alpha: 0.2),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFd97757)
                    : (isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontFamily: 'Menlo',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFFd97757)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        _buildFreeTextInput(isDark),
      ],
    );
  }

  Widget _buildFreeTextInput(bool isDark) {
    return TextField(
      controller: _valueController,
      style: TextStyle(
        fontSize: 13,
        fontFamily: 'Menlo',
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: S.get('config_editor_value_hint'),
        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFd97757)),
        ),
      ),
    );
  }

  Widget _buildActions(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : Colors.black54,
          ),
          child: Text(S.get('cancel')),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _selectedKey == null
              ? null
              : () {
                  widget.onConfirm(_selectedKey!, _parseValue());
                  Navigator.pop(context);
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFd97757),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(S.get('config_editor_confirm_add')),
        ),
      ],
    );
  }
}

// ── 源码编辑视图 ──────────────────────────────────────────────────
class _RawJsonView extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final VoidCallback onTextChanged;

  const _RawJsonView({
    required this.controller,
    required this.error,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: error != null
                  ? Colors.red.shade400
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: null,
            onChanged: (_) => onTextChanged(),
            style: TextStyle(
              fontFamily: 'Menlo',
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.5,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
              hintText: '{\n  "key": "value"\n}',
              hintStyle: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 13,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: Colors.red.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'JSON ${S.get("config_editor_json_error")}',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
