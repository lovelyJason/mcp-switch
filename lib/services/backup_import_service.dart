import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../l10n/s.dart';
import '../models/editor_type.dart';
import 'backup_service.dart';
import 'config/config_service.dart';

// ═══════════════════════════════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════════════════════════════

enum ConflictResolution { keepLocal, useBackup, manual }

class ImportConflict {
  final String category;
  final String itemKey;
  final String displayName;
  final String localValue;
  final String backupValue;
  ConflictResolution? resolution;
  String? manualValue;

  ImportConflict({
    required this.category,
    required this.itemKey,
    required this.displayName,
    required this.localValue,
    required this.backupValue,
  });

  String get resolvedValue {
    switch (resolution) {
      case ConflictResolution.keepLocal:
        return localValue;
      case ConflictResolution.useBackup:
        return backupValue;
      case ConflictResolution.manual:
        return manualValue ?? backupValue;
      case null:
        return backupValue;
    }
  }
}

class BackupData {
  final Map<String, dynamic> manifest;
  final Archive archive;
  final Map<String, List<int>> files;

  BackupData({required this.manifest, required this.archive, required this.files});

  List<String> get categories =>
      (manifest['categories'] as List?)?.cast<String>() ?? [];

  String? getFileContent(String path) {
    final bytes = files[path];
    if (bytes == null) return null;
    return utf8.decode(bytes);
  }
}

class ImportResult {
  final List<ImportConflict> conflicts;
  final Map<String, dynamic> directImports;

  ImportResult({required this.conflicts, required this.directImports});
}

// ═══════════════════════════════════════════════════════════════════
// Service
// ═══════════════════════════════════════════════════════════════════

class BackupImportService {
  final ConfigService _configService;
  final AppDatabase _database;

  BackupImportService(this._configService, this._database);

  // ── Phase 1: Parse ────────────────────────────────────────────

  Future<BackupData> parseBackupFile(String path) async {
    final bytes = await File(path).readAsBytes();
    if (bytes.length < BackupService.headerSize) {
      throw const FormatException('File too small');
    }
    if (!listEquals(
      bytes.sublist(0, BackupService.magic.length),
      BackupService.magic,
    )) {
      throw const FormatException('Invalid .mcpsw file');
    }

    final zipBytes = bytes.sublist(BackupService.headerSize);
    final archive = ZipDecoder().decodeBytes(zipBytes);

    final fileMap = <String, List<int>>{};
    for (final f in archive.files) {
      if (!f.isFile) continue;
      fileMap[f.name] = f.content as List<int>;
    }

    final manifestBytes = fileMap['manifest.json'];
    if (manifestBytes == null) {
      throw const FormatException('Missing manifest.json');
    }
    final manifest =
        jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;

    return BackupData(manifest: manifest, archive: archive, files: fileMap);
  }

  // ── Phase 2: Detect conflicts ─────────────────────────────────

  Future<ImportResult> detectConflicts(
    BackupData data,
    List<BackupCategory> categories,
  ) async {
    final conflicts = <ImportConflict>[];
    final directImports = <String, dynamic>{};

    for (final cat in categories) {
      switch (cat) {
        case BackupCategory.preferences:
          _detectPreferenceConflicts(data, conflicts, directImports);
        case BackupCategory.mcpConfigs:
          await _detectMcpConflicts(data, conflicts, directImports);
        case BackupCategory.prompts:
          _detectPromptConflicts(data, conflicts, directImports);
        case BackupCategory.skills:
          _detectSkillConflicts(data, conflicts, directImports);
        case BackupCategory.providers:
          await _detectProviderConflicts(data, conflicts, directImports);
      }
    }

    return ImportResult(conflicts: conflicts, directImports: directImports);
  }

  // ── Phase 3: Apply ────────────────────────────────────────────

  Future<(bool, String?)> applyImport(
    BackupData data,
    ImportResult result,
    List<BackupCategory> categories,
  ) async {
    try {
      for (final cat in categories) {
        switch (cat) {
          case BackupCategory.preferences:
            await _applyPreferences(data, result);
          case BackupCategory.mcpConfigs:
            await _applyMcpConfigs(data, result);
          case BackupCategory.prompts:
            await _applyPrompts(data, result);
          case BackupCategory.skills:
            await _applySkills(data, result);
          case BackupCategory.providers:
            await _applyProviders(data, result);
        }
      }
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Preferences
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _detectPreferenceConflicts(
    BackupData data,
    List<ImportConflict> conflicts,
    Map<String, dynamic> directImports,
  ) async {
    final content = data.getFileContent('preferences.json');
    if (content == null) return;

    final backupPrefs = jsonDecode(content) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    final localPrefs = <String, dynamic>{};

    localPrefs['locale'] = S.localeNotifier.value.languageCode;
    for (final entry in BackupService.prefKeys.entries) {
      final v = prefs.get(entry.key);
      if (v != null) localPrefs[entry.key] = v;
    }

    final localJson = const JsonEncoder.withIndent('  ').convert(localPrefs);
    final backupJson = const JsonEncoder.withIndent('  ').convert(backupPrefs);

    if (localJson != backupJson) {
      conflicts.add(ImportConflict(
        category: 'preferences',
        itemKey: 'preferences',
        displayName: S.get('export_cat_preferences'),
        localValue: localJson,
        backupValue: backupJson,
      ));
    }
  }

  Future<void> _applyPreferences(BackupData data, ImportResult result) async {
    final conflict = result.conflicts
        .where((c) => c.itemKey == 'preferences')
        .firstOrNull;

    String jsonStr;
    if (conflict != null) {
      if (conflict.resolution == ConflictResolution.keepLocal) return;
      jsonStr = conflict.resolvedValue;
    } else {
      jsonStr = data.getFileContent('preferences.json') ?? '{}';
    }

    final prefs = await SharedPreferences.getInstance();
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;

    if (map.containsKey('locale')) {
      S.setLocale(Locale(map['locale'] as String));
    }

    for (final entry in BackupService.prefKeys.entries) {
      final key = entry.key;
      final value = map[key];
      if (value == null) continue;
      switch (entry.value) {
        case 'int':
          await prefs.setInt(key, value as int);
        case 'bool':
          await prefs.setBool(key, value as bool);
        case 'string':
          await prefs.setString(key, value as String);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // MCP Configs
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _detectMcpConflicts(
    BackupData data,
    List<ImportConflict> conflicts,
    Map<String, dynamic> directImports,
  ) async {
    for (final editor in EditorType.values) {
      final fileName = BackupService.mcpConfigFileName(editor);
      final backupContent = data.getFileContent('mcp_configs/$fileName');
      if (backupContent == null) continue;

      if (editor == EditorType.codex) {
        directImports['mcp_codex'] = backupContent;
        continue;
      }

      final backupJson = _parseMcpServers(backupContent);
      if (backupJson == null) continue;

      final localPath = _configService.getConfigPath(editor);
      final localFile = File(localPath);
      Map<String, dynamic>? localJson;
      if (localFile.existsSync()) {
        localJson = _parseMcpServers(await localFile.readAsString());
      }
      localJson ??= {};

      for (final serverName in backupJson.keys) {
        final backupServer = backupJson[serverName];
        final localServer = localJson[serverName];
        final bStr = const JsonEncoder.withIndent('  ').convert(backupServer);

        if (localServer == null) {
          directImports['mcp_${editor.name}/$serverName'] = bStr;
          continue;
        }

        final lStr = const JsonEncoder.withIndent('  ').convert(localServer);
        if (lStr != bStr) {
          conflicts.add(ImportConflict(
            category: 'mcpConfigs',
            itemKey: 'mcp_${editor.name}/$serverName',
            displayName: '${editor.label} > $serverName',
            localValue: lStr,
            backupValue: bStr,
          ));
        }
      }
    }
  }

  Map<String, dynamic>? _parseMcpServers(String content) {
    try {
      final json = jsonDecode(content) as Map<String, dynamic>;
      final servers = json['mcpServers'] ?? json;
      if (servers is Map<String, dynamic>) return servers;
    } catch (_) {}
    return null;
  }

  Future<void> _applyMcpConfigs(BackupData data, ImportResult result) async {
    for (final editor in EditorType.values) {
      if (editor == EditorType.codex) {
        final toml = result.directImports['mcp_codex'] as String?;
        if (toml != null) {
          final path = _configService.getConfigPath(editor);
          await File(path).writeAsString(toml);
        }
        continue;
      }

      final localPath = _configService.getConfigPath(editor);
      final localFile = File(localPath);
      Map<String, dynamic> fullJson = {};
      Map<String, dynamic> servers = {};

      if (localFile.existsSync()) {
        try {
          fullJson = jsonDecode(await localFile.readAsString()) as Map<String, dynamic>;
          servers = Map<String, dynamic>.from(
            (fullJson['mcpServers'] ?? {}) as Map,
          );
        } catch (_) {}
      }

      bool changed = false;

      for (final entry in result.directImports.entries) {
        final prefix = 'mcp_${editor.name}/';
        if (!entry.key.startsWith(prefix)) continue;
        final serverName = entry.key.substring(prefix.length);
        servers[serverName] = jsonDecode(entry.value as String);
        changed = true;
      }

      for (final c in result.conflicts) {
        if (c.category != 'mcpConfigs') continue;
        if (!c.itemKey.startsWith('mcp_${editor.name}/')) continue;
        if (c.resolution == ConflictResolution.keepLocal) continue;
        final serverName = c.itemKey.substring('mcp_${editor.name}/'.length);
        servers[serverName] = jsonDecode(c.resolvedValue);
        changed = true;
      }

      if (!changed) continue;

      if (editor == EditorType.claude) {
        fullJson['mcpServers'] = servers;
      } else {
        fullJson = {'mcpServers': servers};
      }

      await localFile.parent.create(recursive: true);
      await localFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(fullJson),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Prompts
  // ═══════════════════════════════════════════════════════════════════

  void _detectPromptConflicts(
    BackupData data,
    List<ImportConflict> conflicts,
    Map<String, dynamic> directImports,
  ) {
    for (final entry in BackupService.promptPaths.entries) {
      final backupContent = data.getFileContent(entry.key);
      if (backupContent == null) continue;

      final localFile = File(entry.value);
      final fileName = entry.key.split('/').last;

      if (!localFile.existsSync()) {
        directImports['prompt_${entry.key}'] = backupContent;
        continue;
      }

      final localContent = localFile.readAsStringSync();
      if (localContent != backupContent) {
        conflicts.add(ImportConflict(
          category: 'prompts',
          itemKey: entry.key,
          displayName: fileName,
          localValue: localContent,
          backupValue: backupContent,
        ));
      }
    }
  }

  Future<void> _applyPrompts(BackupData data, ImportResult result) async {
    for (final entry in BackupService.promptPaths.entries) {
      final conflict = result.conflicts
          .where((c) => c.itemKey == entry.key)
          .firstOrNull;

      String? content;
      if (conflict != null) {
        if (conflict.resolution == ConflictResolution.keepLocal) continue;
        content = conflict.resolvedValue;
      } else {
        content = result.directImports['prompt_${entry.key}'] as String?;
      }

      if (content == null) continue;
      final file = File(entry.value);
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Skills
  // ═══════════════════════════════════════════════════════════════════

  void _detectSkillConflicts(
    BackupData data,
    List<ImportConflict> conflicts,
    Map<String, dynamic> directImports,
  ) {
    for (final entry in BackupService.skillsDirPaths.entries) {
      final prefix = '${entry.key}/';
      final backupFiles = data.files.keys
          .where((k) => k.startsWith(prefix))
          .toList();
      if (backupFiles.isEmpty) continue;

      final skillNames = <String>{};
      for (final f in backupFiles) {
        final rel = f.substring(prefix.length);
        final firstSlash = rel.indexOf('/');
        if (firstSlash > 0) {
          skillNames.add(rel.substring(0, firstSlash));
        }
      }

      final localDir = Directory(entry.value);
      final provider = entry.key.split('/').last;

      for (final skill in skillNames) {
        final localSkillDir = Directory('${localDir.path}/$skill');
        final key = '${entry.key}/$skill';

        if (!localSkillDir.existsSync()) {
          directImports['skill_$key'] = true;
          continue;
        }

        final backupSkillFiles = backupFiles
            .where((f) => f.startsWith('$prefix$skill/'))
            .toList();
        bool differs = false;
        for (final bf in backupSkillFiles) {
          final rel = bf.substring(prefix.length);
          final localFile = File('${localDir.path}/$rel');
          if (!localFile.existsSync()) {
            differs = true;
            break;
          }
          final localBytes = localFile.readAsBytesSync();
          if (!listEquals(localBytes, data.files[bf])) {
            differs = true;
            break;
          }
        }

        if (differs) {
          conflicts.add(ImportConflict(
            category: 'skills',
            itemKey: key,
            displayName: '$provider > $skill',
            localValue: _summarizeDir(localSkillDir),
            backupValue: _summarizeArchiveDir(data, '$prefix$skill/'),
          ));
        }
      }
    }
  }

  String _summarizeDir(Directory dir) {
    final files = dir.listSync(recursive: true).whereType<File>().toList();
    final lines = files.map((f) => f.path.substring(dir.path.length + 1));
    return lines.join('\n');
  }

  String _summarizeArchiveDir(BackupData data, String prefix) {
    final files = data.files.keys.where((k) => k.startsWith(prefix));
    return files.map((f) => f.substring(prefix.length)).join('\n');
  }

  Future<void> _applySkills(BackupData data, ImportResult result) async {
    for (final entry in BackupService.skillsDirPaths.entries) {
      final prefix = '${entry.key}/';
      final backupFiles = data.files.keys
          .where((k) => k.startsWith(prefix))
          .toList();

      for (final bf in backupFiles) {
        final rel = bf.substring(prefix.length);
        final firstSlash = rel.indexOf('/');
        if (firstSlash <= 0) continue;
        final skill = rel.substring(0, firstSlash);
        final key = '${entry.key}/$skill';

        final conflict = result.conflicts
            .where((c) => c.itemKey == key)
            .firstOrNull;

        if (conflict != null &&
            conflict.resolution == ConflictResolution.keepLocal) {
          continue;
        }

        final isDirect = result.directImports.containsKey('skill_$key');
        final isConflictResolvedToBackup = conflict != null &&
            conflict.resolution == ConflictResolution.useBackup;

        if (isDirect || isConflictResolvedToBackup) {
          final dest = File('${entry.value}/$rel');
          await dest.parent.create(recursive: true);
          await dest.writeAsBytes(data.files[bf]!);
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Providers
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _detectProviderConflicts(
    BackupData data,
    List<ImportConflict> conflicts,
    Map<String, dynamic> directImports,
  ) async {
    final content = data.getFileContent('providers.json');
    if (content == null) return;

    final backupList = (jsonDecode(content) as List).cast<Map<String, dynamic>>();
    final localRows = await _database.select(_database.providerProfiles).get();

    for (final bp in backupList) {
      final editorType = bp['editorType'] as String;
      final name = bp['name'] as String;
      final key = '$editorType/$name';

      final local = localRows
          .where((r) => r.editorType == editorType && r.name == name)
          .firstOrNull;

      final bStr = const JsonEncoder.withIndent('  ').convert(bp);

      if (local == null) {
        directImports['provider_$key'] = bStr;
        continue;
      }

      final localMap = _providerRowToMap(local);
      final lStr = const JsonEncoder.withIndent('  ').convert(localMap);
      if (lStr != bStr) {
        conflicts.add(ImportConflict(
          category: 'providers',
          itemKey: key,
          displayName: '${EditorType.values.firstWhere((e) => e.name == editorType).label} > $name',
          localValue: lStr,
          backupValue: bStr,
        ));
      }
    }
  }

  Map<String, dynamic> _providerRowToMap(ProviderProfile row) => {
    'id': row.id,
    'editorType': row.editorType,
    'name': row.name,
    'description': row.description,
    'isActive': row.isActive,
    'apiToken': row.apiToken,
    'baseUrl': row.baseUrl,
    'model': row.model,
    'maxOutputTokens': row.maxOutputTokens,
    'maxThinkingTokens': row.maxThinkingTokens,
    'website': row.website,
    'modelReasoningEffort': row.modelReasoningEffort,
    'personality': row.personality,
    'oauthData': row.oauthData,
    'configContent': row.configContent,
    'createdAt': row.createdAt.toIso8601String(),
    'updatedAt': row.updatedAt.toIso8601String(),
  };

  Future<void> _applyProviders(BackupData data, ImportResult result) async {
    final content = data.getFileContent('providers.json');
    if (content == null) return;

    final backupList = (jsonDecode(content) as List).cast<Map<String, dynamic>>();

    for (final bp in backupList) {
      final editorType = bp['editorType'] as String;
      final name = bp['name'] as String;
      final key = '$editorType/$name';

      final conflict = result.conflicts
          .where((c) => c.itemKey == key)
          .firstOrNull;

      Map<String, dynamic> rowData;
      if (conflict != null) {
        if (conflict.resolution == ConflictResolution.keepLocal) continue;
        rowData = jsonDecode(conflict.resolvedValue) as Map<String, dynamic>;
      } else if (result.directImports.containsKey('provider_$key')) {
        rowData = bp;
      } else {
        continue;
      }

      await _database.into(_database.providerProfiles).insertOnConflictUpdate(
        ProviderProfilesCompanion(
          id: Value(rowData['id'] as String),
          editorType: Value(rowData['editorType'] as String),
          name: Value(rowData['name'] as String),
          description: Value(rowData['description'] as String?),
          isActive: Value(rowData['isActive'] as bool? ?? false),
          apiToken: Value(rowData['apiToken'] as String?),
          baseUrl: Value(rowData['baseUrl'] as String?),
          model: Value(rowData['model'] as String?),
          maxOutputTokens: Value(rowData['maxOutputTokens'] as String?),
          maxThinkingTokens: Value(rowData['maxThinkingTokens'] as String?),
          website: Value(rowData['website'] as String?),
          modelReasoningEffort: Value(rowData['modelReasoningEffort'] as String?),
          personality: Value(rowData['personality'] as String?),
          oauthData: Value(rowData['oauthData'] as String?),
          configContent: Value(rowData['configContent'] as String?),
          createdAt: Value(DateTime.parse(rowData['createdAt'] as String)),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
