import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/editor_type.dart';
import '../models/mcp_profile.dart';
import 'package:uuid/uuid.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

class ConfigService extends ChangeNotifier {
  // In-memory storage of profiles for each editor
  final Map<EditorType, List<McpProfile>> _profiles = {};
  final Map<EditorType, String?> _activeProfileIds = {};
  
  // Theme
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
    ThemeMode.system,
  );
  
  bool _minimizeToTray = true;
  bool get minimizeToTray => _minimizeToTray;

  bool _launchAtStartup = false;
  bool get launchAtStartup => _launchAtStartup;

  // Custom paths for editors (configurable by user)
  final Map<EditorType, String> _editorConfigPaths = {};

  bool _isInitialized = false;

  ConfigService();

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadSettings();
    await _initStartup();
    await _loadProfiles();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Load custom paths
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
    
    // Load theme
    final themeIndex = prefs.getInt('theme_mode');
    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      themeModeNotifier.value = ThemeMode.values[themeIndex];
    }
    
    _minimizeToTray = prefs.getBool('minimize_to_tray') ?? true;
    _launchAtStartup =
        prefs.getBool('launch_at_startup') ??
        false; // Actual check via package done in _initStartup
  }

  String _getDefaultPath(EditorType type) {
    // Return placeholder default paths. These need to be verified on macOS.
    final home = Platform.environment['HOME'];
    switch (type) {
      case EditorType.cursor:
        return '$home/.cursor/mcp.json';
      case EditorType.windsurf:
        return '$home/.codeium/windsurf/mcp_config.json';
      case EditorType.claude:
        return '$home/.claude.json'; // Updated default path to root .claude.json
      case EditorType.codex:
        return '$home/.codex/config.toml';
      case EditorType.antigravity:
        return '$home/.gemini/antigravity/mcp_config.json';
      case EditorType.gemini:
        return '$home/.gemini/settings.json';
    }
  }

  Future<void> reloadProfiles() async {
    await _loadProfiles();
    notifyListeners();
  }

  Future<void> _loadProfiles() async {
    // 1. Load cached profiles first to preserve IDs and metadata (like descriptions)
    final prefs = await SharedPreferences.getInstance();
    final String? allProfilesJson = prefs.getString('mcp_profiles');
    
    if (allProfilesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(allProfilesJson);
        decoded.forEach((key, value) {
          final editor = EditorType.values.firstWhere(
            (e) => e.name == key, 
            orElse: () => EditorType.cursor
          );
          if (value is List) {
            _profiles[editor] = value.map((e) => McpProfile.fromJson(e)).toList();
          }
        });
      } catch (e) {
        print("Error loading profiles cache: $e");
      }
    }

    // 2. SYNC with actual config files (Source of Truth)
    for (var type in EditorType.values) {
      if (!_profiles.containsKey(type)) {
        _profiles[type] = [];
      }

      final path = getConfigPath(type);
      final file = File(path);

      // If Cursor/Gemini config file is missing, clear any cached profiles to show empty state
      if ((type == EditorType.cursor || type == EditorType.gemini) &&
          !await file.exists()) {
        _profiles[type] = [];
      }

      if (await file.exists()) {
        try {
          final text = await file.readAsString();

          if (type == EditorType.codex) {
            _profiles[type] = _parseCodexToml(text, _profiles[type] ?? []);
            continue;
          }

          if (text.trim().isEmpty) {
            _profiles[type] = [];
            continue;
          }

          if (type != EditorType.codex && text.trim().isNotEmpty) {
            final content = jsonDecode(text);

            if (type == EditorType.claude) {
              // --- CLAUDE CODE SPECIAL LOGIC (Nested Projects + Global) ---
              final List<McpProfile> syncedList = [];
              final List<McpProfile> cachedList = _profiles[type]!;
              final Map<String, McpProfile> existingMap = {
                for (var p in cachedList) p.name: p,
              };

              // 1. Global Config (Root mcpServers)
              if (content.containsKey('mcpServers') &&
                  content['mcpServers'] is Map) {
                final globalName = 'Global Configuration';
                final existingGlobal = cachedList
                    .cast<McpProfile?>()
                    .firstWhere(
                      (p) =>
                          p != null &&
                          (p.content['isGlobal'] == true ||
                              p.name == globalName),
                      orElse: () => null,
                    );

                syncedList.add(
                  McpProfile(
                    id: existingGlobal?.id ?? const Uuid().v4(),
                    name: globalName,
                    description: 'Global User Settings',
                    content: {
                      'mcpServers': content['mcpServers'],
                      'isGlobal': true,
                    },
                  ),
                );
              }

              // 2. Projects
              if (content['projects'] is Map<String, dynamic>) {
                final Map<String, dynamic> projects = content['projects'];
                projects.forEach((projectPath, projectConfig) {
                  if (projectConfig is Map<String, dynamic> &&
                      projectConfig.containsKey('mcpServers')) {
                    final mcpServers = projectConfig['mcpServers'];

                    if (existingMap.containsKey(projectPath)) {
                      final existing = existingMap[projectPath]!;
                      syncedList.add(
                        McpProfile(
                          id: existing.id,
                          name: projectPath,
                          description: existing.description,
                          content: {'mcpServers': mcpServers},
                        ),
                      );
                    } else {
                      syncedList.add(
                        McpProfile(
                          id: const Uuid().v4(),
                          name: projectPath, // Project Path is the Name
                          description: 'Project Config',
                          content: {'mcpServers': mcpServers},
                        ),
                      );
                    }
                  }
                });
              }
              _profiles[type] = syncedList;
            } else {
              // --- STANDARD LOGIC (Root Impl) ---
              final List<McpProfile> syncedList = [];
              final mcpServers = content['mcpServers'];

              if (mcpServers is Map<String, dynamic>) {
                final List<McpProfile> cachedList = _profiles[type]!;
                final Map<String, McpProfile> existingMap = {
                  for (var p in cachedList) p.name: p,
                };

                mcpServers.forEach((key, value) {
                  if (existingMap.containsKey(key)) {
                    final existing = existingMap[key]!;
                    syncedList.add(
                      McpProfile(
                        id: existing.id,
                        name: key,
                        description: existing.description,
                        content: {
                          'mcpServers': {key: value},
                        },
                      ),
                    );
                  } else {
                    syncedList.add(
                      McpProfile(
                        id: const Uuid().v4(),
                        name: key,
                        description: 'Imported from config',
                        content: {
                          'mcpServers': {key: value}
                        }
                      ));
                  }
                });
              }
              _profiles[type] = syncedList;
            }
          }
        } catch (e) {
          print('Error reading/parsing config for $type: $e');
        }
      }
    }
    
    // 3. Persist the synchronized state
    await _persistProfiles();
  }

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
    // In synced mode, 'active' mainly acts as a UI selection or "Edit Focus".
    // It doesn't exclusive-write to file anymore.
    final profile = _profiles[editor]?.firstWhere((p) => p.id == profileId);
    if (profile == null) return;

    _activeProfileIds[editor] = profileId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_${editor.name}', profileId);

    // We don't overwrite file with single profile here, ensuring aggregate view.
    notifyListeners();
  }

  Future<void> _writeToEditorConfig(EditorType editor, Map<String, dynamic> content) async {
    final path = _editorConfigPaths[editor];
    if (path == null) return;

    final file = File(path);
    // Don't create recursively if it doesn't exist for Claude (should exist?), but standard safe
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(content));
  }

  Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    _profiles.forEach((key, value) {
      data[key.name] = value.map((p) => p.toJson()).toList();
    });
    await prefs.setString('mcp_profiles', jsonEncode(data));
  }
  
  Future<void> _syncCombinedConfig(EditorType editor) async {
    final profiles = _profiles[editor] ?? [];

    if (editor == EditorType.claude) {
      // --- CLAUDE CODE SYNC (Root + Projects) ---
      final path = getConfigPath(editor);
      final file = File(path);
      Map<String, dynamic> fullConfig = {};

      if (await file.exists()) {
        try {
          fullConfig = jsonDecode(await file.readAsString());
        } catch (_) {}
      }

      // 1. Handle Global Config
      McpProfile? globalProfile;
      try {
        globalProfile = profiles.firstWhere(
          (p) => p.content['isGlobal'] == true,
        );
      } catch (_) {}

      if (globalProfile != null) {
        fullConfig['mcpServers'] = globalProfile.content['mcpServers'] ?? {};
      }

      // 2. Handle Projects
      if (!fullConfig.containsKey('projects')) {
        fullConfig['projects'] = {};
      }
      final Map<String, dynamic> projects = fullConfig['projects'];

      final activeProjectPaths = <String>{};

      for (final profile in profiles) {
        if (profile.content['isGlobal'] == true) continue;

        final projectPath = profile.name;
        activeProjectPaths.add(projectPath);

        if (!projects.containsKey(projectPath)) {
          projects[projectPath] = {};
        }
        projects[projectPath]['mcpServers'] =
            profile.content['mcpServers'] ?? {};
      }

      // 3. Remove mcpServers from projects that are NO LONGER in profiles
      projects.keys.toList().forEach((key) {
        if (!activeProjectPaths.contains(key)) {
          if (projects[key] is Map) {
            projects[key].remove('mcpServers');
          }
        }
      });

      await _writeToEditorConfig(editor, fullConfig);
    } else if (editor == EditorType.codex) {
      // --- CODEX TOML GENERATION WITH PRESERVATION ---
      final path = getConfigPath(editor);
      final file = File(path);
      
      if (!await file.exists()) {
        await file.create(recursive: true);
        await file.writeAsString('');
      }

      // Read existing to preserve non-mcp sections
      List<String> preservedLines = [];
      if (await file.exists()) {
        try {
          final lines = await file.readAsLines();
          String? currentSection;
          for (var line in lines) {
            final trimmed = line.trim();
            if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
              currentSection = trimmed;
            }

            // Skip mcp_servers sections
            if (currentSection != null &&
                currentSection.startsWith('[mcp_servers.')) {
              continue;
            }
            preservedLines.add(line);
          }
        } catch (_) {}
      }

      // Clean up trailing empty lines
      while (preservedLines.isNotEmpty && preservedLines.last.trim().isEmpty) {
        preservedLines.removeLast();
      }

      final newConfig = _generateCodexToml(profiles);
      final combined = '${preservedLines.join('\n')}\n\n$newConfig';
      await file.writeAsString(combined.trim() + '\n');
    } else {
      // --- STANDARD SYNC (Combined mcpServers) ---
      final Map<String, dynamic> combinedMcpServers = {};

      for (final profile in profiles) {
        final content = profile.content;
        if (content['mcpServers'] is Map) {
          combinedMcpServers.addAll(
            Map<String, dynamic>.from(content['mcpServers']),
          );
        }
      }
      final fullConfig = {'mcpServers': combinedMcpServers};
      await _writeToEditorConfig(editor, fullConfig);
    }
  }

  // Settings Updates
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

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  // Getters
  List<McpProfile> getProfiles(EditorType editor) => _profiles[editor] ?? [];
  String? getActiveProfileId(EditorType editor) => _activeProfileIds[editor];
  String getConfigPath(EditorType editor) => _editorConfigPaths[editor] ?? _getDefaultPath(editor);

  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('minimize_to_tray', value);
    notifyListeners();
  }

  Future<void> setLaunchAtStartup(bool value) async {
    _launchAtStartup = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('launch_at_startup', value);

    if (value) {
      await LaunchAtStartup.instance.enable();
    } else {
      await LaunchAtStartup.instance.disable();
    }
    notifyListeners();
  }

  Future<void> _initStartup() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      LaunchAtStartup.instance.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );
      _launchAtStartup = await LaunchAtStartup.instance.isEnabled();
    } catch (e) {
      print('Error initializing startup config: $e');
      _launchAtStartup = false;
    }
  }

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

        // Toggle status
        serverConfig['disabled'] = isEnabled;
        serverConfig.remove('enabled');

        await saveProfile(editor, profile);
        // saveProfile calls _syncCombinedConfig, so we are good.
        // But saveProfile also calls notifyListeners.
      }
    }
  }
  // --- HELPERS for Codex TOML ---

  List<McpProfile> _parseCodexToml(
    String content,
    List<McpProfile> cachedProfiles,
  ) {
    final List<McpProfile> profiles = [];
    final lines = content.split('\n');
    String? currentServerName;
    String? currentCommand;
    List<String> currentArgs = [];
    bool inArgs = false;

    // Map for ID preservation
    final Map<String, String> nameToId = {
      for (var p in cachedProfiles) p.name: p.id,
    };

    void saveCurrent() {
      if (currentServerName != null) {
        profiles.add(
          McpProfile(
            id: nameToId[currentServerName] ?? const Uuid().v4(),
            name: currentServerName!,
            description: 'Codex Server configuration',
            content: {
              'mcpServers': {
                currentServerName: {
                  'command': currentCommand ?? '',
                  'args': currentArgs,
                },
              },
            },
          ),
        );
      }
      currentServerName = null;
      currentCommand = null;
      currentArgs = [];
      inArgs = false;
    }

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('[mcp_servers.') && line.endsWith(']')) {
        saveCurrent();
        currentServerName = line.substring(13, line.length - 1).trim();
        continue;
      }

      if (line.startsWith('command')) {
        final match = RegExp(r'command\s*=\s*"(.*)"').firstMatch(line);
        if (match != null) currentCommand = match.group(1);
        continue;
      }

      if (line.startsWith('args')) {
        if (line.contains('[')) {
          // check for inline empty or inline content
          final inlineMatch = RegExp(r'\[(.*)\]').firstMatch(line);
          if (inlineMatch != null && !line.endsWith('[')) {
            // inline
            final raw = inlineMatch.group(1)!;
            if (raw.trim().isNotEmpty) {
              currentArgs = raw
                  .split(',')
                  .map((e) => e.trim().replaceAll('"', ''))
                  .where((s) => s.isNotEmpty)
                  .toList();
            }
          } else {
            inArgs = true;
          }
        }
        continue;
      }

      if (inArgs) {
        if (line.trim() == ']') {
          inArgs = false;
          continue;
        }
        final match = RegExp(r'"(.*)"').firstMatch(line);
        if (match != null) {
          currentArgs.add(match.group(1)!);
        }
      }
    }
    saveCurrent();
    return profiles;
  }

  String _generateCodexToml(List<McpProfile> profiles) {
    final buffer = StringBuffer();
    for (var profile in profiles) {
      final content = profile.content;
      if (content['mcpServers'] is! Map) continue;
      final Map<String, dynamic> servers = content['mcpServers'];

      for (var entry in servers.entries) {
        final name = entry.key;
        final config = entry.value;
        if (config is! Map) continue;

        // Quote name if it contains spaces or non-alphanumeric chars
        final safeName = name.contains(RegExp(r'[^a-zA-Z0-9_\-]'))
            ? '"$name"'
            : name;
        buffer.writeln('[mcp_servers.$safeName]');
        
        buffer.writeln('command = "${config['command']}"');
        final args = config['args'];
        if (args is List && args.isNotEmpty) {
          buffer.writeln('args = [');
          for (var i = 0; i < args.length; i++) {
            final arg = args[i];
            final suffix = (i == args.length - 1) ? '' : ',';
            buffer.writeln('  "$arg"$suffix');
          }
          buffer.writeln(']');
        } else {
          buffer.writeln('args = []');
        }
        buffer.writeln();
      }
    }
    return buffer.toString();
  }
}
