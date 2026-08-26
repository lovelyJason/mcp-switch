import 'dart:io';

import '../utils/platform_utils.dart';

class ClaudeEnvironmentException implements Exception {
  final String message;
  const ClaudeEnvironmentException(this.message);

  @override
  String toString() => message;
}

/// Clash Verge Rev 的 profiles.yaml 使用 `current` 保存当前 profile UID。
/// 直接更新这个轻量状态文件比依赖未公开的 API/CLI 更稳定，也不会接触订阅 URL。
class ClashVergeService {
  final String Function() _configPath;
  final Future<String> Function(String path) _readFile;
  final Future<void> Function(String path, String content) _writeFile;

  ClashVergeService({
    String Function()? configPath,
    Future<String> Function(String path)? readFile,
    Future<void> Function(String path, String content)? writeFile,
  }) : _configPath = configPath ?? _defaultConfigPath,
       _readFile = readFile ?? ((path) => File(path).readAsString()),
       _writeFile =
           writeFile ?? ((path, content) => File(path).writeAsString(content));

  static String _defaultConfigPath() => PlatformUtils.joinPath(
    PlatformUtils.userHome,
    'Library',
    'Application Support',
    'io.github.clash-verge-rev.clash-verge-rev',
    'profiles.yaml',
  );

  /// 按 profiles.yaml 中的可见名称选择 profile，并写入 current UID。
  Future<List<String>> listSubscriptions() async {
    final content = await _readFile(_configPath()).catchError((_) {
      throw const ClaudeEnvironmentException('clash_profiles_file_missing');
    });
    final names = <String>[];
    for (final line in content.split('\n')) {
      final match = RegExp(r'^  name:\s*(.*)$').firstMatch(line);
      if (match == null) continue;
      final name = _unquote(match.group(1)!.trim());
      if (_isUsableName(name) && !names.contains(name)) names.add(name);
    }
    return names;
  }

  /// 按 profiles.yaml 中的可见名称选择 profile，并写入 current UID。
  Future<void> switchSubscription(String subscriptionName) async {
    final name = subscriptionName.trim();
    if (!_isUsableName(name)) {
      throw const ClaudeEnvironmentException('clash_subscription_empty');
    }

    final path = _configPath();
    final content = await _readFile(path).catchError((_) {
      throw const ClaudeEnvironmentException('clash_profiles_file_missing');
    });
    final lines = content.split('\n');
    String? uid;
    for (var i = 0; i < lines.length; i++) {
      final nameMatch = RegExp(r'^  name:\s*(.*)$').firstMatch(lines[i]);
      if (nameMatch == null || _unquote(nameMatch.group(1)!.trim()) != name) {
        continue;
      }
      for (var j = i - 1; j >= 0 && i - j <= 8; j--) {
        final uidMatch = RegExp(r'^- uid:\s*(\S+)').firstMatch(lines[j]);
        if (uidMatch != null) {
          uid = uidMatch.group(1);
          break;
        }
      }
      if (uid != null) break;
    }

    if (uid == null) {
      throw ClaudeEnvironmentException('clash_subscription_not_found: $name');
    }

    final currentIndex = lines.indexWhere(
      (line) => RegExp(r'^current:\s*').hasMatch(line),
    );
    if (currentIndex < 0) {
      throw const ClaudeEnvironmentException('clash_profiles_invalid');
    }
    lines[currentIndex] = 'current: $uid';
    await _writeFile(path, lines.join('\n'));
  }

  static String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"')))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  static bool _isUsableName(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'null';
  }
}

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

class MacTimezoneService {
  final ProcessRunner _run;

  MacTimezoneService({ProcessRunner? run}) : _run = run ?? _defaultRun;

  static Future<ProcessResult> _defaultRun(
    String executable,
    List<String> arguments,
  ) => Process.run(executable, arguments);

  static final RegExp _ianaTimezone = RegExp(
    r'^[A-Za-z0-9._+-]+/[A-Za-z0-9._+-]+(?:/[A-Za-z0-9._+-]+)?$',
  );

  /// 使用 macOS 原生管理员授权对话框，不在应用中保存或传递密码。
  Future<void> setTimezone(String timezone) async {
    final value = timezone.trim();
    if (!_ianaTimezone.hasMatch(value)) {
      throw const ClaudeEnvironmentException('timezone_invalid');
    }
    if (!Platform.isMacOS) {
      throw const ClaudeEnvironmentException('timezone_macos_only');
    }

    final escaped = value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    final script =
        'do shell script "systemsetup -settimezone $escaped" with administrator privileges';
    final result = await _run('osascript', ['-e', script]);
    if (result.exitCode != 0) {
      final error = result.stderr.toString().trim();
      throw ClaudeEnvironmentException(
        error.isEmpty ? 'timezone_authorization_failed' : error,
      );
    }
  }
}
