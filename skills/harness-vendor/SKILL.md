---
name: harness-vendor
model: haiku
description: Eject a self-contained copy of the global harness into the current project's .harness/ directory. The global dispatchers will detect and prefer the project copy on subsequent runs. Use when the user wants the harness to travel with the codebase (CI, pre-commit, teammates) or says "/harness-vendor".
---

You are vendoring the harness into the **current project**. After this, the project's `.harness/` shadows the global harness for any module a teammate wants to override, and the project's harness is usable outside Claude Code (pre-commit, CI).

## Procedure

1. Confirm we're inside a git repo:

       git rev-parse --is-inside-work-tree

   If not, halt and tell the user `/harness-vendor` only works inside a git repo.

2. cd to the repo root:

       cd "$(git rev-parse --show-toplevel)"

3. If `.harness/` already exists, ask the user before overwriting. Note that `/harness-init` may have created `.harness/fitness.d/` — preserve it.

4. Resolve the harness source. Prefer the plugin install path; fall back to a manual install:

       SRC=""
       if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/harness" ]; then
         SRC="${CLAUDE_PLUGIN_ROOT}/harness"
       elif [ -d "$HOME/.claude/harness" ]; then
         SRC="$HOME/.claude/harness"
       else
         echo "harness source not found"; exit 1
       fi

   Copy the harness mechanics into `.harness/`:

       mkdir -p .harness
       cp -r "$SRC/lib.sh" \
             "$SRC/01-context.sh" \
             "$SRC/02-checks.sh" \
             "$SRC/03-verify.sh" \
             "$SRC/context.d" \
             "$SRC/checks.d" \
             "$SRC/verify.d" \
             "$SRC/templates" \
             "$SRC/test" \
             "$SRC/README.md" \
             .harness/

   Do NOT copy any `state/` dir — runtime state lives in `~/.claude/state/`.

5. Verify the smoke test passes against the vendored copy:

       ./.harness/test/run.sh

6. Tell the user, in 4–6 lines:
   - That `.harness/` is now in the repo. Commit it so the team gets the same harness.
   - Global dispatchers (in `~/.claude/settings.json`) automatically prefer this copy when they run inside this repo.
   - The vendored copy is also runnable outside Claude — wire it into pre-commit / CI by calling `.harness/02-checks.sh <file>` or `.harness/03-verify.sh`.
   - To customize a module: edit it under `.harness/<dir>/<module>.sh`. Project copy shadows global by filename.
   - To stop using the project copy: `rm -rf .harness/` (the global harness resumes automatically).

## What you do NOT do

- Do not modify any project source files.
- Do not commit anything — let the user decide.
- Do not edit the harness source dir (`${CLAUDE_PLUGIN_ROOT}` or `~/.claude/harness/` — the source of truth).
