import 'dart:convert';
import 'dart:io';

import '../utils/platform_utils.dart';

class ClaudePluginIntegrationService {
  static Future<File> _configFile() async {
    final home = PlatformUtils.userHome;
    final path = PlatformUtils.joinPath(home, '.claude', 'config.json');
    final file = File(path);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return file;
  }

  static Future<Map<String, dynamic>> _readConfigObject(File file) async {
    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    try {
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  /// Non-official provider mode: set primaryApiKey to "any".
  static Future<bool> writeManagedConfig() async {
    final file = await _configFile();
    final obj = await _readConfigObject(file);
    final current = obj['primaryApiKey']?.toString();
    if (current == 'any') {
      return false;
    }
    obj['primaryApiKey'] = 'any';
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(obj)}\n');
    return true;
  }

  /// Official provider or integration disabled: remove primaryApiKey.
  static Future<bool> clearPrimaryApiKey() async {
    final file = await _configFile();
    final obj = await _readConfigObject(file);
    if (!obj.containsKey('primaryApiKey')) {
      return false;
    }
    obj.remove('primaryApiKey');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(obj)}\n');
    return true;
  }
}
