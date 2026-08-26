import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../utils/platform_utils.dart';
import 'claude_usage_api.dart';
import 'claude_environment_service.dart';

class DuplicateClaudeAccountNameException implements Exception {
  final String name;
  const DuplicateClaudeAccountNameException(this.name);

  @override
  String toString() => 'Duplicate claude account name: $name';
}

class ClaudeAccountSwitchException implements Exception {
  final String message;
  const ClaudeAccountSwitchException(this.message);

  @override
  String toString() => message;
}

/// Claude 官方多账号本地管理与切换。
///
/// 账号 token（写回 Keychain 条目 "Claude Code-credentials" 的完整 JSON blob）
/// 存于 DB 的 ClaudeAccounts 表；切换 = 把目标账号 token 写回 Keychain。
///
/// 安全：token 绝不进 runCommand 日志——读取用 `> 临时文件`（stdout 为空），
/// 写入用 `-w "$(cat 临时文件)"`（日志记录的是未展开字面量），临时文件用完即删。
class ClaudeAccountService extends ChangeNotifier {
  final AppDatabase _db;
  final ClashVergeService _clashVerge;
  final MacTimezoneService _macTimezone;

  /// Keychain 条目 service 名
  static const String _keychainService = 'Claude Code-credentials';

  List<ClaudeAccount> _accounts = [];
  bool _initialized = false;

  /// 账号用量：持久化在 DB 的 usageInfo 列，重启后仍可读（可能已过期）
  ClaudeUsage? usageOf(String id) {
    final a = _accounts.where((x) => x.id == id).firstOrNull;
    return a == null ? null : ClaudeUsage.fromJsonString(a.usageInfo);
  }

  List<ClaudeAccount> get accounts => List.unmodifiable(_accounts);
  ClaudeAccount? get activeAccount =>
      _accounts.where((a) => a.isActive).firstOrNull;

  ClaudeAccountService(
    this._db, {
    ClashVergeService? clashVerge,
    MacTimezoneService? macTimezone,
  }) : _clashVerge = clashVerge ?? ClashVergeService(),
       _macTimezone = macTimezone ?? MacTimezoneService();

  Future<void> init() async {
    if (_initialized) return;
    await _loadAccounts();
    await _reconcileActiveFromKeychain();
    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadAccounts();
    notifyListeners();
  }

  Future<void> _loadAccounts() async {
    _accounts = await _db.getAllClaudeAccounts();
  }

  /// Keychain 条目的 account 属性（= 登录短名，取自 home 目录名）。
  /// Claude Code 以此创建条目，写回时必须一致，否则 -U 会误建第二条。
  static String get _acct {
    final home = PlatformUtils.userHome;
    final idx = home.lastIndexOf(Platform.pathSeparator);
    return idx >= 0 ? home.substring(idx + 1) : home;
  }

  // ── Keychain 读写（token 不进日志） ──────────────────────────

  /// 读取 Keychain 当前登录 token；无登录/读取失败返回 null。
  static Future<String?> _readKeychainToken() async {
    final tmp = await _createTempFile();
    try {
      final cmd =
          "security find-generic-password -s '$_keychainService' -w > '${tmp.path}'";
      final r = await PlatformUtils.runCommand(cmd);
      if (r.exitCode != 0) return null;
      final content = await tmp.readAsString();
      return content.trim().isEmpty ? null : content.trim();
    } finally {
      await _safeDelete(tmp);
    }
  }

  /// 本地删除 Keychain 登录条目（不调 Claude 登出、不撤销服务端 token）。
  /// 条目不存在视为已清除，不报错。
  static Future<void> _deleteKeychainToken() async {
    final cmd = "security delete-generic-password -s '$_keychainService'";
    final r = await PlatformUtils.runCommand(cmd);
    if (r.exitCode != 0) {
      final err = (r.stderr as String).toLowerCase();
      // 条目不存在（already cleared）时 security 报错，忽略
      final notFound =
          err.contains('could not be found') || err.contains('not be found');
      if (!notFound) {
        throw ClaudeAccountSwitchException('keychain_clear_failed: $err');
      }
    }
  }

  /// 把 token 写回 Keychain（覆盖 -U）。失败抛 [ClaudeAccountSwitchException]。
  static Future<void> _writeKeychainToken(String token) async {
    final tmp = await _createTempFile();
    try {
      await tmp.writeAsString(token);
      final cmd =
          "security add-generic-password -s '$_keychainService' "
          "-a '$_acct' -w \"\$(cat '${tmp.path}')\" -U";
      final r = await PlatformUtils.runCommand(cmd);
      if (r.exitCode != 0) {
        throw ClaudeAccountSwitchException(
          'keychain_write_failed: ${(r.stderr as String).trim()}',
        );
      }
    } finally {
      await _safeDelete(tmp);
    }
  }

  static Future<File> _createTempFile() async {
    final dir = await Directory.systemTemp.createTemp('mcp_switch_kc_');
    return File(PlatformUtils.joinPath(dir.path, 'tok.json'));
  }

  static Future<void> _safeDelete(File f) async {
    try {
      final parent = f.parent;
      if (await parent.exists()) await parent.delete(recursive: true);
    } catch (_) {}
  }

  /// 从 token JSON 解析出用于展示的 subscriptionType / organizationUuid。
  static ({String? subscriptionType, String? organizationUuid}) _parseMeta(
    String token,
  ) {
    try {
      final d = jsonDecode(token);
      if (d is Map) {
        final org = d['organizationUuid'] as String?;
        String? sub;
        final oauth = d['claudeAiOauth'];
        if (oauth is Map) sub = oauth['subscriptionType'] as String?;
        return (subscriptionType: sub, organizationUuid: org);
      }
    } catch (_) {}
    return (subscriptionType: null, organizationUuid: null);
  }

  // ── ~/.claude.json 账号身份（email/org 显示，Keychain token 里没有） ──

  static String get _claudeJsonPath =>
      PlatformUtils.joinPath(PlatformUtils.userHome, '.claude.json');

  /// 读取 ~/.claude.json 的账号身份 {userID, oauthAccount}；无则 null。
  static Future<String?> readCurrentAccountInfo() async {
    final file = File(_claudeJsonPath);
    if (!await file.exists()) return null;
    try {
      final raw = (await file.readAsString()).trim();
      if (raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final info = <String, dynamic>{};
        if (decoded.containsKey('userID')) info['userID'] = decoded['userID'];
        if (decoded.containsKey('oauthAccount')) {
          info['oauthAccount'] = decoded['oauthAccount'];
        }
        return info.isEmpty ? null : jsonEncode(info);
      }
    } catch (_) {}
    return null;
  }

  /// 把账号身份 {userID, oauthAccount} 合并写回 ~/.claude.json（保留其余字段）。
  static Future<void> _applyAccountInfo(String? accountInfoJson) async {
    if (accountInfoJson == null || accountInfoJson.trim().isEmpty) return;
    Map<String, dynamic> info;
    try {
      final d = jsonDecode(accountInfoJson);
      if (d is! Map<String, dynamic>) return;
      info = d;
    } catch (_) {
      return;
    }
    final file = File(_claudeJsonPath);
    Map<String, dynamic> obj = <String, dynamic>{};
    if (await file.exists()) {
      try {
        final raw = (await file.readAsString()).trim();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) obj = decoded;
        }
      } catch (_) {}
    } else if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    if (info.containsKey('userID')) obj['userID'] = info['userID'];
    if (info.containsKey('oauthAccount')) {
      obj['oauthAccount'] = info['oauthAccount'];
    }
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString('${encoder.convert(obj)}\n');
  }

  /// 从 accountInfo JSON 解析 oauthAccount.organizationUuid
  static String? _orgOfAccountInfo(String accountInfoJson) {
    try {
      final d = jsonDecode(accountInfoJson);
      if (d is Map && d['oauthAccount'] is Map) {
        return d['oauthAccount']['organizationUuid'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// 解析账号邮箱（展示用）
  static String? emailOf(ClaudeAccount a) {
    final info = a.accountInfo;
    if (info == null || info.isEmpty) return null;
    try {
      final d = jsonDecode(info);
      if (d is Map && d['oauthAccount'] is Map) {
        return d['oauthAccount']['emailAddress'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // ── 对账：识别 Keychain 里当前是哪个已存账号 ────────────────

  /// 读当前 Keychain token，按 organizationUuid 匹配已存账号：
  /// - 匹配到则标记为 active；
  /// - 若该账号存的 token 与实况不同（Claude Code 刷新过），顺带更新为最新，
  ///   避免下次切换写回过期 token。
  Future<void> _reconcileActiveFromKeychain() async {
    await _refreshMatchingAccountFromLive(activate: true);
  }

  /// 把当前 Keychain + ~/.claude.json 登录态刷新回它对应的已存账号，
  /// 保持 token / refreshToken 最新（插件会轮换 refreshToken，旧的会作废）。
  ///
  /// 关键：新版插件(2.1.207+)的 token 顶层已无 organizationUuid，所以账号识别
  /// 一律以 ~/.claude.json 的 oauthAccount.organizationUuid 为准，退回 token 顶层兼容老格式。
  Future<void> _refreshMatchingAccountFromLive({bool activate = false}) async {
    final live = await _readKeychainToken();
    if (live == null) return;
    final rawInfo = await readCurrentAccountInfo();
    final infoOrg = rawInfo != null ? _orgOfAccountInfo(rawInfo) : null;
    final liveMeta = _parseMeta(live);
    final org = infoOrg ?? liveMeta.organizationUuid;
    if (org == null) return;

    final match = _accounts.where((a) => a.organizationUuid == org).firstOrNull;
    if (match == null) return;

    final liveInfo = infoOrg == org ? rawInfo : null;
    final infoChanged = liveInfo != null && liveInfo != match.accountInfo;
    if (match.token != live || infoChanged) {
      await _db.updateClaudeAccount(
        ClaudeAccountsCompanion(
          id: Value(match.id),
          token: Value(live),
          subscriptionType: Value(liveMeta.subscriptionType),
          organizationUuid: Value(org),
          accountInfo: liveInfo != null
              ? Value(liveInfo)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    if (activate && !match.isActive) {
      await _db.activateClaudeAccount(match.id);
    }
    await _loadAccounts();
  }

  // ── 账号增删改 ──────────────────────────────────────────

  /// 读取 Keychain 当前登录态；无登录抛异常。用于「导入当前登录」。
  Future<String> captureCurrentLogin() async {
    final token = await _readKeychainToken();
    if (token == null) {
      throw const ClaudeAccountSwitchException('no_current_login');
    }
    return token;
  }

  /// 读取 Keychain 当前 token（无则 null，不抛）。用于轮询检测。
  static Future<String?> readCurrentToken() => _readKeychainToken();

  /// 当前登录账号的唯一标识（accountUuid 优先，退回 email）。用于检测「换了账号」。
  static Future<String?> currentAccountKey() async {
    final info = await readCurrentAccountInfo();
    if (info == null) return null;
    try {
      final d = jsonDecode(info);
      if (d is Map && d['oauthAccount'] is Map) {
        final o = d['oauthAccount'] as Map;
        return (o['accountUuid'] ?? o['emailAddress']) as String?;
      }
    } catch (_) {}
    return null;
  }

  /// 把当前 Keychain + ~/.claude.json 登录态捕获为新账号并激活；返回新账号 id。
  Future<String> captureCurrentAsNewAccount(String name) async {
    final token = await _readKeychainToken();
    if (token == null) {
      throw const ClaudeAccountSwitchException('no_current_login');
    }
    final info = await readCurrentAccountInfo();
    final id = await addAccount(name: name, token: token, accountInfo: info);
    await _db.activateClaudeAccount(id);
    await refresh();
    return id;
  }

  /// 按 organizationUuid 在已存账号里找与该 token 同一账号的记录；找不到返回 null。
  ClaudeAccount? findByToken(String token) {
    final meta = _parseMeta(token);
    if (meta.organizationUuid == null) return null;
    return _accounts
        .where((a) => a.organizationUuid == meta.organizationUuid)
        .firstOrNull;
  }

  /// 用最新 token（及可选身份）刷新已存账号（Claude Code 续期后保持新鲜）。
  Future<void> refreshAccountToken(
    String id,
    String token, {
    String? accountInfo,
  }) async {
    final meta = _parseMeta(token);
    await _db.updateClaudeAccount(
      ClaudeAccountsCompanion(
        id: Value(id),
        token: Value(token),
        subscriptionType: Value(meta.subscriptionType),
        accountInfo: accountInfo != null
            ? Value(accountInfo)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await refresh();
  }

  /// 本地清除当前 Keychain 登录态，腾出登录位以登录另一个账号。
  /// 纯本地删除，不撤销服务端 token——已保存账号之后仍可写回恢复。
  Future<void> clearCurrentLogin() async {
    await _deleteKeychainToken();
    await _db.deactivateAllClaudeAccounts();
    await refresh();
  }

  /// 用一段 token 新建账号，返回新账号 id。
  Future<String> addAccount({
    required String name,
    required String token,
    String? accountInfo,
    String? proxySoftware,
    String? proxySubscription,
    String? timezone,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
    if (!_isNameAvailable(trimmed)) {
      throw DuplicateClaudeAccountNameException(trimmed);
    }
    final meta = _parseMeta(token);
    // 新版插件 token 顶层已无 organizationUuid，退回从 accountInfo 取
    final org =
        meta.organizationUuid ??
        (accountInfo != null ? _orgOfAccountInfo(accountInfo) : null);
    final now = DateTime.now();
    final id = const Uuid().v4();
    await _db.insertClaudeAccount(
      ClaudeAccountsCompanion.insert(
        id: id,
        name: trimmed,
        token: token,
        subscriptionType: Value(meta.subscriptionType),
        organizationUuid: Value(org),
        accountInfo: Value(accountInfo),
        proxySoftware: Value(proxySoftware),
        proxySubscription: Value(proxySubscription),
        timezone: Value(timezone),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
    return id;
  }

  Future<void> renameAccount({required String id, required String name}) async {
    await updateAccount(id: id, name: name);
  }

  /// 编辑账号：改名，并可选更新身份 accountInfo（{userID, oauthAccount}）。
  /// [accountInfo] 为 null 时保持不变；同时按其中 oauthAccount 重算 organizationUuid。
  Future<void> updateAccount({
    required String id,
    required String name,
    String? accountInfo,
    Value<String?> proxySoftware = const Value.absent(),
    Value<String?> proxySubscription = const Value.absent(),
    Value<String?> timezone = const Value.absent(),
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('name cannot be empty');
    }
    if (!_isNameAvailable(trimmed, excludeId: id)) {
      throw DuplicateClaudeAccountNameException(trimmed);
    }
    final orgFromInfo = accountInfo != null
        ? _orgOfAccountInfo(accountInfo)
        : null;
    await _db.updateClaudeAccount(
      ClaudeAccountsCompanion(
        id: Value(id),
        name: Value(trimmed),
        accountInfo: accountInfo != null
            ? Value(accountInfo)
            : const Value.absent(),
        organizationUuid: orgFromInfo != null
            ? Value(orgFromInfo)
            : const Value.absent(),
        proxySoftware: proxySoftware,
        proxySubscription: proxySubscription,
        timezone: timezone,
        updatedAt: Value(DateTime.now()),
      ),
    );
    await refresh();
  }

  /// 取账号当前的 accountInfo（供编辑弹窗预填），无则 null。
  ClaudeAccount? accountById(String id) =>
      _accounts.where((a) => a.id == id).firstOrNull;

  Future<void> deleteAccount(String id) async {
    final account = await _db.getClaudeAccountById(id);
    if (account?.isActive == true) {
      throw const ClaudeAccountSwitchException('cannot_delete_active_account');
    }
    await _db.deleteClaudeAccount(id);
    await refresh();
  }

  /// 切换到账号 [id]：把其 token 写回 Keychain，并标记 active。
  /// 切换后需用户重启 Claude Code / VSCode 才生效（内存缓存）。
  Future<void> switchToAccount(String id) async {
    // 切换前：把当前登录态刷新回它对应的账号，避免其 refreshToken 因插件轮换而丢失
    await _refreshMatchingAccountFromLive();
    final account = await _db.getClaudeAccountById(id);
    if (account == null) {
      throw const ClaudeAccountSwitchException('account_not_found');
    }
    if (account.token.trim().isEmpty) {
      throw const ClaudeAccountSwitchException('account_missing_token');
    }
    await _writeKeychainToken(account.token);
    // 同步 ~/.claude.json 的账号身份（email/org 显示），否则 UI 仍显示旧账号
    await _applyAccountInfo(account.accountInfo);
    await _db.activateClaudeAccount(id);
    await refresh();

    await applyEnvironment(account);
  }

  /// 应用账号绑定的代理订阅和系统时区。
  /// 登录态已经写入后才调用；环境失败会以明确异常返回，但账号仍保持 active。
  Future<void> applyEnvironment(ClaudeAccount account) async {
    final failures = <String>[];
    if (account.proxySoftware == 'clash_verge' &&
        account.proxySubscription != null &&
        account.proxySubscription!.trim().isNotEmpty) {
      try {
        await _clashVerge.switchSubscription(account.proxySubscription!);
      } catch (e) {
        failures.add('proxy: $e');
      }
    } else if (account.proxySoftware != null &&
        account.proxySoftware!.trim().isNotEmpty &&
        account.proxySoftware != 'clash_verge') {
      failures.add('proxy_software_unsupported: ${account.proxySoftware}');
    }
    if (account.timezone != null && account.timezone!.trim().isNotEmpty) {
      try {
        await _macTimezone.setTimezone(account.timezone!);
      } catch (e) {
        failures.add('timezone: $e');
      }
    }
    if (failures.isNotEmpty) {
      throw ClaudeAccountSwitchException(
        'account_switched_environment_failed: ${failures.join('; ')}',
      );
    }
  }

  // ── 用量（Account & Usage 的 5hr / 7day） ────────────────────

  static String? _oauthField(String tokenJson, String key) {
    try {
      final d = jsonDecode(tokenJson);
      if (d is Map && d['claudeAiOauth'] is Map) {
        return d['claudeAiOauth'][key] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// 把刷新得到的新 token 合并进完整 token JSON（保留 mcpOAuth 等其它字段）。
  static String _mergeRefreshed(String tokenJson, RefreshedToken r) {
    Map<String, dynamic> m;
    try {
      m = Map<String, dynamic>.from(jsonDecode(tokenJson) as Map);
    } catch (_) {
      m = {};
    }
    final oauth = Map<String, dynamic>.from(
      (m['claudeAiOauth'] as Map?) ?? <String, dynamic>{},
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    oauth['accessToken'] = r.accessToken;
    if (r.refreshToken != null) oauth['refreshToken'] = r.refreshToken;
    if (r.expiresInSeconds != null) {
      oauth['expiresAt'] = nowMs + r.expiresInSeconds! * 1000;
    }
    if (r.refreshExpiresInSeconds != null) {
      oauth['refreshTokenExpiresAt'] =
          nowMs + r.refreshExpiresInSeconds! * 1000;
    }
    m['claudeAiOauth'] = oauth;
    return jsonEncode(m);
  }

  /// 拉取单个账号用量。
  /// - 活跃账号：直接用钥匙串里的实时 token（插件保持新鲜），**不触发刷新/轮换**，
  ///   避免与正在运行的插件抢着轮换 refreshToken 导致插件登录失效。
  /// - 非活跃账号：用 DB 存的 token；accessToken 过期(401)才用 refreshToken 刷新，
  ///   且轮换后**只回写 DB、不碰钥匙串**（它本就不在钥匙串里）。
  Future<ClaudeUsage> fetchUsageForAccount(ClaudeAccount account) async {
    var sourceToken = account.token;
    if (account.isActive) {
      final live = await _readKeychainToken();
      if (live != null && _oauthField(live, 'accessToken') != null) {
        sourceToken = live;
      }
    }
    final at = _oauthField(sourceToken, 'accessToken');
    if (at == null || at.isEmpty) {
      throw const ClaudeAccountSwitchException('account_missing_token');
    }
    try {
      final usage = await ClaudeUsageApi.fetchUsage(at);
      await _persistUsage(account.id, usage);
      return usage;
    } on ClaudeUsageUnauthorized {
      // 活跃账号不在这里轮换：钥匙串本该新鲜，若仍 401 多半是插件没在跑，
      // 提示用户打开 Claude Code 让它刷新，而不是我们代劳去动它的 token。
      if (account.isActive) rethrow;
      final rt = _oauthField(sourceToken, 'refreshToken');
      if (rt == null || rt.isEmpty) rethrow;
      final refreshed = await ClaudeUsageApi.refresh(rt);
      // 轮换必须回写 DB，否则旧 refreshToken 作废 → 账号再次损坏
      final newToken = _mergeRefreshed(sourceToken, refreshed);
      await _db.updateClaudeAccount(
        ClaudeAccountsCompanion(
          id: Value(account.id),
          token: Value(newToken),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await _loadAccounts();
      final usage = await ClaudeUsageApi.fetchUsage(refreshed.accessToken);
      await _persistUsage(account.id, usage);
      return usage;
    }
  }

  /// 只查询当前已登录且已标记 active 的账号，不触碰其它账号的 token/IP。
  Future<ClaudeUsage> fetchUsageForCurrentAccount() async {
    final account = activeAccount;
    if (account == null) {
      throw const ClaudeAccountSwitchException('no_current_claude_account');
    }
    return fetchUsageForAccount(account);
  }

  /// 把用量结果持久化到 DB 的 usageInfo 列（重启后仍能显示）。
  Future<void> _persistUsage(String id, ClaudeUsage usage) async {
    await _db.updateClaudeAccount(
      ClaudeAccountsCompanion(
        id: Value(id),
        usageInfo: Value(jsonEncode(usage.toJson())),
      ),
    );
    await _loadAccounts();
  }

  /// 刷新所有账号用量（逐个，某个失败不阻断其它；失败者保留上次的旧值）。
  Future<void> refreshAllUsage() async {
    for (final a in List.of(_accounts)) {
      try {
        await fetchUsageForAccount(a);
      } catch (_) {
        // 保留上次持久化的用量（虽可能过期），不清空
      }
    }
    await _loadAccounts();
    notifyListeners();
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
