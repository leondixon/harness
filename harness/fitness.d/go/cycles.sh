#!/usr/bin/env bash
# Fitness: detect Go import cycles. The Go compiler rejects them; this catches
# them earlier and surfaces the error pair clearly.
set -u
command -v go >/dev/null 2>&1 || exit 0
out="$(go build ./... 2>&1 | grep -i 'import cycle' || true)"
[ -z "$out" ] && exit 0
echo "Go import cycle detected:" >&2
printf '%s\n' "$out" | head -n 10 >&2
exit 1
