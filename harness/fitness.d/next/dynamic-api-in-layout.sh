#!/usr/bin/env bash
# Fitness: surface `headers()` / `cookies()` calls inside any layout.tsx.
# Calling a dynamic API at the layout root forces the whole subtree dynamic
# and breaks `loading.tsx` streaming. Push the dynamic API usage down to the
# leaf page, or wrap the consumer in `<Suspense>` (docs/best-practices.md §
# Next.js 16.2 "Dynamic APIs (headers, cookies) at the layout root").
#
# ADVISORY — a layout can legitimately call these inside an explicit
# `<Suspense>` boundary. Grep can't tell. The agent should confirm intent on
# the next turn, either accepting the wrap or moving the call to a leaf page.
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
  | grep -E '(^|/)layout\.tsx$' \
  | grep -Ev '(^|/)(generated|dist|node_modules|\.next)/')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  # `[^.a-zA-Z0-9_$]` ensures we don't pick up `request.headers(` or similar.
  out="$(grep -nE '(^|[^.a-zA-Z0-9_$])(headers|cookies)[[:space:]]*\(' "$f" \
    | sed "s|^|$f:|")"
  [ -n "$out" ] && hits+="$out"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "ADVISORY — \`headers()\` / \`cookies()\` called inside a layout.tsx:"
  echo "Forces the subtree dynamic and breaks streaming. Push the call to a"
  echo "leaf page or wrap the consumer in <Suspense>"
  echo "(docs/best-practices.md § Next.js 16.2)."
  echo ""
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
