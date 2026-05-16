#!/usr/bin/env bash
# Dimension: architecture
# Run architecture fitness functions from <repo>/.harness/fitness.d/.
# Each script exits 0 (pass) or non-zero (violation). Failures are surfaced and
# appended to $HARNESS_ERR_LOG so the next prompt sees them.
set -u
DIR=".harness/fitness.d"
[ -d "$DIR" ] || exit 0

find "$DIR" -type f -name '*.sh' -perm -111 | sort | while IFS= read -r s; do
  [ -x "$s" ] || continue
  out="$("$s" 2>&1)"; rc=$?
  name="${s#"$DIR"/}"
  name="${name%.sh}"
  if [ $rc -ne 0 ]; then
    printf '[fitness:%s] FAIL\n%s\n' "$name" "$out" >&2
    [ -n "${HARNESS_ERR_LOG:-}" ] && \
      printf '[fitness:%s] FAIL\n%s\n' "$name" "$out" >> "$HARNESS_ERR_LOG"
  elif [ -n "$out" ]; then
    printf '[fitness:%s]\n%s\n' "$name" "$out" >&2
  fi
done
exit 0
