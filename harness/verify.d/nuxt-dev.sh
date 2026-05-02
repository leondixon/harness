#!/usr/bin/env bash
# Dimension: behaviour
# If nuxt.config.ts is present, boot `pnpm dev` and confirm the dev server
# becomes ready, then tear it down. Disable with `touch ~/.claude/state/skip-nuxt-dev`.
set -u
_DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$_DIR/../lib.sh}"
STATE="$(harness_state_dir)"
[ -f "$STATE/skip-nuxt-dev" ] && { echo "[verify:nuxt-dev] skipped (skip-nuxt-dev flag)" >&2; exit 0; }
[ -f "nuxt.config.ts" ] || exit 0
command -v pnpm >/dev/null 2>&1 || { echo "[verify:nuxt-dev] pnpm not found; skipping" >&2; exit 0; }
command -v setsid >/dev/null 2>&1 || { echo "[verify:nuxt-dev] setsid(1) not found; skipping" >&2; exit 0; }

WAIT="${NUXT_DEV_WAIT_SECS:-60}"
LOG="$STATE/last-nuxt-dev.log"
: > "$LOG"

setsid pnpm dev >"$LOG" 2>&1 < /dev/null &
pid=$!

ready=0
for _ in $(seq 1 "$WAIT"); do
  kill -0 "$pid" 2>/dev/null || break
  if grep -qE 'Local: +https?://|Nuxt .* ready|Listening on https?://' "$LOG" 2>/dev/null; then
    ready=1; break
  fi
  sleep 1
done

if kill -0 "$pid" 2>/dev/null; then
  kill -TERM "-$pid" 2>/dev/null || true
  sleep 1
  kill -KILL "-$pid" 2>/dev/null || true
fi
wait "$pid" 2>/dev/null || true

if [ "$ready" = 1 ]; then
  echo "[verify:nuxt-dev] pass (pnpm dev ready within ${WAIT}s)" >&2
else
  echo "[verify:nuxt-dev] FAIL (pnpm dev did not signal ready in ${WAIT}s) — tail of $LOG:" >&2
  tail -n 20 "$LOG" >&2
  { printf '[verify:nuxt-dev] FAIL: pnpm dev did not become ready in %ss\n' "$WAIT"; tail -n 20 "$LOG"; } >> "$HARNESS_ERR_LOG"
fi
exit 0
