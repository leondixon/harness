#!/usr/bin/env bash
# Fitness: TODO/FIXME without an issue reference (#123, issues/123, GH-123, JIRA-1).
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
hits="$(git grep -nE '\b(TODO|FIXME|XXX)\b' -- \
  '*.go' '*.py' '*.ts' '*.tsx' '*.js' '*.jsx' '*.dart' '*.rs' '*.md' 2>/dev/null \
  | grep -vE '#[0-9]+|issues?/[0-9]+|GH-[0-9]+|[A-Z]+-[0-9]+' || true)"
[ -z "$hits" ] && exit 0
echo "TODO/FIXME without issue link:" >&2
printf '%s\n' "$hits" | head -n 10 >&2
exit 1
