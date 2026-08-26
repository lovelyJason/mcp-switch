# Add Codex global prompt

## Why

The home Codex panel currently exposes skills and provider controls but no editor for Codex's global instructions. Users need the same quick prompt access available for Claude.

## Scope

- Add the existing prompt icon and navigation action to the Codex home action group.
- Reuse the Claude prompt editor interaction for creating, editing, activating, and deleting prompt entries.
- Synchronize the active Codex prompt with `~/.codex/AGENTS.md`.
- Keep Claude prompt storage and behavior unchanged.

## Non-goals

- Changing Codex provider configuration or skills.
- Supporting project-local `AGENTS.md` files.
- Adding another database table for prompt content.
