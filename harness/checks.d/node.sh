#!/usr/bin/env bash
# Lint a JS/TS file via eslint; type-check the project via tsc when applicable.
set -u
_DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$_DIR/../lib.sh}"
f="$1"
root="$(harness_project_root "$f")" || exit 0
[ -f "$root/package.json" ] || exit 0
command -v npx >/dev/null 2>&1 || exit 0
grep -q '"eslint"' "$root/package.json" 2>/dev/null && \
  (cd "$root" && harness_run lint:eslint npx --no-install eslint "$f")
case "$f" in
  *.ts|*.tsx)
    [ -f "$root/tsconfig.json" ] && \
      (cd "$root" && harness_run type:tsc npx --no-install tsc --noEmit) ;;
esac
