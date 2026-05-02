#!/usr/bin/env bash
# Dimension: behaviour
# Run project tests with a 60s cap. Disable with `touch ~/.claude/state/skip-tests`.
set -u
_DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$_DIR/../lib.sh}"
STATE="$(harness_state_dir)"
[ -f "$STATE/skip-tests" ] && { echo "[verify:tests] skipped (skip-tests flag)" >&2; exit 0; }
command -v timeout >/dev/null 2>&1 || { echo "[verify:tests] no timeout(1); skipping" >&2; exit 0; }

cmd=""
if   [ -f "go.mod" ];        then cmd="go test -count=1 -short ./..."
elif [ -f "Cargo.toml" ];    then cmd="cargo test --quiet"
elif [ -f "pubspec.yaml" ] && command -v dart >/dev/null 2>&1; then cmd="dart test"
elif [ -f "pyproject.toml" ] && command -v pytest >/dev/null 2>&1; then cmd="pytest -q --no-header"
elif [ -f "package.json" ]   && grep -q '"test"' package.json 2>/dev/null; then cmd="npm test --silent"
fi
[ -z "$cmd" ] && exit 0

LOG="$STATE/last-tests.log"
out="$(timeout 60 sh -c "$cmd" 2>&1)"; rc=$?
printf '%s\n' "$out" > "$LOG"
case $rc in
  0)   echo "[verify:tests] pass ($cmd)" >&2 ;;
  124) echo "[verify:tests] TIMEOUT after 60s ($cmd) — see $LOG" >&2
       printf '[verify:tests] timeout running %s\n' "$cmd" >> "$HARNESS_ERR_LOG" ;;
  *)   echo "[verify:tests] FAIL ($cmd) — tail of output:" >&2
       printf '%s\n' "$out" | tail -n 20 >&2
       { printf '[verify:tests] FAIL: %s\n' "$cmd"; printf '%s\n' "$out" | tail -n 20; } >> "$HARNESS_ERR_LOG" ;;
esac
exit 0
