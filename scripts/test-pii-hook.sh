#!/usr/bin/env bash
# Prove the pre-commit PII hook can actually fail, and that it is tiered.
#
# A negative result from a scan that never ran is indistinguishable from a
# negative result from a scan that ran and found nothing. This tells them
# apart, and also checks that the low-severity tier does NOT block - a hook
# that blocks on a clinic phone number gets bypassed reflexively, which is
# the same as having no hook.
#
# THREE TIERS, THREE CASES. The hook has a high-severity pattern tier, a
# low-severity pattern tier, and a path tier, and passing one says nothing
# about the others. This script tested only the pattern tiers until
# 2026-09-19, which is how three repos ran a passing self-test while one of
# them had a path tier pointed at a directory it did not have. A self-test
# proves the tier it exercises and reads as proof of the whole check.
#
# The path case derives its fixture from .private-paths rather than naming a
# directory, because hardcoding a path here would reintroduce exactly the bug
# it exists to catch.

set -uo pipefail
cd "$(dirname "$0")/.."

HIGH="pii-selftest-high.md"
LOW="pii-selftest-low.md"
# PROBE is reset too: the path tier may stage a real, pre-existing private
# file, and it must never be left in the index if this script dies mid-run.
PROBE=""
trap 'git reset -q -- "$HIGH" "$LOW" ${PROBE:+"$PROBE"} 2>/dev/null; rm -f "$HIGH" "$LOW"' EXIT

fail=0

printf '# fixture\n\nSSN: 123-45-6789\n' > "$HIGH"
git add -f "$HIGH"
./.githooks/pre-commit >/dev/null 2>&1
st=$?
git reset -q -- "$HIGH"; rm -f "$HIGH"
if [ "$st" -ne 0 ]; then
  echo "PASS  high severity: a planted SSN was refused (exit $st)"
else
  echo "FAIL  high severity: an SSN was allowed through. The hook is not protecting you."
  fail=1
fi

printf '# fixture\n\nClinic: (513) 555-0142, front.desk@example.org\n' > "$LOW"
git add -f "$LOW"
OUT=$(./.githooks/pre-commit 2>&1); st=$?
git reset -q -- "$LOW"; rm -f "$LOW"
if [ "$st" -eq 0 ] && printf '%s' "$OUT" | grep -q 'NOTICE'; then
  echo "PASS  low severity: a phone and email were reported but not blocked"
elif [ "$st" -ne 0 ]; then
  echo "FAIL  low severity: a clinic phone number blocked the commit. This hook"
  echo "      will be bypassed with ALLOW_PII=1 as a reflex within a week."
  fail=1
else
  echo "FAIL  low severity: nothing was reported at all. The scan may not have run."
  fail=1
fi

# ---- path tier ------------------------------------------------------------
# Take the first declaration in .private-paths and plant a file behind it.
# dirname:NAME becomes NAME/, a plain path is used as-is.
# EVERY declaration, not the first. Testing one path is the same mistake as
# testing one tier: the repo this was written for declares `dirname:_private`
# first, and the broken hook covered _private too - so a first-only test
# passed against the exact hook it exists to catch.
PRIVS=()
if [ -f .private-paths ]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$line" ] || continue
    case "$line" in
      dirname:*) PRIVS+=("${line#dirname:}") ;;
      *)         PRIVS+=("${line%/}") ;;
    esac
  done < .private-paths
fi
[ "${#PRIVS[@]}" -gt 0 ] || PRIVS=("_private")

for PRIV in "${PRIVS[@]}"; do
  case "$PRIV" in
    *.*) PROBE="$PRIV" ;;          # a declared file, not a directory
    *)   PROBE="$PRIV/pii-selftest-path.md" ;;
  esac

  # A declared file that already exists is staged AS-IS rather than replaced.
  # Its content is never read, written or removed - only the index is touched,
  # and only until the reset two lines later. Skipping it instead would leave
  # the tier unexercised in exactly the repos that have the most to lose, and
  # a test that can never pass is a test that gets ignored.
  PLANTED=0
  if [ ! -e "$PROBE" ]; then
    mkdir -p "$(dirname "$PROBE")" 2>/dev/null || true
    if ! printf '# fixture\n\nnothing sensitive, this is a path test\n' > "$PROBE" 2>/dev/null; then
      echo "SKIP  path tier '$PRIV': could not plant a fixture. Not a pass."
      fail=1
      continue
    fi
    PLANTED=1
  fi

  git add -f "$PROBE" >/dev/null 2>&1
  OUT=$(./.githooks/pre-commit 2>&1); st=$?
  git reset -q -- "$PROBE" 2>/dev/null || true
  [ "$PLANTED" -eq 1 ] && rm -f "$PROBE"

  if [ "$st" -ne 0 ] && printf '%s' "$OUT" | grep -q 'BLOCKED'; then
    echo "PASS  path tier: staging a file under '$PRIV' was refused"
  else
    echo "FAIL  path tier: a file under '$PRIV' was allowed through (exit $st)."
    echo "      The hook is guarding something other than this repo's declared"
    echo "      private paths. Check .private-paths against the scan line."
    fail=1
  fi
done

# ---- scope is reported at all ---------------------------------------------
# Cheap, and it is the output that makes a misconfigured hook visible.
printf '# fixture\n\nplain\n' > "$LOW"
git add -f "$LOW" >/dev/null 2>&1
OUT=$(./.githooks/pre-commit 2>&1)
git reset -q -- "$LOW" 2>/dev/null || true; rm -f "$LOW"
if printf '%s' "$OUT" | grep -q 'guarding \['; then
  echo "PASS  scope: the scan line names what it is guarding"
else
  echo "FAIL  scope: the scan line does not say what it guards, so a hook"
  echo "      pointed at nothing looks exactly like a clean scan."
  fail=1
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "Hook verified: blocks what must never land, reports what usually is fine,"
  echo "guards this repo's declared private paths, and says so on every commit."
else
  echo "Hook NOT verified. Do not rely on it."
fi
exit "$fail"
