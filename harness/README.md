# Harness

Three dispatchers, modular per-concern scripts, one shared lib. Each script is small and exits 0 (soft mode).

```
harness/
├── lib.sh                  # shared helpers (project_root, run, state_dir)
├── 01-context.sh           # UserPromptSubmit dispatcher → context.d/*
├── 02-checks.sh            # PostToolUse dispatcher → checks.d/<lang>
├── 03-verify.sh            # Stop dispatcher → verify.d/*
├── context.d/
│   ├── git.sh              # branch + dirty count
│   └── errors.sh           # last-errors.log replay
├── checks.d/
│   ├── python.sh           # ruff + mypy
│   ├── node.sh             # eslint + tsc
│   ├── go.sh               # go vet
│   ├── dart.sh             # dart analyze
│   └── rust.sh             # cargo check
└── verify.d/
    ├── secrets.sh          # diff scan
    ├── tests.sh            # project tests, 60s cap
    ├── review-hint.sh      # nudge to /review-diff on big diffs
    └── project-fitness.sh  # runs <repo>/.harness/fitness.d/* (architecture)
```

## Activating for a project

The dispatchers are inactive until a project has a `.harness/` directory. Vendor the harness into a project with:

    /harness-vendor

This copies all modules into `<repo>/.harness/`, activates the harness for that project, and makes the scripts runnable outside Claude Code (pre-commit, CI). Commit `.harness/` so the team shares the same harness.

To deactivate: `rm -rf .harness/`.

## Architecture fitness — per-project

Architecture rules (layer dependencies, cycle detection, public-API drift, layer enforcement) live under `.harness/fitness.d/<name>.sh`. Scaffold starter checks with:

    /harness-init

Drops in `cycles.sh` (language-aware), `todos.sh` (TODO without issue link), and a `layers.sh.example` template under `.harness/fitness.d/`.

## Conventions

| Layer       | Input                       | Output                         | Exit |
|-------------|-----------------------------|--------------------------------|------|
| `context.d` | none                        | stdout (becomes prompt context)| 0    |
| `checks.d`  | one file path argument      | stderr; failures → `$HARNESS_ERR_LOG` | 0    |
| `verify.d`  | none (cwd = repo root)      | stderr; failures → `$HARNESS_ERR_LOG` | 0    |

## Add a language

Drop a file in `checks.d/<lang>.sh`. Source `lib.sh`, run your tool, done. Wire the extension in `02-checks.sh`'s `case` block.

## Add a sensor

Drop an executable in `verify.d/`. Dispatcher runs everything in alphabetical order.

## State

- `~/.claude/state/last-errors.log` — written by `02-checks.sh` and `verify.d/tests.sh`, read by `context.d/errors.sh`.
- `~/.claude/state/last-tests.log` — full test output from the last `Stop`.
- `~/.claude/state/skip-tests` (touch to disable test sensor).

## Test

    .harness/test/run.sh        # from a vendored project
    harness/test/run.sh         # from this source repo

Each module is also testable standalone from a vendored project, e.g.:

    .harness/checks.d/python.sh /tmp/foo.py
    .harness/verify.d/secrets.sh
    .harness/context.d/git.sh
