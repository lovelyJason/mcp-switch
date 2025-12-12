enum EditorType {
  cursor,
  windsurf,
  claude,
  codex,
  antigravity,
  gemini; // Added for completeness given the icon in screenshot might be related

  String get label {
    switch (this) {
      case EditorType.cursor:
        return 'Cursor';
      case EditorType.windsurf:
        return 'Windsurf';
      case EditorType.claude:
        return 'Claude';
      case EditorType.codex:
        return 'Codex';
      case EditorType.antigravity:
        return 'Antigravity';
      case EditorType.gemini: 
        return 'Gemini';
    }
  }

  // Helper to get import 'package:path_provider/path_provider.dart';ed later)
  String get iconPath => 'assets/icons/${name}.svg';

}
