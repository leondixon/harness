#!/usr/bin/env bash
# Fitness: surface server actions that perform Prisma mutations without calling
# `revalidateTag` / `revalidatePath`. Without revalidation, the next render
# serves the pre-mutation cached response and the UI appears stuck
# (docs/best-practices.md § Next.js 16.2 "Mutation without revalidateTag /
# revalidatePath").
#
# ADVISORY — some mutations legitimately don't need revalidation (background
# audit writes, side-effect-only mutations with no cached read path). The
# agent should review and either tag the relevant fetches and revalidate, or
# accept the omission.
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
  | grep -E '\.tsx?$' \
  | grep -Ev '(^|/)(generated|dist|node_modules|\.next)/' \
  | grep -Ev '\.(test|spec)\.(ts|tsx)$')"
[ -z "$candidates" ] && exit 0

hits=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head -3 "$f" | grep -Eq "^[[:space:]]*['\"]use server['\"]" || continue
  grep -qE 'prisma\.[a-zA-Z_]+\.(create|update|delete|upsert|createMany|updateMany|deleteMany)[[:space:]]*\(' "$f" || continue
  grep -qE 'revalidate(Tag|Path)[[:space:]]*\(' "$f" && continue
  mutation_lines="$(grep -nE 'prisma\.[a-zA-Z_]+\.(create|update|delete|upsert|createMany|updateMany|deleteMany)[[:space:]]*\(' "$f" | head -n 3 | sed "s|^|$f:|")"
  hits+="$mutation_lines"$'\n'
done <<< "$candidates"

[ -z "$hits" ] && exit 0
{
  echo "ADVISORY — server action mutates without revalidateTag/revalidatePath:"
  echo "Tag fetches (\`{ next: { tags: [...] } }\`) and call \`revalidateTag\`"
  echo "(or \`revalidatePath\`) after the mutation, or confirm no cached read"
  echo "needs invalidating (docs/best-practices.md § Next.js 16.2)."
  echo ""
  printf '%s' "$hits" | head -n 20
} >&2
exit 1
