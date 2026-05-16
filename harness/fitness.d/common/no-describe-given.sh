#!/usr/bin/env bash
# Fitness: flag describe('given …') in test files.
# G/W/T belongs in the it() title (AGENTS.md §3). A describe whose title
# starts with `given` splits the Given from the When/Then across two layers
# and forces one behaviour into many it()s.
# Operates on changed/added test files only; pre-existing violations in
# unchanged files are grandfathered until someone edits the file.
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
  /\.(test|spec)\.(ts|tsx|js|jsx)$/ \
    && !/(^|\/)generated\// \
    && !/(^|\/)dist\//
')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  out="$(awk -v F="$f" '
    {
      lower = tolower($0)
      if (lower ~ /describe(\.[a-z]+)?[[:space:]]*\([[:space:]]*("|'\''|`)[[:space:]]*given[^a-z]/) {
        sub(/^[[:space:]]+/, "", $0)
        print F ":" NR ": " $0
      }
    }
  ' "$f")"
  [ -n "$out" ] && hits+="$out"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "describe('given …') is forbidden (AGENTS.md §3) — put Given/When/Then in the it() title, not the describe wrapper:"
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
