#!/usr/bin/env bash
# PostToolUse hook: enforce markdown conventions on files Claude writes.
#
# Self-contained: reads only scripts/md-conventions.py from this repo. charrette
# is meant to be cloned standalone with no dependency on any other repo, so this
# does not search siblings or parent directories the way a shared workspace copy
# of this hook might.
#
# Behavior:
#   - hard breaks : auto-fixed silently (structural, no meaning changes)
#   - em dashes   : reported to Claude via exit 2, so Claude fixes its own
#                   prose and leaves quoted source material alone
#
# Never blocks and never fails the turn. If the checker script is missing
# (e.g. an incomplete checkout), exits 0 quietly rather than nagging.

input=$(cat)

file_path=$(printf '%s' "$input" | python3 -c \
  'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))' \
  2>/dev/null)

# Only markdown, and only files that still exist.
case "$file_path" in
  *.md|*.markdown) ;;
  *) exit 0 ;;
esac
[ -f "$file_path" ] || exit 0

checker="${CLAUDE_PROJECT_DIR}/scripts/md-conventions.py"
[ -f "$checker" ] || exit 0

# Scope reporting to what actually changed. If the file is tracked, only lines
# differing from HEAD are considered "just written" - otherwise editing one line
# of a legacy doc would dump every pre-existing em dash in it. Untracked files
# are new, so everything in them is fair game.
scope_args=()
if git -C "$(dirname "$file_path")" ls-files --error-unmatch "$file_path" \
     >/dev/null 2>&1; then
  scope_args=(--added-lines HEAD)
fi

python3 "$checker" --fix --quiet "${scope_args[@]}" "$file_path" \
  2>/tmp/md-conventions-hook.err
status=$?

# Exit 2 surfaces stderr to Claude as feedback it can act on. Only em dash
# findings reach here, since --fix already resolved the hard breaks.
if [ "$status" -eq 2 ]; then
  cat /tmp/md-conventions-hook.err >&2
  exit 2
fi

exit 0
