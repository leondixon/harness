#!/usr/bin/env bash
# Analyze a Dart file (covers lint + type errors).
set -u
source "${HARNESS_LIB:-$HOME/.claude/harness/lib.sh}"
f="$1"
root="$(harness_project_root "$f")" || exit 0
command -v dart >/dev/null 2>&1 || exit 0
(cd "$root" && harness_run analyze:dart dart analyze "$f")
