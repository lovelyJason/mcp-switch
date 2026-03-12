import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/editor_type.dart';
import '../../models/mcp_profile.dart';
import 'package:uuid/uuid.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import '../logger_service.dart';
import '../cursor_workspace_service.dart';
import '../claude_plugin_integration_service.dart';
import 'codex_config_helper.dart';
import '../../utils/platform_utils.dart';

part 'config_service_settings.dart';
part 'config_service_sync.dart';

/// 配置服务类 (ConfigService)
///
/// 主要作用：
/// 1. 管理应用全局状态（如主题、最小化到托盘、开机自启等）。
/// 2. 管理各个编辑器（Cursor, Windsurf, Claude Code 等）的 MCP 配置文件路径和内容。
/// 3. 提供配置文件的读取、解析、保存和同步功能（支持 JSON 和 TOML 格式）。
/// 4. 维护当前选中的编辑器状态（Global Editor State），用于跨页面状态共享。
class ConfigService extends ChangeNotifier with _SettingsMixin, _SyncMixin {
  final Map<EditorType, List<McpProfile>> _profiles = {};
  final Map<EditorType, String?> _activeProfileIds = {};

  EditorType _selectedEditor = EditorType.cursor;
  EditorType get selectedEditor => _selectedEditor;

  final Map<EditorType, String> _editorConfigPaths = {};

  bool _isInitialized = false;

  static const List<String> availableModels = [
    'claude-opus-4-5-20251101',
    'claude-sonnet-4-5-20250929',
    'claude-sonnet-4-20250514',
    'claude-haiku-4-5-20251001',
    'claude-3-5-sonnet-20241022',
    'claude-3-5-haiku-20241022',
    'claude-3-opus-20240229',
  ];

  ConfigService();

  // ═══════════════════════════════════════════════════════════════════
  // 初始化
  // ═══════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadCoreState();
    await _loadAppSettings();
    await _initStartup();
    await _loadProfiles();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadCoreState() async {
    final prefs = await SharedPreferences.getInstance();
    for (var type in EditorType.values) {
      String? path = prefs.getString('path_${type.name}');
      if (path != null) {
        _editorConfigPaths[type] = path;
      } else {
        _editorConfigPaths[type] = _getDefaultPath(type);
      }
      String? activeId = prefs.getString('active_${type.name}');
      _activeProfileIds[type] = activeId;
    }
    final savedEditor = prefs.getString('selected_editor');
    if (savedEditor != null) {
      try {
        _selectedEditor = EditorType.values.firstWhere(
          (e) => e.name == savedEditor,
        );
      } catch (_) {}
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Getters
  // ═══════════════════════════════════════════════════════════════════

  List<McpProfile> getProfiles(EditorType editor) => _profiles[editor] ?? [];
  String? getActiveProfileId(EditorType editor) => _activeProfileIds[editor];
  String getConfigPath(EditorType editor) =>
      _editorConfigPaths[editor] ?? _getDefaultPath(editor);

  String _getDefaultPath(EditorType type) {
    final home = PlatformUtils.userHome;
    switch (type) {
      case EditorType.cursor:
        return PlatformUtils.joinPath(home, '.cursor', 'mcp.json');
      case EditorType.windsurf:
        return PlatformUtils.joinPath(
          home, '.codeium', 'windsurf', 'mcp_config.json',
        );
      case EditorType.claude:
        return PlatformUtils.joinPath(home, '.claude.json');
      case EditorType.codex:
        return PlatformUtils.joinPath(home, '.codex', 'config.toml');
      case EditorType.antigravity:
        return PlatformUtils.joinPath(
          home, '.gemini', 'antigravity', 'mcp_config.json',
        );
      case EditorType.gemini:
        return PlatformUtils.joinPath(home, '.gemini', 'settings.json');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Profile CRUD
  // ═══════════════════════════════════════════════════════════════════

  Future<void> saveProfile(EditorType editor, McpProfile profile) async {
    if (_profiles[editor] == null) _profiles[editor] = [];

    final index = _profiles[editor]!.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      _profiles[editor]![index] = profile;
    } else {
      _profiles[editor]!.add(profile);
    }

    await _persistProfiles();
    await _syncCombinedConfig(editor);
    notifyListeners();

    if (editor == EditorType.codex) {
      _enrichCodexAuthStatus(_profiles[editor]!);
    }
  }

  Future<void> deleteProfile(EditorType editor, String profileId) async {
    _profiles[editor]?.removeWhere((p) => p.id == profileId);
    if (_activeProfileIds[editor] == profileId) {
      _activeProfileIds[editor] = null;
    }
    await _persistProfiles();
    await _syncCombinedConfig(editor);
    notifyListeners();
  }

  Future<void> activateProfile(EditorType editor, String profileId) async {
    final profile = _profiles[editor]?.firstWhere((p) => p.id == profileId);
    if (profile == null) return;

    _activeProfileIds[editor] = profileId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_${editor.name}', profileId);
    notifyListeners();
  }

  Future<void> reloadProfiles() async {
    await _loadProfiles();
    notifyListeners();
  }

  Future<void> refreshCodexAuthStatus() async {
    final profiles = _profiles[EditorType.codex];
    if (profiles != null && profiles.isNotEmpty) {
      await _enrichCodexAuthStatus(profiles);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 编辑器切换 & 配置路径
  // ═══════════════════════════════════════════════════════════════════

  Future<void> setEditor(EditorType type) async {
    if (_selectedEditor == type) return;
    _selectedEditor = type;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_editor', type.name);
    notifyListeners();
  }

  Future<void> setConfigPath(EditorType type, String path) async {
    _editorConfigPaths[type] = path;
    final prefs = await SharedPreferences.getInstance();
    if (path.isEmpty) {
      await prefs.remove('path_${type.name}');
      _editorConfigPaths[type] = _getDefaultPath(type);
    } else {
      await prefs.setString('path_${type.name}', path);
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // MCP 开关
  // ═══════════════════════════════════════════════════════════════════

  Future<void> toggleServerStatus(EditorType editor, String profileId) async {
    final profiles = _profiles[editor];
    if (profiles == null) return;
    final index = profiles.indexWhere((p) => p.id == profileId);
    if (index == -1) return;

    final profile = profiles[index];
    final mcpServers = profile.content['mcpServers'];
    if (mcpServers is! Map) return;

    final name = profile.name;
    if (mcpServers.containsKey(name)) {
      final serverConfig = mcpServers[name];
      if (serverConfig is Map) {
        bool isEnabled = true;
        if (serverConfig.containsKey('disabled')) {
          isEnabled = serverConfig['disabled'] != true;
        } else if (serverConfig.containsKey('enabled')) {
          isEnabled = serverConfig['enabled'] == true;
        }

        final nowDisabled = isEnabled;
        serverConfig['disabled'] = nowDisabled;
        serverConfig.remove('enabled');
        await saveProfile(editor, profile);

        if (editor == EditorType.cursor) {
          final cursorWs = CursorWorkspaceService.instance;
          if (cursorWs.shouldUseSqlite) {
            await cursorWs.toggleServerInAllWorkspaces(name, nowDisabled);
          }
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Codex Auth 状态
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _enrichCodexAuthStatus(List<McpProfile> profiles) async {
    try {
      LoggerService.debug(
          '[CodexAuth] enriching ${profiles.length} profiles...');
      final result = await PlatformUtils.runCommand('codex mcp list')
          .timeout(const Duration(seconds: 15));
      if (result.exitCode != 0) {
        LoggerService.warning(
            '[CodexAuth] codex mcp list failed: exit=${result.exitCode}');
        return;
      }
      final output = (result.stdout as String).trim();
      if (output.isEmpty) return;

      final authMap = CodexConfigHelper.parseAuthFromCli(output);
      LoggerService.debug('[CodexAuth] parsed authMap: $authMap');
      if (authMap.isEmpty) return;

      bool changed = false;
      for (final profile in profiles) {
        final auth = authMap[profile.name];
        if (auth == null || auth.isEmpty) continue;
        final mcpServers = profile.content['mcpServers'];
        if (mcpServers is Map && mcpServers.containsKey(profile.name)) {
          final server = mcpServers[profile.name];
          if (server is Map<String, dynamic>) {
            server['auth'] = auth;
            changed = true;
          }
        }
      }
      if (changed) {
        LoggerService.info('[CodexAuth] auth status updated, notifying UI');
        notifyListeners();
      }
    } catch (e) {
      LoggerService.warning('[CodexAuth] enrichment failed: $e');
    }
  }
}
