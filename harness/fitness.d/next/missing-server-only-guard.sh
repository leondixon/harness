#!/usr/bin/env bash
# Fitness: surface server-side modules that import known server-only packages
# (currently `@prisma/client`) but don't declare `import 'server-only'` at the
# top. A misplaced `'use client'` consumer of this module would leak secrets
# into the client bundle; the `server-only` guard turns that into a build-time
# error (docs/best-practices.md § Next.js 16.2 "Importing server-only modules
# from client code").
#
# ADVISORY — some files (Next config, tests, server-only Express code under
# apps/backend) don't benefit from the guard. The agent should review and add
# the import where appropriate, or accept the exclusion.
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
  | grep -E '^apps/web-[^/]+/.+\.tsx?$' \
  | grep -Ev '(^|/)(generated|dist|node_modules|\.next)/' \
  | grep -Ev '\.(test|spec)\.(ts|tsx)$' \
  | grep -Ev '(^|/)next\.config\.[^/]+$' \
  | grep -Ev '(^|/)middleware\.ts$' \
  | grep -Ev '(^|/)proxy\.ts$')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head -3 "$f" | grep -Eq "^[[:space:]]*['\"]use client['\"]" && continue
  grep -qE "from[[:space:]]+['\"]@prisma/client['\"]" "$f" || continue
  grep -qE "import[[:space:]]+['\"]server-only['\"]" "$f" && continue
  hits+="$f"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "ADVISORY — server-touching module without \`import 'server-only'\`:"
  echo "Add \`import 'server-only';\` at the top so a misplaced client import"
  echo "fails the build instead of leaking secrets"
  echo "(docs/best-practices.md § Next.js 16.2)."
  echo ""
  printf '%s' "$hits"
} >&2
exit 1
