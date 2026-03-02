part of '../provider_edit_screen.dart';

/// 表单字段 mixin — 所有字段 Widget 和 InputDecoration helper
mixin _ProviderEditFormFields on State<ProviderEditScreen> {
  // 以下字段由主 State 声明，mixin 直接访问
  TextEditingController get _nameController;
  TextEditingController get _descriptionController;
  TextEditingController get _apiTokenController;
  TextEditingController get _baseUrlController;
  TextEditingController get _websiteController;
  TextEditingController get _maxOutputTokensController;
  TextEditingController get _maxThinkingTokensController;
  bool get _obscureToken;
  set _obscureToken(bool v);
  String? get _selectedModel;
  set _selectedModel(String? v);
  String? get _selectedReasoningEffort;
  set _selectedReasoningEffort(String? v);
  String? get _selectedPersonality;
  set _selectedPersonality(String? v);
  bool get _isOfficial;
  bool get _isOfficialPreset;
  bool get _isClaude;
  bool get _isGemini;
  bool get _isRefreshingCodexModels;
  List<String> get _codexModelOptions;
  Future<void> _refreshCodexModelOptions();

  // ── Label + 红色必填星号 ─────────────────────────────────────────
  Widget _buildLabeledField({
    required String label,
    required Widget child,
    Widget? trailing,
    bool isRequired = false,
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
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
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

  // ── 名称 + 描述 ──────────────────────────────────────────────────
  Widget _buildNameAndDescription(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_name'),
            isRequired: true,
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

  // ── API Token ────────────────────────────────────────────────────
  Widget _buildApiTokenField(bool isDark) {
    return _buildLabeledField(
      label: S.get('provider_api_token'),
      isRequired: true,
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
        validator: _isOfficial
            ? null
            : (v) {
                if (v == null || v.trim().isEmpty) {
                  return S.get('provider_api_token_required');
                }
                return null;
              },
      ),
    );
  }

  // ── Base URL ─────────────────────────────────────────────────────
  Widget _buildBaseUrlField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledField(
          label: S.get('provider_base_url'),
          isRequired: !_isOfficialPreset,
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
                    if (v == null || v.trim().isEmpty) {
                      return S.get('provider_base_url_required');
                    }
                    final uri = Uri.tryParse(v.trim());
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
        if (!_isOfficial && _isClaude)
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

  // ── Website ──────────────────────────────────────────────────────
  Widget _buildWebsiteField(bool isDark) {
    if (_isOfficial) {
      final url = _isClaude
          ? 'https://www.anthropic.com/claude-code'
          : _isGemini
              ? 'https://gemini.google.com'
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

  // ── Model ────────────────────────────────────────────────────────
  Widget _buildModelField(bool isDark) {
    final models = _isClaude
        ? ProviderSwitchService.claudeModels
        : _isGemini
            ? ProviderSwitchService.geminiModels
            : _codexModelOptions;

    return Row(
      children: [
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_model'),
            isRequired: true,
            child: _isGemini
                ? _buildGeminiModelField(models)
                : FormField<String>(
                    initialValue: models.contains(_selectedModel) ? _selectedModel : null,
                    validator: (_) {
                      if (_selectedModel == null || _selectedModel!.trim().isEmpty) {
                        return S.get('provider_model_required');
                      }
                      return null;
                    },
                    builder: (state) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCustomDropdown<String>(
                            value: models.contains(_selectedModel) ? _selectedModel : null,
                            items: models,
                            labelBuilder: (m) => m,
                            onChanged: (val) {
                              setState(() => _selectedModel = val);
                              state.didChange(val);
                            },
                            hint: S.get('provider_model_hint'),
                            hasError: state.hasError,
                          ),
                          if (state.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                state.errorText!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        if (!_isClaude && !_isGemini) ...[
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Tooltip(
              message: S.get('provider_refresh_models'),
              child: IconButton(
                onPressed: _isRefreshingCodexModels ? null : _refreshCodexModelOptions,
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

  // ── Claude Token Fields ──────────────────────────────────────────
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

  // ── Codex Fields ─────────────────────────────────────────────────
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
              value: ProviderSwitchService.reasoningEfforts.contains(_selectedReasoningEffort)
                  ? _selectedReasoningEffort
                  : null,
              items: ProviderSwitchService.reasoningEfforts,
              labelBuilder: (e) => '$e（${S.get(_reasoningLabels[e] ?? e)}）',
              onChanged: (val) => setState(() => _selectedReasoningEffort = val),
              hint: 'high',
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLabeledField(
            label: S.get('provider_personality'),
            child: _buildCustomDropdown<String>(
              value: ProviderSwitchService.personalities.contains(_selectedPersonality)
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

  // ── Official Hint Icon ───────────────────────────────────────────
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

  // ── Gemini Autocomplete Model Field ─────────────────────────────
  Widget _buildGeminiModelField(List<String> models) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.grey.shade600 : Colors.grey.shade400;
    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _selectedModel ?? ''),
      optionsBuilder: (textEditingValue) {
        final input = textEditingValue.text.trim().toLowerCase();
        if (input.isEmpty) return models;
        return models.where((m) => m.toLowerCase().contains(input));
      },
      onSelected: (val) => setState(() => _selectedModel = val),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          style: TextStyle(fontSize: 14, color: textColor),
          onChanged: (val) => setState(
            () => _selectedModel = val.trim().isEmpty ? null : val.trim(),
          ),
          decoration: InputDecoration(
            hintText: S.get('provider_model_hint'),
            hintStyle: TextStyle(fontSize: 14, color: hintColor),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: bgColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.orange.shade300),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            suffixIcon: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return S.get('provider_model_required');
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(10),
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260, maxWidth: 400),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  final isSelected = option == _selectedModel;
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: textColor,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check, size: 16, color: Color(0xFFd97757)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Custom Dropdown ──────────────────────────────────────────────
  Widget _buildCustomDropdown<T>({
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
    required String hint,
    bool hasError = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = hasError
        ? Colors.red
        : (isDark ? Colors.white12 : Colors.grey.shade300);
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
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFFd97757),
                    ),
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

  // ── InputDecoration helpers ──────────────────────────────────────
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
}
