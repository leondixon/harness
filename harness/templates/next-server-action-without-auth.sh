#!/usr/bin/env bash
# Fitness: surface server actions (`'use server'`) with exported handlers but
# no recognisable auth check. Server actions are public RPC endpoints — treat
# them like API routes and re-check the session inside the action
# (docs/best-practices.md § Next.js 16.2 "Server action without a fresh auth
# check").
#
# ADVISORY — some actions are intentionally public (signup, password reset
# initiation). The agent should review and either add the auth check, or
# accept the action as a deliberate public endpoint.
#
# Recognised auth helpers (allow-list): getSession, requireAuth, requireSession,
# requireFreshSession, auth.api.*. Extend the list when new helpers ship.
#
# Operates on changed files only.
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

files="$(
  { git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null
    git diff --name-only --cached --diff-filter=ACMR 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | sort -u
)"
[ -z "$files" ] && exit 0

candidates="$(printf '%s\n' "$files" \
  | grep -E '\.tsx?$' \
  | grep -Ev '(^|/)(generated|dist|node_modules|\.next)/' \
  | grep -Ev '\.(test|spec)\.(ts|tsx)$')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head -3 "$f" | grep -Eq "^[[:space:]]*['\"]use server['\"]" || continue
  grep -qE '^[[:space:]]*export[[:space:]]+async[[:space:]]+function[[:space:]]' "$f" || continue
  grep -qE '(getSession|requireAuth|requireSession|requireFreshSession|auth\.api\.)' "$f" && continue
  lines="$(grep -nE '^[[:space:]]*export[[:space:]]+async[[:space:]]+function[[:space:]]' "$f" | head -n 3 | sed "s|^|$f:|")"
  hits+="$lines"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "ADVISORY — server action without an auth check:"
  echo "Server actions are public RPC endpoints. Re-check the session inside"
  echo "the action (auth.api.getSession / requireAuth / requireSession), or"
  echo "confirm the action is intentionally public"
  echo "(docs/best-practices.md § Next.js 16.2)."
  echo ""
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
