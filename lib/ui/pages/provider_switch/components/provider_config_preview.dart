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

  // ── 主配置预览 ────────────────────────────────────────────────────
  Widget _buildConfigPreview(bool isDark) {
    final filePath = _isClaude
        ? S.get('provider_claude_file_path')
        : _isGemini
            ? S.get('provider_gemini_file_path')
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
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.grey.shade400 : Colors.black54,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                );
              }
              final text = snapshot.data ?? '';
              final service =
                  Provider.of<ProviderSwitchService>(context, listen: false);
              final displayText = _isClaude
                  ? text
                  : _isGemini
                      ? service.generateGeminiPreview(_buildPreviewProfile())
                      : service.generateCodexPreview(
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
            Toast.show(context, message: S.get('format_error'), type: ToastType.error);
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
