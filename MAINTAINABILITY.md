# Maintainability

> Code-quality sensors. The first of [Fowler's three quality dimensions](https://martinfowler.com/articles/harness-engineering.html). Catches lint and type errors *as Claude writes*, before they compound.

## Where it lives

```
harness/checks.d/<lang>.sh
```

Wired to `PostToolUse` (Edit | Write | MultiEdit) via `harness/02-checks.sh`.

## Contract

Each `checks.d/*.sh` script:

- Receives **one file path** as `$1`.
- Sources `lib.sh` for `harness_run` (which captures output, surfaces failures on stderr, and appends to `$HARNESS_ERR_LOG` so the next prompt sees them).
- Exits 0 — soft mode. Sensors inform, never block.

The dispatcher (`02-checks.sh`) routes by extension and skips generated files (`*.g.dart`, `*.freezed.dart`, `*_pb.go`, `*.pb.go`, `*/generated/*`).

## Language map

| Extension | Module | Tools |
|---|---|---|
| `.py` | `python.sh` | ruff, mypy (when `[tool.mypy]` in `pyproject.toml`) |
| `.ts .tsx .js .jsx .mjs .cjs` | `node.sh` | eslint (when in `package.json`), tsc (when `tsconfig.json` exists) |
| `.go` | `go.sh` | go vet |
| `.dart` | `dart.sh` | dart analyze |
| `.rs` | `rust.sh` | cargo check |

Wiring lives in `02-checks.sh`'s `case` block.

## Adding a language

1. Drop `checks.d/<lang>.sh` — source `lib.sh`, run your tool through `harness_run`.
2. Add the extension to the `case` block in `02-checks.sh`.
3. Run `harness/test/run.sh`.

Keep it ≤30 lines. If the script grows, the tool config probably belongs in the project, not the harness.

## Disabling

- Per-tool: don't install the binary; `command -v` guards skip it.
- Per-project: `chmod -x .harness/checks.d/<lang>.sh`.
- Whole project: `rm -rf .harness/` deactivates the harness for that project.

## Why this dimension

Maintainability is the cheapest dimension to fix when caught early — a misspelt import or a type mismatch is a 10-second fix at write time and a half-hour archaeology later. The PostToolUse hook makes that loop tight.
