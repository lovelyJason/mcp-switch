import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/s.dart';
import '../../../data/database.dart';
import '../../../services/provider_switch_service.dart';
import '../../components/custom_toast.dart';

class ProviderEditScreen extends StatefulWidget {
  final String editorType;
  final ProviderProfile? profile;

  const ProviderEditScreen({super.key, required this.editorType, this.profile});

  @override
  State<ProviderEditScreen> createState() => _ProviderEditScreenState();
}

/// 预设供应商数据
class _ProviderPreset {
  final String name;
  final String description;
  final String baseUrl;
  final String? website;
  final String? iconPath;

  const _ProviderPreset({
    required this.name,
    required this.description,
    required this.baseUrl,
    this.website,
    this.iconPath,
  });
}

/// 自定义预设（清空所有字段）
const _customPreset = _ProviderPreset(
  name: '',
  description: '',
  baseUrl: '',
);

/// Claude Code 预设供应商
const _claudePresets = [
  _ProviderPreset(
    name: 'DMXAPI',
    description: 'DMX API Relay',
    baseUrl: 'https://api.dmxapi.com/v1',
    website: 'https://www.dmxapi.com',
    iconPath: 'assets/icons/dmxapi.svg',
  ),
  _ProviderPreset(
    name: 'OpenRouter',
    description: 'OpenRouter Relay',
    baseUrl: 'https://openrouter.ai/api/v1',
    website: 'https://openrouter.ai',
    iconPath: 'assets/icons/openrouter.svg',
  ),
  _ProviderPreset(
    name: 'SiliconFlow',
    description: 'SiliconFlow Relay',
    baseUrl: 'https://api.siliconflow.cn/v1',
    website: 'https://siliconflow.cn',
    iconPath: 'assets/icons/siliconflow.svg',
  ),
  _customPreset,
];

/// Codex 预设供应商
const _codexPresets = [
  _ProviderPreset(
    name: 'DMXAPI',
    description: 'DMX API Relay',
    baseUrl: 'https://api.dmxapi.com/v1',
    website: 'https://www.dmxapi.com',
    iconPath: 'assets/icons/dmxapi.svg',
  ),
  _customPreset,
];

class _ProviderEditScreenState extends State<ProviderEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _apiTokenController;
  late TextEditingController _baseUrlController;
  late TextEditingController _maxOutputTokensController;
  late TextEditingController _maxThinkingTokensController;
  late TextEditingController _websiteController;
  late List<TextEditingController> _previewControllers;
  bool _obscureToken = true;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  String? _selectedModel;
  String? _selectedReasoningEffort;
  String? _selectedPersonality;
  String? _selectedPresetName;
  late Future<String> _configPreviewFuture;
  String _codexExistingConfigContent = '';
  List<String> _codexModelOptions = List.of(ProviderSwitchService.codexModels);
  bool _isRefreshingCodexModels = false;

  bool get _isEditMode => widget.profile != null;
  bool get _isClaude => widget.editorType == 'claude';
  bool get _isOfficial =>
      widget.profile != null &&
      ProviderSwitchService.isOfficialProfile(widget.profile!);

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
    _selectedModel = p?.model ?? (_isClaude ? ProviderSwitchService.claudeModels.first : ProviderSwitchService.codexModels.first);
    _selectedReasoningEffort = p?.modelReasoningEffort ?? 'high';
    _selectedPersonality = p?.personality ?? 'pragmatic';
    _selectedPresetName = '_custom_';
    _previewControllers = [
      _nameController,
      _descriptionController,
      _apiTokenController,
      _baseUrlController,
      _websiteController,
      _maxOutputTokensController,
      _maxThinkingTokensController,
    ];
    for (final c in _previewControllers) {
      c.addListener(_onPreviewFieldsChanged);
    }
    _configPreviewFuture = _isClaude
        ? ProviderSwitchService.readClaudeConfigFile()
        : ProviderSwitchService.readCodexConfigFile().then((text) {
            _codexExistingConfigContent = text;
            return text;
          });
    if (!_isClaude) {
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
    for (final c in _previewControllers) {
      c.removeListener(_onPreviewFieldsChanged);
    }
    _nameController.dispose();
    _descriptionController.dispose();
    _apiTokenController.dispose();
    _baseUrlController.dispose();
    _websiteController.dispose();
    _maxOutputTokensController.dispose();
    _maxThinkingTokensController.dispose();
    super.dispose();
  }

  void _onPreviewFieldsChanged() {
    if (!mounted) return;
    setState(() {});
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
                      const SizedBox(height: 20),
                      _buildApiTokenField(isDark),
                      const SizedBox(height: 16),
                      _buildBaseUrlField(isDark),
                      const SizedBox(height: 16),
                      _buildWebsiteField(isDark),
                      const SizedBox(height: 16),
                      _buildModelField(isDark),
                      if (_isClaude) ...[
                        const SizedBox(height: 16),
                        _buildTokenFields(isDark),
                      ],
                      if (!_isClaude) ...[
                        const SizedBox(height: 16),
                        _buildCodexFields(isDark),
                        const SizedBox(height: 24),
                        _buildCodexAuthPreview(isDark),
                      ],
                      const SizedBox(height: 24),
                      _buildConfigPreview(isDark),
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
            _isClaude ? 'assets/icons/claude.svg' : 'assets/icons/chatgpt.svg',
            width: 24,
            height: 24,
            colorFilter: _isClaude
                ? const ColorFilter.mode(Color(0xFFd97757), BlendMode.srcIn)
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
    final presets = _isClaude ? _claudePresets : _codexPresets;
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
            final isCustom = preset == _customPreset;
            final chipKey = isCustom ? '_custom_' : preset.name;
            final isSelected = _selectedPresetName == chipKey;
            return ChoiceChip(
              avatar: preset.iconPath != null
                  ? SvgPicture.asset(
                      preset.iconPath!,
                      width: 16,
                      height: 16,
                    )
                  : Icon(
                      Icons.edit_note,
                      size: 18,
                      color: isSelected
                          ? const Color(0xFFd97757)
                          : (isDark ? Colors.white70 : Colors.black54),
                    ),
              label: Text(isCustom
                  ? S.get('provider_preset_custom')
                  : preset.name),
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

  void _applyPreset(_ProviderPreset preset) {
    final isCustom = preset == _customPreset;
    setState(() {
      _selectedPresetName = isCustom ? '_custom_' : preset.name;
      _nameController.text = preset.name;
      _descriptionController.text = preset.description;
      _baseUrlController.text = preset.baseUrl;
      _websiteController.text = preset.website ?? '';
    });
  }

  Widget _buildNameAndDescription(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_name'),
            child: TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDecoration(S.get('provider_name_hint')),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return S.get('provider_name_required');
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_description'),
            child: TextFormField(
              controller: _descriptionController,
              style: const TextStyle(fontSize: 14),
              decoration: _inputDecoration(S.get('provider_description_hint')),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApiTokenField(bool isDark) {
    return _buildLabeledField(
      label: S.get('provider_api_token'),
      trailing: _isOfficial ? _buildOfficialHintIcon(isDark) : null,
      child: TextFormField(
        controller: _apiTokenController,
        style: TextStyle(
          fontSize: 14,
          color: _isOfficial ? Colors.grey.shade500 : null,
        ),
        obscureText: _obscureToken,
        enabled: !_isOfficial,
        decoration: _disabledDecoration(
          S.get('provider_api_token_hint'),
          disabled: _isOfficial,
        ).copyWith(
          suffixIcon: IconButton(
            icon: Icon(
              _obscureToken ? Icons.visibility_off : Icons.visibility,
              size: 18,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
            onPressed: () => setState(() => _obscureToken = !_obscureToken),
          ),
        ),
      ),
    );
  }

  Widget _buildBaseUrlField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledField(
          label: S.get('provider_base_url'),
          trailing: _isOfficial ? _buildOfficialHintIcon(isDark) : null,
          child: TextFormField(
            controller: _baseUrlController,
            style: TextStyle(
              fontSize: 14,
              color: _isOfficial ? Colors.grey.shade500 : null,
            ),
            enabled: !_isOfficial,
            decoration: _disabledDecoration(
              S.get('provider_base_url_hint'),
              disabled: _isOfficial,
            ),
            validator: _isOfficial
                ? null
                : (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final url = v.trim();
                    final uri = Uri.tryParse(url);
                    if (uri == null ||
                        !uri.hasScheme ||
                        (uri.scheme != 'http' && uri.scheme != 'https') ||
                        uri.host.isEmpty) {
                      return S.get('provider_base_url_invalid');
                    }
                    return null;
                  },
          ),
        ),
        if (!_isOfficial)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.amber.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      S.get('provider_base_url_tip'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWebsiteField(bool isDark) {
    if (_isOfficial) {
      final url = _isClaude
          ? 'https://www.anthropic.com/claude-code'
          : 'https://chatgpt.com/codex';
      return _buildLabeledField(
        label: S.get('provider_website'),
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(url)),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade300,
              ),
              color: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    url,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFd97757),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _buildLabeledField(
      label: S.get('provider_website'),
      child: TextFormField(
        controller: _websiteController,
        style: const TextStyle(fontSize: 14),
        decoration: _inputDecoration(S.get('provider_website_hint')),
      ),
    );
  }

  Widget _buildOfficialHintIcon(bool isDark) {
    return Tooltip(
      message: S.get('provider_official_hint'),
      preferBelow: false,
      child: Icon(
        Icons.help_outline,
        size: 16,
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildModelField(bool isDark) {
    final models = _isClaude
        ? ProviderSwitchService.claudeModels
        : _codexModelOptions;

    return Row(
      children: [
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_model'),
            child: _buildCustomDropdown<String>(
              value: models.contains(_selectedModel) ? _selectedModel : null,
              items: models,
              labelBuilder: (m) => m,
              onChanged: (val) => setState(() => _selectedModel = val),
              hint: S.get('provider_model_hint'),
            ),
          ),
        ),
        if (!_isClaude) ...[
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Tooltip(
              message: S.get('provider_refresh_models'),
              child: IconButton(
                onPressed: _isRefreshingCodexModels
                    ? null
                    : _refreshCodexModelOptions,
                icon: _isRefreshingCodexModels
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      )
                    : Icon(
                        Icons.refresh,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
              ),
            ),
          ),
        ],
        const Spacer(),
      ],
    );
  }

  Widget _buildTokenFields(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_max_output_tokens'),
            child: TextFormField(
              controller: _maxOutputTokensController,
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('64000'),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_max_thinking_tokens'),
            child: TextFormField(
              controller: _maxThinkingTokensController,
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('31999'),
            ),
          ),
        ),
      ],
    );
  }

  static const _reasoningLabels = {
    'high': 'reasoning_high',
    'medium': 'reasoning_medium',
    'low': 'reasoning_low',
    'minimal': 'reasoning_minimal',
    'xhigh': 'reasoning_xhigh',
  };

  static const _personalityLabels = {
    'pragmatic': 'personality_pragmatic',
    'friendly': 'personality_friendly',
    'none': 'personality_none',
  };

  Widget _buildCodexFields(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_reasoning_effort'),
            child: _buildCustomDropdown<String>(
              value:
                  ProviderSwitchService.reasoningEfforts.contains(
                    _selectedReasoningEffort,
                  )
                  ? _selectedReasoningEffort
                  : null,
              items: ProviderSwitchService.reasoningEfforts,
              labelBuilder: (e) => '$e（${S.get(_reasoningLabels[e] ?? e)}）',
              onChanged: (val) =>
                  setState(() => _selectedReasoningEffort = val),
              hint: 'high',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_personality'),
            child: _buildCustomDropdown<String>(
              value:
                  ProviderSwitchService.personalities.contains(
                    _selectedPersonality,
                  )
                  ? _selectedPersonality
                  : null,
              items: ProviderSwitchService.personalities,
              labelBuilder: (e) => '$e（${S.get(_personalityLabels[e] ?? e)}）',
              onChanged: (val) => setState(() => _selectedPersonality = val),
              hint: 'pragmatic',
            ),
          ),
        ),
      ],
    );
  }

  void _formatPreview(bool isDark) {
    if (_isClaude) {
      _configPreviewFuture.then((raw) {
        if (raw.isEmpty) return;
        try {
          final decoded = jsonDecode(raw);
          final formatted =
              const JsonEncoder.withIndent('  ').convert(decoded);
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
      // Codex TOML 预览本身就是格式化好的，无需额外处理
      Toast.show(
        context,
        message: S.get('format_error'),
        type: ToastType.info,
      );
    }
  }

  Widget _buildConfigPreview(bool isDark) {
    final filePath = _isClaude
        ? S.get('provider_claude_file_path')
        : S.get('provider_codex_file_path');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            TextButton.icon(
              onPressed: () => _formatPreview(isDark),
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text(
                S.get('format'),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor:
                    isDark ? Colors.grey.shade400 : Colors.black54,
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
            future: _configPreviewFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text(
                  '...',
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 13,
                    color: isDark
                        ? Colors.grey.shade300
                        : Colors.grey.shade700,
                  ),
                );
              }
              final text = snapshot.data ?? '';
              final displayText = _isClaude
                  ? text
                  : Provider.of<ProviderSwitchService>(
                      context,
                      listen: false,
                    ).generateCodexPreview(
                      _buildPreviewProfile(),
                      existingConfigContent: _codexExistingConfigContent,
                    );
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: SelectionArea(
                      child: Text(
                        displayText,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 13,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                          height: 1.5,
                        ),
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

  /// 官方配置：展示 auth.json 文件真实内容
  Widget _buildOfficialAuthContent(TextStyle codeStyle) {
    return FutureBuilder<String>(
      future: ProviderSwitchService.readCodexAuthFile(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text('...', style: codeStyle);
        }
        final text = snapshot.data ?? '';
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
      },
    );
  }

  /// 自定义配置：实时跟随 apiToken 输入框
  Widget _buildCustomAuthContent(TextStyle codeStyle) {
    final apiToken = _apiTokenController.text.trim();
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

      setState(() {
        _codexModelOptions = merged;
      });
    } catch (e) {
      if (!silent) rethrow;
    }
  }

  ProviderProfile _buildPreviewProfile() {
    return ProviderProfile(
      id: widget.profile?.id ?? '',
      editorType: widget.editorType,
      name: _nameController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      isActive: widget.profile?.isActive ?? false,
      apiToken: _apiTokenController.text.isEmpty ? null : _apiTokenController.text,
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
      createdAt: widget.profile?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _refreshCodexModelOptions() async {
    if (_isRefreshingCodexModels) return;
    setState(() {
      _isRefreshingCodexModels = true;
    });

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
      if (mounted) {
        setState(() {
          _isRefreshingCodexModels = false;
        });
      }
    }
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
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      return;
    }

    final service = Provider.of<ProviderSwitchService>(context, listen: false);

    if (_isEditMode) {
      await service.updateProfile(
        id: widget.profile!.id,
        editorType: widget.editorType,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        apiToken: _apiTokenController.text.trim().isEmpty
            ? null
            : _apiTokenController.text.trim(),
        baseUrl: _baseUrlController.text.trim().isEmpty
            ? null
            : _baseUrlController.text.trim(),
        model: _selectedModel,
        maxOutputTokens: _maxOutputTokensController.text.trim().isEmpty
            ? null
            : _maxOutputTokensController.text.trim(),
        maxThinkingTokens: _maxThinkingTokensController.text.trim().isEmpty
            ? null
            : _maxThinkingTokensController.text.trim(),
        modelReasoningEffort: _selectedReasoningEffort,
        personality: _selectedPersonality,
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
      );
    } else {
      await service.addProfile(
        editorType: widget.editorType,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        apiToken: _apiTokenController.text.trim().isEmpty
            ? null
            : _apiTokenController.text.trim(),
        baseUrl: _baseUrlController.text.trim().isEmpty
            ? null
            : _baseUrlController.text.trim(),
        model: _selectedModel,
        maxOutputTokens: _maxOutputTokensController.text.trim().isEmpty
            ? null
            : _maxOutputTokensController.text.trim(),
        maxThinkingTokens: _maxThinkingTokensController.text.trim().isEmpty
            ? null
            : _maxThinkingTokensController.text.trim(),
        modelReasoningEffort: _selectedReasoningEffort,
        personality: _selectedPersonality,
        website: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
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
        borderSide: const BorderSide(color: Color(0xFFd97757)),
      ),
    );
  }

  /// 置灰版本的 InputDecoration，带明显的灰色背景
  InputDecoration _disabledDecoration(String hint, {bool disabled = false}) {
    final base = _inputDecoration(hint);
    if (!disabled) return base;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return base.copyWith(
      filled: true,
      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
    );
  }

  Widget _buildLabeledField({
    required String label,
    required Widget child,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing],
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  /// 自定义下拉选择器，替代丑陋的 DropdownButtonFormField
  Widget _buildCustomDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
    required String hint,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;

    final dropdownKey = GlobalKey();

    return GestureDetector(
      key: dropdownKey,
      onTapDown: (details) {
        final renderBox =
            dropdownKey.currentContext!.findRenderObject() as RenderBox;
        final boxSize = renderBox.size;
        final boxOffset = renderBox.localToGlobal(Offset.zero);

        final position = RelativeRect.fromLTRB(
          boxOffset.dx,
          boxOffset.dy + boxSize.height + 4,
          MediaQuery.of(context).size.width - boxOffset.dx - boxSize.width,
          0,
        );

        showMenu<T>(
          context: context,
          position: position,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
          elevation: 8,
          shadowColor: Colors.black45,
          constraints: BoxConstraints(
            maxHeight: 300,
            minWidth: boxSize.width,
            maxWidth: boxSize.width,
          ),
          items: items.map((item) {
            final isSelected = item == value;
            return PopupMenuItem<T>(
              value: item,
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      labelBuilder(item),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, size: 16, color: Color(0xFFd97757)),
                ],
              ),
            );
          }).toList(),
        ).then((selected) {
          if (selected != null) onChanged(selected);
        });
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null ? labelBuilder(value as T) : hint,
                style: TextStyle(
                  fontSize: 14,
                  color: value != null ? textColor : hintColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }
}
