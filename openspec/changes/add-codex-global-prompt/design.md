# Design

## Prompt storage

Add a Codex-specific prompt service that reuses the existing prompt model and application-level prompt list storage, while using `~/.codex/AGENTS.md` as the live file. File I/O remains in the service layer.

## UI

Add the same lightbulb prompt icon to the Codex home action group. The prompt screen receives an editor type and selects the corresponding service/file path; Claude continues using `~/.claude/CLAUDE.md`.

## Synchronization

Activating a prompt writes its content to the Codex global file and deactivating it clears the file. On initialization, existing file content is imported into the prompt list using the same backfill behavior as Claude.
