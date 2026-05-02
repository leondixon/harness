#!/usr/bin/env bash
# UserPromptSubmit dispatcher. Runs each module in context.d/.
# Project's <repo>/.harness/context.d/<name>.sh shadows global by filename.
#
# Test:  echo '{}' | ./01-context.sh
set -u
DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$DIR/lib.sh}"
export HARNESS_LIB="$DIR/lib.sh"

seen=""
while IFS= read -r base; do
  [ -d "$base/context.d" ] || continue
  for m in "$base/context.d"/*.sh; do
    [ -x "$m" ] || continue
    n="$(basename "$m")"
    case " $seen " in *" $n "*) continue ;; esac
    seen="$seen $n"
    "$m"
  done
done < <(harness_module_bases "$DIR")
exit 0
