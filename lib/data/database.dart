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
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(false))();
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
  // 完整配置内容 (JSON/TOML/ENV)
  TextColumn get configContent => text().nullable()();
  // 通用
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ProviderProfiles])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  static AppDatabase? _instance;

  factory AppDatabase() {
    _instance ??= AppDatabase._internal(_openConnection());
    return _instance!;
  }

  @override
  int get schemaVersion => 4;

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
              m, providerProfiles, providerProfiles.configContent);
        }
      },
    );
  }

  /// 安全添加列：如果列已存在则忽略错误
  Future<void> _safeAddColumn(
      Migrator m, TableInfo table, GeneratedColumn column) async {
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
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .get();
  }

  /// 监听指定编辑器类型的供应商配置变化
  Stream<List<ProviderProfile>> watchProfilesByEditor(String editorType) {
    return (select(providerProfiles)
          ..where((t) => t.editorType.equals(editorType))
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
        .watch();
  }

  /// 根据 ID 获取单条配置
  Future<ProviderProfile?> getProfileById(String id) {
    return (select(providerProfiles)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// 获取指定编辑器类型的激活配置
  Future<ProviderProfile?> getActiveProfile(String editorType) {
    return (select(providerProfiles)
          ..where(
            (t) =>
                t.editorType.equals(editorType) & t.isActive.equals(true),
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
    return (update(providerProfiles)
          ..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// 删除供应商配置
  Future<int> deleteProfile(String id) {
    return (delete(providerProfiles)..where((t) => t.id.equals(id))).go();
  }

  /// 取消指定编辑器类型的所有激活状态
  Future<int> deactivateAll(String editorType) {
    return (update(providerProfiles)
          ..where(
            (t) =>
                t.editorType.equals(editorType) & t.isActive.equals(true),
          ))
        .write(
          const ProviderProfilesCompanion(isActive: Value(false)),
        );
  }

  /// 激活指定配置
  Future<void> activateProfile(String editorType, String profileId) async {
    await transaction(() async {
      // 先取消所有激活
      await deactivateAll(editorType);
      // 再激活目标
      await (update(providerProfiles)
            ..where((t) => t.id.equals(profileId)))
          .write(const ProviderProfilesCompanion(isActive: Value(true)));
    });
  }

  /// 导出所有数据（JSON 格式）
  Future<List<ProviderProfile>> getAllProfiles() {
    return select(providerProfiles).get();
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
