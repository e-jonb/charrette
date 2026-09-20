#!/usr/bin/env bash
# One-time setup after cloning. Run: ./scripts/install-hooks.sh
#
# Git hooks in .git/hooks/ are local-only and never travel with a clone, which
# is why the hooks live in .githooks/ and this script points git at them. That
# makes the hook a tracked file at the cost of one manual step per clone. The
# step is here rather than in a README because a README instruction that must
# be followed to be protected is not protection.
#
# Everything repo-specific is read from .private-paths. This script is meant to
# be identical in every repo that has it.

set -e
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true
chmod +x scripts/*.sh 2>/dev/null || true

INSTALLED=()
INSTALLED+=(".githooks/pre-commit – PII scan + private-path block")

# Private directories are gitignored, so they do not survive a clone. Recreate
# the ones declared in .private-paths as plain paths; a `dirname:` entry names
# a convention rather than a location, so there is nothing to create for it.
if [ -f .private-paths ]; then
  CREATED=()
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$line" ] || continue
    case "$line" in
      dirname:*) continue ;;
      *.*)       continue ;;   # looks like a file, not a directory
    esac
    if [ ! -d "$line" ]; then
      mkdir -p "$line"
      CREATED+=("$line")
    fi
  done < .private-paths
  if [ "${#CREATED[@]}" -gt 0 ]; then
    INSTALLED+=("recreated gitignored private dirs: ${CREATED[*]}")
  fi
fi

# Only meaningful in a repo that actually has submodules. This makes pull and
# checkout recurse into them; it does NOT catch the parent's pin lagging the
# submodule's own origin, which is what sync.sh is for.
if [ -f .gitmodules ]; then
  git config submodule.recurse true
  INSTALLED+=("submodule.recurse=true – pull and checkout recurse into submodules")
fi

echo "Installed:"
printf '  %s\n' "${INSTALLED[@]}"
echo

if [ -f scripts/sync.sh ]; then
  echo "Start each session with ./scripts/sync.sh rather than a bare git pull."
  echo
fi

if [ -f scripts/test-pii-hook.sh ]; then
  echo "Before trusting the hook, watch it fail once:"
  echo "  ./scripts/test-pii-hook.sh"
  echo
  echo "A scan whose passing result is 'nothing found' is worth nothing until you"
  echo "have seen it fire. House rule, learned the hard way on a scan that"
  echo "reported clean for every category while reading no files."
  echo
fi

echo "To bypass the PII scan for a known false positive:"
echo "  ALLOW_PII=1 git commit ..."
echo "To escalate the low-severity tier to blocking:"
echo "  PII_STRICT=1 git commit ..."
