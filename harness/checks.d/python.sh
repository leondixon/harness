#!/usr/bin/env bash
# Lint + type-check a Python file.
set -u
source "${HARNESS_LIB:-$HOME/.claude/harness/lib.sh}"
f="$1"
root="$(harness_project_root "$f")" || exit 0
command -v ruff >/dev/null 2>&1 && (cd "$root" && harness_run lint:ruff ruff check "$f")
if command -v mypy >/dev/null 2>&1 && [ -f "$root/pyproject.toml" ] && \
   grep -q '\[tool.mypy\]\|^mypy' "$root/pyproject.toml" 2>/dev/null; then
  (cd "$root" && harness_run type:mypy mypy --no-error-summary "$f")
fi
