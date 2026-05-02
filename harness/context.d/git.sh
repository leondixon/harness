#!/usr/bin/env bash
# Inject git branch + dirty-count.
set -u
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
branch="$(git symbolic-ref --short HEAD 2>/dev/null || echo detached)"
dirty="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
printf '<harness:git>branch=%s changes=%s</harness:git>\n' "$branch" "$dirty"
