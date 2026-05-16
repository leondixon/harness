#!/usr/bin/env bash
# Fitness: flag cryptic 1-2 char variable and function names.
# Loop indices (i, j, k, n, idx, _) are allowed. Tune the allowlist below.
# Scoped to files changed vs HEAD plus untracked — pre-existing names are
# grandfathered until someone next edits the file.
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

allow='^(i|j|k|n|idx|_)$'

files="$(
  { git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null
    git diff --name-only --cached --diff-filter=ACMR 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | awk '/\.(go|ts|tsx|js|jsx|vue|dart|rs)$/' | sort -u
)"
[ -z "$files" ] && exit 0

hits="$(printf '%s\n' "$files" | tr '\n' '\0' | xargs -0 grep -nE \
  '((let|const|var|final)[[:space:]]+(mut[[:space:]]+)?[a-z_]+[[:space:]]*[:=]|^[[:space:]]*[a-z_]+[[:space:]]*:=|(function|func|fn)[[:space:]]+[a-z_]+[[:space:]]*[(<])' \
  2>/dev/null \
  | awk -v allow="$allow" '
      {
        # Strip "path:lineno:" prefix to recover the source line.
        src = $0
        p = index(src, ":"); if (!p) next; src = substr(src, p+1)
        p = index(src, ":"); if (!p) next; src = substr(src, p+1)

        name = ""
        if (match(src, /(let|const|var|final)[[:space:]]+(mut[[:space:]]+)?[a-z_]+/)) {
          name = substr(src, RSTART, RLENGTH); sub(/.*[[:space:]]/, "", name)
        } else if (match(src, /(function|func|fn)[[:space:]]+[a-z_]+/)) {
          name = substr(src, RSTART, RLENGTH); sub(/.*[[:space:]]/, "", name)
        } else if (match(src, /^[[:space:]]*[a-z_]+[[:space:]]*:=/)) {
          name = substr(src, RSTART, RLENGTH)
          sub(/[[:space:]]*:=.*/, "", name); sub(/^[[:space:]]*/, "", name)
        } else next

        if (length(name) <= 2 && name !~ allow) print
      }' || true)"

[ -z "$hits" ] && exit 0
echo "Cryptic variable/function names — prefer explicit (e.g. 'player' not 'p'):" >&2
printf '%s\n' "$hits" | head -n 10 >&2
exit 1
