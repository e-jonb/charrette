#!/usr/bin/env bash
# Prove the pre-commit PII hook can actually fail, and that it is tiered.
#
# A negative result from a scan that never ran is indistinguishable from a
# negative result from a scan that ran and found nothing. This tells them
# apart, and also checks that the low-severity tier does NOT block - a hook
# that blocks on a clinic phone number gets bypassed reflexively, which is
# the same as having no hook.

set -uo pipefail
cd "$(dirname "$0")/.."

HIGH="pii-selftest-high.md"
LOW="pii-selftest-low.md"
trap 'git reset -q -- "$HIGH" "$LOW" 2>/dev/null; rm -f "$HIGH" "$LOW"' EXIT

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

echo
[ "$fail" -eq 0 ] && echo "Hook verified: blocks what must never land, reports what usually is fine." \
                  || echo "Hook NOT verified. Do not rely on it."
exit "$fail"
