#!/usr/bin/env bash
# Fitness: surface server-side `fetch(...)` calls in Next apps with no options
# argument. Next 16 changed the default — fetch is NOT cached unless you opt
# in. A bare `fetch(url)` from a server component is a silent cache miss every
# render (docs/best-practices.md § Next.js 16.2 "Assuming `fetch` is cached by
# default in Next 16").
#
# ADVISORY — uncached is sometimes correct (mutations, third-party APIs you
# don't want to cache). The agent should confirm intent on the next turn,
# either accepting the no-cache default or adding `{ next: { revalidate } }`
# / `{ cache: 'force-cache' }`.
#
# Scope: .ts/.tsx in apps/web-*/ that don't open with 'use client'.
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
  | grep -E '^apps/web-[^/]+/.+\.tsx?$' \
  | grep -Ev '(^|/)(generated|dist|node_modules|\.next)/')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head -3 "$f" | grep -Eq "^[[:space:]]*['\"]use client['\"]" && continue

  out="$(grep -nE 'fetch[[:space:]]*\([^,)]*\)' "$f" | sed "s|^|$f:|")"
  [ -n "$out" ] && hits+="$out"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "ADVISORY — server-side \`fetch(...)\` with no options in a Next 16 app:"
  echo "Next 16 doesn't cache fetch by default. Confirm uncached is intended,"
  echo "or pass \`{ next: { revalidate } }\` / \`{ cache: 'force-cache' }\`"
  echo "(docs/best-practices.md § Next.js 16.2)."
  echo ""
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
