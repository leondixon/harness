#!/usr/bin/env bash
# Fitness: surface files with multiple `useOptimistic` calls for review.
# Two `useOptimistic` calls for related fields (isFollowing / followerCount,
# count / totalCount, etc.) can fall out of sync if one update fails. Prefer
# a single optimistic state object with one reducer (docs/best-practices.md
# § React 19.2 "useOptimistic with separate setters for related fields").
#
# ADVISORY — the check can't tell if the two calls are for related state or
# truly independent state. Multiple useOptimistic calls in separate components
# in the same file are also fine. The agent should review and confirm intent
# on the next turn.
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
  /\.tsx?$/ && !/(^|\/)(generated|dist|node_modules|\.next)\//
')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  count="$(grep -c "useOptimistic[[:space:]]*(" "$f" 2>/dev/null || echo 0)"
  [ "$count" -lt 2 ] && continue
  lines="$(grep -n "useOptimistic[[:space:]]*(" "$f" | head -n 5 | sed "s|^|$f:|")"
  hits+="$lines"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "ADVISORY — multiple \`useOptimistic\` calls in one file:"
  echo "If these track related state, merge into one optimistic state object"
  echo "with a single reducer to avoid drift on partial failure"
  echo "(docs/best-practices.md § React 19.2). If they're in separate components"
  echo "or for genuinely independent state, this is fine."
  echo ""
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
