part of 'config_service.dart';

/// 配置文件同步 Mixin
///
/// 负责从编辑器配置文件加载 Profile、持久化到 SharedPreferences、
/// 以及将内存中的 Profile 合并写回编辑器配置文件。
mixin _SyncMixin on ChangeNotifier {
  ConfigService get _self => this as ConfigService;

  // ═══════════════════════════════════════════════════════════════════
  // 从配置文件加载 Profile
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final String? allProfilesJson = prefs.getString('mcp_profiles');

    if (allProfilesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(allProfilesJson);
        decoded.forEach((key, value) {
          final editor = EditorType.values.firstWhere(
            (e) => e.name == key,
            orElse: () => EditorType.cursor,
          );
          if (value is List) {
            _self._profiles[editor] =
                value.map((e) => McpProfile.fromJson(e)).toList();
          }
        });
      } catch (e) {
        print("Error loading profiles cache: $e");
      }
    }

    for (var type in EditorType.values) {
      if (!_self._profiles.containsKey(type)) {
        _self._profiles[type] = [];
      }

      final path = _self.getConfigPath(type);
      final file = File(path);

      if ((type == EditorType.cursor || type == EditorType.gemini) &&
          !await file.exists()) {
        _self._profiles[type] = [];
      }

      if (await file.exists()) {
        try {
          final text = await file.readAsString();

          if (type == EditorType.codex) {
            _self._profiles[type] = CodexConfigHelper.parseToml(
              text,
              _self._profiles[type] ?? [],
            );
            if (_self._selectedEditor == EditorType.codex) {
              _self._enrichCodexAuthStatus(_self._profiles[type]!);
            }
            continue;
          }

          if (text.trim().isEmpty) {
            _self._profiles[type] = [];
            continue;
          }

          final content = jsonDecode(text);
          if (type == EditorType.claude) {
            _self._profiles[type] = _parseClaudeConfig(content, type);
          } else {
            _self._profiles[type] = _parseStandardConfig(content, type);
          }
        } catch (e) {
          print('Error reading/parsing config for $type: $e');
        }
      }
    }

    await _persistProfiles();
  }

  List<McpProfile> _parseClaudeConfig(
    dynamic content,
    EditorType type,
  ) {
    final List<McpProfile> syncedList = [];
    final List<McpProfile> cachedList = _self._profiles[type]!;
    final Map<String, McpProfile> existingMap = {
      for (var p in cachedList) p.name: p,
    };

    if (content.containsKey('mcpServers') && content['mcpServers'] is Map) {
      final globalName = 'Global Configuration';
      final existingGlobal = cachedList.cast<McpProfile?>().firstWhere(
            (p) =>
                p != null &&
                (p.content['isGlobal'] == true || p.name == globalName),
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

    if (content['projects'] is Map<String, dynamic>) {
      final Map<String, dynamic> projects = content['projects'];
      projects.forEach((projectPath, projectConfig) {
        if (projectConfig is Map<String, dynamic> &&
            projectConfig.containsKey('mcpServers')) {
          final mcpServers = projectConfig['mcpServers'];
          final disabledMcpServers = projectConfig['disabledMcpServers'];

          if (existingMap.containsKey(projectPath)) {
            final existing = existingMap[projectPath]!;
            syncedList.add(
              McpProfile(
                id: existing.id,
                name: projectPath,
                description: existing.description,
                content: {
                  'mcpServers': mcpServers,
                  if (disabledMcpServers is List)
                    'disabledMcpServers': disabledMcpServers,
                },
              ),
            );
          } else {
            syncedList.add(
              McpProfile(
                id: const Uuid().v4(),
                name: projectPath,
                description: 'Project Config',
                content: {
                  'mcpServers': mcpServers,
                  if (disabledMcpServers is List)
                    'disabledMcpServers': disabledMcpServers,
                },
              ),
            );
          }
        }
      });
    }
    return syncedList;
  }

  List<McpProfile> _parseStandardConfig(
    dynamic content,
    EditorType type,
  ) {
    final List<McpProfile> syncedList = [];
    final mcpServers = content['mcpServers'];

    if (mcpServers is Map<String, dynamic>) {
      final List<McpProfile> cachedList = _self._profiles[type]!;
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
              content: {'mcpServers': {key: value}},
            ),
          );
        } else {
          syncedList.add(
            McpProfile(
              id: const Uuid().v4(),
              name: key,
              description: 'Imported from config',
              content: {'mcpServers': {key: value}},
            ),
          );
        }
      });
    }
    return syncedList;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 持久化到 SharedPreferences
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _persistProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> data = {};
    _self._profiles.forEach((key, value) {
      data[key.name] = value.map((p) => p.toJson()).toList();
    });
    await prefs.setString('mcp_profiles', jsonEncode(data));
  }

  // ═══════════════════════════════════════════════════════════════════
  // 合并写回编辑器配置文件
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _syncCombinedConfig(EditorType editor) async {
    final profiles = _self._profiles[editor] ?? [];

    if (editor == EditorType.claude) {
      await _syncClaudeConfig(profiles, editor);
    } else if (editor == EditorType.codex) {
      await _syncCodexConfig(profiles, editor);
    } else {
      await _syncStandardConfig(profiles, editor);
    }
  }

  Future<void> _syncClaudeConfig(
    List<McpProfile> profiles,
    EditorType editor,
  ) async {
    final path = _self.getConfigPath(editor);
    final file = File(path);
    Map<String, dynamic> fullConfig = {};

    if (await file.exists()) {
      try {
        fullConfig = jsonDecode(await file.readAsString());
      } catch (_) {}
    }

    McpProfile? globalProfile;
    try {
      globalProfile = profiles.firstWhere(
        (p) => p.content['isGlobal'] == true,
      );
    } catch (_) {}

    if (globalProfile != null) {
      fullConfig['mcpServers'] = globalProfile.content['mcpServers'] ?? {};
    }

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

      final disabledMcpServers = profile.content['disabledMcpServers'];
      if (disabledMcpServers is List && disabledMcpServers.isNotEmpty) {
        projects[projectPath]['disabledMcpServers'] = disabledMcpServers;
      } else {
        projects[projectPath].remove('disabledMcpServers');
      }
    }

    projects.keys.toList().forEach((key) {
      if (!activeProjectPaths.contains(key)) {
        if (projects[key] is Map) {
          projects[key].remove('mcpServers');
        }
      }
    });

    await _writeToEditorConfig(editor, fullConfig);
  }

  Future<void> _syncCodexConfig(
    List<McpProfile> profiles,
    EditorType editor,
  ) async {
    final path = _self.getConfigPath(editor);
    final file = File(path);

    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsString('');
    }

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
          if (currentSection != null &&
              currentSection.startsWith('[mcp_servers.')) {
            continue;
          }
          preservedLines.add(line);
        }
      } catch (_) {}
    }

    while (preservedLines.isNotEmpty && preservedLines.last.trim().isEmpty) {
      preservedLines.removeLast();
    }

    final newConfig = CodexConfigHelper.generateToml(profiles);
    final combined = '${preservedLines.join('\n')}\n\n$newConfig';
    await file.writeAsString('${combined.trim()}\n');
  }

  Future<void> _syncStandardConfig(
    List<McpProfile> profiles,
    EditorType editor,
  ) async {
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

  Future<void> _writeToEditorConfig(
    EditorType editor,
    Map<String, dynamic> content,
  ) async {
    final path = _self._editorConfigPaths[editor];
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(content));
  }
}
