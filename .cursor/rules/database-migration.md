---
description: Rules for Drift/SQLite database migrations in this project
globs: lib/data/database.dart
---

# 数据库迁移规范

## 强制规则

在 `onUpgrade` 中添加列时，**必须**使用 `_safeAddColumn` 而非 `m.addColumn`：

```dart
// ❌ 禁止
await m.addColumn(providerProfiles, providerProfiles.newColumn);

// ✅ 正确
await _safeAddColumn(m, providerProfiles, providerProfiles.newColumn);
```

## 原因

Release 包和 Debug 包共享同一个 SQLite 数据库文件，一方已执行迁移后另一方再运行会触发 `SqliteException: duplicate column name` 错误。`_safeAddColumn` 通过 try-catch 静默忽略该异常。

## 新增迁移清单

1. 在 `ProviderProfiles` 表类中添加新字段定义
2. `schemaVersion` 递增 +1
3. 在 `onUpgrade` 中添加 `if (from < N)` 块，使用 `_safeAddColumn`
4. 运行 `dart run build_runner build` 重新生成 `database.g.dart`
5. 测试：先用旧版本数据库运行新代码，确认迁移无报错
