import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

/// 供应商配置表
class ProviderProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get editorType => text()(); // 'claude' | 'codex'
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  // Claude Code 字段
  TextColumn get apiToken => text().nullable()();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get model => text().nullable()();
  TextColumn get maxOutputTokens => text().nullable()();
  TextColumn get maxThinkingTokens => text().nullable()();
  TextColumn get website => text().nullable()();
  // Codex 字段
  TextColumn get modelReasoningEffort => text().nullable()();
  TextColumn get personality => text().nullable()();
  TextColumn get oauthData => text().nullable()(); // Codex OAuth tokens JSON
  TextColumn get vscodeModel => text().nullable()();

  /// VSCode 插件模型写入位置：'legacy'（VSCode settings.json -> claudeCode.selectedModel）
  /// 或 'modern'（~/.claude/settings.json -> model）。null 视为 legacy。
  TextColumn get vscodeModelMode => text().nullable()();
  TextColumn get defaultHaikuModel => text().nullable()();
  TextColumn get defaultSonnetModel => text().nullable()();
  TextColumn get defaultOpusModel => text().nullable()();
  // 完整配置内容 (JSON/TOML/ENV)
  TextColumn get configContent => text().nullable()();

  /// 是否为官方供应商（通过 OAuth 登录，不需要 apiToken/baseUrl）
  BoolColumn get isOfficialProvider =>
      boolean().withDefault(const Constant(false))();
  // 通用
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cursor 账号切换配置（认证 token + 设备指纹）
class CursorAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text().nullable()();
  TextColumn get accessToken => text().nullable()();
  TextColumn get refreshToken => text().nullable()();
  TextColumn get membershipType => text().nullable()();
  TextColumn get signUpType => text().nullable()();
  TextColumn get machineId => text().nullable()();
  TextColumn get macMachineId => text().nullable()();
  TextColumn get devDeviceId => text().nullable()();
  TextColumn get sqmId => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Claude 官方账号（多 Anthropic 账号切换）
/// token 为写回 Keychain 条目 "Claude Code-credentials" 的完整 JSON blob，
/// subscriptionType/organizationUuid 从 token 解析出来仅用于列表展示。
class ClaudeAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get token => text()();
  TextColumn get subscriptionType => text().nullable()();
  TextColumn get organizationUuid => text().nullable()();

  /// ~/.claude.json 中的账号身份 JSON：{userID, oauthAccount}
  /// 用于切换时恢复 UI 显示的邮箱/组织（Keychain token 里没有 email）
  TextColumn get accountInfo => text().nullable()();

  /// 最近一次「刷新额度」的结果 JSON（持久化，重启后仍显示，虽可能过期）
  TextColumn get usageInfo => text().nullable()();

  /// 与该 Claude 账号绑定的本地环境配置。
  TextColumn get proxySoftware => text().nullable()();
  TextColumn get proxySubscription => text().nullable()();
  TextColumn get timezone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ProviderProfiles, CursorAccounts, ClaudeAccounts])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  static AppDatabase? _instance;

  factory AppDatabase() {
    _instance ??= AppDatabase._internal(_openConnection());
    return _instance!;
  }

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await _safeAddColumn(m, providerProfiles, providerProfiles.website);
        }
        if (from < 3) {
          await _safeAddColumn(m, providerProfiles, providerProfiles.oauthData);
        }
        if (from < 4) {
          await _safeAddColumn(
            m,
            providerProfiles,
            providerProfiles.configContent,
          );
        }
        if (from < 5) {
          await _safeAddColumn(
            m,
            providerProfiles,
            providerProfiles.vscodeModel,
          );
        }
        if (from < 6) {
          await _safeAddColumn(
            m,
            providerProfiles,
            providerProfiles.defaultHaikuModel,
          );
          await _safeAddColumn(
            m,
            providerProfiles,
            providerProfiles.defaultSonnetModel,
          );
          await _safeAddColumn(
            m,
            providerProfiles,
            providerProfiles.defaultOpusModel,
          );
        }
        if (from < 7) {
          await _safeAddColumn(
            m,
            providerProfiles,
            providerProfiles.isOfficialProvider,
          );
          // 迁移：已有的官方种子 profile 标记为 isOfficialProvider = true
          await customStatement(
            "UPDATE provider_profiles SET is_official_provider = 1 "
            "WHERE id LIKE 'official-%'",
          );
        }
        if (from < 8) {
          await _safeAddColumn(
            m,
            providerProfiles,
            providerProfiles.vscodeModelMode,
          );
        }
        if (from < 9) {
          await m.createTable(cursorAccounts);
        }
        if (from < 10) {
          await m.createTable(claudeAccounts);
        }
        if (from < 11) {
          await _safeAddColumn(m, claudeAccounts, claudeAccounts.accountInfo);
        }
        if (from < 12) {
          await _safeAddColumn(m, claudeAccounts, claudeAccounts.usageInfo);
        }
        if (from < 13) {
          await _safeAddColumn(m, claudeAccounts, claudeAccounts.proxySoftware);
          await _safeAddColumn(
            m,
            claudeAccounts,
            claudeAccounts.proxySubscription,
          );
          await _safeAddColumn(m, claudeAccounts, claudeAccounts.timezone);
        }
      },
    );
  }

  /// 安全添加列：如果列已存在则忽略错误
  Future<void> _safeAddColumn(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
  ) async {
    try {
      await m.addColumn(table, column);
    } on Exception catch (_) {
      // 列已存在，忽略 duplicate column 错误
    }
  }

  // --- CRUD Operations ---

  /// 获取指定编辑器类型的所有供应商配置
  Future<List<ProviderProfile>> getProfilesByEditor(String editorType) {
    return (select(providerProfiles)
          ..where((t) => t.editorType.equals(editorType))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .get();
  }

  /// 监听指定编辑器类型的供应商配置变化
  Stream<List<ProviderProfile>> watchProfilesByEditor(String editorType) {
    return (select(providerProfiles)
          ..where((t) => t.editorType.equals(editorType))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// 根据 ID 获取单条配置
  Future<ProviderProfile?> getProfileById(String id) {
    return (select(
      providerProfiles,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 获取指定编辑器类型的激活配置
  Future<ProviderProfile?> getActiveProfile(String editorType) {
    return (select(providerProfiles)..where(
          (t) => t.editorType.equals(editorType) & t.isActive.equals(true),
        ))
        .getSingleOrNull();
  }

  /// 插入新的供应商配置
  Future<int> insertProfile(ProviderProfilesCompanion entry) {
    return into(providerProfiles).insert(entry);
  }

  /// 插入或更新供应商配置（upsert）
  Future<void> upsertProfile(ProviderProfilesCompanion entry) {
    return into(providerProfiles).insertOnConflictUpdate(entry);
  }

  /// 更新供应商配置
  Future<bool> updateProfile(ProviderProfilesCompanion entry) {
    return (update(providerProfiles)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// 删除供应商配置
  Future<int> deleteProfile(String id) {
    return (delete(providerProfiles)..where((t) => t.id.equals(id))).go();
  }

  /// 取消指定编辑器类型的所有激活状态
  Future<int> deactivateAll(String editorType) {
    return (update(providerProfiles)..where(
          (t) => t.editorType.equals(editorType) & t.isActive.equals(true),
        ))
        .write(const ProviderProfilesCompanion(isActive: Value(false)));
  }

  /// 激活指定配置
  Future<void> activateProfile(String editorType, String profileId) async {
    await transaction(() async {
      // 先取消所有激活
      await deactivateAll(editorType);
      // 再激活目标
      await (update(providerProfiles)..where((t) => t.id.equals(profileId)))
          .write(const ProviderProfilesCompanion(isActive: Value(true)));
    });
  }

  /// 导出所有数据（JSON 格式）
  Future<List<ProviderProfile>> getAllProfiles() {
    return select(providerProfiles).get();
  }

  // --- Cursor Accounts ---

  Future<List<CursorAccount>> getAllCursorAccounts() {
    return (select(
      cursorAccounts,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  Future<CursorAccount?> getCursorAccountById(String id) {
    return (select(
      cursorAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<CursorAccount?> getActiveCursorAccount() {
    return (select(
      cursorAccounts,
    )..where((t) => t.isActive.equals(true))).getSingleOrNull();
  }

  Future<int> insertCursorAccount(CursorAccountsCompanion entry) {
    return into(cursorAccounts).insert(entry);
  }

  Future<bool> updateCursorAccount(CursorAccountsCompanion entry) {
    return (update(cursorAccounts)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  Future<int> deleteCursorAccount(String id) {
    return (delete(cursorAccounts)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deactivateAllCursorAccounts() {
    return (update(cursorAccounts)..where((t) => t.isActive.equals(true)))
        .write(const CursorAccountsCompanion(isActive: Value(false)));
  }

  Future<void> activateCursorAccount(String accountId) async {
    await transaction(() async {
      await deactivateAllCursorAccounts();
      await (update(cursorAccounts)..where((t) => t.id.equals(accountId)))
          .write(const CursorAccountsCompanion(isActive: Value(true)));
    });
  }

  // --- Claude Accounts ---

  Future<List<ClaudeAccount>> getAllClaudeAccounts() {
    return (select(
      claudeAccounts,
    )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();
  }

  Future<ClaudeAccount?> getClaudeAccountById(String id) {
    return (select(
      claudeAccounts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<ClaudeAccount?> getActiveClaudeAccount() {
    return (select(
      claudeAccounts,
    )..where((t) => t.isActive.equals(true))).getSingleOrNull();
  }

  Future<int> insertClaudeAccount(ClaudeAccountsCompanion entry) {
    return into(claudeAccounts).insert(entry);
  }

  Future<bool> updateClaudeAccount(ClaudeAccountsCompanion entry) {
    return (update(claudeAccounts)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  Future<int> deleteClaudeAccount(String id) {
    return (delete(claudeAccounts)..where((t) => t.id.equals(id))).go();
  }

  Future<int> deactivateAllClaudeAccounts() {
    return (update(claudeAccounts)..where((t) => t.isActive.equals(true)))
        .write(const ClaudeAccountsCompanion(isActive: Value(false)));
  }

  Future<void> activateClaudeAccount(String accountId) async {
    await transaction(() async {
      await deactivateAllClaudeAccounts();
      await (update(claudeAccounts)..where((t) => t.id.equals(accountId)))
          .write(const ClaudeAccountsCompanion(isActive: Value(true)));
    });
  }

  /// 获取数据库文件路径
  static Future<String> getDatabasePath() async {
    final dbFolder = await getApplicationSupportDirectory();
    return p.join(dbFolder.path, 'mcp_switch.db');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbPath = await AppDatabase.getDatabasePath();
    final file = File(dbPath);
    return NativeDatabase(
      file,
      logStatements: false,
      setup: (database) {
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA busy_timeout = 5000');
        database.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}
