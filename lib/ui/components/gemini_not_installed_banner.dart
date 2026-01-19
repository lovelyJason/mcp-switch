import 'package:flutter/material.dart';
import '../../l10n/s.dart';
import '../../utils/platform_utils.dart';
import 'gemini_copy_command_dialog.dart';

/// Gemini CLI 未安装提示 Banner
/// 显示在 Gemini Tab 顶部，当检测到 Gemini CLI 未安装时显示
class GeminiNotInstalledBanner extends StatefulWidget {
  final VoidCallback? onInstallComplete;
  final ValueChanged<bool>? onInstallStateChanged;

  const GeminiNotInstalledBanner({
    super.key,
    this.onInstallComplete,
    this.onInstallStateChanged,
  });

  @override
  State<GeminiNotInstalledBanner> createState() => _GeminiNotInstalledBannerState();
}

class _GeminiNotInstalledBannerState extends State<GeminiNotInstalledBanner> {
  bool _isInstalling = false;
  final List<String> _logLines = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String line) {
    if (!mounted) return;
    setState(() {
      _logLines.add(line);
    });
    // 自动滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleInstall() async {
    setState(() {
      _isInstalling = true;
      _logLines.clear();
    });
    // 通知父组件安装状态变化
    widget.onInstallStateChanged?.call(true);

    _addLog('🔍 正在检测 Gemini CLI 安装状态...');

    // 先检测当前状态
    final status = await PlatformUtils.checkGeminiInstallStatus();

    if (!mounted) return;

    if (status.isReady) {
      // 已安装且 PATH 已配置 → 直接完成
      _addLog('✅ Gemini CLI 已安装且配置完成');
      _addLog('📍 路径: ${status.exePath}');
      _notifyComplete();
      return;
    }

    if (status.isInstalled) {
      // 已安装（npm 全局安装通常会自动配置 PATH）
      _addLog('✅ 发现已安装的 Gemini CLI');
      _addLog('📍 路径: ${status.exePath}');
      _notifyComplete();
      return;
    }

    // 未安装 → 执行下载安装
    _addLog('❌ 未检测到 Gemini CLI，开始安装...');
    _addLog('');
    _addLog('> ${PlatformUtils.getGeminiInstallCommand()}');
    _addLog('');

    final exitCode = await PlatformUtils.installGeminiWithOutput(_addLog);

    if (!mounted) return;

    if (exitCode == 0) {
      _addLog('');
      _addLog('✅ 安装完成！');

      // 稍等一下让文件系统同步
      await Future.delayed(const Duration(milliseconds: 500));

      // 再次检测状态
      final newStatus = await PlatformUtils.checkGeminiInstallStatus();

      if (newStatus.isReady) {
        _addLog('✅ Gemini CLI 已就绪');
      } else if (newStatus.isInstalled) {
        _addLog('✅ Gemini CLI 已安装');
        _addLog('📍 路径: ${newStatus.exePath}');
      } else {
        _addLog('⚠️ 未检测到 Gemini CLI，可能需要重启终端或软件');
      }

      _notifyComplete();
    } else {
      _addLog('');
      _addLog('❌ 安装失败 (退出码: $exitCode)');
      setState(() => _isInstalling = false);
      widget.onInstallStateChanged?.call(false);
    }
  }

  void _notifyComplete() {
    if (!mounted) return;

    setState(() => _isInstalling = false);
    widget.onInstallStateChanged?.call(false);

    if (widget.onInstallComplete != null) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) widget.onInstallComplete!();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.blue.shade900.withValues(alpha: 0.3)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.blue.shade700.withValues(alpha: 0.5)
              : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.get('gemini_not_installed_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Text(
              S.get('gemini_not_installed_message'),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isInstalling ? null : _handleInstall,
                  icon: _isInstalling
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.white70 : Colors.deepPurple,
                          ),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(_isInstalling
                      ? S.get('gemini_installing')
                      : S.get('gemini_install_button')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => PlatformUtils.openUrl(
                      'https://github.com/google-gemini/gemini-cli'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(S.get('gemini_install_docs')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => GeminiCopyCommandDialog.show(context),
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(S.get('copy')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                  ),
                ),
              ],
            ),
          ),
          // 日志输出区域
          if (_logLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Container(
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade600,
                  ),
                ),
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: true),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _logLines.length,
                    itemBuilder: (context, index) {
                      final line = _logLines[index];
                      Color textColor = Colors.grey.shade300;

                      // 根据内容设置颜色
                      if (line.startsWith('>')) {
                        textColor = Colors.cyan;
                      } else if (line.startsWith('✅')) {
                        textColor = Colors.green;
                      } else if (line.startsWith('❌') || line.startsWith('[stderr]')) {
                        textColor = Colors.red.shade300;
                      } else if (line.contains('npm') || line.contains('added')) {
                        textColor = Colors.yellow.shade300;
                      }

                      return Text(
                        line,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Menlo, Monaco, Consolas, monospace',
                          color: textColor,
                          height: 1.4,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
