#!/usr/bin/env bash
# Fitness: detect circular imports via madge. Requires `npm i -D madge`.
set -u
command -v npx >/dev/null 2>&1 || exit 0
[ -d src ] || exit 0
out="$(npx --no-install madge --circular src/ 2>&1)"; rc=$?
case "$out" in *"No circular dependency found"*) exit 0 ;; esac
[ $rc -ne 0 ] && [ -z "$out" ] && exit 0  # madge not installed
echo "Circular dependency detected:" >&2
printf '%s\n' "$out" | head -n 10 >&2
exit 1
