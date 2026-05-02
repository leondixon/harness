#!/usr/bin/env bash
# Type-check a Rust crate without producing artifacts.
set -u
_DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$_DIR/../lib.sh}"
f="$1"
root="$(harness_project_root "$f")" || exit 0
command -v cargo >/dev/null 2>&1 || exit 0
(cd "$root" && harness_run check:cargo cargo check --quiet)
