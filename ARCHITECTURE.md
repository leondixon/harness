# Architecture Fitness

> Does the codebase still obey the rules its authors set for it? The third of [Fowler's three quality dimensions](https://martinfowler.com/articles/harness-engineering.html). The other two dimensions are language-agnostic; this one is project-specific by definition.

## Where it lives

```
.harness/fitness.d/<name>.sh    # one fitness function per file (project-local)
harness/verify.d/project-fitness.sh   # the runner; Dimension: architecture
```

Run on every `Stop`. Each project owns its own fitness functions — there is no global ruleset, because there is no global architecture.

## Contract

A fitness function is an executable shell script that:

- Reads from the working tree (or `git diff`). **No arguments.**
- Exits **0** on pass, **non-zero** on violation.
- Prints a violation summary on stderr — **≤10 lines**, with a clear first line ("Layer violation: src/web → src/db").

Violations are appended to `$HARNESS_ERR_LOG` and surface in the next prompt as `<harness:last-errors>`. The runner never blocks.

## Bootstrap

`/harness-vendor` activates the harness *and* seeds starter fitness functions in one step. It drops three starters into `.harness/fitness.d/`:

| File | Catches |
|---|---|
| `cycles-go.sh` *or* `cycles-node.sh` | Import cycles (language-aware) |
| `todos.sh` | `TODO`/`FIXME`/`XXX` without an issue reference (`#123`, `GH-123`, `JIRA-1`) |
| `layers.sh.example` | Cross-layer dependency violation. Rename to `layers.sh` and edit |

## Writing your own

Whenever a code-review comment is "we shouldn't depend X → Y" or "this kind of thing has to live in module Z," that's a fitness function waiting to happen. The pattern:

1. Express the rule as a `git grep` (cheap) or static-analysis pipe.
2. Exit non-zero if any matches.
3. Print the offenders, capped to 10.

Examples worth having:
- **Public API drift.** `git diff` against the last release tag for changes in `src/public/**`.
- **Generated-file edits.** `git diff` for changes inside `*/generated/**` or `*.pb.go`.
- **Dependency direction.** "Domain layer must not import from infrastructure layer."
- **Frozen module.** "No edits to `legacy/payments/` without a `legacy-edit:` commit trailer."

## Disable / amend

Edit, delete, or `chmod -x` any script. The runner skips non-executables.

## Run all locally

```
for s in .harness/fitness.d/*.sh; do echo "==> $s"; "$s"; done
```

Same scripts run inside Claude Code, in CI (call `.harness/03-verify.sh`), and from pre-commit. One source of truth.

## Why this dimension is project-local

Lint rules generalise across projects of the same language. Tests are owned by the project but use a generic runner. Architecture rules cannot be generalised — they encode decisions that are valid *only* in this codebase. That's why fitness functions live under `.harness/`, version-controlled with the code.
