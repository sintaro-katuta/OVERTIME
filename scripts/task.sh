#!/usr/bin/env bash
# File-based task board for OVERTIME. Requires only Bash, Python 3, and Git (for worktrees).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$ROOT_DIR/scripts/task_board.py" "$@"
