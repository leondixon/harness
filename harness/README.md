# Harness — plumbing

Three dispatchers + a shared lib. Per-concern scripts live in `*.d/` drop-in directories. Each script is small and exits 0 (soft mode).

For *what* the harness checks (and how to extend each dimension), see the root docs:

- [MAINTAINABILITY.md](../MAINTAINABILITY.md) — `checks.d/`
- [BEHAVIOUR.md](../BEHAVIOUR.md) — `verify.d/tests.sh`, `verify.d/secrets.sh`
- [ARCHITECTURE.md](../ARCHITECTURE.md) — `verify.d/project-fitness.sh` + `.harness/fitness.d/`

This README is about the dispatch plumbing only.

## Layout

```
harness/
├── lib.sh                  # shared helpers (project_root, run, state_dir)
├── 01-context.sh           # UserPromptSubmit dispatcher → context.d/*
├── 02-checks.sh            # PostToolUse dispatcher → checks.d/<lang>
├── 03-verify.sh            # Stop dispatcher → verify.d/*
├── context.d/              # feedforward sensors (no args, stdout → prompt)
├── checks.d/               # maintainability sensors (one file path arg)
├── verify.d/               # behaviour + architecture sensors (no args, cwd = repo root)
└── templates/              # starter fitness functions for /harness-init
```

## Activation

The dispatchers are inactive until a project has a `.harness/` directory. Vendor with:

    /harness-vendor

Copies all modules into `<repo>/.harness/`. Activates the harness for that project and makes the scripts runnable in CI and pre-commit. Commit `.harness/`. Deactivate with `rm -rf .harness/`.

## Conventions

| Layer       | Input                  | Output                                | Exit |
|-------------|------------------------|---------------------------------------|------|
| `context.d` | none                   | stdout (becomes prompt context)       | 0    |
| `checks.d`  | one file path argument | stderr; failures → `$HARNESS_ERR_LOG` | 0    |
| `verify.d`  | none (cwd = repo root) | stderr; failures → `$HARNESS_ERR_LOG` | 0    |

Scripts in `verify.d/` carry a `# Dimension: <name>` header so the file's role is greppable.

## State

- `~/.claude/state/last-errors.log` — written by `02-checks.sh` and `verify.d/tests.sh`, read by `context.d/errors.sh`.
- `~/.claude/state/last-tests.log` — full test output from the last `Stop`.
- `~/.claude/state/skip-tests` — touch to disable the test sensor.

## Test

    .harness/test/run.sh        # from a vendored project
    harness/test/run.sh         # from this source repo

Each module is also testable standalone, e.g.:

    .harness/checks.d/python.sh /tmp/foo.py
    .harness/verify.d/secrets.sh
    .harness/context.d/git.sh
