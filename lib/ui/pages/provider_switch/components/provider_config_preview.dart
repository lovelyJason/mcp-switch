part of '../provider_edit_screen.dart';

/// 配置预览区块 mixin
mixin _ProviderEditPreview on State<ProviderEditScreen> {
  bool get _isClaude;
  bool get _isGemini;
  bool get _isOfficial;
  Future<String> get _configPreviewFuture;
  set _configPreviewFuture(Future<String> value);
  String get _codexExistingConfigContent;
  ProviderProfile _buildPreviewProfile();

  bool get _isPreviewEditing;
  set _isPreviewEditing(bool v);
  Map<String, dynamic>? get _editedConfigData;
  set _editedConfigData(Map<String, dynamic>? v);
  Map<String, dynamic> get _claudeBaseConfig;
  set _claudeBaseConfig(Map<String, dynamic> v);

  TextEditingController get _apiTokenController;
  TextEditingController get _baseUrlController;
  TextEditingController? get _cliModelController;
  TextEditingController get _maxOutputTokensController;
  TextEditingController get _maxThinkingTokensController;
  String? get _selectedModel;
  set _selectedModel(String? v);
  String? get _selectedReasoningEffort;
  set _selectedReasoningEffort(String? v);
  String? get _selectedPersonality;
  set _selectedPersonality(String? v);

  String get _editedCodexText;
  set _editedCodexText(String v);
  set _codexExistingConfigContent(String v);
  bool get _codexConfigLoaded;
  ScrollController get _pageScrollController;

  String get _codexAuthContent;
  bool get _codexAuthLoaded;

  String get _geminiExistingEnvContent;
  bool get _geminiEnvLoaded;

  bool get _hasConfigConflict;
  set _hasConfigConflict(bool v);
  String get _localFileContent;
  set _localFileContent(String v);

  bool get _isCodex => !_isClaude && !_isGemini;

  // ── 主配置预览 ────────────────────────────────────────────────────
  Widget _buildConfigPreview(bool isDark) {
    final filePath = _isClaude
        ? S.get('provider_claude_file_path')
        : _isGemini
        ? S.get('provider_gemini_file_path')
        : S.get('provider_codex_file_path');

    if (_hasConfigConflict) {
      return _buildConflictDiff(isDark, filePath);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreviewHeader(isDark, filePath),
        const SizedBox(height: 8),
        if (_isPreviewEditing && _isClaude)
          _buildClaudeEditor()
        else if (_isPreviewEditing && _isCodex)
          _buildCodexEditor()
        else
          _buildReadonlyPreview(isDark),
      ],
    );
  }

  Widget _buildPreviewHeader(bool isDark, String filePath) {
    return Row(
      children: [
        Text(
          S.get('provider_config_preview'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          filePath,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontFamily: 'Menlo',
          ),
        ),
        const Spacer(),
        if (_isClaude || _isCodex)
          TextButton.icon(
            onPressed: _togglePreviewEdit,
            icon: Icon(
              _isPreviewEditing ? Icons.visibility : Icons.edit_outlined,
              size: 16,
            ),
            label: Text(
              _isPreviewEditing
                  ? S.get('config_editor_preview_mode')
                  : S.get('config_editor_edit_mode'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _isPreviewEditing
                  ? Colors.orange
                  : (isDark ? Colors.grey.shade400 : Colors.black54),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        if (_isGemini)
          TextButton.icon(
            onPressed: () => _formatPreview(isDark),
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: Text(
              S.get('format'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? Colors.grey.shade400
                  : Colors.black54,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildConflictDiff(bool isDark, String filePath) {
    String savedContent;
    if (_isClaude) {
      savedContent = _claudeBaseConfig.isEmpty
          ? '{}'
          : const JsonEncoder.withIndent('  ').convert(_claudeBaseConfig);
    } else if (_isGemini) {
      savedContent = _geminiExistingEnvContent;
    } else {
      savedContent = _codexExistingConfigContent;
    }
    return ConfigConflictDiff(
      localContent: _localFileContent,
      savedContent: savedContent,
      filePath: filePath,
      isDark: isDark,
      onUseLocal: () => _resolveConflict(useLocal: true),
      onUseSaved: () => _resolveConflict(useLocal: false),
    );
  }

  void _resolveConflict({required bool useLocal});

  void _togglePreviewEdit() {
    if (_isClaude) {
      _toggleClaudePreviewEdit();
    } else if (_isCodex) {
      _toggleCodexPreviewEdit();
    }
  }

  void _toggleClaudePreviewEdit() {
    _keepScrollPosition(() {
      if (!_isPreviewEditing) {
        final data = Map<String, dynamic>.from(_claudeBaseConfig);
        _overlayFormValues(data);
        setState(() {
          _editedConfigData = data;
          _isPreviewEditing = true;
        });
      } else {
        if (_editedConfigData != null) {
          _claudeBaseConfig = Map<String, dynamic>.from(_editedConfigData!);
        }
        setState(() => _isPreviewEditing = false);
      }
    });
  }

  void _toggleCodexPreviewEdit() {
    _keepScrollPosition(() {
      if (!_isPreviewEditing) {
        setState(() {
          _editedCodexText = _generateCodexPreviewText();
          _isPreviewEditing = true;
        });
      } else {
        _codexExistingConfigContent = _editedCodexText;
        setState(() => _isPreviewEditing = false);
      }
    });
  }

  /// 在 action 执行后按比例恢复页面滚动位置
  void _keepScrollPosition(VoidCallback action) {
    final sc = _pageScrollController;
    if (!sc.hasClients || sc.position.maxScrollExtent <= 0) {
      action();
      return;
    }
    final ratio = sc.offset / sc.position.maxScrollExtent;
    action();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!sc.hasClients) return;
        final max = sc.position.maxScrollExtent;
        sc.jumpTo((ratio * max).clamp(0.0, max));
      });
    });
  }

  void _onConfigEditorChanged(Map<String, dynamic> data) {
    setState(() => _editedConfigData = data);
    _syncFromConfig(data);
    _configPreviewFuture = Future.value(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  /// 反向同步：编辑器中的表单管理字段 → 表单控件
  void _syncFromConfig(Map<String, dynamic> data) {
    final env = (data['env'] as Map<String, dynamic>?) ?? {};

    final token = env['ANTHROPIC_AUTH_TOKEN']?.toString() ?? '';
    if (token != _apiTokenController.text) {
      _apiTokenController.text = token;
    }
    final baseUrl = env['ANTHROPIC_BASE_URL']?.toString() ?? '';
    if (baseUrl != _baseUrlController.text) {
      _baseUrlController.text = baseUrl;
    }
    final maxOut = env['CLAUDE_CODE_MAX__OUTPUT_TOKENS']?.toString() ?? '';
    if (maxOut != _maxOutputTokensController.text) {
      _maxOutputTokensController.text = maxOut;
    }
    final maxThink = env['MAX_THINKING_TOKENS']?.toString() ?? '';
    if (maxThink != _maxThinkingTokensController.text) {
      _maxThinkingTokensController.text = maxThink;
    }
    final model = data['model']?.toString();
    if (model != null && model != _selectedModel) {
      _selectedModel = model;
      _cliModelController?.text = model;
    }
  }

  /// 正向同步：表单字段 → 编辑器数据
  /// 由 _onFieldChanged 和 model 下拉变化触发
  /// 只读模式下不再更新 Future（改为 build 时同步生成），避免滚动位置跳动
  void _syncFormToClaudePreview() {
    if (!_isClaude) return;

    if (_isPreviewEditing && _editedConfigData != null) {
      final data = Map<String, dynamic>.from(_editedConfigData!);
      _overlayFormValues(data);
      _editedConfigData = data;
    }
  }

  /// 基于 _claudeBaseConfig + 当前表单值，同步生成 Claude 预览文本
  String _generateClaudePreviewText() {
    final data = Map<String, dynamic>.from(_claudeBaseConfig);
    _overlayFormValues(data);
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, dynamic>? _buildClaudeConfigForSave() {
    if (!_isClaude) return null;

    final data = _isPreviewEditing && _editedConfigData != null
        ? Map<String, dynamic>.from(_editedConfigData!)
        : Map<String, dynamic>.from(_claudeBaseConfig);
    _overlayFormValues(data);
    return data;
  }

  /// 将表单管理的字段值覆盖到 config Map 上
  void _overlayFormValues(Map<String, dynamic> data) {
    if (data['env'] is! Map) {
      data['env'] = <String, dynamic>{};
    }
    final env = data['env'] as Map<String, dynamic>;

    ProviderSwitchService.setOrRemove(
      env,
      'ANTHROPIC_AUTH_TOKEN',
      _apiTokenController.text.trim(),
    );
    ProviderSwitchService.setOrRemove(
      env,
      'ANTHROPIC_BASE_URL',
      _baseUrlController.text.trim(),
    );
    ProviderSwitchService.setOrRemove(
      env,
      'CLAUDE_CODE_MAX__OUTPUT_TOKENS',
      _maxOutputTokensController.text.trim(),
    );
    ProviderSwitchService.setOrRemove(
      env,
      'MAX_THINKING_TOKENS',
      _maxThinkingTokensController.text.trim(),
    );

    final model = _selectedModel;
    if (model != null && model.isNotEmpty) {
      data['model'] = model;
    } else {
      data.remove('model');
    }
  }

  Widget _buildClaudeEditor() {
    return ClaudeConfigEditor(
      configData: _editedConfigData ?? {},
      onChanged: _onConfigEditorChanged,
    );
  }

  // ── Codex 编辑器 ──────────────────────────────────────────────────

  Widget _buildCodexEditor() {
    return CodexConfigEditor(
      initialText: _editedCodexText,
      onChanged: _onCodexEditorChanged,
    );
  }

  void _onCodexEditorChanged(String text) {
    _editedCodexText = text;
    _syncFromCodexToml(text);
    setState(() {});
  }

  /// 反向同步：TOML 文本 → 表单控件
  void _syncFromCodexToml(String toml, {bool clearMissing = false}) {
    final model = _parseTomlValue(toml, 'model');
    if ((clearMissing || model != null) && model != _selectedModel) {
      _selectedModel = model;
    }
    final effort = _parseTomlValue(toml, 'model_reasoning_effort');
    if ((clearMissing || effort != null) &&
        effort != _selectedReasoningEffort) {
      _selectedReasoningEffort = effort;
    }
    final personality = _parseTomlValue(toml, 'personality');
    if ((clearMissing || personality != null) &&
        personality != _selectedPersonality) {
      _selectedPersonality = personality;
    }
    final section = _detectModelProviderSection(toml);
    final baseUrl = section != null
        ? _parseSectionTomlValue(toml, section, 'base_url')
        : null;
    final nextBaseUrl = baseUrl ?? (clearMissing ? '' : null);
    if (nextBaseUrl != null && nextBaseUrl != _baseUrlController.text.trim()) {
      _baseUrlController.text = nextBaseUrl;
    }
  }

  void _syncFormFromGeminiEnv(String envContent) {
    for (final line in envContent.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx < 0) continue;
      final key = trimmed.substring(0, eqIdx).trim();
      final value = trimmed.substring(eqIdx + 1).trim();
      if (key == 'GEMINI_API_KEY' && value != _apiTokenController.text) {
        _apiTokenController.text = value;
      } else if (key == 'GOOGLE_GEMINI_BASE_URL' &&
          value != _baseUrlController.text) {
        _baseUrlController.text = value;
      } else if (key == 'GEMINI_MODEL' && value != _selectedModel) {
        _selectedModel = value;
      }
    }
  }

  /// 正向同步：表单字段 → TOML 编辑器文本
  void _syncFormToCodexPreview() {
    if (!_isCodex) return;
    if (_isPreviewEditing && _editedCodexText.isNotEmpty) {
      var text = _editedCodexText;
      text = _upsertTomlValue(text, 'model', _selectedModel);
      text = _upsertTomlValue(
        text,
        'model_reasoning_effort',
        _selectedReasoningEffort,
      );
      text = _upsertTomlValue(text, 'personality', _selectedPersonality);
      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        final section = _detectModelProviderSection(text);
        if (section != null) {
          text = _upsertSectionTomlValue(text, section, 'base_url', baseUrl);
        }
      }
      _editedCodexText = text;
    }
  }

  /// 同步生成 Codex 预览文本（基于缓存的现有配置 + 当前表单值）
  String _generateCodexPreviewText() {
    final service = Provider.of<ProviderSwitchService>(context, listen: false);
    return service.generateCodexPreview(
      _buildPreviewProfile(),
      existingConfigContent: _codexExistingConfigContent,
    );
  }

  String? _buildCodexTomlForSave() {
    if (!_isCodex) return null;
    if (_isPreviewEditing) {
      return _editedCodexText.isNotEmpty ? _editedCodexText : null;
    }
    if (_codexConfigLoaded) {
      return _generateCodexPreviewText();
    }
    return _editedCodexText.isNotEmpty ? _editedCodexText : null;
  }

  String _generateGeminiPreviewText() {
    final service = Provider.of<ProviderSwitchService>(context, listen: false);
    return service.generateGeminiPreview(
      _buildPreviewProfile(),
      existingEnvContent: _geminiExistingEnvContent,
    );
  }

  String? _buildGeminiEnvForSave() {
    if (!_isGemini) return null;
    if (_geminiEnvLoaded) {
      return _generateGeminiPreviewText();
    }
    return null;
  }

  // ── TOML 行级工具方法 ──────────────────────────────────────────────

  /// 根据 model_provider 值动态检测 [model_providers.xxx] section 名称
  /// 如 model_provider = "OpenAI" → 返回 "model_providers.OpenAI"
  /// 如 model_provider = "custom" → 返回 "model_providers.custom"
  /// 无 model_provider 或值为空 → 返回 null
  static String? _detectModelProviderSection(String toml) {
    final provider = _parseTomlValue(toml, 'model_provider');
    if (provider == null || provider.isEmpty) return null;
    return 'model_providers.$provider';
  }

  /// 从 TOML 顶级区域（第一个 [section] 之前）解析 key = "value"
  static String? _parseTomlValue(String toml, String key) {
    final lines = const LineSplitter().convert(toml);
    final regex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=\s*"([^"]*)"');
    for (final line in lines) {
      if (line.trimLeft().startsWith('[')) break;
      final m = regex.firstMatch(line);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// 从 TOML 指定 [section] 内解析 key = "value"
  static String? _parseSectionTomlValue(
    String toml,
    String section,
    String key,
  ) {
    final lines = const LineSplitter().convert(toml);
    final header = '[$section]';
    final regex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=\s*"([^"]*)"');
    bool inSection = false;
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('[')) {
        if (trimmed == header) {
          inSection = true;
          continue;
        } else if (inSection) {
          break;
        }
      }
      if (inSection) {
        final m = regex.firstMatch(line);
        if (m != null) return m.group(1);
      }
    }
    return null;
  }

  /// 更新指定 [section] 内 key 的值
  static String _upsertSectionTomlValue(
    String toml,
    String section,
    String key,
    String value,
  ) {
    final lines = const LineSplitter().convert(toml);
    final header = '[$section]';
    final regex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=');
    int sectionStart = -1;
    int sectionEnd = lines.length;
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (trimmed == header) {
        sectionStart = i;
      } else if (sectionStart >= 0 && trimmed.startsWith('[')) {
        sectionEnd = i;
        break;
      }
    }
    if (sectionStart >= 0) {
      for (var i = sectionStart + 1; i < sectionEnd; i++) {
        if (regex.hasMatch(lines[i])) {
          lines[i] = '$key = "$value"';
          return lines.join('\n');
        }
      }
      lines.insert(sectionStart + 1, '$key = "$value"');
      return lines.join('\n');
    }
    return toml;
  }

  /// 更新顶级 key 的值，不存在则插入到第一个 [section] 之前
  static String _upsertTomlValue(String toml, String key, String? value) {
    if (value == null || value.isEmpty) return toml;
    final lines = const LineSplitter().convert(toml);
    final regex = RegExp(r'^\s*' + RegExp.escape(key) + r'\s*=');
    int firstSection = lines.length;
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trimLeft().startsWith('[')) {
        firstSection = i;
        break;
      }
    }
    for (var i = 0; i < firstSection; i++) {
      if (regex.hasMatch(lines[i])) {
        lines[i] = '$key = "$value"';
        return lines.join('\n');
      }
    }
    lines.insert(firstSection, '$key = "$value"');
    return lines.join('\n');
  }

  Widget _buildReadonlyPreview(bool isDark) {
    final codeStyle = TextStyle(
      fontFamily: 'Menlo',
      fontSize: 13,
      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
      height: 1.5,
    );

    if (_isClaude) {
      return _buildPreviewContainer(
        isDark,
        child: _buildPreviewText(_generateClaudePreviewText(), codeStyle),
      );
    }

    if (_isCodex) {
      return _buildPreviewContainer(
        isDark,
        child: _buildPreviewText(_generateCodexPreviewText(), codeStyle),
      );
    }

    return _buildPreviewContainer(
      isDark,
      child: _buildPreviewText(_generateGeminiPreviewText(), codeStyle),
    );
  }

  Widget _buildPreviewContainer(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: child,
    );
  }

  Widget _buildPreviewText(String text, TextStyle style) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectionArea(
            child: Text(text, softWrap: false, style: style),
          ),
        ),
      ),
    );
  }

  void _formatPreview(bool isDark) {
    if (_isClaude) {
      _configPreviewFuture.then((raw) {
        if (raw.isEmpty) return;
        try {
          final decoded = jsonDecode(raw);
          final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
          if (mounted) {
            setState(() {
              _configPreviewFuture = Future.value(formatted);
            });
          }
        } catch (_) {
          if (mounted) {
            Toast.show(
              context,
              message: S.get('format_error'),
              type: ToastType.error,
            );
          }
        }
      });
    } else {
      Toast.show(context, message: S.get('format_error'), type: ToastType.info);
    }
  }

  // ── Codex Auth 预览 ───────────────────────────────────────────────
  Widget _buildCodexAuthPreview(bool isDark) {
    final codeStyle = TextStyle(
      fontFamily: 'Menlo',
      fontSize: 13,
      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'auth.json',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              S.get('provider_codex_auth_file_path'),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: _isOfficial
                ? _buildOfficialAuthContent(codeStyle)
                : _buildCustomAuthContent(codeStyle),
          ),
        ),
      ],
    );
  }

  Widget _buildOfficialAuthContent(TextStyle codeStyle) {
    if (!_codexAuthLoaded) {
      return Text('...', style: codeStyle);
    }
    final text = _codexAuthContent;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SelectionArea(
          child: Text(
            text.isEmpty ? S.get('provider_codex_auth_not_found') : text,
            softWrap: false,
            style: codeStyle,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAuthContent(TextStyle codeStyle) {
    // 通过 mixin 访问需要引用主 State 的 controller
    // 由子类 getter 提供
    final apiToken = _getApiTokenText();
    final displayText = apiToken.isNotEmpty
        ? ProviderSwitchService.generateCodexAuthPreview(apiToken)
        : '{}';
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: SelectionArea(
          child: Text(displayText, softWrap: false, style: codeStyle),
        ),
      ),
    );
  }

  // ── Gemini settings.json 预览 ───────────────────────────────────
  Widget _buildGeminiSettingsPreview(bool isDark) {
    final codeStyle = TextStyle(
      fontFamily: 'Menlo',
      fontSize: 13,
      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
      height: 1.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'settings.json',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              S.get('provider_gemini_settings_file_path'),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontFamily: 'Menlo',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
          ),
          child: FutureBuilder<String>(
            future: ProviderSwitchService.readGeminiSettingsFile(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text('...', style: codeStyle);
              }
              final text = snapshot.data ?? '';
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: SelectionArea(
                      child: Text(
                        text.isEmpty
                            ? S.get('provider_gemini_settings_not_found')
                            : text,
                        softWrap: false,
                        style: codeStyle,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 由主 State 提供 apiToken 文本
  String _getApiTokenText();
}
