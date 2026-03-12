enum EditorType {
  cursor,
  windsurf,
  claude,
  codex,
  antigravity,
  gemini,
  kiro;

  String get label {
    switch (this) {
      case EditorType.claude:
        return 'Claude Code';
      case EditorType.codex:
        return 'Codex';
      case EditorType.cursor:
        return 'Cursor';
      case EditorType.windsurf:
        return 'Windsurf';
      case EditorType.antigravity:
        return 'Antigravity';
      case EditorType.gemini:
        return 'Gemini';
      case EditorType.kiro:
        return 'Kiro';
    }
  }

  String get iconPath => 'assets/icons/editors/${this == codex ? "chatgpt" : name}.svg';

}
