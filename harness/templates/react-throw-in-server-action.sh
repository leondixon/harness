#!/usr/bin/env bash
# Fitness: surface `throw` statements inside server actions / useActionState
# action functions for review. Throwing inside an action aborts the action
# queue and disables optimistic state — usually you want to return an error in
# the action's state shape (docs/best-practices.md § React 19.2 "Throwing
# inside an action instead of returning error state").
#
# Some throws are legitimate (Next.js control flow: notFound / redirect /
# unauthorized / forbidden / permanentRedirect). Those are allow-listed.
# Anything else is flagged as ADVISORY so the agent can confirm intent on the
# next turn.
#
# Operates on changed files only — pre-existing throws in unchanged files are
# grandfathered until someone edits the file.
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
  is_action=0
  head -3 "$f" | grep -Eq "['\"]use server['\"]" && is_action=1
  grep -q "useActionState[[:space:]]*(" "$f" && is_action=1
  [ "$is_action" -eq 0 ] && continue

  out="$(awk -v F="$f" '
    /(^|[^a-zA-Z0-9_$])throw[[:space:]]+/ {
      line = $0
      if (line ~ /throw[[:space:]]+(notFound|redirect|unauthorized|forbidden|permanentRedirect)[[:space:]]*\(/) next
      sub(/^[[:space:]]+/, "", line)
      print F ":" NR ": " line
    }
  ' "$f")"
  [ -n "$out" ] && hits+="$out"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "ADVISORY — \`throw\` inside server action / useActionState handler:"
  echo "Throwing aborts the action queue and disables optimistic state."
  echo "Verify each one is intentional control flow, otherwise return the error"
  echo "in the action's state shape (docs/best-practices.md § React 19.2)."
  echo ""
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
