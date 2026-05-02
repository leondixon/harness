#!/usr/bin/env bash
# Smoke test for the harness. Covers dispatchers and modules.
set -e
cd "$(dirname "$0")"
H="$(cd .. && pwd)"
STATE="${CLAUDE_HARNESS_STATE:-$HOME/.claude/state}"

pass() { printf '  \e[32m✓\e[0m %s\n' "$1"; }
fail() { printf '  \e[31m✗\e[0m %s\n' "$1"; exit 1; }

echo "==> context.d/git.sh"
"$H/context.d/git.sh" | grep -q 'harness:git' && pass "git module emits context" || fail "no git context"

echo "==> 01-context.sh dispatcher"
echo '{}' | "$H/01-context.sh" | grep -q 'harness:git' && pass "dispatcher runs git module" || fail "dispatcher broken"

echo "==> 02-checks.sh (clean python)"
tmp="$(mktemp --suffix=.py)"; printf 'x = 1\n' > "$tmp"
err="$(echo "{\"tool_input\":{\"file_path\":\"$tmp\"}}" | "$H/02-checks.sh" 2>&1 >/dev/null || true)"
[ -z "$err" ] && pass "clean python file → no error" || fail "unexpected: $err"
rm -f "$tmp"

echo "==> 02-checks.sh (state cleared)"
[ ! -s "$STATE/last-errors.log" ] && pass "no error log on clean run" || fail "stale log"

echo "==> 02-checks.sh (failure persists state)"
if command -v ruff >/dev/null 2>&1; then
  proj="$(mktemp -d)"; touch "$proj/pyproject.toml"
  bad="$proj/bad.py"; printf 'import os\n' > "$bad"
  echo "{\"tool_input\":{\"file_path\":\"$bad\"}}" | "$H/02-checks.sh" 2>/dev/null >/dev/null || true
  [ -s "$STATE/last-errors.log" ] && pass "lint failure recorded" || fail "lint failure missing"
  rm -rf "$proj"; rm -f "$STATE/last-errors.log"
else
  pass "ruff absent — skipped"
fi

echo "==> context.d/errors.sh replay"
printf '[checks:demo] FAIL\nboom\n' > "$STATE/last-errors.log"
echo '{}' | "$H/01-context.sh" | grep -q 'harness:last-errors' && pass "errors replayed" || fail "no replay"
rm -f "$STATE/last-errors.log"

echo "==> verify.d/secrets.sh"
"$H/verify.d/secrets.sh" >/dev/null 2>&1 && pass "secrets module exits 0" || fail "secrets non-zero"

echo "==> 03-verify.sh dispatcher"
"$H/03-verify.sh" < /dev/null && pass "dispatcher exits 0" || fail "dispatcher non-zero"

echo
echo "All hooks healthy."
