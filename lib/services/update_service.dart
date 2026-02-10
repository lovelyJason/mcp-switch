import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// 更新信息模型
class UpdateInfo {
  final String version;
  final String notes;
  final String? downloadUrl; // macOS ZIP 下载地址
  final String releaseUrl; // GitHub Release 页面地址

  UpdateInfo({
    required this.version,
    required this.notes,
    this.downloadUrl,
    required this.releaseUrl,
  });

  /// 是否支持自动更新（有 ZIP 下载地址）
  bool get supportsAutoUpdate => downloadUrl != null;
}

/// 更新检测服务
class UpdateService extends ChangeNotifier {
  static const String _lastCheckKey = 'update_last_check_time';
  static const String _autoCheckKey = 'update_auto_check_enabled';
  static const String _skippedVersionKey = 'update_skipped_version';
  static const Duration _checkInterval = Duration(hours: 24);
  static const String _repoUrl = 'https://api.github.com/repos/lovelyJason/mcp-switch/releases/latest';

  Timer? _periodicTimer;
  UpdateInfo? _availableUpdate;
  bool _isChecking = false;

  /// 可用更新（null 表示无更新或未检测）
  UpdateInfo? get availableUpdate => _availableUpdate;

  /// 是否正在检测
  bool get isChecking => _isChecking;

  /// 是否有可用更新
  bool get hasUpdate => _availableUpdate != null;

  /// 初始化服务：启动时检测 + 定时检测
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final autoCheck = prefs.getBool(_autoCheckKey) ?? true;

    if (!autoCheck) return;

    // 延迟 3 秒后检测，避免阻塞应用启动
    Future.delayed(const Duration(seconds: 3), () {
      _checkIfNeeded();
    });

    // 启动定时检测
    startPeriodicCheck();
  }

  /// 检查是否需要检测（距离上次检测超过 24 小时）
  Future<void> _checkIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastCheck > _checkInterval.inMilliseconds) {
      await checkForUpdates(silent: true);
    }
  }

  /// 启动定时检测（每 24 小时）
  void startPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(_checkInterval, (_) {
      checkForUpdates(silent: true);
    });
  }

  /// 停止定时检测
  void stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// 检查更新
  /// [silent] 静默模式不抛异常，用于自动检测
  Future<UpdateInfo?> checkForUpdates({bool silent = false}) async {
    if (_isChecking) return null;

    _isChecking = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(_repoUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch releases: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final latestVersion = data['tag_name'] as String;
      final assets = data['assets'] as List;
      final releaseUrl = data['html_url'] as String;
      final notes = data['body'] as String? ?? '';

      // 查找 macOS ZIP 下载地址
      String? downloadUrl;
      for (var asset in assets) {
        final name = asset['name'].toString().toLowerCase();
        if (name.endsWith('.zip') && name.contains('macos')) {
          downloadUrl = asset['browser_download_url'];
          break;
        }
      }

      // 获取当前版本
      final packageInfo = await PackageInfo.fromPlatform();
      final current = _normalizeVersion(packageInfo.version);
      final latest = _normalizeVersion(latestVersion);

      // 记录检测时间
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      // 检查是否为跳过的版本
      final skippedVersion = prefs.getString(_skippedVersionKey);
      if (skippedVersion == latest) {
        _availableUpdate = null;
        _isChecking = false;
        notifyListeners();
        return null;
      }

      // 比较版本
      if (_compareVersions(latest, current) > 0) {
        _availableUpdate = UpdateInfo(
          version: latestVersion,
          notes: notes,
          downloadUrl: downloadUrl,
          releaseUrl: releaseUrl,
        );
      } else {
        _availableUpdate = null;
      }

      _isChecking = false;
      notifyListeners();
      return _availableUpdate;
    } catch (e) {
      _isChecking = false;
      notifyListeners();
      if (!silent) rethrow;
      debugPrint('[UpdateService] Check failed: $e');
      return null;
    }
  }

  /// 跳过此版本（不再提示）
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedVersionKey, _normalizeVersion(version));
    _availableUpdate = null;
    notifyListeners();
  }

  /// 清除跳过的版本
  Future<void> clearSkippedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_skippedVersionKey);
  }

  /// 设置自动检测开关
  Future<void> setAutoCheck(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckKey, enabled);
    if (enabled) {
      startPeriodicCheck();
    } else {
      stopPeriodicCheck();
    }
  }

  /// 获取自动检测开关状态
  Future<bool> getAutoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCheckKey) ?? true;
  }

  /// 执行自动更新（macOS）
  Future<void> performAutoUpdate(String zipUrl) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Auto update only supported on macOS');
    }

    // 1. 下载 ZIP
    final response = await http.get(Uri.parse(zipUrl));
    if (response.statusCode != 200) {
      throw Exception('Download failed: ${response.statusCode}');
    }

    final tempDir = await getTemporaryDirectory();
    final zipFile = File('${tempDir.path}/update.zip');
    await zipFile.writeAsBytes(response.bodyBytes);

    // 2. 解压
    final extractDir = Directory('${tempDir.path}/update_extract');
    if (await extractDir.exists()) await extractDir.delete(recursive: true);
    await extractDir.create();

    final result = await Process.run('unzip', [
      '-o',
      zipFile.path,
      '-d',
      extractDir.path,
    ]);
    if (result.exitCode != 0) throw Exception('Unzip failed');

    // 3. 查找 .app
    const appName = 'MCP Switch.app';
    final newAppPath = '${extractDir.path}/$appName';
    if (!await Directory(newAppPath).exists()) {
      throw Exception('App bundle not found in update');
    }

    // 4. 获取当前应用路径
    String currentAppPath = Platform.resolvedExecutable;
    while (currentAppPath.isNotEmpty && !currentAppPath.endsWith('.app')) {
      currentAppPath = Directory(currentAppPath).parent.path;
    }
    if (currentAppPath.isEmpty || !currentAppPath.endsWith('.app')) {
      throw Exception('Could not determine current app path');
    }

    // 5. 创建替换脚本
    final scriptFile = File('${tempDir.path}/update_script.sh');
    await scriptFile.writeAsString('''
#!/bin/bash
sleep 2
rm -rf "$currentAppPath"
mv "$newAppPath" "$currentAppPath"
open "$currentAppPath"
''');

    // 6. 执行脚本并退出
    await Process.run('chmod', ['+x', scriptFile.path]);
    await Process.start('sh', [scriptFile.path], mode: ProcessStartMode.detached);
    exit(0);
  }

  /// 标准化版本号（去除 v 前缀和 build number）
  String _normalizeVersion(String version) {
    return version.replaceAll('v', '').split('+')[0];
  }

  /// 比较版本号，返回 >0 表示 v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (var i = 0; i < maxLen; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
