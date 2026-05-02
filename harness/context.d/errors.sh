#!/usr/bin/env bash
# Inject errors recorded by the previous PostToolUse / Stop run.
set -u
_DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$_DIR/../lib.sh}"
log="$(harness_state_dir)/last-errors.log"
[ -s "$log" ] || exit 0
printf '<harness:last-errors>\n'
tail -n 50 "$log"
printf '</harness:last-errors>\n'
