#!/usr/bin/env bash
# Lint a JS/TS file via eslint; type-check the project via tsc when applicable.
# Skips silently when the relevant binary isn't locally installed — a fresh
# worktree without `pnpm install` should not produce false-positive failures.
set -u
_DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$_DIR/../lib.sh}"

# Walk up from $1 looking for node_modules/.bin/$2. Echoes the absolute path on
# hit, returns 1 on miss. Stops at filesystem root.
find_node_bin() {
  local d bin="$2" candidate
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    candidate="$d/node_modules/.bin/$bin"
    [ -x "$candidate" ] && { echo "$candidate"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

f="$1"
root="$(harness_project_root "$f")" || exit 0
[ -f "$root/package.json" ] || exit 0

if grep -q '"eslint"' "$root/package.json" 2>/dev/null; then
  if eslint_bin="$(find_node_bin "$root" eslint)"; then
    (cd "$root" && harness_run lint:eslint "$eslint_bin" "$f")
  fi
fi

case "$f" in
  *.ts|*.tsx)
    if [ -f "$root/tsconfig.json" ]; then
      if tsc_bin="$(find_node_bin "$root" tsc)"; then
        (cd "$root" && harness_run type:tsc "$tsc_bin" --noEmit)
      fi
    fi
    ;;
esac
