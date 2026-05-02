#!/usr/bin/env bash
# Inject errors recorded by the previous PostToolUse / Stop run.
set -u
source "${HARNESS_LIB:-$HOME/.claude/harness/lib.sh}"
log="$(harness_state_dir)/last-errors.log"
[ -s "$log" ] || exit 0
printf '<harness:last-errors>\n'
tail -n 50 "$log"
printf '</harness:last-errors>\n'
