#!/usr/bin/env bash
# Stop dispatcher. Runs every module in .harness/verify.d/.
# Exits 0 silently when no project .harness/ exists.
#
# Test:  ./03-verify.sh < /dev/null
set -u
DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$DIR/lib.sh}"
STATE="$(harness_state_dir)"; mkdir -p "$STATE"
export HARNESS_ERR_LOG="$STATE/last-errors.log"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
cd "$(git rev-parse --show-toplevel)" || exit 0

seen=""
while IFS= read -r base; do
  export HARNESS_LIB="$base/lib.sh"
  [ -d "$base/verify.d" ] || continue
  for m in "$base/verify.d"/*.sh; do
    [ -x "$m" ] || continue
    n="$(basename "$m")"
    case " $seen " in *" $n "*) continue ;; esac
    seen="$seen $n"
    "$m"
  done
done < <(harness_module_bases)
exit 0
