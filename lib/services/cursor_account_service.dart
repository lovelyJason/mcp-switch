import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/cursor_auth_snapshot.dart';
import 'cursor_auth_file_service.dart';
import 'cursor_process_service.dart';
import 'logger_service.dart';

class DuplicateCursorAccountNameException implements Exception {
  final String name;
  const DuplicateCursorAccountNameException(this.name);

  @override
  String toString() => 'Duplicate cursor account name: $name';
}

class CursorAccountSwitchException implements Exception {
  final String message;
  const CursorAccountSwitchException(this.message);

  @override
  String toString() => message;
}

/// Cursor 多账号本地管理与切换
class CursorAccountService extends ChangeNotifier {
  final AppDatabase _db;
  final _authFiles = CursorAuthFileService.instance;
  final _process = CursorProcessService.instance;

  List<CursorAccount> _accounts = [];
  bool _initialized = false;

  List<CursorAccount> get accounts => List.unmodifiable(_accounts);
  CursorAccount? get activeAccount =>
      _accounts.where((a) => a.isActive).firstOrNull;

  CursorAccountService(this._db);

  Future<void> init() async {
    if (_initialized) return;
    await _loadAccounts();
    await _reconcileActiveFromDisk();
    _initialized = true;
    notifyListeners();
  }

  Future<CursorAccount?> getAccountById(String id) =>
      _db.getCursorAccountById(id);

  Future<void> refresh() async {
    await _loadAccounts();
    notifyListeners();
  }

  Future<void> _loadAccounts() async {
    _accounts = await _db.getAllCursorAccounts();
  }

  Future<void> _reconcileActiveFromDisk() async {
    if (!_authFiles.stateDbExists) return;
    try {
      final live = await _authFiles.readLiveSnapshot();
      if (!live.hasAuth) return;

      final match = _accounts.where((a) {
        return _sameNullable(a.email, live.email) &&
            _sameNullable(a.accessToken, live.accessToken);
      }).firstOrNull;

      if (match != null && !match.isActive) {
        await _db.activateCursorAccount(match.id);
        await _loadAccounts();
      }
    } catch (e) {
      LoggerService.error('CursorAccountService: reconcile failed', e);
    }
  }

  bool _sameNullable(String? a, String? b) {
    if (a == null || b == null) return false;
    return a.trim() == b.trim();
  }

  Future<CursorAuthSnapshot> captureFromCursor() async {
    if (!_authFiles.stateDbExists) {
      throw CursorAccountSwitchException('cursor_auth_db_not_found');
    }
    return _authFiles.readLiveSnapshot();
  }

  Future<bool> isCursorRunning() => _process.isCursorRunning();

  Future<bool> isLiveAccountSynced(String accountId) async {
    final account = await _db.getCursorAccountById(accountId);
    if (account == null) return true;
    if (!_authFiles.stateDbExists) return false;

    try {
      final live = await _authFiles.readLiveSnapshot();
      return _sameNullable(account.email, live.email) &&
          _sameNullable(account.accessToken, live.accessToken);
    } catch (_) {
      return false;
    }
  }

  Future<String> addAccount({
    required String name,
    String? email,
    String? accessToken,
    String? refreshToken,
    String? membershipType,
    String? signUpType,
    String? machineId,
    String? macMachineId,
    String? devDeviceId,
    String? sqmId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
    if (!_isNameAvailable(trimmed)) {
      throw DuplicateCursorAccountNameException(trimmed);
    }

    final now = DateTime.now();
    final id = const Uuid().v4();
    await _db.insertCursorAccount(
      CursorAccountsCompanion.insert(
        id: id,
        name: trimmed,
        email: Value(email?.trim()),
        accessToken: Value(accessToken?.trim()),
        refreshToken: Value(refreshToken?.trim()),
        membershipType: Value(membershipType?.trim()),
        signUpType: Value(signUpType?.trim()),
        machineId: Value(machineId?.trim()),
        macMachineId: Value(macMachineId?.trim()),
        devDeviceId: Value(devDeviceId?.trim()),
        sqmId: Value(sqmId?.trim()),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
    return id;
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    String? email,
    String? accessToken,
    String? refreshToken,
    String? membershipType,
    String? signUpType,
    String? machineId,
    String? macMachineId,
    String? devDeviceId,
    String? sqmId,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
    if (!_isNameAvailable(trimmed, excludeId: id)) {
      throw DuplicateCursorAccountNameException(trimmed);
    }

    await _db.updateCursorAccount(
      CursorAccountsCompanion(
        id: Value(id),
        name: Value(trimmed),
        email: Value(email?.trim()),
        accessToken: Value(accessToken?.trim()),
        refreshToken: Value(refreshToken?.trim()),
        membershipType: Value(membershipType?.trim()),
        signUpType: Value(signUpType?.trim()),
        machineId: Value(machineId?.trim()),
        macMachineId: Value(macMachineId?.trim()),
        devDeviceId: Value(devDeviceId?.trim()),
        sqmId: Value(sqmId?.trim()),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await refresh();
  }

  Future<void> deleteAccount(String id) async {
    final account = await _db.getCursorAccountById(id);
    if (account?.isActive == true) {
      throw CursorAccountSwitchException('cannot_delete_active_account');
    }
    await _db.deleteCursorAccount(id);
    await refresh();
  }

  Future<void> switchToAccount(
    String id, {
    bool createBackup = true,
  }) async {
    final account = await _db.getCursorAccountById(id);
    if (account == null) {
      throw CursorAccountSwitchException('account_not_found');
    }

    final snapshot = _snapshotFromAccount(account);
    if (!snapshot.hasAuth) {
      throw CursorAccountSwitchException('account_missing_auth');
    }

    if (createBackup && _authFiles.stateDbExists) {
      await _authFiles.backupToAppDir();
    }

    await _process.killCursorAndWait();
    await _authFiles.applySnapshot(snapshot);
    await _db.activateCursorAccount(id);
    await _process.startCursor();
    await refresh();
  }

  CursorAuthSnapshot _snapshotFromAccount(CursorAccount account) {
    return CursorAuthSnapshot(
      email: account.email,
      accessToken: account.accessToken,
      refreshToken: account.refreshToken,
      membershipType: account.membershipType,
      signUpType: account.signUpType,
      machineId: account.machineId,
      macMachineId: account.macMachineId,
      devDeviceId: account.devDeviceId,
      sqmId: account.sqmId,
    );
  }

  bool _isNameAvailable(String name, {String? excludeId}) {
    final lower = name.toLowerCase();
    for (final a in _accounts) {
      if (excludeId != null && a.id == excludeId) continue;
      if (a.name.toLowerCase() == lower) return false;
    }
    return true;
  }

  bool isNameAvailable(String name, {String? excludeId}) =>
      _isNameAvailable(name.trim(), excludeId: excludeId);
}
