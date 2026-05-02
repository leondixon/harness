#!/usr/bin/env bash
# UserPromptSubmit dispatcher. Runs each module in .harness/context.d/.
# Exits 0 silently when no project .harness/ exists.
#
# Test:  echo '{}' | ./01-context.sh
set -u
DIR="$(dirname "$(readlink -f "$0")")"
source "${HARNESS_LIB:-$DIR/lib.sh}"

seen=""
while IFS= read -r base; do
  export HARNESS_LIB="$base/lib.sh"
  [ -d "$base/context.d" ] || continue
  for m in "$base/context.d"/*.sh; do
    [ -x "$m" ] || continue
    n="$(basename "$m")"
    case " $seen " in *" $n "*) continue ;; esac
    seen="$seen $n"
    "$m"
  done
done < <(harness_module_bases)
exit 0
