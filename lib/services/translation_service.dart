import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/translation_engines.dart';

/// 翻译结果
class TranslationResult {
  final String text;
  final String engineUsed;
  final bool engineSwitched; // 是否发生了引擎切换

  TranslationResult({
    required this.text,
    required this.engineUsed,
    this.engineSwitched = false,
  });
}

/// 翻译服务
///
/// 核心职责：
/// 1. 管理多个翻译引擎的降级策略
/// 2. 处理限流状态（429 → 标记 → 24小时冷却）
/// 3. 自动切换到下一个可用引擎
/// 4. 文本分块翻译
/// 5. Markdown 格式修复
class TranslationService extends ChangeNotifier {
  static const String _rateLimitKeyPrefix = 'translation_rate_limit_';
  static const int _cooldownHours = 24;

  /// DeepL API Key（从 ConfigService 获取）
  String? _deeplApiKey;

  /// 设置 DeepL API Key
  void setDeepLApiKey(String? key) {
    _deeplApiKey = key;
    notifyListeners();
  }

  /// 检查引擎是否被限流
  Future<bool> _isEngineLimited(String engineId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_rateLimitKeyPrefix$engineId';
    final timestamp = prefs.getInt(key);

    if (timestamp == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = now - timestamp;

    // 24小时 = 86400000 毫秒
    if (duration > _cooldownHours * 60 * 60 * 1000) {
      await prefs.remove(key); // 自动重置
      return false;
    }

    return true;
  }

  /// 标记引擎被限流
  Future<void> _markEngineLimited(String engineId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_rateLimitKeyPrefix$engineId';
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(key, now);
    debugPrint('🚫 Marked $engineId as rate limited (24h cooldown)');
  }

  /// 执行翻译（带自动降级）
  Future<TranslationResult> translate(String text) async {
    // 1. 先尝试所有内置引擎
    final result = await _tryEngines(builtInEngines, text);
    if (result != null) return result;

    // 2. 内置引擎全部失败，尝试可选引擎（DeepL）
    if (_deeplApiKey != null && _deeplApiKey!.isNotEmpty) {
      final optionalResult = await _tryEngines(optionalEngines, text, apiKey: _deeplApiKey);
      if (optionalResult != null) return optionalResult;
    }

    // 3. 全部失败
    throw Exception('ALL_ENGINES_FAILED');
  }

  /// 尝试一组引擎
  Future<TranslationResult?> _tryEngines(
    List<TranslationEngine> engines,
    String text, {
    String? apiKey,
  }) async {
    bool engineSwitched = false;

    for (int i = 0; i < engines.length; i++) {
      final engine = engines[i];

      // 检查是否被限流
      if (await _isEngineLimited(engine.id)) {
        debugPrint('⏭️ Skipping ${engine.displayName} (rate limited)');
        continue;
      }

      // 需要 API Key 但没有配置
      if (engine.requiresApiKey && (apiKey == null || apiKey.isEmpty)) {
        debugPrint('⏭️ Skipping ${engine.displayName} (no API key)');
        continue;
      }

      try {
        debugPrint('🔄 Trying ${engine.displayName}...');

        // 分块翻译
        final translatedText = await _translateWithChunks(engine, text, apiKey: apiKey);

        debugPrint('✅ Translation succeeded with ${engine.displayName}');

        return TranslationResult(
          text: translatedText,
          engineUsed: engine.displayName,
          engineSwitched: engineSwitched,
        );
      } catch (e) {
        final errorMsg = e.toString();
        debugPrint('❌ ${engine.displayName} failed: $errorMsg');

        // 限流错误，标记引擎
        if (errorMsg.contains('RATE_LIMIT')) {
          await _markEngineLimited(engine.id);
          engineSwitched = true; // 下一个引擎成功时需要提示切换
          continue;
        }

        // 其他错误也尝试下一个引擎
        engineSwitched = true;
        continue;
      }
    }

    return null;
  }

  /// 分块翻译
  Future<String> _translateWithChunks(
    TranslationEngine engine,
    String text, {
    String? apiKey,
  }) async {
    final chunks = _splitTextIntoChunks(text, 450);
    final translatedChunks = <String>[];

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final translatedChunk = await engine.translate(chunk, apiKey: apiKey);
      translatedChunks.add(translatedChunk);

      // 避免短时间内大量请求
      if (i < chunks.length - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    final result = translatedChunks.join('\n');
    return _fixMarkdownFormat(result);
  }

  /// 文本分块
  List<String> _splitTextIntoChunks(String text, int maxLength) {
    final chunks = <String>[];
    final lines = text.split('\n');
    var currentChunk = StringBuffer();

    for (final line in lines) {
      if (currentChunk.length + line.length + 1 > maxLength) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk.toString());
          currentChunk = StringBuffer();
        }
        if (line.length > maxLength) {
          var remaining = line;
          while (remaining.length > maxLength) {
            chunks.add(remaining.substring(0, maxLength));
            remaining = remaining.substring(maxLength);
          }
          if (remaining.isNotEmpty) {
            currentChunk.write(remaining);
          }
        } else {
          currentChunk.write(line);
        }
      } else {
        if (currentChunk.isNotEmpty) {
          currentChunk.write('\n');
        }
        currentChunk.write(line);
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString());
    }

    return chunks;
  }

  /// 修复 Markdown 格式
  String _fixMarkdownFormat(String text) {
    var result = text;

    // 修复标题格式：##标题 -> ## 标题
    result = result.replaceAllMapped(
      RegExp(r'^(#{1,6})([^\s#])', multiLine: true),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // 修复重复的 # 号：## #标题 -> ## 标题
    result = result.replaceAllMapped(
      RegExp(r'^(#{1,6})\s+#+(.*)', multiLine: true),
      (match) => '${match.group(1)} ${match.group(2)?.trim()}',
    );

    // 修复列表格式：*项目 -> * 项目
    result = result.replaceAllMapped(
      RegExp(r'^(\s*[\*\-])\s*([^\s\*\-])', multiLine: true),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    // 修复链接格式
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+?)([\]】）\)]*[。，、；：！？\.\,\;\:\!\?]*)(\)?)'),
      (match) {
        final linkText = match.group(1) ?? '';
        var url = match.group(2) ?? '';
        final trailingPunct = match.group(3) ?? '';
        url = url.replaceAll(RegExp(r'[\]】）。，、；：！？\.\,]+$'), '');
        return '[$linkText]($url)$trailingPunct';
      },
    );

    // 修复被翻译破坏的链接：[文本]（URL） -> [文本](URL)
    result = result.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]（([^）]+)）'),
      (match) => '[${match.group(1)}](${match.group(2)})',
    );

    return result;
  }

  /// 获取被限流的引擎及剩余冷却时间
  Future<Map<String, Duration>> getRateLimitedEngines() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, Duration>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final engine in getAllEngines()) {
      final key = '$_rateLimitKeyPrefix${engine.id}';
      final timestamp = prefs.getInt(key);

      if (timestamp != null) {
        final elapsed = now - timestamp;
        final cooldownMs = _cooldownHours * 60 * 60 * 1000;

        if (elapsed < cooldownMs) {
          final remaining = Duration(milliseconds: cooldownMs - elapsed);
          result[engine.displayName] = remaining;
        }
      }
    }

    return result;
  }

  /// 清除所有限流状态
  Future<void> clearAllRateLimits() async {
    final prefs = await SharedPreferences.getInstance();
    for (final engine in getAllEngines()) {
      final key = '$_rateLimitKeyPrefix${engine.id}';
      await prefs.remove(key);
    }
    notifyListeners();
  }
}
