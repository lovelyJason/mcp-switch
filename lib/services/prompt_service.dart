import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../models/claude_prompt.dart';
import '../utils/platform_utils.dart';

import 'dart:async'; // Add import

class PromptService extends ChangeNotifier {
  List<ClaudePrompt> _prompts = [];
  bool _isInitialized = false;
  final Completer<void> _initCompleter = Completer<void>(); // Add completer
  bool _hasSeenTerminalArt = false;

  List<ClaudePrompt> get prompts => _prompts;
  bool get hasSeenTerminalArt => _hasSeenTerminalArt;
  
  Future<void> get ensureInitialized => _initCompleter.future;

  // Path constants
  static const String _mcpSwitchDir = '.mcp-switch';
  static const String _configFile = 'config.json';
  static const String _claudeDir = '.claude';
  static const String _claudeFile = 'CLAUDE.md';

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _loadPrompts();
      await _syncFromClaudeFile();
    } finally {
      _isInitialized = true;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
      notifyListeners();
    }
  }
  
  Future<void> markTerminalArtLoaded() async {
    _hasSeenTerminalArt = true;
    await _savePrompts();
    notifyListeners();
  }

  Future<String> get _appConfigPath async {
    final home = PlatformUtils.userHome;
    if (home.isEmpty) throw Exception('User home directory not found');
    final dir = Directory(PlatformUtils.joinPath(home, _mcpSwitchDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return PlatformUtils.joinPath(dir.path, _configFile);
  }

  String get _claudeFilePath {
    final home = PlatformUtils.userHome;
    if (home.isEmpty) throw Exception('User home directory not found');
    return PlatformUtils.joinPath(home, _claudeDir, _claudeFile);
  }

  Future<void> _loadPrompts() async {
    try {
      final path = await _appConfigPath;
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isEmpty) return;
        
        final Map<String, dynamic> json = jsonDecode(content);
        
        // Load settings
        if (json.containsKey('terminal_art_seen')) {
          _hasSeenTerminalArt = json['terminal_art_seen'] == true;
        }
        
        List<dynamic>? promptsList;

        // 1. Try new structure: claude.prompts
        if (json.containsKey('claude') && json['claude'] is Map) {
          if (json['claude']['prompts'] is List) {
            promptsList = json['claude']['prompts'];
          }
        }

        // 2. Fallback to old structure: root.prompts
        if (promptsList == null && json['prompts'] is List) {
          promptsList = json['prompts'];
        }

        if (promptsList != null) {
          _prompts = promptsList
              .map((e) => ClaudePrompt.fromJson(e))
              .toList();
          
          // Sort by updated descending
          _prompts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        }
      }
    } catch (e) {
      print('Error loading prompts: $e');
    }
  }

  Future<void> _savePrompts() async {
    try {
      final path = await _appConfigPath;
      final file = File(path);
      
      // Preserve other config if exists?
      Map<String, dynamic> fullConfig = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          fullConfig = jsonDecode(content);
        } catch (_) {}
      }
      
      fullConfig['terminal_art_seen'] = _hasSeenTerminalArt;
      
      // Ensure 'claude' object exists
      if (!fullConfig.containsKey('claude') || fullConfig['claude'] is! Map) {
        // Preserve existing if it was not a map (unlikely) or create new
        fullConfig['claude'] = {};
      }

      // Update prompts under claude
      fullConfig['claude']['prompts'] = _prompts
          .map((e) => e.toJson())
          .toList();

      // Clean up legacy root field
      fullConfig.remove('prompts');
      
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(fullConfig));
    } catch (e) {
      print('Error saving prompts: $e');
    }
  }

  Future<void> addPrompt(ClaudePrompt prompt) async {
    _prompts.insert(0, prompt);
    if (prompt.isActive) {
      // If adding an already active one (unlikely but possible), deactivate others
      _deactivateothers(prompt.id);
      await _writeToClaudeFile(prompt.content);
    }
    await _savePrompts();
    notifyListeners();
  }

  Future<void> updatePrompt(ClaudePrompt prompt) async {
    final index = _prompts.indexWhere((p) => p.id == prompt.id);
    if (index != -1) {
      _prompts[index] = prompt;
      if (prompt.isActive) {
         _deactivateothers(prompt.id);
        await _writeToClaudeFile(prompt.content);
      } else {
        // If we turned it OFF, check if it was the one active
        // If so, clear file.
        // Logic: The toggle calls activatePrompt usually. 
        // But if updating title/content while active, we should re-write file.
        if (_didActiveChangeToInactive(index)) {
             await _writeToClaudeFile(''); // Clear
        } else if (prompt.isActive) { 
             // Updated content of active prompt
             await _writeToClaudeFile(prompt.content);
        }
      }
      _prompts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      await _savePrompts();
      notifyListeners();
    }
  }
  
  bool _didActiveChangeToInactive(int index) {
      // Logic requires prev state. 
      // For simplicity, UI handles toggle via specific method.
      return false; 
  }

  Future<void> deletePrompt(String id) async {
    final index = _prompts.indexWhere((p) => p.id == id);
    if (index == -1) return;

    // Rust logic: proper error if active. For now just return to prevent deletion.
    if (_prompts[index].isActive) {
      // Ideally throw error or notify user.
      // print("Cannot delete active prompt");
      return;
    }
    
    _prompts.removeAt(index);
    await _savePrompts();
    notifyListeners();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final index = _prompts.indexWhere((p) => p.id == id);
    if (index == -1) return;

    if (isActive) {
      // Backfill logic from Rust reference
      await _backfillContent();

      // Deactivate all others
      for (var i = 0; i < _prompts.length; i++) {
        if (_prompts[i].id != id && _prompts[i].isActive) {
          _prompts[i] = _prompts[i].copyWith(isActive: false);
        }
      }
      // Activate target
      _prompts[index] = _prompts[index].copyWith(isActive: true);
      await _writeToClaudeFile(_prompts[index].content);
    } else {
      // Deactivate target
      _prompts[index] = _prompts[index].copyWith(isActive: false);
      // Clear file
      await _writeToClaudeFile('');
    }

    await _savePrompts();
    notifyListeners();
  }

  Future<void> _backfillContent() async {
    try {
      final path = _claudeFilePath;
      final file = File(path);
      if (await file.exists()) {
        final liveContent = (await file.readAsString()).trim();
        if (liveContent.isNotEmpty) {
          // Try to find currently active prompt
          final activeIndex = _prompts.indexWhere((p) => p.isActive);

          if (activeIndex != -1) {
            // Update active prompt with live content
            log(
              'Backfilling live content to active prompt: ${_prompts[activeIndex].id}',
            );
            _prompts[activeIndex] = _prompts[activeIndex].copyWith(
              content: liveContent,
            );
            // Note: 'updatedAt' update is implicit in copyWith if I implemented it that way?
            // Checking model: copyWith updates updatedAt to DateTime.now(). Yes.
          } else {
            // No active prompt. Check if content exists to avoid duplicates.
            final contentExists = _prompts.any(
              (p) => p.content.trim() == liveContent,
            );

            if (!contentExists) {
              final now = DateTime.now();
              final timestamp = now.millisecondsSinceEpoch ~/ 1000;
              final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);

              final backupId = 'backup-$timestamp';
              final backupPrompt = ClaudePrompt(
                id: backupId,
                title: '原始提示词 $formattedDate',
                description: '自动备份的原始提示词',
                content: liveContent,
                isActive: false,
                updatedAt: now,
              );
              log('Backfilling live content, created backup: $backupId');
              _prompts.insert(0, backupPrompt);
            }
          }
        }
      }
    } catch (e) {
      print('Error backfilling content: $e');
    }
  }

  void _deactivateothers(String activeId) {
     for (var i = 0; i < _prompts.length; i++) {
        if (_prompts[i].id != activeId) {
          _prompts[i] = _prompts[i].copyWith(isActive: false);
        }
      }
  }

  Future<void> _writeToClaudeFile(String content) async {
    try {
      final path = _claudeFilePath;
      final file = File(path);
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true); // Should exist for Claude Code users but checking anyway
      }
      await file.writeAsString(content);
    } catch (e) {
      print('Error writing to CLAUDE.md: $e');
      throw e;
    }
  }

  Future<void> _syncFromClaudeFile() async {
    try {
      final path = _claudeFilePath;
      final file = File(path);
      if (await file.exists()) {
        final content = (await file.readAsString()).trim();
        if (content.isNotEmpty) {
          // Check if this content is already in our list (Active or Inactive)
          final existingIndex = _prompts.indexWhere(
            (p) => p.content.trim() == content,
          );

          if (existingIndex != -1) {
            // It exists. If it's not active, should we activate it?
            // Logic: If external file content matches an existing prompt, that prompt 'represents' the file.
            // We ensure it is marked active to reflect reality.
            if (!_prompts[existingIndex].isActive) {
              // Deactivate others
              _deactivateothers(_prompts[existingIndex].id);
              _prompts[existingIndex] = _prompts[existingIndex].copyWith(
                isActive: true,
              );
              await _savePrompts();
            }
            return;
          }

          // Content is new (not in config). Import it.
          final now = DateTime.now();
          final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
          final timestamp = now.millisecondsSinceEpoch ~/ 1000;

          final newPrompt = ClaudePrompt(
            id: 'import-$timestamp',
            title: 'Imported $formattedDate',
            description: '从 CLAUDE.md 自动同步',
            content: content,
            isActive: true,
            updatedAt: now,
          );
           
          // Deactivate others since this is the "Live" one
          _deactivateothers(newPrompt.id);
          
          _prompts.insert(0, newPrompt);
          await _savePrompts();
        }
      }
    } catch (e) {
      print('Error syncing CLAUDE.md: $e');
    }
  }
}
