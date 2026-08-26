import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/prompt_service.dart';
import 'claude_prompts_screen.dart';

class CodexPromptsScreen extends StatelessWidget {
  const CodexPromptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<CodexPromptService>();
    return ChangeNotifierProvider<PromptService>.value(
      value: service,
      child: ClaudePromptsScreen(
        titleKey: 'codex_prompt_title',
        promptService: service,
      ),
    );
  }
}
