import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'config_service.dart';
import 'proxy_service.dart';

/// 更新信息模型
class UpdateInfo {
  final String version;
  final String notes;
  final String? downloadUrl;
  final String releaseUrl;

  UpdateInfo({
    required this.version,
    required this.notes,
    this.downloadUrl,
    required this.releaseUrl,
  });

  bool get supportsAutoUpdate => downloadUrl != null;
}

/// 下载进度回调: (receivedBytes, totalBytes) — totalBytes 为 -1 表示未知
typedef DownloadProgressCallback = void Function(int received, int total);

/// 更新阶段
enum UpdatePhase { idle, checking, downloading, extracting, restarting, error }

/// 更新检测服务
class UpdateService extends ChangeNotifier {
  static const String _autoCheckKey = 'update_auto_check_enabled';
  static const String _skippedVersionKey = 'update_skipped_version';
  static const String _repoUrl =
      'https://api.github.com/repos/lovelyJason/mcp-switch/releases/latest';

  final ConfigService? _configService;

  UpdateInfo? _availableUpdate;
  bool _isChecking = false;

  UpdatePhase _phase = UpdatePhase.idle;
  double _progress = 0;

  UpdateService({ConfigService? configService})
      : _configService = configService;

  UpdateInfo? get availableUpdate => _availableUpdate;
  bool get isChecking => _isChecking;
  bool get hasUpdate => _availableUpdate != null;
  UpdatePhase get phase => _phase;
  double get progress => _progress;

  http.Client _createClient() {
    if (_configService != null && _configService.hasProxy) {
      return ProxyService(_configService).createProxiedClient();
    }
    return http.Client();
  }

  /// 初始化服务：每次启动都检测一次
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final autoCheck = prefs.getBool(_autoCheckKey) ?? true;

    if (!autoCheck) return;

    // 延迟 3 秒后检测，避免阻塞应用启动
    Future.delayed(const Duration(seconds: 3), () {
      checkForUpdates(silent: true);
    });
  }

  /// 检查更新
  /// [silent] 静默模式不抛异常，用于自动检测
  Future<UpdateInfo?> checkForUpdates({bool silent = false}) async {
    if (_isChecking) return null;

    _isChecking = true;
    _phase = UpdatePhase.checking;
    notifyListeners();

    http.Client? client;
    try {
      client = _createClient();
      final response = await client
          .get(Uri.parse(_repoUrl))
          .timeout(const Duration(seconds: 15));

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

      // 检查是否为跳过的版本
      final prefs = await SharedPreferences.getInstance();
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
      _phase = UpdatePhase.idle;
      notifyListeners();
      return _availableUpdate;
    } catch (e) {
      _isChecking = false;
      _phase = UpdatePhase.idle;
      notifyListeners();
      if (!silent) rethrow;
      debugPrint('[UpdateService] Check failed: $e');
      return null;
    } finally {
      client?.close();
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
  }

  /// 获取自动检测开关状态
  Future<bool> getAutoCheck() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCheckKey) ?? true;
  }

  /// 执行自动更新（macOS），带下载进度
  Future<void> performAutoUpdate(String zipUrl) async {
    if (!Platform.isMacOS) {
      throw UnsupportedError('Auto update only supported on macOS');
    }

    _phase = UpdatePhase.downloading;
    _progress = 0;
    notifyListeners();

    http.Client? client;
    try {
      client = _createClient();
      final request = http.Request('GET', Uri.parse(zipUrl));
      final streamedResponse = await client.send(request).timeout(
        const Duration(seconds: 120),
      );

      if (streamedResponse.statusCode != 200) {
        throw Exception('Download failed: ${streamedResponse.statusCode}');
      }

      final totalBytes = streamedResponse.contentLength ?? -1;
      int receivedBytes = 0;
      final chunks = <List<int>>[];

      await for (final chunk in streamedResponse.stream) {
        chunks.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          _progress = receivedBytes / totalBytes;
          notifyListeners();
        }
      }

      final bytes =
          chunks.expand((c) => c).toList();

      _phase = UpdatePhase.extracting;
      _progress = 1.0;
      notifyListeners();

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/update.zip');
      await zipFile.writeAsBytes(bytes);

      final extractDir = Directory('${tempDir.path}/update_extract');
      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create();

      final result = await Process.run('unzip', [
        '-o',
        zipFile.path,
        '-d',
        extractDir.path,
      ]);
      if (result.exitCode != 0) throw Exception('Unzip failed');

      const appName = 'MCP Switch.app';
      final newAppPath = '${extractDir.path}/$appName';
      if (!await Directory(newAppPath).exists()) {
        throw Exception('App bundle not found in update');
      }

      String currentAppPath = Platform.resolvedExecutable;
      while (currentAppPath.isNotEmpty && !currentAppPath.endsWith('.app')) {
        currentAppPath = Directory(currentAppPath).parent.path;
      }
      if (currentAppPath.isEmpty || !currentAppPath.endsWith('.app')) {
        throw Exception('Could not determine current app path');
      }

      _phase = UpdatePhase.restarting;
      notifyListeners();

      final scriptFile = File('${tempDir.path}/update_script.sh');
      await scriptFile.writeAsString('''
#!/bin/bash
sleep 2
rm -rf "$currentAppPath"
mv "$newAppPath" "$currentAppPath"
open "$currentAppPath"
''');

      await Process.run('chmod', ['+x', scriptFile.path]);
      await Process.start(
          'sh', [scriptFile.path], mode: ProcessStartMode.detached);
      exit(0);
    } catch (e) {
      _phase = UpdatePhase.error;
      notifyListeners();
      rethrow;
    } finally {
      client?.close();
    }
  }

  void resetPhase() {
    _phase = UpdatePhase.idle;
    _progress = 0;
    notifyListeners();
  }

  /// Debug: 伪造一个新版本用于测试横幅显示
  void debugFakeUpdate() {
    _availableUpdate = UpdateInfo(
      version: 'v99.0.0',
      notes: 'This is a fake update for debug testing.',
      releaseUrl: 'https://github.com/lovelyJason/mcp-switch/releases',
    );
    notifyListeners();
  }

  /// Debug: 清除伪造的更新
  void debugClearFakeUpdate() {
    _availableUpdate = null;
    notifyListeners();
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
    super.dispose();
  }
}
