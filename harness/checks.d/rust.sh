#!/usr/bin/env bash
# Type-check a Rust crate without producing artifacts.
set -u
source "${HARNESS_LIB:-$HOME/.claude/harness/lib.sh}"
f="$1"
root="$(harness_project_root "$f")" || exit 0
command -v cargo >/dev/null 2>&1 || exit 0
(cd "$root" && harness_run check:cargo cargo check --quiet)
