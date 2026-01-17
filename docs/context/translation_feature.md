# 翻译功能实现

## 概述

在 Markdown 内容查看弹窗中实现英译中翻译功能，支持**多翻译引擎自动降级**、限流保护、翻译缓存和语言切换。

## 功能特性

1. **多引擎降级** - 内置 3 个免费引擎 + 1 个可选引擎（DeepL），自动切换
2. **限流保护** - 429 错误自动标记，24 小时冷却期
3. **翻译缓存** - 翻译结果保存到 `*-zh.md` 文件，下次直接读取
4. **语言切换** - 翻译完成后显示 EN/中文 Tab 切换
5. **错误处理** - 翻译失败时显示 Toast 提示，引擎切换时通知用户

## 架构设计

```
┌─────────────────────────────────────────────────────────┐
│                  TranslationService                      │
│                                                          │
│   translate(text)                                        │
│        │                                                 │
│        ▼                                                 │
│   ┌─────────────────┐                                   │
│   │ 内置引擎（优先） │                                   │
│   │   MyMemory      │──429──┐                           │
│   │   LibreTranslate│──429──┼──► 标记限流（24h冷却）    │
│   │   Lingva        │──429──┘                           │
│   └────────┬────────┘                                   │
│            │ 全部失败                                    │
│            ▼                                             │
│   ┌─────────────────┐                                   │
│   │ 可选引擎（备用） │                                   │
│   │   DeepL Free    │◄─── 需要 API Key                  │
│   └────────┬────────┘                                   │
│            │                                             │
│            ▼                                             │
│   TranslationResult { text, engineUsed, engineSwitched } │
└─────────────────────────────────────────────────────────┘
```

## 翻译引擎

### 内置引擎（无需 API Key）

| 引擎 | 优先级 | API 地址 | 限制 |
|------|--------|----------|------|
| MyMemory | 1 | `api.mymemory.translated.net` | 5000 字/天 |
| LibreTranslate | 2 | `libretranslate.com` | 公共实例 |
| Lingva | 3 | `lingva.ml` | Google 翻译代理 |

### 可选引擎（需要 API Key）

| 引擎 | 优先级 | API 地址 | 配置位置 |
|------|--------|----------|----------|
| DeepL Free | 4（最低） | `api-free.deepl.com` | 设置 → 高级 |

## 文件结构

```
lib/
├── config/
│   └── translation_engines.dart    # 引擎配置（抽象类 + 具体实现）
├── services/
│   └── translation_service.dart    # 翻译服务核心（降级逻辑、限流管理）
└── ui/skills/dialogs/
    └── skill_content_dialog.dart   # UI 集成
```

## 核心代码

### 1. 翻译引擎抽象类

```dart
// lib/config/translation_engines.dart

abstract class TranslationEngine {
  String get id;           // 引擎唯一标识
  String get displayName;  // 显示名称
  bool get requiresApiKey => false;

  /// 执行翻译
  /// 抛出 Exception('RATE_LIMIT') 表示限流
  /// 抛出 Exception('API_ERROR_xxx') 表示其他错误
  Future<String> translate(String text, {String? apiKey});
}

// 内置引擎（按优先级排序）
final builtInEngines = <TranslationEngine>[
  MyMemoryEngine(),
  LibreTranslateEngine(),
  LingvaEngine(),
];

// 可选引擎（需要 API Key）
final optionalEngines = <TranslationEngine>[
  DeepLEngine(),
];
```

### 2. 翻译服务（核心逻辑）

```dart
// lib/services/translation_service.dart

class TranslationResult {
  final String text;
  final String engineUsed;
  final bool engineSwitched;  // 是否发生了引擎切换
}

class TranslationService extends ChangeNotifier {
  static const String _rateLimitKeyPrefix = 'translation_rate_limit_';
  static const int _cooldownHours = 24;

  String? _deeplApiKey;

  /// 执行翻译（带自动降级）
  Future<TranslationResult> translate(String text) async {
    // 1. 先尝试所有内置引擎
    final result = await _tryEngines(builtInEngines, text);
    if (result != null) return result;

    // 2. 内置引擎全部失败，尝试可选引擎（DeepL）
    if (_deeplApiKey != null && _deeplApiKey!.isNotEmpty) {
      final optionalResult = await _tryEngines(
        optionalEngines, text, apiKey: _deeplApiKey
      );
      if (optionalResult != null) return optionalResult;
    }

    // 3. 全部失败
    throw Exception('ALL_ENGINES_FAILED');
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
      await prefs.remove(key);  // 自动重置
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
  }
}
```

### 3. UI 集成

```dart
// lib/ui/skills/dialogs/skill_content_dialog.dart

Future<void> _translateContent() async {
  if (_translating) return;

  setState(() => _translating = true);

  try {
    final translationService = TranslationService();

    // 从 ConfigService 获取 DeepL API Key（如果有）
    final configService = Provider.of<ConfigService>(context, listen: false);
    translationService.setDeepLApiKey(configService.deeplApiKey);

    final result = await translationService.translate(_originalContent);

    // 翻译成功
    _translatedContent = result.text;
    _hasTranslation = true;

    // 缓存翻译结果
    final translatedFile = File(_translatedPath);
    await translatedFile.writeAsString(result.text);

    setState(() {
      _showTranslated = true;
      _translating = false;
    });

    // 如果发生了引擎切换，显示提示
    if (result.engineSwitched && mounted) {
      Toast.show(
        context,
        message: S.get('engine_switched').replaceAll('{engine}', result.engineUsed),
        type: ToastType.info,
      );
    }
  } catch (e) {
    // 错误处理...
  }
}
```

### 4. DeepL API Key 配置

```dart
// lib/services/config_service.dart

String? _deeplApiKey;
String? get deeplApiKey => _deeplApiKey;

Future<void> setDeepLApiKey(String? key) async {
  _deeplApiKey = key;
  final prefs = await SharedPreferences.getInstance();
  if (key == null || key.isEmpty) {
    await prefs.remove('deepl_api_key');
  } else {
    await prefs.setString('deepl_api_key', key);
  }
  notifyListeners();
}
```

## 本地化字符串

```json
// zh.json
{
  "translate": "翻译",
  "translating": "正在翻译中，请稍等...",
  "translate_failed": "翻译失败: {error}",
  "error_timeout": "请求超时",
  "error_network": "网络连接失败",
  "error_rate_limit": "请求过于频繁，请稍后再试",
  "error_empty_result": "翻译结果为空",
  "error_all_engines_failed": "所有翻译引擎均不可用",
  "engine_switched": "已自动切换至 {engine} 引擎",
  "deepl_api_key_title": "DeepL API Key",
  "deepl_api_key_desc": "配置后将作为备用翻译引擎（内置引擎失败时启用）",
  "deepl_api_key_hint": "输入 DeepL Free API Key",
  "get_api_key": "获取 API Key"
}

// en.json
{
  "translate": "Translate",
  "translating": "Translating, please wait...",
  "translate_failed": "Translation failed: {error}",
  "error_timeout": "Request timeout",
  "error_network": "Network connection failed",
  "error_rate_limit": "Too many requests, please try again later",
  "error_empty_result": "Translation result is empty",
  "error_all_engines_failed": "All translation engines unavailable",
  "engine_switched": "Switched to {engine} engine",
  "deepl_api_key_title": "DeepL API Key",
  "deepl_api_key_desc": "Will be used as backup engine when built-in engines fail",
  "deepl_api_key_hint": "Enter DeepL Free API Key",
  "get_api_key": "Get API Key"
}
```

## 依赖

```yaml
dependencies:
  http: ^1.1.0              # API 请求
  shared_preferences: ^x.x.x # 限流状态持久化
```

## 扩展指南

### 添加新翻译引擎

1. 在 `lib/config/translation_engines.dart` 中创建新类：

```dart
class NewEngine extends TranslationEngine {
  @override
  String get id => 'new_engine';

  @override
  String get displayName => 'New Engine';

  @override
  Future<String> translate(String text, {String? apiKey}) async {
    // 实现翻译逻辑
    // 429 时抛出 Exception('RATE_LIMIT')
    // 其他错误抛出 Exception('API_ERROR_xxx')
  }
}
```

2. 添加到引擎列表：

```dart
final builtInEngines = <TranslationEngine>[
  MyMemoryEngine(),
  LibreTranslateEngine(),
  LingvaEngine(),
  NewEngine(),  // 添加在这里
];
```

## 注意事项

1. **限流处理**：引擎返回 429 后会被标记，24 小时后自动重置
2. **分段翻译**：长文本按 450 字符分段，每段间隔 500ms
3. **Markdown 修复**：自动修复翻译后破损的标题、列表、链接格式
4. **翻译缓存**：保存在原文件同目录，命名为 `原文件名-zh.md`
5. **DeepL 优先级最低**：仅在内置引擎全部失败时才使用
