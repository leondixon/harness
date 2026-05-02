#!/usr/bin/env bash
# Dimension: behaviour (boundary leak)
# Scan working diff for likely secrets.
set -u
diff="$(git diff HEAD 2>/dev/null; git diff --cached 2>/dev/null)"
[ -z "$diff" ] && exit 0
hits="$(printf '%s' "$diff" | grep -nE \
  -e 'AWS_(ACCESS|SECRET)_KEY' \
  -e 'sk-[A-Za-z0-9_-]{20,}' \
  -e 'ghp_[A-Za-z0-9]{30,}' \
  -e '-----BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY-----' \
  -e '(password|secret|api[_-]?key|token)[[:space:]]*[:=][[:space:]]*['"'"'"][^'"'"'"]{6,}' \
  2>/dev/null | head -n 10)"
[ -n "$hits" ] && printf '[verify:secrets] possible secrets in diff:\n%s\n' "$hits" >&2
exit 0
