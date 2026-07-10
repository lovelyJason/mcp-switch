import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../models/cursor_auth_snapshot.dart';
import '../utils/platform_utils.dart';
import 'logger_service.dart';

/// 读写 Cursor 全局认证（state.vscdb）与设备指纹（storage.json）
class CursorAuthFileService {
  CursorAuthFileService._();
  static final instance = CursorAuthFileService._();

  static const _authKeys = [
    'cursorAuth/accessToken',
    'cursorAuth/refreshToken',
    'cursorAuth/cachedEmail',
    'cursorAuth/stripeMembershipType',
    'cursorAuth/cachedSignUpType',
  ];

  String get globalStorageDir {
    final home = PlatformUtils.userHome;
    if (Platform.isMacOS) {
      return p.join(home, 'Library', 'Application Support', 'Cursor', 'User', 'globalStorage');
    }
    if (Platform.isWindows) {
      return p.join(home, 'AppData', 'Roaming', 'Cursor', 'User', 'globalStorage');
    }
    return p.join(home, '.config', 'Cursor', 'User', 'globalStorage');
  }

  String get stateDbPath => p.join(globalStorageDir, 'state.vscdb');
  String get storageJsonPath => p.join(globalStorageDir, 'storage.json');
  String get stateDbBackupPath => p.join(globalStorageDir, 'state.vscdb.backup');

  bool get stateDbExists => File(stateDbPath).existsSync();
  bool get storageJsonExists => File(storageJsonPath).existsSync();

  Future<CursorAuthSnapshot> readLiveSnapshot() async {
    final auth = await _readAuthFromDb();
    final device = await _readDeviceFromStorage();
    return CursorAuthSnapshot(
      email: auth['email'],
      accessToken: auth['accessToken'],
      refreshToken: auth['refreshToken'],
      membershipType: auth['membershipType'],
      signUpType: auth['signUpType'],
      machineId: device['machineId'],
      macMachineId: device['macMachineId'],
      devDeviceId: device['devDeviceId'],
      sqmId: device['sqmId'],
    );
  }

  Future<void> applySnapshot(
    CursorAuthSnapshot snapshot, {
    bool removeStateDbBackup = true,
  }) async {
    await _writeAuthToDb(snapshot);
    await _writeDeviceToStorage(snapshot);
    if (removeStateDbBackup) {
      await _removeStateDbBackup();
    }
  }

  Future<String?> backupToAppDir() async {
    final snapshot = await readLiveSnapshot();
    if (!snapshot.hasAuth && !snapshot.hasDeviceIds) return null;

    final backupDir = p.join(PlatformUtils.appDataDir, 'backups', 'cursor');
    await Directory(backupDir).create(recursive: true);
    final fileName =
        'backup_${DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first}.json';
    final file = File(p.join(backupDir, fileName));
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'auth': {
          'email': snapshot.email,
          'accessToken': snapshot.accessToken,
          'refreshToken': snapshot.refreshToken,
          'membershipType': snapshot.membershipType,
          'signUpType': snapshot.signUpType,
        },
        'device': {
          'machineId': snapshot.machineId,
          'macMachineId': snapshot.macMachineId,
          'devDeviceId': snapshot.devDeviceId,
          'sqmId': snapshot.sqmId,
        },
      }),
      flush: true,
    );
    return file.path;
  }

  Future<Map<String, String?>> _readAuthFromDb() async {
    final result = <String, String?>{};
    if (!stateDbExists) return result;

    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(stateDbPath, mode: sqlite.OpenMode.readOnly);
      for (final key in _authKeys) {
        final rows = db.select(
          "SELECT value FROM ItemTable WHERE key = ?",
          [key],
        );
        if (rows.isEmpty) continue;
        final raw = rows.first['value']?.toString();
        switch (key) {
          case 'cursorAuth/accessToken':
            result['accessToken'] = raw;
          case 'cursorAuth/refreshToken':
            result['refreshToken'] = _normalizeRefreshToken(raw);
          case 'cursorAuth/cachedEmail':
            result['email'] = raw;
          case 'cursorAuth/stripeMembershipType':
            result['membershipType'] = raw;
          case 'cursorAuth/cachedSignUpType':
            result['signUpType'] = raw;
        }
      }
    } catch (e, st) {
      LoggerService.error('CursorAuthFileService: read auth failed', e, st);
      rethrow;
    } finally {
      db?.dispose();
    }
    return result;
  }

  Future<Map<String, String?>> _readDeviceFromStorage() async {
    final result = <String, String?>{};
    final file = File(storageJsonPath);
    if (!await file.exists()) return result;

    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      result['machineId'] = map['telemetry.machineId']?.toString();
      result['macMachineId'] = map['telemetry.macMachineId']?.toString();
      result['devDeviceId'] = map['telemetry.devDeviceId']?.toString();
      result['sqmId'] = map['telemetry.sqmId']?.toString();
    } catch (e, st) {
      LoggerService.error('CursorAuthFileService: read storage.json failed', e, st);
      rethrow;
    }
    return result;
  }

  Future<void> _writeAuthToDb(CursorAuthSnapshot snapshot) async {
    final dir = Directory(globalStorageDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    sqlite.Database? db;
    try {
      db = sqlite.sqlite3.open(stateDbPath, mode: sqlite.OpenMode.readWriteCreate);
      _upsertItem(db, 'cursorAuth/accessToken', snapshot.accessToken);
      _upsertItem(db, 'cursorAuth/refreshToken', snapshot.refreshToken);
      _upsertItem(db, 'cursorAuth/cachedEmail', snapshot.email);
      _upsertItem(db, 'cursorAuth/stripeMembershipType', snapshot.membershipType);
      _upsertItem(db, 'cursorAuth/cachedSignUpType', snapshot.signUpType ?? 'Auth_0');
    } catch (e, st) {
      LoggerService.error('CursorAuthFileService: write auth failed', e, st);
      rethrow;
    } finally {
      db?.dispose();
    }
  }

  void _upsertItem(sqlite.Database db, String key, String? value) {
    if (value == null || value.isEmpty) {
      db.execute('DELETE FROM ItemTable WHERE key = ?', [key]);
      return;
    }
    db.execute(
      'INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  Future<void> _writeDeviceToStorage(CursorAuthSnapshot snapshot) async {
    final file = File(storageJsonPath);
    Map<String, dynamic> map = {};
    if (await file.exists()) {
      try {
        map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } catch (_) {
        map = {};
      }
    }

    void setIfPresent(String key, String? value) {
      if (value != null && value.isNotEmpty) {
        map[key] = value;
      }
    }

    setIfPresent('telemetry.machineId', snapshot.machineId);
    setIfPresent('telemetry.macMachineId', snapshot.macMachineId);
    setIfPresent('telemetry.devDeviceId', snapshot.devDeviceId);
    setIfPresent('telemetry.sqmId', snapshot.sqmId);

    final dir = file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(map),
      flush: true,
    );
  }

  Future<void> _removeStateDbBackup() async {
    final backup = File(stateDbBackupPath);
    if (await backup.exists()) {
      await backup.delete();
    }
  }

  String? _normalizeRefreshToken(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) return trimmed;
    try {
      final map = jsonDecode(trimmed) as Map<String, dynamic>;
      final token = map['token']?.toString();
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return trimmed;
  }
}
