import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_switch/models/claude_prompt.dart';
import 'package:mcp_switch/models/editor_type.dart';
import 'package:mcp_switch/services/prompt_service.dart';

void main() {
  late Directory home;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('mcp-switch-prompt-');
  });

  tearDown(() async {
    if (await home.exists()) await home.delete(recursive: true);
  });

  test('imports Codex global instructions from AGENTS.md', () async {
    final file = File('${home.path}/.codex/AGENTS.md')
      ..parent.createSync(recursive: true);
    await file.writeAsString('Use concise answers.');

    final service = CodexPromptServiceWithHome(home.path);
    await service.init();

    expect(service.prompts, hasLength(1));
    expect(service.prompts.single.content, 'Use concise answers.');
    expect(service.prompts.single.isActive, isTrue);
    expect(service.prompts.single.description, '从 AGENTS.md 自动同步');
  });

  test(
    'activating and deactivating a Codex prompt updates AGENTS.md',
    () async {
      final service = CodexPromptServiceWithHome(home.path);
      await service.init();
      await service.addPrompt(
        ClaudePrompt(
          id: 'codex-test',
          title: 'Test instructions',
          content: 'Prefer direct answers.',
          isActive: false,
          updatedAt: DateTime.now(),
        ),
      );

      await service.toggleActive('codex-test', true);
      final file = File('${home.path}/.codex/AGENTS.md');
      expect(await file.readAsString(), 'Prefer direct answers.');

      await service.toggleActive('codex-test', false);
      expect(await file.readAsString(), isEmpty);
    },
  );

  test(
    'saving through the Claude service does not add to Codex prompts',
    () async {
      final claude = PromptService(homeDirectory: home.path);
      final codex = CodexPromptServiceWithHome(home.path);
      await claude.init();
      await codex.init();

      await claude.addPrompt(
        ClaudePrompt(
          id: 'claude-only',
          title: 'Claude only',
          content: 'Claude instructions',
          updatedAt: DateTime.now(),
        ),
      );

      expect(claude.prompts, hasLength(1));
      expect(codex.prompts, isEmpty);
    },
  );
}

class CodexPromptServiceWithHome extends PromptService {
  CodexPromptServiceWithHome(String home)
    : super(editorType: EditorType.codex, homeDirectory: home);
}
