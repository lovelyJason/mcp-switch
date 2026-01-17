# OpenSpec Agent Instructions

This document defines how AI assistants should work with OpenSpec in this project.

## What is OpenSpec?

OpenSpec is a spec-driven development workflow that helps you:
1. **Plan changes thoroughly** before writing code
2. **Document requirements** in a structured, testable format
3. **Track implementation progress** with clear task lists
4. **Archive completed work** as living documentation

## Directory Structure

```
openspec/
├── AGENTS.md           # This file - AI assistant instructions
├── project.md          # Project context, tech stack, conventions
├── specs/              # Living specification documents
│   └── <capability>/
│       └── spec.md     # Requirements for a capability
└── changes/            # Change proposals (in progress or archived)
    └── <change-id>/
        ├── proposal.md # Change overview and rationale
        ├── tasks.md    # Ordered implementation tasks
        ├── design.md   # (Optional) Architecture decisions
        └── specs/      # Spec deltas (additions/modifications)
            └── <capability>/
                └── spec.md
```

## Workflow Overview

### 1. Proposal Stage (`/openspec:proposal`)

When the user wants to add a feature or make a significant change:

1. **Understand the request** - Ask clarifying questions if ambiguous
2. **Research the codebase** - Use `rg`, `ls`, file reads to understand current state
3. **Choose a change-id** - Verb-led identifier (e.g., `add-profile-switching`, `fix-tray-icon`)
4. **Create proposal files**:
   - `proposal.md` - What, why, scope, impact
   - `tasks.md` - Ordered implementation steps
   - `design.md` - (If architectural decisions needed)
   - `specs/<capability>/spec.md` - Requirement deltas

**IMPORTANT**: Do NOT write implementation code during proposal. Only create design documents.

### 2. Apply Stage (`/openspec:apply`)

After the user approves a proposal:

1. **Read the approved proposal** - Load tasks.md and spec deltas
2. **Implement incrementally** - Follow tasks.md order
3. **Update tasks** - Mark completed, note blockers
4. **Validate as you go** - Run tests, check requirements

### 3. Archive Stage (`/openspec:archive`)

After implementation is complete and validated:

1. **Merge spec deltas** - Apply changes to main `specs/` directory
2. **Archive the change** - Move to `changes/<id>/archived/` or mark as complete
3. **Update project.md** - If conventions or structure changed

## Spec Format

Requirements use a structured format:

```markdown
## ADDED Requirements

### Requirement: <Short descriptive name>
<Detailed description of the requirement>

#### Scenario: <Test case name>
- Given: <Initial state>
- When: <Action taken>
- Then: <Expected outcome>

## MODIFIED Requirements

### Requirement: <Existing requirement name>
<Updated description>

## REMOVED Requirements

### Requirement: <Requirement being removed>
<Reason for removal>
```

## Task Format

Tasks in `tasks.md` should be:

```markdown
# Tasks for <change-id>

## Phase 1: <Phase name>

- [ ] **Task 1**: Description
  - Details or sub-steps
  - Validation criteria
- [ ] **Task 2**: Description
  - Depends on: Task 1

## Phase 2: <Phase name>

- [ ] **Task 3**: Description (can run parallel with Task 2)
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `openspec list` | List all changes |
| `openspec list --specs` | List all specs |
| `openspec validate <id>` | Validate a change proposal |
| `openspec validate <id> --strict` | Strict validation (required before approval) |
| `openspec show <id>` | Show change details |
| `openspec show <spec> --type spec` | Show spec details |

## Best Practices

1. **Keep changes focused** - One logical change per proposal
2. **Break down large features** - Multiple proposals if needed
3. **Include scenarios** - Every requirement needs at least one testable scenario
4. **Reference existing specs** - Use `rg "Requirement:" openspec/specs` to find related work
5. **Validate early** - Run `openspec validate --strict` before asking for approval

## Project-Specific Notes

For MCP Switch:

- **Editor configs** are defined in `lib/models/editor_type.dart`
- **Service layer** handles all file I/O - specs should reference services, not direct file ops
- **Localization** - New user-facing text requires entries in both `en.json` and `zh.json`
- **macOS-specific** - Consider tray integration and window management for UX changes
