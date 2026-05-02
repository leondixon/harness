# Project fitness functions

This directory holds architecture fitness functions for **this project**. They are run by the global Claude harness on every `Stop`, plus on demand:

    .harness/fitness.d/<name>.sh        # one check per file, executable
    .harness/fitness.d/*.example        # templates — rename to *.sh to enable

Each script:

- Reads from the working tree (or `git diff`) — no args.
- Exits **0** on pass, non-zero on violation.
- Prints the violation summary on stderr (≤10 lines).

Violations get persisted to `~/.claude/state/last-errors.log` and surface at the start of the next prompt as `<harness:last-errors>`.

## Disable / amend

Edit, delete, or `chmod -x` any script. The runner skips non-executables.

## Run all locally

    for s in .harness/fitness.d/*.sh; do echo "==> $s"; "$s"; done
