import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/provider_presets_config.dart';
import '../../../l10n/s.dart';
import '../../../data/database.dart';
import '../../../services/provider_switch_service.dart';
import '../../components/custom_dialog.dart';
import '../../components/custom_toast.dart';
import 'components/claude_config_editor.dart';
import 'components/codex_config_editor.dart';
import 'components/config_conflict_banner.dart';

part 'components/provider_edit_form_fields.dart';
part 'components/provider_config_preview.dart';

class _SpeedTestResult {
  final int? latencyMs;
  final int? statusCode;
  final String? error;
  const _SpeedTestResult({this.latencyMs, this.statusCode, this.error});
}

class ProviderEditScreen extends StatefulWidget {
  final String editorType;
  final ProviderProfile? profile;

  const ProviderEditScreen({super.key, required this.editorType, this.profile});

  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

// 自定义占位预设（无 icon、空字段），固定追加在预设列表末尾
final _customPreset = ProviderPreset(
  id: '_custom_',
  name: '',
  description: '',
  baseUrl: '',
);

class _ProviderEditScreenState extends State<ProviderEditScreen>
    with _ProviderEditFormFields, _ProviderEditPreview {
  final _formKey = GlobalKey<FormState>();

  @override
  late TextEditingController _nameController;
  @override
  late TextEditingController _descriptionController;
  @override
  late TextEditingController _apiTokenController;
  @override
  late TextEditingController _baseUrlController;
  @override
  late TextEditingController _websiteController;
  @override
  late TextEditingController _maxOutputTokensController;
  @override
  late TextEditingController _maxThinkingTokensController;
  @override
  late Future<String> _configPreviewFuture;

  @override
  bool _obscureToken = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  String? _selectedModel;
  @override
  String? _selectedVscodeModel;
  @override
  String? _selectedReasoningEffort;
  @override
  String? _selectedPersonality;
  String? _selectedPresetName;
  @override
  String _codexExistingConfigContent = '';
  @override
  List<String> _codexModelOptions = List.of(ProviderSwitchService.codexModels);
  @override
  bool _isRefreshingCodexModels = false;
  @override
  bool _isPreviewEditing = false;
  @override
  Map<String, dynamic>? _editedConfigData;
  @override
  Map<String, dynamic> _claudeBaseConfig = {};
  @override
  TextEditingController? _cliModelController;
  @override
  bool _isSpeedTesting = false;
  @override
  _SpeedTestResult? _speedTestResult;
  @override
  String _editedCodexText = '';
  @override
  bool _codexConfigLoaded = false;
  @override
  String _codexAuthContent = '';
  @override
  bool get _codexAuthLoaded => _codexAuthContentLoaded;
  bool _codexAuthContentLoaded = false;

  @override
  String _geminiExistingEnvContent = '';
  @override
  bool _geminiEnvLoaded = false;

  @override
  bool _hasConfigConflict = false;
  @override
  String _localFileContent = '';

  bool _hasVscodeModelConflict = false;
  String? _localVscodeModel;

  @override
  final ScrollController _pageScrollController = ScrollController();

  /// 初始快照，用于检测是否有未保存的更改
  late Map<String, String?> _initialSnapshot;

  bool get _isEditMode => widget.profile != null;
  @override
  bool get _isClaude => widget.editorType == 'claude';
  @override
  bool get _isGemini => widget.editorType == 'gemini';
  @override
  bool get _isOfficial =>
      widget.profile != null &&
      ProviderSwitchService.isOfficialProfile(widget.profile!);
  @override
  bool get _isOfficialPreset {
    if (_selectedPresetName == null || _selectedPresetName == '_custom_') {
      return false;
    }
    final presets = ProviderPresetsConfig.presetsFor(widget.editorType);
    return presets.any((p) => p.id == _selectedPresetName && p.isOfficial);
  }

  @override
  String _getApiTokenText() => _apiTokenController.text.trim();

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _apiTokenController = TextEditingController(text: p?.apiToken ?? '');
    _baseUrlController = TextEditingController(text: p?.baseUrl ?? '');
    _websiteController = TextEditingController(text: p?.website ?? '');
    _maxOutputTokensController = TextEditingController(
      text: p?.maxOutputTokens ?? '',
    );
    _maxThinkingTokensController = TextEditingController(
      text: p?.maxThinkingTokens ?? '',
    );
    _selectedModel = p?.model;
    _selectedVscodeModel = _isClaude ? p?.vscodeModel : null;
    _selectedReasoningEffort = p?.modelReasoningEffort ?? 'high';
    _selectedPersonality = p?.personality ?? 'pragmatic';
    _selectedPresetName = '_custom_';

    final previewControllers = [
      _nameController,
      _descriptionController,
      _apiTokenController,
      _baseUrlController,
      _websiteController,
      _maxOutputTokensController,
      _maxThinkingTokensController,
    ];
    for (final c in previewControllers) {
      c.addListener(_onFieldChanged);
    }

    _initConfigFromSqlite();
    _checkConfigConflict();

    if (!_isClaude && !_isGemini) {
      final selected = _selectedModel;
      if (selected != null &&
          selected.isNotEmpty &&
          !_codexModelOptions.contains(selected)) {
        _codexModelOptions = [selected, ..._codexModelOptions];
      }
      unawaited(_loadCodexModelOptions(silent: true));
      ProviderSwitchService.readCodexAuthFile().then((text) {
        if (mounted) {
          setState(() {
            _codexAuthContent = text;
            _codexAuthContentLoaded = true;
          });
        }
      });
    }

    _initialSnapshot = _takeSnapshot();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialSnapshot = _takeSnapshot();
    });
  }

  /// 从 SQLite configContent 初始化配置预览数据
  /// 编辑模式：直接使用 SQLite 数据
  /// 新增模式：异步读取本地配置文件作为基础，合并表单字段并回填
  void _initConfigFromSqlite() {
    final stored = widget.profile?.configContent;

    if (_isEditMode) {
      _initFromStored(stored);
    } else {
      _initFromStored(stored);
      _loadLocalConfigForNewProfile();
    }
  }

  void _initFromStored(String? stored) {
    if (_isClaude) {
      if (stored != null && stored.trim().isNotEmpty) {
        try {
          _claudeBaseConfig = jsonDecode(stored) as Map<String, dynamic>;
        } catch (_) {
          _claudeBaseConfig = {};
        }
      }
      _configPreviewFuture = Future.value(
        _claudeBaseConfig.isEmpty
            ? '{}'
            : const JsonEncoder.withIndent('  ').convert(_claudeBaseConfig),
      );
    } else if (_isGemini) {
      _geminiExistingEnvContent = stored ?? '';
      _geminiEnvLoaded = true;
      _configPreviewFuture = Future.value(_geminiExistingEnvContent);
    } else {
      _codexExistingConfigContent = stored ?? '';
      _codexConfigLoaded = true;
      _configPreviewFuture = Future.value(_codexExistingConfigContent);
    }
  }

  /// 新增模式：读取本地配置文件，合并到 baseConfig 并回填表单
  Future<void> _loadLocalConfigForNewProfile() async {
    try {
      if (_isClaude) {
        final fileContent = await ProviderSwitchService.readClaudeConfigFile();
        if (fileContent.trim().isEmpty || fileContent.trim() == '{}') return;
        final localData = jsonDecode(fileContent) as Map<String, dynamic>;
        if (!mounted) return;
        setState(() {
          _claudeBaseConfig = localData;
          _configPreviewFuture = Future.value(
            const JsonEncoder.withIndent('  ').convert(_claudeBaseConfig),
          );
        });
        _backfillClaudeForm(localData);
      } else if (_isGemini) {
        final fileContent = await ProviderSwitchService.readGeminiEnvFile();
        if (fileContent.trim().isEmpty) return;
        if (!mounted) return;
        setState(() {
          _geminiExistingEnvContent = fileContent;
          _configPreviewFuture = Future.value(fileContent);
        });
        // 不回填表单：API Key、Base URL、Model 都是供应商特有字段
      } else {
        final fileContent = await ProviderSwitchService.readCodexConfigFile();
        if (fileContent.trim().isEmpty) return;
        if (!mounted) return;
        setState(() {
          _codexExistingConfigContent = fileContent;
          _configPreviewFuture = Future.value(fileContent);
        });
        _backfillCodexForm(fileContent);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _initialSnapshot = _takeSnapshot();
      });
    } catch (_) {}
  }

  /// 回填 Claude 本地配置中的表单字段
  void _backfillClaudeForm(Map<String, dynamic> data) {
    final env = (data['env'] as Map<String, dynamic>?) ?? {};
    final maxOut = env['CLAUDE_CODE_MAX__OUTPUT_TOKENS']?.toString() ?? '';
    if (maxOut.isNotEmpty && _maxOutputTokensController.text.isEmpty) {
      _maxOutputTokensController.text = maxOut;
    }
    final maxThink = env['MAX_THINKING_TOKENS']?.toString() ?? '';
    if (maxThink.isNotEmpty && _maxThinkingTokensController.text.isEmpty) {
      _maxThinkingTokensController.text = maxThink;
    }
  }

  /// 回填 Codex 本地配置中的表单字段（仅通用配置，不回填供应商特有字段）
  void _backfillCodexForm(String toml) {
    // 不调用 _syncFromCodexToml，因为它会回填 model、base_url 等供应商特有字段
    // 新增模式只需要保留本地 TOML 的完整内容到 _codexExistingConfigContent
    // 表单字段由用户或预设填写，不从本地配置继承
  }

  Future<void> _checkConfigConflict() async {
    final p = widget.profile;
    if (p == null || !p.isActive) return;

    if (p.configContent != null) {
      try {
        String fileContent;
        bool isSynced;
        if (_isClaude) {
          fileContent = await ProviderSwitchService.readClaudeConfigFile();
          isSynced = ProviderSwitchService.jsonEquals(
              p.configContent!, fileContent);
        } else if (_isGemini) {
          fileContent = await ProviderSwitchService.readGeminiEnvFile();
          isSynced = ProviderSwitchService.envEquals(
              p.configContent!, fileContent);
        } else {
          fileContent = await ProviderSwitchService.readCodexConfigFile();
          isSynced = ProviderSwitchService.normalizedEquals(
              p.configContent!, fileContent);
        }
        if (!isSynced && mounted) {
          setState(() {
            _hasConfigConflict = true;
            _localFileContent = fileContent;
          });
        }
      } catch (_) {}
    }

    if (_isClaude) {
      await _checkVscodeModelConflict(p);
    }
  }

  Future<void> _checkVscodeModelConflict(ProviderProfile p) async {
    try {
      final fileModel = await ProviderSwitchService.readVscodeSelectedModel();
      final dbModel = (p.vscodeModel ?? '').trim();
      final diskModel = (fileModel ?? '').trim();
      if (dbModel != diskModel && mounted) {
        setState(() {
          _hasVscodeModelConflict = true;
          _localVscodeModel = fileModel;
        });
      }
    } catch (_) {}
  }

  Widget _buildVscodeModelConflictBanner() {
    final dbVal = widget.profile?.vscodeModel ?? '';
    final fileVal = _localVscodeModel ?? '';
    final dbDisplay = dbVal.isEmpty
        ? S.get('provider_vscode_model_empty')
        : dbVal;
    final fileDisplay = fileVal.isEmpty
        ? S.get('provider_vscode_model_empty')
        : fileVal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: Colors.amber.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              S.get('vscode_model_conflict_banner')
                  .replaceAll('{db}', dbDisplay)
                  .replaceAll('{file}', fileDisplay),
              style: const TextStyle(fontSize: 13, color: Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          _buildVscodeConflictAction(
            label: S.get('vscode_model_use_file'),
            onTap: () => _resolveVscodeModelConflict(useFile: true),
          ),
          const SizedBox(width: 4),
          _buildVscodeConflictAction(
            label: S.get('vscode_model_use_saved'),
            onTap: () => _resolveVscodeModelConflict(useFile: false),
          ),
        ],
      ),
    );
  }

  Widget _buildVscodeConflictAction({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.amber,
          ),
        ),
      ),
    );
  }

  void _resolveVscodeModelConflict({required bool useFile}) {
    setState(() {
      if (useFile) {
        _selectedVscodeModel = _localVscodeModel;
      }
      _hasVscodeModelConflict = false;
      _localVscodeModel = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialSnapshot = _takeSnapshot();
    });
  }

  @override
  void _resolveConflict({required bool useLocal}) {
    if (useLocal) {
      if (_isClaude) {
        try {
          _claudeBaseConfig =
              jsonDecode(_localFileContent) as Map<String, dynamic>;
        } catch (_) {
          _claudeBaseConfig = {};
        }
        _configPreviewFuture = Future.value(
          _claudeBaseConfig.isEmpty
              ? '{}'
              : const JsonEncoder.withIndent('  ').convert(_claudeBaseConfig),
        );
        _syncFromConfig(_claudeBaseConfig);
      } else if (_isGemini) {
        _geminiExistingEnvContent = _localFileContent;
        _configPreviewFuture = Future.value(_localFileContent);
        _syncFormFromGeminiEnv(_localFileContent);
      } else {
        _codexExistingConfigContent = _localFileContent;
        _editedCodexText = _localFileContent;
        _configPreviewFuture = Future.value(_localFileContent);
        _syncFromCodexToml(_localFileContent);
      }
    }
    setState(() {
      _hasConfigConflict = false;
      _localFileContent = '';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initialSnapshot = _takeSnapshot();
    });
  }

  Map<String, String?> _takeSnapshot() {
    return {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'apiToken': _apiTokenController.text.trim(),
      'baseUrl': _baseUrlController.text.trim(),
      'website': _websiteController.text.trim(),
      'maxOutputTokens': _maxOutputTokensController.text.trim(),
      'maxThinkingTokens': _maxThinkingTokensController.text.trim(),
      'model': _selectedModel?.trim(),
      'vscodeModel': _selectedVscodeModel?.trim(),
      'reasoningEffort': _selectedReasoningEffort,
      'personality': _selectedPersonality,
      'editedConfig': _isClaude && _claudeBaseConfig.isNotEmpty
          ? (_isPreviewEditing && _editedConfigData != null
                ? const JsonEncoder.withIndent('  ').convert(_editedConfigData)
                : _generateClaudePreviewText())
          : null,
      'editedCodexText': !_isClaude && !_isGemini && _codexConfigLoaded
          ? (_isPreviewEditing && _editedCodexText.isNotEmpty
                ? _editedCodexText
                : _generateCodexPreviewText())
          : null,
      'editedGeminiEnv': _isGemini && _geminiEnvLoaded
          ? _generateGeminiPreviewText()
          : null,
    };
  }

  bool _hasUnsavedChanges() {
    final current = _takeSnapshot();
    for (final key in current.keys) {
      if (current[key] != _initialSnapshot[key]) return true;
    }
    return false;
  }

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasUnsavedChanges()) return true;
    final confirmed = await CustomConfirmDialog.show(
      context,
      title: S.get('unsaved_changes_title'),
      content: S.get('unsaved_changes_content'),
      confirmText: S.get('discard'),
      cancelText: S.get('keep_editing'),
      confirmColor: Colors.red,
    );
    return confirmed == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _apiTokenController.dispose();
    _baseUrlController.dispose();
    _websiteController.dispose();
    _maxOutputTokensController.dispose();
    _maxThinkingTokensController.dispose();
    _pageScrollController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) {
      _syncFormToClaudePreview();
      _syncFormToCodexPreview();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nav = Navigator.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscardIfNeeded()) {
          if (mounted) nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              if (_hasConfigConflict)
                ConfigConflictBanner(
                  onDismiss: () => _resolveConflict(useLocal: false),
                ),
              if (_hasVscodeModelConflict)
                _buildVscodeModelConflictBanner(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _pageScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidateMode,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isEditMode) ...[
                          const SizedBox(height: 16),
                          _buildPresetChips(isDark),
                        ],
                        const SizedBox(height: 24),
                        _buildNameAndDescription(isDark),
                        if (!_isOfficialPreset) ...[
                          const SizedBox(height: 20),
                          _buildApiTokenField(isDark),
                          const SizedBox(height: 16),
                          _buildBaseUrlField(isDark),
                        ],
                        const SizedBox(height: 16),
                        _buildWebsiteField(isDark),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildModelField(isDark)),
                            if (_isClaude) ...[
                              const SizedBox(width: 16),
                              Expanded(child: _buildVscodeModelField(isDark)),
                            ],
                          ],
                        ),
                        if (_isClaude) ...[
                          const SizedBox(height: 16),
                          _buildTokenFields(isDark),
                        ],
                        if (!_isClaude && !_isGemini) ...[
                          const SizedBox(height: 16),
                          _buildCodexFields(isDark),
                          const SizedBox(height: 24),
                          _buildCodexAuthPreview(isDark),
                        ],
                        const SizedBox(height: 24),
                        _buildConfigPreview(isDark),
                        if (_isGemini) ...[
                          const SizedBox(height: 24),
                          _buildGeminiSettingsPreview(isDark),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      padding: const EdgeInsets.only(top: 38, left: 24, right: 24, bottom: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark
                    ? Colors.white24
                    : Colors.grey.withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, size: 20, color: textColor),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () async {
                if (await _confirmDiscardIfNeeded()) {
                  if (mounted) Navigator.of(context).pop();
                }
              },
              tooltip: S.get('cancel'),
            ),
          ),
          const SizedBox(width: 16),
          SvgPicture.asset(
            _isClaude
                ? 'assets/icons/editors/claude.svg'
                : _isGemini
                ? 'assets/icons/editors/gemini.svg'
                : 'assets/icons/editors/chatgpt.svg',
            width: 24,
            height: 24,
            colorFilter: _isClaude
                ? const ColorFilter.mode(Color(0xFFd97757), BlendMode.srcIn)
                : _isGemini
                ? null
                : ColorFilter.mode(textColor, BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          Text(
            _isEditMode ? S.get('provider_edit') : S.get('provider_add'),
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

  Widget _buildPresetChips(bool isDark) {
    final editorType = widget.editorType;
    final presets = [
      ...ProviderPresetsConfig.presetsFor(editorType),
      _customPreset,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.get('provider_preset_label'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((preset) {
            final isCustom = preset.id == '_custom_';
            final isSelected = _selectedPresetName == preset.id;
            return ChoiceChip(
              avatar: preset.icon != null
                  ? SvgPicture.asset(preset.icon!, width: 16, height: 16)
                  : Icon(
                      Icons.edit_note,
                      size: 18,
                      color: isSelected
                          ? const Color(0xFFd97757)
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
              label: Text(
                isCustom ? S.get('provider_preset_custom') : preset.name,
              ),
              selected: isSelected,
              onSelected: (_) => _applyPreset(preset),
              selectedColor: const Color(0xFFd97757).withValues(alpha: 0.2),
              backgroundColor: isDark
                  ? const Color(0xFF2C2C2E)
                  : Colors.grey.shade100,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFFd97757)
                    : (isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFFd97757)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _applyPreset(ProviderPreset preset) {
    setState(() {
      _selectedPresetName = preset.id;
      _nameController.text = preset.name;
      _descriptionController.text = preset.description;
      _baseUrlController.text = preset.baseUrl;
      _websiteController.text = preset.website ?? '';
    });
  }

  Widget _buildBottomBar(bool isDark) {
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
            onPressed: () async {
              if (await _confirmDiscardIfNeeded()) {
                if (mounted) Navigator.of(context).pop();
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
            ),
            child: Text(S.get('cancel')),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: const Color(0xFFd97757),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              S.get('save'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_isClaude && !_isGemini) {
      final codexTomlForSave = _buildCodexTomlForSave();
      if (codexTomlForSave != null && codexTomlForSave.isNotEmpty) {
        _syncFromCodexToml(codexTomlForSave, clearMissing: true);
      }
    }

    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }

    final service = Provider.of<ProviderSwitchService>(context, listen: false);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final apiToken = _apiTokenController.text.trim().isEmpty
        ? null
        : _apiTokenController.text.trim();
    final baseUrl = _baseUrlController.text.trim().isEmpty
        ? null
        : _baseUrlController.text.trim();
    final maxOutputTokens = _maxOutputTokensController.text.trim().isEmpty
        ? null
        : _maxOutputTokensController.text.trim();
    final maxThinkingTokens = _maxThinkingTokensController.text.trim().isEmpty
        ? null
        : _maxThinkingTokensController.text.trim();
    final website = _websiteController.text.trim().isEmpty
        ? null
        : _websiteController.text.trim();

    final configContent = _buildConfigContentForSave();

    if (_isEditMode) {
      await service.updateProfile(
        id: widget.profile!.id,
        editorType: widget.editorType,
        name: name,
        description: description,
        apiToken: apiToken,
        baseUrl: baseUrl,
        model: _selectedModel,
        maxOutputTokens: maxOutputTokens,
        maxThinkingTokens: maxThinkingTokens,
        modelReasoningEffort: _selectedReasoningEffort,
        personality: _selectedPersonality,
        website: website,
        configContent: configContent,
        vscodeModel: _selectedVscodeModel,
      );
    } else {
      await service.addProfile(
        editorType: widget.editorType,
        name: name,
        description: description,
        apiToken: apiToken,
        baseUrl: baseUrl,
        model: _selectedModel,
        maxOutputTokens: maxOutputTokens,
        maxThinkingTokens: maxThinkingTokens,
        modelReasoningEffort: _selectedReasoningEffort,
        personality: _selectedPersonality,
        website: website,
        configContent: configContent,
        vscodeModel: _selectedVscodeModel,
      );
    }

    if (mounted) {
      Toast.show(
        context,
        message: S.get('provider_save_success'),
        type: ToastType.success,
      );
      Navigator.of(context).pop();
    }
  }

  /// 构建完整配置内容字符串，存入 SQLite configContent
  String? _buildConfigContentForSave() {
    if (_isClaude) {
      final data = _buildClaudeConfigForSave();
      if (data != null) {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
      return null;
    }
    if (_isGemini) {
      return _buildGeminiEnvForSave();
    }
    return _buildCodexTomlForSave();
  }

  @override
  ProviderProfile _buildPreviewProfile() {
    return ProviderProfile(
      id: widget.profile?.id ?? '',
      editorType: widget.editorType,
      name: _nameController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      isActive: widget.profile?.isActive ?? false,
      apiToken: _apiTokenController.text.isEmpty
          ? null
          : _apiTokenController.text,
      baseUrl: _baseUrlController.text.isEmpty ? null : _baseUrlController.text,
      model: _selectedModel,
      maxOutputTokens: _maxOutputTokensController.text.isEmpty
          ? null
          : _maxOutputTokensController.text,
      maxThinkingTokens: _maxThinkingTokensController.text.isEmpty
          ? null
          : _maxThinkingTokensController.text,
      modelReasoningEffort: _selectedReasoningEffort,
      personality: _selectedPersonality,
      website: _websiteController.text.isEmpty ? null : _websiteController.text,
      vscodeModel: _selectedVscodeModel,
      createdAt: widget.profile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _loadCodexModelOptions({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    try {
      final service = Provider.of<ProviderSwitchService>(
        context,
        listen: false,
      );
      final models = await service.getCodexModels(forceRefresh: forceRefresh);
      if (!mounted || models.isEmpty) return;

      final merged = List<String>.from(models);
      final selected = _selectedModel;
      if (selected != null &&
          selected.isNotEmpty &&
          !merged.contains(selected)) {
        merged.insert(0, selected);
      }
      setState(() => _codexModelOptions = merged);
    } catch (e) {
      if (!silent) rethrow;
    }
  }

  @override
  Future<void> _refreshCodexModelOptions() async {
    if (_isRefreshingCodexModels) return;
    setState(() => _isRefreshingCodexModels = true);
    try {
      await _loadCodexModelOptions(forceRefresh: true, silent: false);
      if (!mounted) return;
      Toast.show(
        context,
        message: S.get('provider_refresh_models_success'),
        type: ToastType.success,
      );
    } catch (_) {
      if (!mounted) return;
      Toast.show(
        context,
        message: S.get('provider_refresh_models_failed'),
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isRefreshingCodexModels = false);
    }
  }
}
