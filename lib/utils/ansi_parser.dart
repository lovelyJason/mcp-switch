/// ANSI 转义码解析工具
///
/// 用于剥离终端输出中的 ANSI 转义序列，
/// 提取纯文本内容用于解析 TUI 输出。
class AnsiParser {
  /// 匹配 ANSI 转义序列的正则表达式
  /// 包括 CSI 序列、SGR、光标移动、OSC 等
  static final RegExp _ansiRegex = RegExp(
    r'\x1B'        // ESC 字符
    r'(?:'
    r'[@-Z\\-_]'   // 单字符转义 (Fe)
    r'|'
    r'\[[0-?]*[ -/]*[@-~]'  // CSI 序列
    r'|'
    r'\].*?(?:\x07|\x1B\\)'  // OSC 序列
    r')',
  );

  /// 剥离所有 ANSI 转义码，返回纯文本
  static String strip(String text) {
    return text.replaceAll(_ansiRegex, '');
  }

  /// 提取非空行列表
  static List<String> extractLines(String text) {
    final cleaned = strip(text);
    return cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }
}
