# harness — a lean modular harness for Claude Code

A small, modular harness around Claude Code that turns your editor session into a feedback-controlled coding agent. Catches lint and type errors as Claude writes, runs your project's tests on `Stop`, scans the working diff for secrets, and surfaces an on-demand AI diff review.

Inspired by [Martin Fowler — *Harness Engineering for Coding Agents*](https://martinfowler.com/articles/harness-engineering.html). Every sensor in this repo maps to one of the article's three quality dimensions:

- **[Maintainability](MAINTAINABILITY.md)** — lint and type checks, per-file, on every edit.
- **[Behaviour](BEHAVIOUR.md)** — project tests and secret-leak scan, on every Stop.
- **[Architecture fitness](ARCHITECTURE.md)** — project-local rules under `.harness/fitness.d/`.

## What you get

| Hook                   | Wired to                            | Dimension                              | Job                                              |
|------------------------|-------------------------------------|----------------------------------------|--------------------------------------------------|
| `01-context.sh`        | `UserPromptSubmit`                  | feedforward                            | Inject git state + errors from the previous run  |
| `02-checks.sh`         | `PostToolUse` (Edit\|Write\|MultiEdit) | [maintainability](MAINTAINABILITY.md) | Lint + type-check the file Claude just changed |
| `03-verify.sh`         | `Stop`                              | [behaviour](BEHAVIOUR.md) + [architecture](ARCHITECTURE.md) | Secret scan + project tests + fitness checks |
| `/review-diff` skill   | on demand                           | feedback (inferential)                 | Spawn the `reviewer` agent against `git diff HEAD` |
| `/harness-vendor` skill | on demand                          | setup                                  | Vendor the harness into `<repo>/.harness/` and seed starter fitness checks |

All hooks are **soft mode** — they always exit 0 and surface findings on stderr or via `<harness:last-errors>` in the next prompt. Sensors inform; they never block.

## Install

### As a Claude Code plugin (recommended)

    /plugin marketplace add leondixon/harness
    /plugin install harness@harness

The hooks wire themselves; the two skills (`/review-diff`, `/harness-vendor`) become available immediately.

### Manual

    git clone https://github.com/leondixon/harness ~/Documents/claude/harness
    ~/Documents/claude/harness/install.sh

The installer copies the harness modules to `~/.claude/harness/`, the skills to `~/.claude/skills/`, the agent to `~/.claude/agents/`, and patches `~/.claude/settings.json` with the three hooks.

## Project setup

The harness is inactive until a project has a `.harness/` directory. One command sets that up:

    /harness-vendor

This copies all harness modules into `<repo>/.harness/` (activating the harness), detects the project's primary language, and seeds starter architecture fitness checks (`cycles.sh`, `todos.sh`, `layers.sh.example`) under `.harness/fitness.d/`. Commit `.harness/` so teammates share the same harness. To deactivate: `rm -rf .harness/`.

## Layout

```
harness/                         # the modules (also at <repo>/.harness/ when vendored)
├── lib.sh                       # shared helpers
├── 01-context.sh                # UserPromptSubmit dispatcher
├── 02-checks.sh                 # PostToolUse dispatcher
├── 03-verify.sh                 # Stop dispatcher
├── context.d/{git,errors}.sh
├── checks.d/{python,node,go,dart,rust}.sh
├── verify.d/{secrets,tests,review-hint,project-fitness}.sh
├── templates/                   # starter fitness checks
└── test/run.sh                  # smoke test
skills/
├── harness-vendor/SKILL.md
└── review-diff/SKILL.md
agents/reviewer.md
```

## Test the install

    harness/test/run.sh                  # from this source repo
    .harness/test/run.sh                 # from a vendored project

Each module is also runnable standalone from a vendored project:

    .harness/checks.d/python.sh /tmp/foo.py
    .harness/verify.d/secrets.sh
    .harness/context.d/git.sh

## Outside Claude Code

After `/harness-vendor`, `.harness/02-checks.sh <file>` and `.harness/03-verify.sh` are plain shell scripts. Wire them into pre-commit:

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: harness-checks
      name: harness checks
      entry: ./.harness/02-checks.sh
      language: system
      types_or: [python, javascript, typescript, go, rust, dart]
      pass_filenames: true
    - id: harness-verify
      name: harness verify
      entry: ./.harness/03-verify.sh
      language: system
      pass_filenames: false
      always_run: true
      stages: [pre-push]
```

Or call them from CI directly. Same scripts, no Claude required.

## State

`~/.claude/state/` (user-level runtime, not in repo):

- `last-errors.log` — written by `02-checks.sh` and `verify.d/tests.sh`, read by `context.d/errors.sh` next prompt.
- `last-tests.log` — full output of the most recent test run.
- `skip-tests` (touch to disable the test sensor for this session).

## Customize

Each module is small (≤30 lines) and runs standalone. Edit a module, run `harness/test/run.sh`, done. Per-dimension extension guides:

- Add a language → [MAINTAINABILITY.md](MAINTAINABILITY.md#adding-a-language)
- Tune tests or secrets scan → [BEHAVIOUR.md](BEHAVIOUR.md)
- Write a fitness function → [ARCHITECTURE.md](ARCHITECTURE.md#writing-your-own)

## License

MIT.
