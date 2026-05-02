#!/usr/bin/env bash
# Vet a Go file's package.
set -u
_DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$_DIR/../lib.sh}"
f="$1"
root="$(harness_project_root "$f")" || exit 0
command -v go >/dev/null 2>&1 || exit 0
(cd "$root" && harness_run vet:go go vet ./...)
