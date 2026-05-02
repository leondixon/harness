# Behaviour

> Does the code do what it claims? The second of [Fowler's three quality dimensions](https://martinfowler.com/articles/harness-engineering.html). Runs the project's tests and scans the diff for boundary leaks on every `Stop`.

## Where it lives

```
harness/verify.d/tests.sh       # Dimension: behaviour
harness/verify.d/secrets.sh     # Dimension: behaviour (boundary leak)
```

Wired to `Stop` via `harness/03-verify.sh`.

## Tests (`verify.d/tests.sh`)

Auto-detects the test runner from project files, in order:

| Marker | Command |
|---|---|
| `go.mod` | `go test -count=1 -short ./...` |
| `Cargo.toml` | `cargo test --quiet` |
| `pubspec.yaml` (+ `dart` on PATH) | `dart test` |
| `pyproject.toml` (+ `pytest` on PATH) | `pytest -q --no-header` |
| `package.json` with `"test"` script | `npm test --silent` |

**Cap: 60s.** Anything longer is a slow-test problem the harness shouldn't silently absorb. On timeout the run is marked failed and the command is logged.

**Artifacts:**
- `~/.claude/state/last-tests.log` — full output of the most recent run.
- `$HARNESS_ERR_LOG` — failure tail (last 20 lines) for the next prompt's `<harness:last-errors>`.

**Disable:** `touch ~/.claude/state/skip-tests` for the session.

## Secrets (`verify.d/secrets.sh`)

Greps `git diff HEAD` plus the staged diff for known secret shapes:

- AWS access/secret key names
- OpenAI-style `sk-…` keys
- GitHub PATs (`ghp_…`)
- PEM private key headers
- Inline `password|secret|api_key|token = "…"` patterns

A "behaviour at the boundary" check: it's not about architectural intent, it's about what the code would *expose* if shipped. Findings print to stderr; nothing blocks.

**Tuning:** edit the regex list at `secrets.sh:6-12`. Keep additions narrow — false positives train the user to ignore the channel.

## Why this dimension

Tests are the canonical behaviour sensor. Secrets is grouped here (rather than under architecture or maintainability) because both answer the same question — *what does this code do at runtime, and is that what we meant?* — for different audiences (the test runner for correctness, the diff scan for security).

## Why not block

The Stop hook always exits 0. Failing tests are loud (stderr, error log, next-prompt context) but never refuse a turn. A blocking sensor that fires on a flaky test or a slow run trains the user to disable the harness. Soft mode keeps the channel trustworthy.
