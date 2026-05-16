#!/usr/bin/env bash
# Manual install — copies dispatchers, modules, skills, and agent into ~/.claude/
# and patches ~/.claude/settings.json with the three hooks.
#
# The harness is inactive until a project runs /vendor to populate
# its .harness/ directory. Dispatchers exit 0 silently in projects without one.
#
# Idempotent: re-running upgrades existing files; never deletes user content.
set -eu

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude"
SETTINGS="$DEST/settings.json"

echo "==> harness manual install"
echo "    source: $SRC"
echo "    dest:   $DEST"

mkdir -p "$DEST/harness" "$DEST/skills" "$DEST/agents" "$DEST/state"

cp -r "$SRC/harness/." "$DEST/harness/"
chmod +x "$DEST/harness"/0?-*.sh "$DEST/harness/lib.sh" \
         "$DEST/harness/checks.d"/*.sh \
         "$DEST/harness/verify.d"/*.sh \
         "$DEST/harness/context.d"/*.sh \
         "$DEST/harness/test/run.sh" 2>/dev/null || true
find "$DEST/harness/fitness.d" -type f -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

cp -r "$SRC/skills/." "$DEST/skills/"
cp -r "$SRC/agents/." "$DEST/agents/"

echo "==> patching $SETTINGS"
if ! command -v jq >/dev/null 2>&1; then
  echo "    jq not found — install jq, or copy hook entries from .claude-plugin/plugin.json into $SETTINGS by hand."
  exit 1
fi
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

tmp="$(mktemp)"
jq '
  .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // [])
    | .hooks.UserPromptSubmit |=
        (map(select((.hooks // []) | map(.command) | any(. == "$HOME/.claude/harness/01-context.sh") | not))
         + [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/harness/01-context.sh" }] }])
  | .hooks.PostToolUse = (.hooks.PostToolUse // [])
    | .hooks.PostToolUse |=
        (map(select((.hooks // []) | map(.command) | any(. == "$HOME/.claude/harness/02-checks.sh") | not))
         + [{ "matcher": "Edit|Write|MultiEdit", "hooks": [{ "type": "command", "command": "$HOME/.claude/harness/02-checks.sh" }] }])
  | .hooks.Stop = (.hooks.Stop // [])
    | .hooks.Stop |=
        (map(select((.hooks // []) | map(.command) | any(. == "$HOME/.claude/harness/03-verify.sh") | not))
         + [{ "hooks": [{ "type": "command", "command": "$HOME/.claude/harness/03-verify.sh" }] }])
' "$SETTINGS" > "$tmp"
mv "$tmp" "$SETTINGS"

echo "==> smoke test"
"$DEST/harness/test/run.sh"

echo
echo "Installed. Two skills are now available: /review-diff, /vendor."
echo "Run /vendor inside a project to activate the harness for that repo."
echo "Open a fresh Claude Code session to pick up the hook changes."
