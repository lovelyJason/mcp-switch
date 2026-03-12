import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../l10n/s.dart';
import '../../../../services/config/config_service.dart';
import '../../../../services/proxy_service.dart';
import '../../../components/custom_toast.dart';

class ProxySettingsSection extends StatefulWidget {
  const ProxySettingsSection({super.key});

  @override
  State<ProxySettingsSection> createState() => _ProxySettingsSectionState();
}

class _ProxySettingsSectionState extends State<ProxySettingsSection> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isTesting = false;
  bool _isScanning = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    final config = Provider.of<ConfigService>(context, listen: false);
    _urlController.text = config.proxyUrl;
    _usernameController.text = config.proxyUsername;
    _passwordController.text = config.proxyPassword;
    _isExpanded = config.hasProxy;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey.shade900 : Colors.grey.shade50;
    final borderColor =
        isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          _buildHeader(isDark),
          if (_isExpanded) ...[
            Divider(height: 0.5, color: borderColor),
            _buildBody(isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.public, size: 20,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.get('proxy_title'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    S.get('proxy_description'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 20,
              color: Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.get('proxy_detail_desc'),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 12),
          _buildUrlRow(isDark),
          const SizedBox(height: 10),
          _buildAuthRow(isDark),
        ],
      ),
    );
  }

  Widget _buildUrlRow(bool isDark) {
    final inputBg = isDark ? Colors.grey.shade800 : Colors.white;
    final inputBorder =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _urlController,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: S.get('proxy_url_hint'),
                hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.orange.shade300, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _actionButton(
          icon: Icons.search,
          tooltip: S.get('proxy_scan'),
          isLoading: _isScanning,
          onPressed: _onScan,
          isDark: isDark,
        ),
        _actionButton(
          icon: Icons.speed,
          tooltip: S.get('proxy_test'),
          isLoading: _isTesting,
          onPressed: _onTest,
          isDark: isDark,
        ),
        _actionButton(
          icon: Icons.close,
          tooltip: S.get('proxy_clear'),
          onPressed: _onClear,
          isDark: isDark,
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 34,
          child: FilledButton(
            onPressed: _onSave,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
            child: Text(S.get('proxy_save')),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          icon: isLoading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.grey.shade500,
                  ),
                )
              : Icon(icon, size: 18),
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: isLoading ? null : onPressed,
        ),
      ),
    );
  }

  Widget _buildAuthRow(bool isDark) {
    final inputBg = isDark ? Colors.grey.shade800 : Colors.white;
    final inputBorder =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _usernameController,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: S.get('proxy_username_hint'),
                hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: inputBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.orange.shade300, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: S.get('proxy_password_hint'),
                hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: inputBg,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                suffixIconConstraints:
                    const BoxConstraints(minWidth: 32),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.orange.shade300, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    final url = _urlController.text.trim();
    if (url.isNotEmpty && !ProxyService.isValidProxyUrl(url)) {
      Toast.show(context,
          message: S.get('proxy_invalid_url'), type: ToastType.warning);
      return;
    }
    final config = Provider.of<ConfigService>(context, listen: false);
    await config.saveProxyConfig(
      url: url,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    Toast.show(context,
        message: S.get('proxy_saved'), type: ToastType.success);
  }

  Future<void> _onClear() async {
    _urlController.clear();
    _usernameController.clear();
    _passwordController.clear();
    final config = Provider.of<ConfigService>(context, listen: false);
    await config.clearProxyConfig();
    if (!mounted) return;
    Toast.show(context,
        message: S.get('proxy_cleared'), type: ToastType.info);
  }

  Future<void> _onTest() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !ProxyService.isValidProxyUrl(url)) {
      Toast.show(context,
          message: S.get('proxy_invalid_url'), type: ToastType.warning);
      return;
    }
    setState(() => _isTesting = true);
    final config = Provider.of<ConfigService>(context, listen: false);
    final service = ProxyService(config);
    final result = await service.testProxy(
      url,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isTesting = false);

    if (result.success) {
      final ms = result.elapsed?.inMilliseconds ?? 0;
      Toast.show(context,
          message: S.get('proxy_test_success').replaceAll('{ms}', '$ms'),
          type: ToastType.success);
    } else {
      Toast.show(context,
          message: '${S.get('proxy_test_failed')}: ${result.error ?? ''}',
          type: ToastType.error,
          duration: const Duration(seconds: 5));
    }
  }

  Future<void> _onScan() async {
    setState(() => _isScanning = true);
    final config = Provider.of<ConfigService>(context, listen: false);
    final service = ProxyService(config);
    final proxies = await service.scanLocalProxies();
    if (!mounted) return;
    setState(() => _isScanning = false);

    if (proxies.isEmpty) {
      Toast.show(context,
          message: S.get('proxy_scan_empty'), type: ToastType.info);
      return;
    }
    _showScanResults(proxies);
  }

  void _showScanResults(List<ScannedProxy> proxies) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    Icon(Icons.wifi_find, size: 20, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      S.get('proxy_scan_title'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...proxies.map((p) => ListTile(
                    dense: true,
                    leading: Icon(
                      p.type == 'socks5' ? Icons.security : Icons.public,
                      size: 18,
                      color: Colors.orange,
                    ),
                    title: Text(p.displayUrl,
                        style: const TextStyle(
                            fontSize: 13, fontFamily: 'monospace')),
                    subtitle: Text(p.type.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                    onTap: () {
                      _urlController.text = p.displayUrl;
                      Navigator.of(ctx).pop();
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
