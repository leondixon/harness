---
name: harness-init
model: haiku
description: Scaffold project-local architecture fitness functions under .harness/fitness.d/. Detects the project's primary language and drops in cycle-detection plus a TODO-without-issue check and a layers.sh.example template. Use when the user says "/harness-init" or wants to enable fitness checks in a fresh project.
---

You are scaffolding architecture fitness functions for the **current project**. The harness runs `.harness/fitness.d/*.sh` on every `Stop` when `.harness/` is present; you are dropping in starter checks that the user can edit. If `.harness/` does not yet exist, remind the user to run `/harness-vendor` first to activate the harness.

## Procedure

1. Confirm we're inside a git repo:

       git rev-parse --is-inside-work-tree

   If not, halt and tell the user `/harness-init` only works inside a git repo.

2. cd to the repo root:

       cd "$(git rev-parse --show-toplevel)"

3. If `.harness/fitness.d/` already exists and is non-empty, ask the user before overwriting. Otherwise create it:

       mkdir -p .harness/fitness.d

4. Detect the project's primary language by checking, in this order:

   - `go.mod`        → go
   - `package.json`  → node
   - `pubspec.yaml`  → dart
   - `pyproject.toml`→ python
   - `Cargo.toml`    → rust

   Pick the first match. If none match, set `lang=unknown`.

5. Resolve the harness source. Prefer the plugin install path; fall back to a manual install:

       SRC=""
       if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/harness" ]; then
         SRC="${CLAUDE_PLUGIN_ROOT}/harness"
       elif [ -d "$HOME/.claude/harness" ]; then
         SRC="$HOME/.claude/harness"
       else
         echo "harness source not found"; exit 1
       fi

   Copy the templates from `$SRC/templates/` into `.harness/fitness.d/`:

       cp "$SRC/templates/README.md"          .harness/README.md
       cp "$SRC/templates/todos.sh"           .harness/fitness.d/todos.sh
       cp "$SRC/templates/layers.sh.example"  .harness/fitness.d/layers.sh.example

   If a `cycles-<lang>.sh` template exists, copy it as `cycles.sh`:

       cp "$SRC/templates/cycles-<lang>.sh"   .harness/fitness.d/cycles.sh

6. Make the `.sh` files executable; leave `*.example` non-executable so the runner skips it:

       chmod +x .harness/fitness.d/*.sh

7. Run the new checks once to surface any pre-existing violations:

       for s in .harness/fitness.d/*.sh; do echo "==> $s"; "$s" || true; done

8. Tell the user, in 3–5 lines:
   - Which files were created.
   - Which checks ran clean and which flagged violations (if any).
   - That `layers.sh.example` is a template — rename to `layers.sh` after editing.
   - That checks run automatically on every `Stop` from now on.

## What you do NOT do

- Do not modify any project source files.
- Do not change `.gitignore` — `.harness/` is a project artefact and should be tracked.
- Do not commit the changes — let the user decide.
