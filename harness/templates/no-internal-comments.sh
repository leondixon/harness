#!/usr/bin/env bash
# Fitness: flag JSDoc or `//` comment blocks above non-`export`ed declarations.
# Public-package APIs pass naturally — the next non-comment line begins with `export`.
#
# JSDoc:  file-based. Once a `.ts`/`.tsx` file is touched, any JSDoc above a
#         non-`export` declaration is flagged (including pre-existing ones).
# `//`:   diff-based. Only `//` blocks where at least one line was added in the
#         current diff are flagged — pre-existing narrative `//` is grandfathered
#         until someone edits it. Pragmas (`eslint-`, `@ts-`, `biome-ignore`,
#         `prettier-ignore`) are ignored.
# Skips:  `*.test.ts`, `*.spec.ts`, `*.d.ts`, `generated/`, `dist/`.
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
  /\.(ts|tsx)$/ \
    && !/\.test\.(ts|tsx)$/ \
    && !/\.spec\.(ts|tsx)$/ \
    && !/\.d\.ts$/ \
    && !/(^|\/)generated\// \
    && !/(^|\/)dist\//
')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue

  added_lines="$(
    { git diff --unified=0 --diff-filter=ACMR HEAD -- "$f" 2>/dev/null
      git diff --unified=0 --cached --diff-filter=ACMR -- "$f" 2>/dev/null
    } | awk '
      /^@@ / {
        if (match($0, /\+[0-9]+(,[0-9]+)?/)) {
          spec = substr($0, RSTART+1, RLENGTH-1)
          split(spec, a, ",")
          line = a[1] + 0
        }
        next
      }
      /^\+\+\+/ { next }
      /^\+/ {
        print line
        line++
      }
    ' | sort -un | tr '\n' ' '
  )"

  out="$(awk -v F="$f" -v ADDED="$added_lines" '
    BEGIN {
      state = "code"; start = 0; block_kind = ""; block_has_added = 0
      n = split(ADDED, alines, " ")
      for (i = 1; i <= n; i++) if (alines[i] != "") added[alines[i] + 0] = 1
    }
    function is_pragma(line,    inner) {
      inner = line
      sub(/^[[:space:]]*\/\/[[:space:]]*/, "", inner)
      return (inner ~ /^(eslint-|@ts-|biome-ignore|prettier-ignore)/)
    }
    function flush_if_violation(line) {
      if (line ~ /^[[:space:]]*export[[:space:]]/) return
      if (block_kind == "jsdoc") {
        print F ":" start ": jsdoc"
      } else if (block_kind == "line" && block_has_added) {
        print F ":" start ": //"
      }
    }
    state == "code" && $0 ~ /^[[:space:]]*\/\*\*([^\/]|$)/ {
      state = "in_jsdoc"; start = NR; block_kind = "jsdoc"; block_has_added = 1
      if ($0 ~ /\*\//) state = "after_block"
      next
    }
    state == "code" && $0 ~ /^[[:space:]]*\/\// {
      if (is_pragma($0)) next
      state = "in_line_block"; start = NR; block_kind = "line"
      block_has_added = (NR in added) ? 1 : 0
      next
    }
    state == "in_jsdoc" {
      if ($0 ~ /\*\//) state = "after_block"
      next
    }
    state == "in_line_block" && $0 ~ /^[[:space:]]*\/\// {
      if (is_pragma($0)) next
      if (NR in added) block_has_added = 1
      next
    }
    state == "in_line_block" {
      state = "after_block"
    }
    state == "in_skip_comment" {
      if ($0 ~ /\*\//) state = "after_block"
      next
    }
    state == "after_block" {
      if ($0 ~ /^[[:space:]]*$/) next
      if ($0 ~ /^[[:space:]]*\/\//) next
      if ($0 ~ /^[[:space:]]*\/\*/) {
        if ($0 !~ /\*\//) state = "in_skip_comment"
        next
      }
      flush_if_violation($0)
      state = "code"; block_kind = ""; block_has_added = 0
      next
    }
  ' "$f")"
  [ -n "$out" ] && hits+="$out"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "Internal comments above non-\`export\`ed declarations (AGENTS.md §3) — write WHY only, and only when non-obvious:"
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
