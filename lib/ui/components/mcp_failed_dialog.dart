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

/// 生成 Clash YAML 规则文本
/// 对每个域名同时生成子域名规则和根域名规则（去重）
String buildClashRules(List<String> domains) {
  final ruleSet = <String>{};
  for (final domain in domains) {
    ruleSet.add(domain); // 原始域名（如 mcp.figma.com）
    ruleSet.add(_rootDomain(domain)); // 根域名（如 figma.com）
  }
  final sorted = ruleSet.toList()..sort();
  final lines = <String>['rules:'];
  for (final d in sorted) {
    lines.add('  - DOMAIN-SUFFIX,$d,DIRECT');
  }
  return lines.join('\n');
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
  late final String _clashRules;

  /// Clash Verge 的 Merge.yaml 路径
  static String get _mergeYamlPath =>
      '${PlatformUtils.userHome}/Library/Application Support'
      '/io.github.clash-verge-rev.clash-verge-rev/profiles/Merge.yaml';

  @override
  void initState() {
    super.initState();
    _domains = extractDomainsFromConfig(widget.config);
    _clashRules = _domains.isEmpty ? '' : buildClashRules(_domains);
  }

  Future<void> _importToClashVerge() async {
    setState(() => _isImporting = true);
    try {
      final file = File(_mergeYamlPath);
      if (!await file.parent.exists()) {
        throw Exception(S.get('clash_verge_not_found'));
      }

      String existing = '';
      if (await file.exists()) {
        existing = await file.readAsString();
      }

      // 检查是否已经有 rules 块
      final newRules = _buildRuleLines();
      if (existing.contains(newRules.first)) {
        // 规则已存在
        if (mounted) {
          Toast.show(
            context,
            message: S.get('clash_rules_already_exist'),
            type: ToastType.info,
          );
        }
        return;
      }

      // 判断是否已有 rules: 块
      final hasRulesBlock = existing.contains('\nrules:') ||
          existing.trimLeft().startsWith('rules:');

      String newContent;
      if (hasRulesBlock) {
        // 已有 rules: 块：在文件末尾（rules 块内）追加规则行
        // Clash Verge Merge.yaml 的 rules 列表项格式为 "  - DOMAIN-SUFFIX,..."
        final rulesLines = newRules.map((r) => '  $r').join('\n');
        final base = existing.trimRight();
        newContent = '$base\n$rulesLines\n  # imported by MCP Switch\n';
      } else {
        // 没有 rules: 块，整体追加新 rules 段
        final rulesLines = newRules.map((r) => '  $r').join('\n');
        final base = existing.trimRight();
        newContent = '$base\n\n# imported by MCP Switch\nrules:\n$rulesLines\n';
      }

      await file.writeAsString(newContent);

      setState(() => _importSuccess = true);
      if (mounted) {
        Toast.show(
          context,
          message: S.get('clash_rules_imported'),
          type: ToastType.success,
          duration: const Duration(seconds: 5),
        );
        // 稍延迟再弹重启提示，让用户先看到成功消息
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Toast.show(
              context,
              message: S.get('clash_restart_required'),
              type: ToastType.warning,
              duration: const Duration(seconds: 6),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        Toast.show(
          context,
          message: '${S.get('clash_import_failed')}: $e',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  /// 构建规则行列表（与 buildClashRules 保持一致，不含 rules: 头）
  List<String> _buildRuleLines() {
    final ruleSet = <String>{};
    for (final d in _domains) {
      ruleSet.add(d);
      ruleSet.add(_rootDomain(d));
    }
    final sorted = ruleSet.toList()..sort();
    return sorted.map((d) => '- DOMAIN-SUFFIX,$d,DIRECT').toList();
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
          constraints: const BoxConstraints(maxHeight: 600),
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

                  // Clash 规则区域
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: Colors.orange.shade400),
                      const SizedBox(width: 6),
                      Text(
                        S.get('mcp_clash_rules_title'),
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
                    S.get('mcp_clash_rules_desc'),
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                  const SizedBox(height: 8),

                  // 规则代码块
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: codeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      _clashRules,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Menlo',
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 按钮行
                  Row(
                    children: [
                      // 复制按钮
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _clashRules));
                          Toast.show(
                            context,
                            message: S.get('copied'),
                            type: ToastType.success,
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: Text(S.get('copy_rules')),
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
                      // 一键导入按钮
                      FilledButton.icon(
                        onPressed: _isImporting ? null : _importToClashVerge,
                        icon: _isImporting
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _importSuccess
                                    ? Icons.check_circle_outline
                                    : Icons.download_outlined,
                                size: 14,
                              ),
                        label: Text(
                          _importSuccess
                              ? S.get('clash_rules_imported_btn')
                              : S.get('import_to_clash_verge'),
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
                    S.get('clash_import_hint'),
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
