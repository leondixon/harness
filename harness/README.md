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

## Project override

When the current git repo has a `.harness/` directory, the dispatchers prefer modules from there over the global ones, matched by filename. Drop a `<repo>/.harness/checks.d/python.sh` to override the global Python check; remove `<repo>/.harness/` to revert.

Vendor a self-contained copy of the whole harness (for CI / pre-commit / teammates):

    /harness-vendor

The vendored `.harness/02-checks.sh`, `.harness/03-verify.sh` etc. are runnable outside Claude Code — wire them into pre-commit hooks or a CI step the same way you'd wire any shell script.

## Architecture fitness — per-project

Architecture rules (layer dependencies, cycle detection, public-API drift, layer enforcement) are project-specific. The global harness only provides the runner; each project owns its rules under `.harness/fitness.d/<name>.sh`.

Scaffold a project with starter checks:

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

    ~/.claude/harness/test/run.sh

Each module is also testable standalone, e.g.:

    ~/.claude/harness/checks.d/python.sh /tmp/foo.py
    ~/.claude/harness/verify.d/secrets.sh
    ~/.claude/harness/context.d/git.sh
