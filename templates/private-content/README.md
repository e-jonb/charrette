# Private Content Set

**What:** Everything a scaffolded solution needs when it will hold gitignored private content \
**Triggered by:** Item 17 of the File Generation Order in `CLAUDE.md` \
**Status:** Canonical. Copy from here; do not fork per repo

---

## The problem this exists for

A folder excluded from git is excluded from the backup, the sync and the disaster recovery, all at once and silently, because git is all three. And the excluded folder is by definition the one holding what would hurt most to lose: the scans, the records, the notes with real names in them. Everything else in the repo is one clone away from safe.

So a repo that gitignores private content has two exposures, and they need different answers:

| Exposure | What it looks like | What answers it |
|---|---|---|
| **Leak** | Private content gets committed, usually via `git add -f` or a path nobody realized was tracked | `.githooks/pre-commit` |
| **Loss** | Private content is deleted, overwritten, or taken by `git clean -xdf`, and no copy exists | `scripts/backup-private.sh` |

A commit hook cannot stop `rm`. Do not read a passing hook as "the private content is safe" – it is a statement about one of the two exposures.

## The pieces

| File | What it does |
|---|---|
| `scripts/backup-private.sh` | Mirrors the declared paths to a backup directory. `--check` is a tripwire worth running at session start |
| `.githooks/pre-commit` | Blocks anything staged from a private path, blocks SSNs and credentials, reports contact-shaped patterns without blocking |
| `scripts/install-hooks.sh` | Points git at `.githooks/`, recreates gitignored private directories after a clone, and tells the reader to prove the hook can fail |
| `scripts/test-pii-hook.sh` | Proves it. Plants an SSN and expects a refusal, plants a clinic phone number and expects a report rather than a refusal |
| `.private-paths` | **The only file that should differ between repos.** Declares what is irreplaceable |
| `.pii-allowlist` | Public institutional contacts that would otherwise trip the low-severity tier |

## The one rule

**Per-repo variation goes in `.private-paths`. Nowhere else.** Both the hook and the backup script read it, so a correct `.private-paths` makes both correct without either script being edited.

This is not a style preference. The hook in this framework's parent workspace once hardcoded one repo's private paths and was then copied verbatim into two more. One of those repos gitignored `documents/` and got a hook checking for `documents/print-ready/`, so staging a real document there was not blocked – while the hook printed its usual `pii-scan: N added line(s) across N file(s)` and exited 0. It looked exactly like a hook that had run and found nothing, because it had: in the wrong place.

## Two design decisions worth keeping

**Diff-scoped, not whole-file.** Only lines the commit adds are scanned. Measured on a real records repo, whole-file scanning flagged 39% of tracked files, nearly all legitimate agency phone numbers in ordinary correspondence. A check that fires on a legitimate case in its first week is a check nobody runs by its second. The same reasoning applies to any check retrofitted onto an existing codebase.

**Severity-tiered, not uniform.** An SSN or a credential is unambiguous and blocks. An email, phone or street address is usually an office, so it reports and does not block unless `PII_STRICT=1`. A hook that blocks on a clinic phone number gets bypassed reflexively within a week, which is the same as having no hook. `test-pii-hook.sh` asserts both halves, including that the low tier does **not** block.

## Installing into a solution

```bash
cp $FRAMEWORK/scripts/backup-private.sh   scripts/
cp $FRAMEWORK/scripts/install-hooks.sh    scripts/
cp $FRAMEWORK/scripts/test-pii-hook.sh    scripts/
mkdir -p .githooks && cp $FRAMEWORK/.githooks/pre-commit .githooks/
cp $FRAMEWORK/templates/private-content/.private-paths .
cp $FRAMEWORK/templates/private-content/.pii-allowlist .
chmod +x scripts/*.sh .githooks/pre-commit
```

Then, in order:

1. **Edit `.private-paths`** for this solution. This is the step that matters and the only one that is not mechanical.
2. Add `.private-backup-dir` to `.gitignore`, along with the private paths themselves.
3. Run `./scripts/install-hooks.sh`.
4. Run `./scripts/test-pii-hook.sh` and read the output. Both tiers should pass.
5. Write the **Private Content Backup** and **What can actually destroy private content** sections into the solution's `CLAUDE.md`.

Step 4 is not optional. A scan whose passing result is "nothing found" is indistinguishable from a scan that never ran, and both print the same thing.

## Tuning it for your domain

Two places are meant to be edited, and only these two:

- **`CRED_RE` in the hook**, for credential shapes specific to your work – a portal's login-ID naming, a vendor's token prefix. Keep additions high-confidence, because this tier blocks.
- **`.pii-allowlist`**, for public institutional contacts. Never a person, and every entry needs a reason on the line above it. An allowlist without reasons becomes where people quietly park things they did not want to deal with.
