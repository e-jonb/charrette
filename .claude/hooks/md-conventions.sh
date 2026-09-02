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

# Scoping is NOT passed from here. The checker defaults to diffing a tracked
# file against HEAD, so only lines just written are reported and legacy content
# is left alone. That default deliberately lives in the checker: this file is
# COPIED into each repo that adopts the convention, so any behavior kept here
# drifts out of date the moment the rules change, and an old copy that scopes
# nothing dumps pre-existing findings the author never touched. Keep this file
# free of behavior so a years-old copy still does the right thing.
python3 "$checker" --fix --quiet "$file_path" 2>/tmp/md-conventions-hook.err
status=$?

# Exit 2 surfaces stderr to Claude as feedback it can act on. Only em dash
# findings reach here, since --fix already resolved the hard breaks.
if [ "$status" -eq 2 ]; then
  cat /tmp/md-conventions-hook.err >&2
  exit 2
fi

exit 0
