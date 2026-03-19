import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/version.dart';
import '../data/database.dart';
import '../l10n/s.dart';
import '../models/editor_type.dart';
import '../utils/platform_utils.dart';
import 'config/config_service.dart';

enum BackupCategory {
  preferences,
  mcpConfigs,
  prompts,
  skills,
  providers,
}

class BackupService {
  static const List<int> magic = [0x4D, 0x43, 0x50, 0x53, 0x57]; // "MCPSW"
  static const int formatVersion = 0x01;
  static const int headerSize = 6;

  final ConfigService _configService;
  final AppDatabase _database;

  BackupService(this._configService, this._database);

  /// SharedPreferences keys to export for [BackupCategory.preferences]
  static const prefKeys = <String, String>{
    'theme_mode': 'int',
    'minimize_to_tray': 'bool',
    'launch_at_startup': 'bool',
    'enable_claude_plugin_integration': 'bool',
    'skip_claude_code_onboarding': 'bool',
    'log_level': 'int',
    'claude_api_key': 'string',
    'claude_api_base_url': 'string',
    'claude_model': 'string',
    'show_chatbot_icon': 'bool',
    'terminal_ai_model_id': 'string',
    'chat_ai_model_id': 'string',
    'deepl_api_key': 'string',
    'proxy_url': 'string',
    'proxy_username': 'string',
    'proxy_password': 'string',
  };

  Future<(bool, String?)> exportBackup(
    List<BackupCategory> categories,
    String outputPath,
  ) async {
    try {
      final archive = Archive();
      final exportedCategories = <String>[];
      final skippedFiles = <String>[];

      if (categories.contains(BackupCategory.preferences)) {
        await _exportPreferences(archive);
        exportedCategories.add('preferences');
      }
      if (categories.contains(BackupCategory.mcpConfigs)) {
        await _exportMcpConfigs(archive, skippedFiles);
        exportedCategories.add('mcpConfigs');
      }
      if (categories.contains(BackupCategory.prompts)) {
        await _exportPrompts(archive, skippedFiles);
        exportedCategories.add('prompts');
      }
      if (categories.contains(BackupCategory.skills)) {
        await _exportSkills(archive, skippedFiles);
        exportedCategories.add('skills');
      }
      if (categories.contains(BackupCategory.providers)) {
        await _exportProviders(archive);
        exportedCategories.add('providers');
      }

      _addManifest(archive, exportedCategories, skippedFiles);

      final zipBytes = ZipEncoder().encode(archive);

      final output = Uint8List(headerSize + zipBytes.length);
      output.setAll(0, magic);
      output[5] = formatVersion;
      output.setAll(6, zipBytes);

      await File(outputPath).writeAsBytes(output);
      return (true, null);
    } catch (e) {
      return (false, e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Preferences
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _exportPreferences(Archive archive) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    data['locale'] = S.localeNotifier.value.languageCode;

    for (final entry in prefKeys.entries) {
      final key = entry.key;
      final type = entry.value;
      switch (type) {
        case 'int':
          final v = prefs.getInt(key);
          if (v != null) data[key] = v;
        case 'bool':
          final v = prefs.getBool(key);
          if (v != null) data[key] = v;
        case 'string':
          final v = prefs.getString(key);
          if (v != null) data[key] = v;
      }
    }

    _addJsonFile(archive, 'preferences.json', data);
  }

  // ═══════════════════════════════════════════════════════════════════
  // MCP Configs
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _exportMcpConfigs(
    Archive archive,
    List<String> skippedFiles,
  ) async {
    for (final editor in EditorType.values) {
      final path = _configService.getConfigPath(editor);
      final file = File(path);
      if (!file.existsSync()) {
        skippedFiles.add('mcp_configs/${editor.name} (not found)');
        continue;
      }

      if (editor == EditorType.claude) {
        await _exportClaudeMcpServers(archive, file, skippedFiles);
      } else {
        final bytes = await file.readAsBytes();
        final archiveName = mcpConfigFileName(editor);
        archive.addFile(ArchiveFile('mcp_configs/$archiveName', bytes.length, bytes));
      }
    }
  }

  Future<void> _exportClaudeMcpServers(
    Archive archive,
    File file,
    List<String> skippedFiles,
  ) async {
    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final mcpServers = json['mcpServers'];
      if (mcpServers == null) {
        skippedFiles.add('mcp_configs/claude.json (no mcpServers)');
        return;
      }
      _addJsonFile(archive, 'mcp_configs/claude.json', {'mcpServers': mcpServers});
    } catch (e) {
      skippedFiles.add('mcp_configs/claude.json (parse error)');
    }
  }

  static String mcpConfigFileName(EditorType editor) {
    switch (editor) {
      case EditorType.cursor:
        return 'cursor_mcp.json';
      case EditorType.windsurf:
        return 'windsurf_mcp_config.json';
      case EditorType.claude:
        return 'claude.json';
      case EditorType.codex:
        return 'codex_config.toml';
      case EditorType.antigravity:
        return 'antigravity_mcp_config.json';
      case EditorType.gemini:
        return 'gemini_settings.json';
      case EditorType.kiro:
        return 'kiro_mcp.json';
    }
  }

  static EditorType? editorFromFileName(String fileName) {
    for (final e in EditorType.values) {
      if (mcpConfigFileName(e) == fileName) return e;
    }
    return null;
  }

  static Map<String, String> get promptPaths {
    final home = PlatformUtils.userHome;
    return {
      'prompts/CLAUDE.md': PlatformUtils.joinPath(home, '.claude', 'CLAUDE.md'),
      'prompts/GEMINI.md': PlatformUtils.joinPath(home, '.gemini', 'GEMINI.md'),
    };
  }

  static Map<String, String> get skillsDirPaths {
    final home = PlatformUtils.userHome;
    return {
      'skills/claude': PlatformUtils.joinPath(home, '.claude', 'skills'),
      'skills/codex': PlatformUtils.joinPath(home, '.codex', 'skills'),
      'skills/antigravity': PlatformUtils.joinPath(
        home, '.gemini', 'antigravity', 'skills',
      ),
    };
  }

  // ═══════════════════════════════════════════════════════════════════
  // Prompts
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _exportPrompts(
    Archive archive,
    List<String> skippedFiles,
  ) async {
    for (final entry in promptPaths.entries) {
      final file = File(entry.value);
      if (!file.existsSync()) {
        skippedFiles.add('${entry.key} (not found)');
        continue;
      }
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Skills
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _exportSkills(
    Archive archive,
    List<String> skippedFiles,
  ) async {
    for (final entry in skillsDirPaths.entries) {
      final dir = Directory(entry.value);
      if (!dir.existsSync()) {
        skippedFiles.add('${entry.key}/ (not found)');
        continue;
      }
      _addDirectoryToArchive(archive, dir, entry.key);
    }
  }

  void _addDirectoryToArchive(Archive archive, Directory dir, String prefix) {
    final entities = dir.listSync(recursive: true);
    for (final entity in entities) {
      if (entity is File) {
        final relativePath = entity.path.substring(dir.path.length + 1);
        final archivePath = '$prefix/$relativePath';
        final bytes = entity.readAsBytesSync();
        archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Provider Profiles (SQLite)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _exportProviders(Archive archive) async {
    final rows = await _database.select(_database.providerProfiles).get();
    final list = rows.map((row) => {
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
    }).toList();

    _addJsonFile(archive, 'providers.json', list);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Manifest & Helpers
  // ═══════════════════════════════════════════════════════════════════

  void _addManifest(
    Archive archive,
    List<String> exportedCategories,
    List<String> skippedFiles,
  ) {
    final manifest = {
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'exportDate': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'categories': exportedCategories,
      'skipped': skippedFiles,
    };
    _addJsonFile(archive, 'manifest.json', manifest);
  }

  void _addJsonFile(Archive archive, String name, dynamic data) {
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }
}
