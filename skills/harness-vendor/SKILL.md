---
name: harness-vendor
model: haiku
description: Activate the harness for the current project by copying all modules into .harness/. The dispatchers only run modules from a project's .harness/ — this is the required step to turn the harness on. Also makes the harness runnable outside Claude Code (CI, pre-commit, teammates). Use when the user says "/harness-vendor".
---

You are vendoring the harness into the **current project**. The harness dispatchers only look for modules inside a project's `.harness/` directory — this step activates the harness for the repo. After this, the harness travels with the codebase and is usable outside Claude Code (pre-commit, CI).

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
   - That `.harness/` is now in the repo and the harness is active. Commit it so the team gets the same harness.
   - The harness dispatchers (wired in `~/.claude/settings.json`) will now run for this project on every Edit/Write/Stop.
   - The vendored copy is also runnable outside Claude — wire it into pre-commit / CI by calling `.harness/02-checks.sh <file>` or `.harness/03-verify.sh`.
   - To customize a module: edit it under `.harness/<dir>/<module>.sh`.
   - To deactivate the harness for this project: `rm -rf .harness/`.

## What you do NOT do

- Do not modify any project source files.
- Do not commit anything — let the user decide.
- Do not edit the harness source dir (`${CLAUDE_PLUGIN_ROOT}` or `~/.claude/harness/` — the source of truth).
