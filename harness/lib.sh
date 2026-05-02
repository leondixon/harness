# Shared helpers for harness modules. Source, don't execute.
#   source "${HARNESS_LIB:-$HOME/.claude/harness/lib.sh}"

harness_state_dir() {
  echo "${CLAUDE_HARNESS_STATE:-$HOME/.claude/state}"
}

# Emit base directories for harness modules in priority order.
# Project (<repo>/.harness) shadows global (~/.claude/harness) by filename.
harness_module_bases() {
  local global="${1:-$HOME/.claude/harness}"
  local root
  if root="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -d "$root/.harness" ]; then
    echo "$root/.harness"
  fi
  echo "$global"
}

# Walk up from a file or dir to the nearest project root marker.
harness_project_root() {
  local d="$1"
  [ -d "$d" ] || d="$(dirname "$d")"
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    for m in package.json pyproject.toml go.mod Cargo.toml pubspec.yaml; do
      [ -f "$d/$m" ] && { echo "$d"; return 0; }
    done
    d="$(dirname "$d")"
  done
  return 1
}

# Run a command. On failure, print to stderr AND append to $HARNESS_ERR_LOG (if set).
# $1 = label (e.g. "lint:ruff"), rest = command.
harness_run() {
  local label="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [ $rc -ne 0 ]; then
    printf '[%s] FAIL\n%s\n' "$label" "$out" >&2
    [ -n "${HARNESS_ERR_LOG:-}" ] && printf '[%s] FAIL\n%s\n' "$label" "$out" >> "$HARNESS_ERR_LOG"
  elif [ -n "$out" ]; then
    printf '[%s]\n%s\n' "$label" "$out" >&2
  fi
  return 0
}
