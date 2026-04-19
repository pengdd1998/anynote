#!/usr/bin/env bash
# AnyNote — Headless state checkpoint
# Usage: ./scripts/save-state.sh
# Runs Claude in headless mode to update all project documentation.
# Can be scheduled via cron for periodic checkpoints.

set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "[checkpoint] Saving project state at $(date -Iseconds)"

claude -p \
  "Run the /save-state skill: review the project, update work log, development plan, and memory file with current progress. Be concise but thorough." \
  --allowedTools "Edit,Read,Write,Bash(git*),Bash(ls*),Bash(cat*),Bash(wc*)" \
  --cwd "$PROJECT_DIR"

echo "[checkpoint] Done at $(date -Iseconds)"
