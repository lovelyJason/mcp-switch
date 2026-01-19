# Ralph - Autonomous Agent Harness

Ralph is a local autonomous agent harness for running Claude Code tasks in the background.

## Overview

Ralph allows you to queue up development tasks and have Claude execute them autonomously, perfect for:
- Overnight batch processing
- Background task execution
- Unattended development work

## Directory Structure

```
scripts/ralph/
├── README.md           # This file
├── run.sh              # Main runner script
├── config.yaml         # Configuration
├── tasks/              # Task queue directory
│   ├── pending/        # Tasks waiting to run
│   ├── running/        # Currently executing task
│   └── completed/      # Finished tasks
└── logs/               # Execution logs
```

## Usage

### 1. Add a task

Create a markdown file in `tasks/pending/` with your task description:

```bash
echo "Refactor the login component to use the new auth service" > tasks/pending/001-refactor-login.md
```

### 2. Run Ralph

```bash
./scripts/ralph/run.sh
```

Ralph will:
1. Pick up the oldest task from `pending/`
2. Move it to `running/`
3. Execute it with Claude Code
4. Move it to `completed/` when done
5. Repeat until no tasks remain

### 3. Check logs

```bash
tail -f scripts/ralph/logs/ralph.log
```

## Configuration

Edit `config.yaml` to customize:

```yaml
# Maximum tasks to run in one session
max_tasks: 10

# Delay between tasks (seconds)
task_delay: 5

# Auto-commit changes after each task
auto_commit: false

# Model to use
model: opus
```

## Safety

- Ralph runs in a sandboxed mode by default
- Each task is logged for review
- You can set `auto_commit: false` to review changes before committing

## Integration with flow-next

Ralph works best with flow-next workflow:

1. Use `/flow-next:plan` to create a plan
2. Break the plan into individual task files
3. Queue them in `tasks/pending/`
4. Let Ralph execute overnight
5. Review results in the morning
