---
name: sync
model: haiku
description: Top up `.harness/` with anything new upstream — framework-grouped fitness checks and any new dispatcher modules (`context.d/`, `checks.d/`, `verify.d`) that didn't exist when the project was vendored. Safe to run repeatedly — never overwrites existing files. Use when the user says "/sync".
---

You are syncing the harness against the **current project**. `/vendor` is a one-shot activation; `/sync` is the ongoing top-up. It does two jobs:

1. Top up framework-grouped starter fitness rules under `.harness/fitness.d/`.
2. As the upstream harness gains new modules (e.g. a new `verify.d/nuxt-dev.sh`), drop them into the project's vendored `.harness/` so the project picks them up.

Both jobs are strictly additive: existing files in `.harness/` are never overwritten, because users may have customised them.

## Procedure

1. Confirm we're inside a git repo and the harness is vendored:

       git rev-parse --is-inside-work-tree
       test -d .harness/fitness.d

   If either fails, halt and tell the user to run `/vendor` first.

2. cd to the repo root:

       cd "$(git rev-parse --show-toplevel)"

3. Resolve the harness source the same way `/vendor` does:

       SRC=""
       if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -d "${CLAUDE_PLUGIN_ROOT}/harness" ]; then
         SRC="${CLAUDE_PLUGIN_ROOT}/harness"
       elif [ -d "$HOME/.claude/harness" ]; then
         SRC="$HOME/.claude/harness"
       else
         echo "harness source not found"; exit 1
       fi

   Fitness starters live at `$SRC/fitness.d/`.

4. Top up `.harness/fitness.d/` from `$SRC/fitness.d/` without overwriting existing files:

       describe() { # first comment line after shebang, stripped of leading `# `
         awk 'NR>1 && /^#/ { sub(/^#[[:space:]]*/, ""); print; exit }' "$1"
       }
       if [ -d "$SRC/fitness.d" ]; then
         mkdir -p .harness/fitness.d
         find "$SRC/fitness.d" -type f | sort | while read -r f; do
           rel="${f#"$SRC/fitness.d/"}"
           dest=".harness/fitness.d/$rel"
           if [ ! -e "$dest" ]; then
             mkdir -p "$(dirname "$dest")"
             cp "$f" "$dest"
             chmod +x "$dest" 2>/dev/null || true
             echo "seeded $dest — $(describe "$dest")"
           fi
         done
       fi

5. Top up the dispatcher module dirs with any **new** upstream modules. For each of `context.d`, `checks.d`, `verify.d`, copy files from `$SRC/<dir>/` into `.harness/<dir>/` only when the destination file does not already exist. Never overwrite — users may have edited their copy.

       mkdir -p .harness/context.d .harness/checks.d .harness/verify.d
       for dir in context.d checks.d verify.d; do
         [ -d "$SRC/$dir" ] || continue
         for f in "$SRC/$dir"/*; do
           [ -e "$f" ] || continue
           name="$(basename "$f")"
           dest=".harness/$dir/$name"
           if [ ! -e "$dest" ]; then
             cp "$f" "$dest"
             chmod +x "$dest" 2>/dev/null || true
             echo "synced $dest — $(describe "$dest")"
           fi
         done
       done

   Also top up the top-level mechanics (`lib.sh`, `01-context.sh`, `02-checks.sh`, `03-verify.sh`) the same additive way — only copy if absent. If any are missing, the project was vendored before they existed and needs them to dispatch correctly.

6. Run any newly-seeded fitness functions once so pre-existing violations surface immediately:

       find .harness/fitness.d -type f -name '*.sh' -perm -111 | sort | while read -r s; do echo "==> $s"; "$s" || true; done

7. Tell the user, in ≤8 lines:
   - Which fitness checks were newly seeded — list each by path with its one-line purpose (or "nothing new").
   - Which new dispatcher modules were synced into `context.d/`, `checks.d/`, `verify.d/` — list each by name with its one-line purpose (or "modules already in sync").
   - Which seeded checks flagged violations on first run.
   - Reminder: every `.harness/**/*.sh` is project-owned; edit or delete freely. Re-running `/sync` will not clobber edits; if it re-adds a deleted upstream starter, delete that file again.

## What you do NOT do

- Do not overwrite any existing file in `.harness/`.
- Do not modify project source files.
- Do not commit anything.
- Do not edit the harness source dir (`$SRC`).
