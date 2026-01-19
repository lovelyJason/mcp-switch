#!/bin/bash
# =============================================================================
# Ralph - Autonomous Agent Runner
# =============================================================================
# Usage: ./scripts/ralph/run.sh [options]
#
# Options:
#   --dry-run     Don't execute tasks, just show what would run
#   --single      Run only one task then exit
#   --verbose     Enable verbose logging
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASKS_DIR="$SCRIPT_DIR/tasks"
LOGS_DIR="$SCRIPT_DIR/logs"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
SINGLE_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --single)
            SINGLE_MODE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Ensure directories exist
mkdir -p "$TASKS_DIR/pending"
mkdir -p "$TASKS_DIR/running"
mkdir -p "$TASKS_DIR/completed"
mkdir -p "$TASKS_DIR/failed"
mkdir -p "$LOGS_DIR"

# Log file
LOG_FILE="$LOGS_DIR/ralph-$(date +%Y%m%d-%H%M%S).log"

log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "${BLUE}$1${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$1${NC}"
}

log_warn() {
    log "WARN" "${YELLOW}$1${NC}"
}

log_error() {
    log "ERROR" "${RED}$1${NC}"
}

# Check if Claude CLI is available
check_claude() {
    if ! command -v claude &> /dev/null; then
        log_error "Claude CLI not found. Please install it first."
        exit 1
    fi
    log_info "Claude CLI found: $(which claude)"
}

# Get next pending task
get_next_task() {
    local task=$(ls -1t "$TASKS_DIR/pending"/*.md 2>/dev/null | head -n 1)
    echo "$task"
}

# Run a single task
run_task() {
    local task_file=$1
    local task_name=$(basename "$task_file")

    log_info "Starting task: $task_name"

    # Move to running
    mv "$task_file" "$TASKS_DIR/running/"
    local running_file="$TASKS_DIR/running/$task_name"

    # Read task content
    local task_content=$(cat "$running_file")

    if [ "$DRY_RUN" = true ]; then
        log_warn "[DRY RUN] Would execute task:"
        echo "$task_content"
        mv "$running_file" "$TASKS_DIR/completed/"
        return 0
    fi

    # Execute with Claude
    log_info "Executing with Claude CLI..."

    cd "$PROJECT_ROOT"

    if claude -p "$task_content" >> "$LOG_FILE" 2>&1; then
        log_success "Task completed: $task_name"
        mv "$running_file" "$TASKS_DIR/completed/"
        return 0
    else
        log_error "Task failed: $task_name"
        mv "$running_file" "$TASKS_DIR/failed/"
        return 1
    fi
}

# Main loop
main() {
    log_info "=== Ralph Autonomous Agent Starting ==="
    log_info "Project: $PROJECT_ROOT"
    log_info "Tasks directory: $TASKS_DIR"
    log_info "Log file: $LOG_FILE"

    check_claude

    local task_count=0
    local max_tasks=10  # TODO: Read from config

    while true; do
        local next_task=$(get_next_task)

        if [ -z "$next_task" ]; then
            log_info "No more pending tasks. Ralph is done."
            break
        fi

        task_count=$((task_count + 1))
        log_info "Processing task $task_count..."

        run_task "$next_task"

        if [ "$SINGLE_MODE" = true ]; then
            log_info "Single mode: exiting after one task."
            break
        fi

        if [ $task_count -ge $max_tasks ]; then
            log_warn "Reached max tasks limit ($max_tasks). Stopping."
            break
        fi

        # Delay between tasks
        log_info "Waiting 5 seconds before next task..."
        sleep 5
    done

    log_info "=== Ralph Session Complete ==="
    log_info "Tasks processed: $task_count"
    log_info "Pending: $(ls -1 "$TASKS_DIR/pending"/*.md 2>/dev/null | wc -l | tr -d ' ')"
    log_info "Completed: $(ls -1 "$TASKS_DIR/completed"/*.md 2>/dev/null | wc -l | tr -d ' ')"
    log_info "Failed: $(ls -1 "$TASKS_DIR/failed"/*.md 2>/dev/null | wc -l | tr -d ' ')"
}

main "$@"
