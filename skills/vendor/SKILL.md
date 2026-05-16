---
name: vendor
model: haiku
description: Activate the harness for the current project by copying all modules into .harness/, including framework-grouped starter architecture fitness checks under .harness/fitness.d/. The dispatchers only run modules from a project's .harness/ — this is the required step to turn the harness on. Also makes the harness runnable outside Claude Code (CI, pre-commit, teammates). Use when the user says "/vendor".
---

You are vendoring the harness into the **current project**. The harness dispatchers only look for modules inside a project's `.harness/` directory — this step activates the harness for the repo. After this, the harness travels with the codebase and is usable outside Claude Code (pre-commit, CI). This skill also copies framework-grouped starter fitness functions under `.harness/fitness.d/`; the project should delete the checks it does not want.

## Procedure

1. Confirm we're inside a git repo:

       git rev-parse --is-inside-work-tree

   If not, halt and tell the user `/vendor` only works inside a git repo.

2. cd to the repo root:

       cd "$(git rev-parse --show-toplevel)"

3. If `.harness/` already exists, ask the user before overwriting. Preserve any existing `fitness.d/` they may have edited.

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
             "$SRC/test" \
             "$SRC/README.md" \
             .harness/

   Do NOT copy any `state/` dir — runtime state lives in `~/.claude/state/`.

5. Copy starter fitness checks additively, preserving any existing project-owned checks:

       if [ -d "$SRC/fitness.d" ]; then
         mkdir -p .harness/fitness.d
         find "$SRC/fitness.d" -type f | sort | while read -r f; do
           rel="${f#"$SRC/fitness.d/"}"
           dest=".harness/fitness.d/$rel"
           if [ ! -e "$dest" ]; then
             mkdir -p "$(dirname "$dest")"
             cp "$f" "$dest"
           fi
         done
       fi

6. Ensure copied fitness scripts are executable:

       find .harness/fitness.d -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

7. Verify the smoke test passes against the vendored copy:

       ./.harness/test/run.sh

8. Run the fitness functions once to surface any pre-existing violations:

       find .harness/fitness.d -type f -name '*.sh' -perm -111 | sort | while read -r s; do echo "==> $s"; "$s" || true; done

9. Tell the user, in ≤8 lines:
   - That `.harness/` is now in the repo and the harness is active. Commit it so the team gets the same harness.
   - Which fitness check groups were copied under `.harness/fitness.d/`, and which (if any) flagged pre-existing violations.
   - That starter checks are grouped by framework/platform; delete the ones the project does not want.
   - That `common/layers.sh.example` is a template — rename to `layers.sh` after editing.
   - The harness dispatchers (wired in `~/.claude/settings.json`) will now run for this project on every Edit/Write/Stop.
   - The vendored copy is also runnable outside Claude — wire it into pre-commit / CI by calling `.harness/02-checks.sh <file>` or `.harness/03-verify.sh`.
   - To customize a module: edit it under `.harness/<dir>/<module>.sh`.
   - To deactivate the harness for this project: `rm -rf .harness/`.

## What you do NOT do

- Do not modify any project source files.
- Do not commit anything — let the user decide.
- Do not edit the harness source dir (`${CLAUDE_PLUGIN_ROOT}` or `~/.claude/harness/` — the source of truth).
- Do not overwrite an existing `.harness/fitness.d/**` file — those are user edits.
