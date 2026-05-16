#!/usr/bin/env bash
# Fitness: flag decorative banner comments (// ====, // ----, // ****, // ####).
# Scans added/modified lines in the working diff; pre-existing banners are grandfathered.
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

diff="$(
  { git diff HEAD --unified=0 --diff-filter=ACMR 2>/dev/null
    git diff --cached --unified=0 --diff-filter=ACMR 2>/dev/null
  }
)"
[ -z "$diff" ] && exit 0

hits="$(printf '%s\n' "$diff" | awk '
  /^diff --git / {
    file = ""
    in_target = 0
    if (match($0, /[[:space:]]b\/[^[:space:]]+$/)) {
      file = substr($0, RSTART+3, RLENGTH-3)
      in_target = (file ~ /\.(ts|tsx|js|jsx)$/ \
        && file !~ /\.test\.(ts|tsx|js|jsx)$/ \
        && file !~ /\.spec\.(ts|tsx|js|jsx)$/ \
        && file !~ /\.d\.ts$/ \
        && file !~ /(^|\/)generated\// \
        && file !~ /(^|\/)dist\//)
    }
    next
  }
  /^@@ / {
    if (match($0, /\+[0-9]+/)) {
      line_num = substr($0, RSTART+1, RLENGTH-1) + 0
    }
    next
  }
  in_target && /^\+\+\+/ { next }
  in_target && /^\+/ {
    if ($0 ~ /^\+[[:space:]]*\/\/[[:space:]]*[-=*#]{3,}/) {
      print file ":" line_num ": " substr($0, 2)
    }
    line_num++
    next
  }
')"

[ -z "$hits" ] && exit 0
{
  echo "Decorative banner comments (AGENTS.md §3) — names should carry meaning:"
  printf '%s\n' "$hits" | head -n 20
} >&2
exit 1
