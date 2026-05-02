---
name: sync
model: haiku
description: Re-scan the current project for tech it uses (Go, Node, Vue, Tailwind, …) and top up `.harness/` with anything new upstream — fitness templates the project now qualifies for, and any new dispatcher modules (`context.d/`, `checks.d/`, `verify.d/`) that didn't exist when the project was vendored. Safe to run repeatedly — never overwrites existing files. Use when the user says "/sync".
---

You are syncing the harness against the **current project**. `/vendor` is a one-shot activation; `/sync` is the ongoing top-up. It does two jobs:

1. As a project adopts new tech (a Vue frontend, a Tailwind config, a new language), seed the matching starter fitness rules into `.harness/fitness.d/`.
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

   Templates live at `$SRC/templates/`.

4. Run the detection table below. For every rule that fires, copy the named template(s) into `.harness/fitness.d/` **only if both** (a) the source template exists and (b) the destination file does not. Never overwrite. Skip silently when a template isn't shipped yet.

   | Detect (any match) | Seed |
   |---|---|
   | `go.mod` | `cycles-go.sh` → `cycles.sh` |
   | `package.json`, `pnpm-lock.yaml`, `yarn.lock` | `cycles-node.sh` → `cycles.sh` |
   | `pubspec.yaml` | `cycles-dart.sh` → `cycles.sh` |
   | `pyproject.toml`, `requirements.txt` | `cycles-python.sh` → `cycles.sh` |
   | `Cargo.toml` | `cycles-rust.sh` → `cycles.sh` |
   | always | `todos.sh`, `layers.sh.example` |

   `cycles.sh` is single-slot — if any cycles variant already exists in `fitness.d/`, do not seed another. Use cheap checks (`test -f`, `compgen -G '*.vue'`, or `git ls-files '*.vue' | head -1`) — do not walk the whole tree.

   Implementation sketch:

       seed() { # seed <src-template> <dest-name>
         local s="$SRC/templates/$1" d=".harness/fitness.d/$2"
         [ -f "$s" ] && [ ! -e "$d" ] && cp "$s" "$d" && chmod +x "$d" && echo "seeded $d"
       }

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
             echo "synced $dest"
           fi
         done
       done

   Also top up the top-level mechanics (`lib.sh`, `01-context.sh`, `02-checks.sh`, `03-verify.sh`) the same additive way — only copy if absent. If any are missing, the project was vendored before they existed and needs them to dispatch correctly.

6. Refresh `.harness/templates/` from `$SRC/templates/` so the project has the latest starter library available locally (this is a read-only copy of upstream starters, not user-owned, so it's safe to overwrite):

       cp -r "$SRC/templates/." .harness/templates/

7. Run any newly-seeded fitness functions once so pre-existing violations surface immediately:

       for s in .harness/fitness.d/*.sh; do echo "==> $s"; "$s" || true; done

8. Tell the user, in ≤8 lines:
   - Which tech was detected.
   - Which fitness templates were newly seeded (or "nothing new").
   - Which new dispatcher modules were synced into `context.d/`, `checks.d/`, `verify.d/` (or "modules already in sync").
   - Which seeded checks flagged violations on first run.
   - Reminder: every `.harness/**/*.sh` is project-owned; edit or delete freely. Re-running `/sync` will not clobber edits, but will not re-add a module the user deleted either — to restore one, copy it back from `$SRC` manually.

## What you do NOT do

- Do not overwrite any existing file in `.harness/` (other than `templates/`, which is upstream-owned).
- Do not modify project source files.
- Do not commit anything.
- Do not edit the harness source dir (`$SRC`).
- Do not seed a second cycles variant if one is already present.
