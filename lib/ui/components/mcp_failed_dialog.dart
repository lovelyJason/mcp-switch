import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/s.dart';
import '../../utils/platform_utils.dart';
import 'custom_toast.dart';

/// 从 MCP 配置中提取域名列表（用于生成 Clash 直连规则）
/// 支持 HTTP 类型（url 字段）和 stdio 类型（command/args 字段）
List<String> extractDomainsFromConfig(Map<String, dynamic> config) {
  final domains = <String>{};

  // HTTP/SSE 类型：直接从 url 字段提取
  final url = config['url'] as String? ?? '';
  // stdio 类型：从 command 和 args 字段提取
  final cmd = config['command'] as String? ?? '';
  final args = config['args'];
  final allText = [
    url,
    cmd,
    if (args is List) ...args.map((a) => a.toString()),
  ].join(' ');

  // 匹配形如 something.tld 或 sub.something.tld 的词
  final domainRegex = RegExp(
    r'(?:https?://)?([a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9\-]*[a-zA-Z0-9])?)+)',
  );
  for (final match in domainRegex.allMatches(allText)) {
    final host = match.group(1)!;
    // 过滤掉明显的文件路径和版本号（含数字的短片段）
    if (!host.contains('/') && host.contains('.')) {
      domains.add(host);
    }
  }

  return domains.toList()..sort();
}

/// 生成要插入到 main 函数体内的脚本片段（不含函数签名和大括号）
String buildClashScriptBody(List<String> domains) {
  final ruleSet = <String>{};
  for (final domain in domains) {
    ruleSet.add(domain);
    ruleSet.add(_rootDomain(domain));
  }
  final sorted = ruleSet.toList()..sort();

  final allRules = <String>[
    ...sorted.map((d) => 'DOMAIN-SUFFIX,$d,DIRECT'),
    'GEOIP,PRIVATE,DIRECT',
    'GEOIP,CN,DIRECT',
    'DOMAIN-SUFFIX,cn,DIRECT',
  ];
  final rulesStr = allRules.map((r) => '    "$r"').join(',\n');

  return '''  // imported by MCP Switch
  const customRules = [
$rulesStr,
  ];
  if (Array.isArray(config.rules)) {
    config.rules = [...customRules, ...config.rules];
  } else {
    config.rules = customRules;
  }''';
}

/// 生成完整的预览脚本（用于 UI 显示）
String buildClashScriptPreview(List<String> domains) {
  final body = buildClashScriptBody(domains)
      .replaceFirst('  // imported by MCP Switch\n', '');
  return '// Define main function (script entry)\n\n'
      'function main(config, profileName) {\n$body\n  return config;\n}';
}

/// 取根域名（最后两段）
String _rootDomain(String domain) {
  final parts = domain.split('.');
  if (parts.length <= 2) return domain;
  return parts.sublist(parts.length - 2).join('.');
}

/// MCP 连接失败诊断弹窗
class McpFailedDialog extends StatefulWidget {
  final String serverName;
  final Map<String, dynamic> config;

  const McpFailedDialog({
    super.key,
    required this.serverName,
    required this.config,
  });

  static Future<void> show(
    BuildContext context, {
    required String serverName,
    required Map<String, dynamic> config,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, a1, a2) => McpFailedDialog(
        serverName: serverName,
        config: config,
      ),
      transitionBuilder: (context, anim, _, child) => Transform.scale(
        scale: 0.9 + 0.1 * anim.value,
        child: Opacity(opacity: anim.value, child: child),
      ),
    );
  }

  @override
  State<McpFailedDialog> createState() => _McpFailedDialogState();
}

class _McpFailedDialogState extends State<McpFailedDialog> {
  bool _isImporting = false;
  bool _importSuccess = false;

  late final List<String> _domains;
  late final String _clashScript;

  static String get _scriptJsPath =>
      '${PlatformUtils.userHome}/Library/Application Support'
      '/io.github.clash-verge-rev.clash-verge-rev/profiles/Script.js';

  static final _mainFuncRegex = RegExp(
    r'(function\s+main\s*\([^)]*\)\s*\{)([\s\S]*?)(\n\})',
  );

  @override
  void initState() {
    super.initState();
    _domains = extractDomainsFromConfig(widget.config);
    _clashScript = _domains.isEmpty ? '' : buildClashScriptPreview(_domains);
  }

  Future<void> _importToClashVerge() async {
    setState(() => _isImporting = true);
    try {
      final file = File(_scriptJsPath);
      if (!await file.parent.exists()) {
        throw Exception(S.get('clash_verge_not_found'));
      }

      String existing = '';
      if (await file.exists()) {
        existing = await file.readAsString();
      }

      if (existing.contains('// imported by MCP Switch')) {
        if (mounted) {
          Toast.show(context,
              message: S.get('clash_script_already_exist'),
              type: ToastType.info);
        }
        return;
      }

      if (_hasNonEmptyMainBody(existing)) {
        if (mounted) {
          Toast.show(context,
              message: S.get('clash_script_conflict'),
              type: ToastType.error,
              duration: const Duration(seconds: 5));
        }
        return;
      }

      final newBody = buildClashScriptBody(_domains);
      String output;
      final match = _mainFuncRegex.firstMatch(existing);
      if (match != null) {
        output = existing.replaceFirst(
          _mainFuncRegex,
          '${match.group(1)}\n$newBody\n  return config;\n}',
        );
      } else {
        output = '// Define main function (script entry)\n\n'
            'function main(config, profileName) {\n$newBody\n  return config;\n}\n';
      }

      await file.writeAsString(output);

      setState(() => _importSuccess = true);
      if (mounted) {
        Toast.show(context,
            message: S.get('clash_script_imported'),
            type: ToastType.success,
            duration: const Duration(seconds: 5));
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Toast.show(context,
                message: S.get('clash_restart_required'),
                type: ToastType.warning,
                duration: const Duration(seconds: 6));
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Toast.show(context,
            message: '${S.get('clash_import_failed')}: $e',
            type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 检测 main 函数体是否有实际逻辑（排除注释、空行、`return config;`）
  bool _hasNonEmptyMainBody(String content) {
    final match = _mainFuncRegex.firstMatch(content);
    if (match == null) return false;
    final body = match.group(2) ?? '';
    final lines = body.split('\n').where((line) {
      final trimmed = line.trim();
      return trimmed.isNotEmpty &&
          !trimmed.startsWith('//') &&
          trimmed != 'return config;';
    });
    return lines.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final codeColor = isDark ? Colors.grey.shade900 : Colors.grey.shade100;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 440,
          constraints: const BoxConstraints(maxHeight: 460),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.link_off, color: Colors.red, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.serverName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          Text(
                            S.get('mcp_failed_dialog_subtitle'),
                            style: TextStyle(fontSize: 12, color: subColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: subColor),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 可能原因
                Text(
                  S.get('mcp_failed_possible_causes'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCauseItem(
                  isDark,
                  Icons.vpn_lock_outlined,
                  Colors.orange,
                  S.get('mcp_cause_tun'),
                ),
                const SizedBox(height: 4),
                _buildCauseItem(
                  isDark,
                  Icons.terminal,
                  Colors.blue,
                  S.get('mcp_cause_process'),
                ),
                const SizedBox(height: 4),
                _buildCauseItem(
                  isDark,
                  Icons.rule,
                  Colors.purple,
                  S.get('mcp_cause_rule'),
                ),

                if (_domains.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Divider(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Icon(Icons.code, size: 16, color: Colors.orange.shade400),
                      const SizedBox(width: 6),
                      Text(
                        S.get('mcp_clash_script_title'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    S.get('mcp_clash_script_desc'),
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                  const SizedBox(height: 8),

                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: codeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _clashScript,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Menlo',
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _clashScript));
                          Toast.show(context,
                              message: S.get('copied'),
                              type: ToastType.success);
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: Text(S.get('copy_script')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isImporting ? null : _importToClashVerge,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(
                                _importSuccess
                                    ? Icons.check_circle_outline
                                    : Icons.download_outlined,
                                size: 14,
                              ),
                        label: Text(
                          _importSuccess
                              ? S.get('clash_script_imported_btn')
                              : S.get('import_script_to_clash'),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _importSuccess ? Colors.green : Colors.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    S.get('clash_script_import_hint'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                // 关闭按钮
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: subColor,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: Text(S.get('ok')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCauseItem(bool isDark, IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
