# harness — a lean modular harness for Claude Code

A small, modular harness around Claude Code that turns your editor session into a feedback-controlled coding agent. Catches lint and type errors as Claude writes, runs your project's tests on `Stop`, scans the working diff for secrets, and surfaces an on-demand AI diff review.

Inspired by [Martin Fowler — *Harness Engineering for Coding Agents*](https://martinfowler.com/articles/harness-engineering.html). Every script in this repo maps to one of the article's three quality dimensions (maintainability, behaviour, architecture fitness) or one of its two control types (feedforward / feedback).

## What you get

| Hook                   | Wired to                            | Type                | Job                                              |
|------------------------|-------------------------------------|---------------------|--------------------------------------------------|
| `01-context.sh`        | `UserPromptSubmit`                  | Feedforward         | Inject git state + errors from the previous run  |
| `02-checks.sh`         | `PostToolUse` (Edit\|Write\|MultiEdit) | Feedback (computational) | Lint + type-check the file Claude just changed |
| `03-verify.sh`         | `Stop`                              | Feedback (computational) | Secret scan + run project tests + fitness checks |
| `/review-diff` skill   | on demand                           | Feedback (inferential) | Spawn the `reviewer` agent against `git diff HEAD` |
| `/harness-init` skill  | on demand                           | Setup               | Scaffold project-local fitness checks under `.harness/fitness.d/` |
| `/harness-vendor` skill | on demand                          | Setup               | Eject a self-contained copy of the harness into `<repo>/.harness/` |

All hooks are **soft mode** — they always exit 0 and surface findings on stderr or via `<harness:last-errors>` in the next prompt. Sensors inform; they never block.

## Install

### As a Claude Code plugin (recommended)

    /plugin marketplace add leondixon/harness
    /plugin install harness@harness

The hooks wire themselves; the three skills (`/review-diff`, `/harness-init`, `/harness-vendor`) become available immediately.

### Manual

    git clone https://github.com/leondixon/harness ~/Documents/claude/harness
    ~/Documents/claude/harness/install.sh

The installer copies the harness modules to `~/.claude/harness/`, the skills to `~/.claude/skills/`, the agent to `~/.claude/agents/`, and patches `~/.claude/settings.json` with the three hooks.

## Project setup

The harness is inactive until a project has a `.harness/` directory. Two commands set that up:

- `/harness-vendor` — copy all harness modules into `<repo>/.harness/`. This activates the harness for the project and makes the scripts runnable in CI and pre-commit. Commit `.harness/` so teammates share the same harness. To deactivate: `rm -rf .harness/`.
- `/harness-init` — drop only starter architecture-fitness checks (`cycles.sh`, `todos.sh`, `layers.sh.example`) into `.harness/fitness.d/`. They run on every `Stop`. Edit them; commit them.

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
├── harness-init/SKILL.md
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

Each module is small (≤30 lines) and runs standalone. Edit a module, run `harness/test/run.sh`, done. Add a new language by dropping a script into `checks.d/<lang>.sh` and wiring the extension in `02-checks.sh`'s `case` block. Add a new sensor by dropping an executable into `verify.d/`.

## License

MIT.
