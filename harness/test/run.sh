#!/usr/bin/env bash
# Smoke test for the harness. Covers dispatchers and modules.
# Creates a temp git repo with .harness/ vendored so dispatcher tests
# exercise the harness as installed in the repo.
set -e
cd "$(dirname "$0")"
H="$(cd .. && pwd)"
STATE="${CLAUDE_HARNESS_STATE:-$HOME/.claude/state}"
mkdir -p "$STATE"

pass() { printf '  \e[32m✓\e[0m %s\n' "$1"; }
fail() { printf '  \e[31m✗\e[0m %s\n' "$1"; exit 1; }

# Temp git repo with .harness/ for dispatcher tests
TDIR="$(mktemp -d)"
trap 'rm -rf "$TDIR"' EXIT
(cd "$TDIR" && git init -q)
cp -r "$H/." "$TDIR/.harness/"
chmod +x "$TDIR/.harness/"*.sh \
         "$TDIR/.harness/checks.d/"*.sh \
         "$TDIR/.harness/verify.d/"*.sh \
         "$TDIR/.harness/context.d/"*.sh \
         "$TDIR/.harness/test/run.sh" 2>/dev/null || true

echo "==> context.d/git.sh"
(cd "$TDIR" && "$H/context.d/git.sh") | grep -q 'harness:git' && pass "git module emits context" || fail "no git context"

echo "==> 01-context.sh dispatcher"
(cd "$TDIR" && echo '{}' | "$H/01-context.sh") | grep -q 'harness:git' && pass "dispatcher runs git module" || fail "dispatcher broken"

echo "==> 02-checks.sh (clean python)"
tmp="$TDIR/test_clean.py"; printf 'x = 1\n' > "$tmp"
err="$(cd "$TDIR" && echo "{\"tool_input\":{\"file_path\":\"$tmp\"}}" | "$H/02-checks.sh" 2>&1 >/dev/null || true)"
[ -z "$err" ] && pass "clean python file → no error" || fail "unexpected: $err"

echo "==> 02-checks.sh (state cleared)"
[ ! -s "$STATE/last-errors.log" ] && pass "no error log on clean run" || fail "stale log"

echo "==> 02-checks.sh (failure persists state)"
if command -v ruff >/dev/null 2>&1; then
  touch "$TDIR/pyproject.toml"
  bad="$TDIR/bad.py"; printf 'import os\n' > "$bad"
  (cd "$TDIR" && echo "{\"tool_input\":{\"file_path\":\"$bad\"}}" | "$H/02-checks.sh" 2>/dev/null >/dev/null || true)
  [ -s "$STATE/last-errors.log" ] && pass "lint failure recorded" || fail "lint failure missing"
  rm -f "$STATE/last-errors.log"
else
  pass "ruff absent — skipped"
fi

echo "==> context.d/errors.sh replay"
printf '[checks:demo] FAIL\nboom\n' > "$STATE/last-errors.log"
(cd "$TDIR" && echo '{}' | "$H/01-context.sh") | grep -q 'harness:last-errors' && pass "errors replayed" || fail "no replay"
rm -f "$STATE/last-errors.log"

echo "==> verify.d/secrets.sh"
(cd "$TDIR" && "$H/verify.d/secrets.sh" >/dev/null 2>&1) && pass "secrets module exits 0" || fail "secrets non-zero"

echo "==> 03-verify.sh dispatcher"
(cd "$TDIR" && "$H/03-verify.sh" < /dev/null) && pass "dispatcher exits 0" || fail "dispatcher non-zero"

echo "==> dispatcher exits 0 outside project (no .harness/)"
NODIR="$(mktemp -d)"
trap 'rm -rf "$TDIR" "$NODIR"' EXIT
(cd "$NODIR" && git init -q && echo '{}' | "$H/01-context.sh" >/dev/null) && pass "no .harness/ → silent exit 0" || fail "unexpected failure outside project"

echo
echo "All hooks healthy."
