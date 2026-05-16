#!/usr/bin/env bash
# Fitness: forbid `'use client'` as a leading directive in a root layout.
# Marking the root layout client pushes the whole tree into the client bundle
# and disables server data fetching downstream. Keep the layout server; wrap
# only the provider in a client component (docs/best-practices.md § Next.js
# 16.2 "'use client' on the root layout").
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

candidates="$(printf '%s\n' "$files" | awk '
  /(^|\/)app\/layout\.tsx$/
')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head -3 "$f" | grep -Eq "^[[:space:]]*['\"]use client['\"]" || continue
  hits+="$f"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "'use client' on a root layout is forbidden — keep the root layout"
  echo "server and wrap only the provider in a client component"
  echo "(docs/best-practices.md § Next.js 16.2):"
  echo ""
  printf '%s' "$hits"
} >&2
exit 1
