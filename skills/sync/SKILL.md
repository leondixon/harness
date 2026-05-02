---
name: sync
model: haiku
description: Re-scan the current project for tech it uses (Go, Node, Vue, Tailwind, …) and seed matching fitness-function templates into .harness/fitness.d/ that aren't already there. Safe to run repeatedly — never overwrites existing fitness functions, only adds new ones for tech the project has picked up since the last vendor/sync. Use when the user says "/sync".
---

You are syncing the harness's fitness-function library against the **current project**. `/vendor` is a one-shot activation; `/sync` is the ongoing top-up. As a project adopts new tech (a Vue frontend, a Tailwind config, a new language), `/sync` detects that and seeds the matching starter rules — without touching anything the user has already customised.

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

5. Also refresh `.harness/templates/` from `$SRC/templates/` so the project has the latest library available locally (this is a copy of upstream starters, not user-owned):

       cp -r "$SRC/templates/." .harness/templates/

6. Run any newly-seeded fitness functions once so pre-existing violations surface immediately:

       for s in .harness/fitness.d/*.sh; do echo "==> $s"; "$s" || true; done

7. Tell the user, in ≤6 lines:
   - Which tech was detected.
   - Which templates were newly seeded (or "nothing new — already in sync").
   - Which seeded checks flagged violations on first run.
   - Reminder: `.harness/fitness.d/*.sh` are now project-owned; edit or delete freely. Re-running `/sync` will not clobber edits.

## What you do NOT do

- Do not overwrite any existing file in `.harness/fitness.d/`.
- Do not modify project source files.
- Do not commit anything.
- Do not edit the harness source dir (`$SRC`).
- Do not seed a second cycles variant if one is already present.
