import 'dart:convert';
import 'package:http/http.dart' as http;

/// 翻译引擎抽象类
abstract class TranslationEngine {
  /// 引擎唯一标识
  String get id;

  /// 显示名称
  String get displayName;

  /// 是否需要 API Key
  bool get requiresApiKey => false;

  /// 执行翻译
  /// 抛出 Exception('RATE_LIMIT') 表示限流
  /// 抛出 Exception('API_ERROR_xxx') 表示其他错误
  Future<String> translate(String text, {String? apiKey});
}

/// MyMemory 翻译引擎（免费，带邮箱参数提高额度）
class MyMemoryEngine extends TranslationEngine {
  @override
  String get id => 'mymemory';

  @override
  String get displayName => 'MyMemory';

  @override
  Future<String> translate(String text, {String? apiKey}) async {
    final encoded = Uri.encodeComponent(text);
    // 添加 de 参数（邮箱）可以提高每日额度到 10000 字
    final url = 'https://api.mymemory.translated.net/get'
        '?q=$encoded&langpair=en|zh-CN&de=mcp-switch@example.com';

    final response = await http
        .get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 429) {
      throw Exception('RATE_LIMIT');
    }

    if (response.statusCode != 200) {
      throw Exception('API_ERROR_${response.statusCode}');
    }

    final json = jsonDecode(response.body);

    // 检查是否返回了配额警告
    final responseStatus = json['responseStatus'];
    if (responseStatus == 429) {
      throw Exception('RATE_LIMIT');
    }

    final translatedText = json['responseData']?['translatedText'];

    // 检查是否返回了限额警告文本
    if (translatedText != null &&
        translatedText.toString().contains('MYMEMORY WARNING')) {
      throw Exception('RATE_LIMIT');
    }

    if (translatedText == null || translatedText.toString().isEmpty) {
      throw Exception('EMPTY_RESULT');
    }

    return translatedText.toString();
  }
}

/// SimplyTranslate 翻译引擎（Google 翻译代理，免费无限制）
class SimplyTranslateEngine extends TranslationEngine {
  @override
  String get id => 'simplytranslate';

  @override
  String get displayName => 'SimplyTranslate';

  @override
  Future<String> translate(String text, {String? apiKey}) async {
    final encoded = Uri.encodeComponent(text);
    final url = 'https://simplytranslate.org/api/translate'
        '?engine=google&from=en&to=zh-CN&text=$encoded';

    final response = await http
        .get(
          Uri.parse(url),
          headers: {'Accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 429) {
      throw Exception('RATE_LIMIT');
    }

    if (response.statusCode != 200) {
      throw Exception('API_ERROR_${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final translatedText = json['translated_text'];

    if (translatedText == null || translatedText.toString().isEmpty) {
      throw Exception('EMPTY_RESULT');
    }

    return translatedText.toString();
  }
}

/// DeepL Free 翻译引擎（需要 API Key）
class DeepLEngine extends TranslationEngine {
  @override
  String get id => 'deepl';

  @override
  String get displayName => 'DeepL';

  @override
  bool get requiresApiKey => true;

  @override
  Future<String> translate(String text, {String? apiKey}) async {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DEEPL_NO_API_KEY');
    }

    const apiUrl = 'https://api-free.deepl.com/v2/translate';

    final response = await http
        .post(
          Uri.parse(apiUrl),
          headers: {
            'Authorization': 'DeepL-Auth-Key $apiKey',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'text': text,
            'target_lang': 'ZH',
          },
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 429) {
      throw Exception('RATE_LIMIT');
    }

    if (response.statusCode == 403) {
      throw Exception('DEEPL_INVALID_KEY');
    }

    if (response.statusCode != 200) {
      throw Exception('API_ERROR_${response.statusCode}');
    }

    final json = jsonDecode(response.body);
    final translations = json['translations'] as List?;

    if (translations == null || translations.isEmpty) {
      throw Exception('EMPTY_RESULT');
    }

    final translatedText = translations[0]['text'];
    if (translatedText == null || translatedText.toString().isEmpty) {
      throw Exception('EMPTY_RESULT');
    }

    return translatedText.toString();
  }
}

/// 内置翻译引擎列表（按优先级排序，无需 API Key）
final builtInEngines = <TranslationEngine>[
  MyMemoryEngine(),
  SimplyTranslateEngine(),
];

/// 可选翻译引擎（需要 API Key）
final optionalEngines = <TranslationEngine>[
  DeepLEngine(),
];

/// 获取所有引擎（内置 + 可选）
List<TranslationEngine> getAllEngines() {
  return [...builtInEngines, ...optionalEngines];
}
