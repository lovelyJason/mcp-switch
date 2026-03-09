import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/provider_presets_config.dart';
import '../../../l10n/s.dart';
import '../../../data/database.dart';
import '../../../services/provider_switch_service.dart';
import '../../components/custom_toast.dart';

part 'components/provider_edit_form_fields.dart';
part 'components/provider_config_preview.dart';

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
    return presets
        .any((p) => p.id == _selectedPresetName && p.isOfficial);
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
    _maxOutputTokensController =
        TextEditingController(text: p?.maxOutputTokens ?? '');
    _maxThinkingTokensController =
        TextEditingController(text: p?.maxThinkingTokens ?? '');
    _selectedModel = p?.model ??
        (_isClaude
            ? ProviderSwitchService.claudeModels.first
            : _isGemini
                ? null
                : ProviderSwitchService.codexModels.first);
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

    _configPreviewFuture = _isClaude
        ? ProviderSwitchService.readClaudeConfigFile()
        : _isGemini
            ? ProviderSwitchService.readGeminiEnvFile()
            : ProviderSwitchService.readCodexConfigFile().then((text) {
                _codexExistingConfigContent = text;
                return text;
              });

    if (!_isClaude && !_isGemini) {
      final selected = _selectedModel;
      if (selected != null &&
          selected.isNotEmpty &&
          !_codexModelOptions.contains(selected)) {
        _codexModelOptions = [selected, ..._codexModelOptions];
      }
      unawaited(_loadCodexModelOptions(silent: true));
    }
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
    super.dispose();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: SingleChildScrollView(
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
                      _buildModelField(isDark),
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
              onPressed: () => Navigator.of(context).pop(),
              tooltip: S.get('cancel'),
            ),
          ),
          const SizedBox(width: 16),
          SvgPicture.asset(
            _isClaude
                ? 'assets/icons/claude.svg'
                : _isGemini
                    ? 'assets/icons/gemini.svg'
                    : 'assets/icons/chatgpt.svg',
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
                  isCustom ? S.get('provider_preset_custom') : preset.name),
              selected: isSelected,
              onSelected: (_) => _applyPreset(preset),
              selectedColor: const Color(0xFFd97757).withValues(alpha: 0.2),
              backgroundColor:
                  isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
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
            onPressed: () => Navigator.of(context).pop(),
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
      );
    }

    if (mounted) {
      Toast.show(context,
          message: S.get('provider_save_success'), type: ToastType.success);
      Navigator.of(context).pop();
    }
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
      apiToken:
          _apiTokenController.text.isEmpty ? null : _apiTokenController.text,
      baseUrl:
          _baseUrlController.text.isEmpty ? null : _baseUrlController.text,
      model: _selectedModel,
      maxOutputTokens: _maxOutputTokensController.text.isEmpty
          ? null
          : _maxOutputTokensController.text,
      maxThinkingTokens: _maxThinkingTokensController.text.isEmpty
          ? null
          : _maxThinkingTokensController.text,
      modelReasoningEffort: _selectedReasoningEffort,
      personality: _selectedPersonality,
      website:
          _websiteController.text.isEmpty ? null : _websiteController.text,
      createdAt: widget.profile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _loadCodexModelOptions({
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    try {
      final service =
          Provider.of<ProviderSwitchService>(context, listen: false);
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
      Toast.show(context,
          message: S.get('provider_refresh_models_success'),
          type: ToastType.success);
    } catch (_) {
      if (!mounted) return;
      Toast.show(context,
          message: S.get('provider_refresh_models_failed'),
          type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isRefreshingCodexModels = false);
    }
  }
}
