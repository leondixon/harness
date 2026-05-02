#!/usr/bin/env bash
# Fitness: flag cryptic 1-2 char variable names. Loop indices (i, j, k, n, idx, _) are allowed.
# Tune the allowlist below for your project.
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

allow='^(i|j|k|n|idx|_)$'

# Match declarations: `let|const|var|final NAME =`, `NAME :=` (Go), `let mut? NAME =` (Rust).
hits="$(git grep -nE \
  '(\b(let|const|var|final)\s+(mut\s+)?[a-z_]{1,2}\b\s*[:=]|^\s*[a-z_]{1,2}\s*:=)' -- \
  '*.go' '*.ts' '*.tsx' '*.js' '*.jsx' '*.dart' '*.rs' 2>/dev/null \
  | awk -v allow="$allow" '
      {
        line=$0
        # extract candidate name: last word before = or :=
        if (match(line, /(let|const|var|final)[[:space:]]+(mut[[:space:]]+)?[a-z_]{1,2}\b/)) {
          n=substr(line, RSTART, RLENGTH); sub(/.*[[:space:]]/, "", n)
        } else if (match(line, /^[^:]*:[0-9]+:[[:space:]]*[a-z_]{1,2}[[:space:]]*:=/)) {
          n=substr(line, RSTART, RLENGTH); sub(/.*:[[:space:]]*/, "", n); sub(/[[:space:]]*:=.*/, "", n)
        } else next
        if (n !~ allow) print
      }' || true)"

[ -z "$hits" ] && exit 0
echo "Cryptic variable names — prefer explicit (e.g. 'player' not 'p'):" >&2
printf '%s\n' "$hits" | head -n 10 >&2
exit 1
