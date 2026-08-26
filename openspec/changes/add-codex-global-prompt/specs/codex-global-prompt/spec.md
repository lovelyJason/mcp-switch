## ADDED Requirements

### Requirement: Codex global prompt access

The home Codex panel MUST show the same prompt icon and prompt management interaction as Claude.

#### Scenario: Open Codex global prompt manager

- Given Codex is the selected editor
- When the user clicks the prompt icon
- Then the app opens the prompt manager for Codex instructions

### Requirement: Codex prompt file

The active Codex global prompt MUST be synchronized with `~/.codex/AGENTS.md`.

#### Scenario: Save active Codex prompt

- Given a Codex prompt is activated
- When the prompt is saved
- Then its content is written to `~/.codex/AGENTS.md`

#### Scenario: Import existing Codex instructions

- Given `~/.codex/AGENTS.md` exists with content
- When the Codex prompt manager initializes
- Then the existing content is available for editing without modifying Claude's prompt file
