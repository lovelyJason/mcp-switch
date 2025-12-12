import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class S {
  static final ValueNotifier<Locale> localeNotifier = ValueNotifier(const Locale('zh'));

  static bool get isEn => localeNotifier.value.languageCode == 'en';

  static void switchLanguage() {
    localeNotifier.value = isEn ? const Locale('zh') : const Locale('en');
  }

  static void setLocale(Locale locale) {
    localeNotifier.value = locale;
  }

  // Dictionary
  // Dictionary
  static final Map<String, Map<String, String>> _localizedValues = {};

  static Future<void> init() async {
    try {
      final zhJson = await rootBundle.loadString('lib/l10n/locales/zh.json');
      final enJson = await rootBundle.loadString('lib/l10n/locales/en.json');

      _localizedValues['zh'] = Map<String, String>.from(jsonDecode(zhJson));
      _localizedValues['en'] = Map<String, String>.from(jsonDecode(enJson));
    } catch (e) {
      debugPrint('Failed to load localization files: $e');
    }
  }

  static String get(String key) {
    return _localizedValues[localeNotifier.value.languageCode]?[key] ?? key;
  }
}
