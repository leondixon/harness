#!/usr/bin/env bash
# Dimension: meta (workflow nudge, not a quality sensor)
# Suggest /review-diff when the working diff is substantial.
set -u
diff="$(git diff HEAD 2>/dev/null; git diff --cached 2>/dev/null)"
loc="$(printf '%s' "$diff" | wc -l | tr -d ' ')"
[ "$loc" -gt 50 ] && \
  echo "[verify:review] $loc diff lines — consider /review-diff for an adversarial AI critique" >&2
exit 0
