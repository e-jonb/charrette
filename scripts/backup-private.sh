#!/usr/bin/env bash
# Back up the gitignored private content of this repo.
#
# WHY THIS EXISTS
#
# `_private/` and friends work precisely because git cannot see them. That is
# the correct design for PII and it is also, silently, an opt-out of every
# durability mechanism this workspace has: the remote is the backup, sync.sh
# is the sync, and a re-clone is the disaster recovery. All three run through
# git. Exclude a folder from git and you exclude it from all of them at once.
#
# On 2026-09-07 the owner deliberately deleted a working directory whose work
# was fully pushed. Every tracked file came back from the remote in one
# command. Everything gitignored was gone permanently, including a document
# that had taken a session to produce.
#
# That is the case worth designing for. It was not an accident, a bug, or a
# rogue process - it was a reasonable decision made on a correct belief ("this
# is all pushed") that happens to be true only of tracked files. Nothing in
# the system said otherwise. This script is the compensating control, and it
# lives next to the decision rather than in a lesson file in another repo,
# because that is exactly where the last copy of this warning was and nobody
# read it in time.
#
# WHAT IT DOES
#
# Mirrors the paths declared in `.private-paths` to a backup directory using
# rsync. A mirror, not dated archives: a records-heavy repo runs to hundreds of
# megabytes of scans, and ten tarball generations of that is gigabytes of
# duplicate data for no benefit. The threat is accidental loss, not corruption three days
# ago - git already covers the latter for everything it can see.
#
# The mirror is ADDITIVE. `--delete` is deliberately not used, because a file
# disappearing from the source is the failure being defended against, and a
# mirror that faithfully reproduces a deletion defends against nothing. The
# cost is that intentionally removing something from `_private/` leaves a copy
# in the backup. If that matters for a given file, delete it in both places.
#
# ---------------------------------------------------------------------------
# VENDORED COPY. Canonical lives in the Studio, at
# solution-architect-studio/scripts/backup-private.sh (since 2026-09-20).
#
# EDIT THE CANONICAL COPY, THEN PROPAGATE. Never edit a vendored copy in place:
# that is the drift this comment exists to prevent, and it has happened - a
# markdown bug in the manifest header was fixed in one copy on 2026-09-10 and
# the other two still had it the same day. An earlier version of this comment
# claimed the copies would "drift harmlessly." They did not. A later version
# named the three repos as siblings with no canonical among them, which left a
# reader correctly concluding that any change at all creates drift.
#
# This is deliberately NOT a shim. A shim that cannot find its canonical script
# exits quietly - survivable for a linter, unacceptable for a backup. Loud
# failure is worth the propagation step.
#
# Per-repo variation belongs in `.private-paths` and `.private-backup-dir`,
# which are data. Nothing behavioral should differ between copies - including
# the destination type, which is read from `.private-backup-dir` rather than
# branched in the script per repo.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO_ROOT="$PWD"
REPO_NAME="$(basename "$REPO_ROOT")"

MANIFEST_MODE="full"
DRY_RUN=0
CHECK_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --safe-manifest) MANIFEST_MODE="summary" ;;
    --no-manifest)   MANIFEST_MODE="none" ;;
    --dry-run)       DRY_RUN=1 ;;
    --check)         CHECK_ONLY=1 ;;
    -h|--help)
      echo "usage: $0 [--check] [--safe-manifest|--no-manifest] [--dry-run]"
      echo
      echo "  --check          TRIPWIRE. Compare live private files against the count"
      echo "                   recorded in PRIVATE_MANIFEST.md and fail if any have"
      echo "                   gone missing. Copies nothing. Run it at session start."
      echo "  --safe-manifest  manifest lists directories and counts, not filenames"
      echo "  --no-manifest    do not write PRIVATE_MANIFEST.md"
      echo "  --dry-run        report what would be copied, copy nothing"
      exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------- declaration
if [ ! -f .private-paths ]; then
  cat >&2 <<'EOF'
ERROR: no .private-paths in this repo.

This script will not guess. `git status --ignored` is not a usable source -
it lists .DS_Store, __pycache__, node_modules, and rendered .docx/.pdf output
that is regenerable from committed markdown and does not need backing up.

Create .private-paths with one entry per line:

  records                 a literal file or directory, relative to repo root
  documents/print-ready
  dirname:_private        every directory with this name, at any depth

Optional directive, anywhere in the file:

  # manifest: summary     directory-level manifest instead of filenames
EOF
  exit 1
fi

# A `# manifest:` directive in the file overrides the default, and a
# command-line flag overrides the directive.
if [ "$MANIFEST_MODE" = "full" ]; then
  declared="$(grep -E '^[[:space:]]*#[[:space:]]*manifest:' .private-paths | tail -1 | sed 's/.*manifest:[[:space:]]*//' | tr -d '[:space:]')"
  case "$declared" in
    summary|none) MANIFEST_MODE="$declared" ;;
  esac
fi

# Read declarations into an array. A while-read loop rather than $(...) word
# splitting: zsh does not word-split unquoted expansions, and this repo has
# already been bitten once by a scan that silently examined nothing because of
# exactly that difference.
DECLARED=()
while IFS= read -r line; do
  line="${line%%#*}"
  line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [ -n "$line" ] || continue
  DECLARED+=("$line")
done < .private-paths

if [ "${#DECLARED[@]}" -eq 0 ]; then
  echo "ERROR: .private-paths contains no entries." >&2
  exit 1
fi

# ---------------------------------------------------------------- destination
if [ -n "${PRIVATE_BACKUP_DIR:-}" ]; then
  DEST="$PRIVATE_BACKUP_DIR"; DEST_SRC="PRIVATE_BACKUP_DIR"
elif [ -f .private-backup-dir ]; then
  DEST="$(head -1 .private-backup-dir | sed 's/[[:space:]]*$//')"
  DEST="${DEST/#\~/$HOME}"; DEST_SRC=".private-backup-dir"
else
  DEST="$HOME/private-backups/$REPO_NAME"; DEST_SRC="default"
fi

# The destination TYPE is data, not a per-repo code branch. A destination
# beginning `rclone:` is an rclone remote - typically a `crypt` remote over
# cloud storage - and everything downstream that assumes a local filesystem
# path has to be skipped for it. Anything else is a filesystem path and
# behaves exactly as it always has.
#
# This is what lets one repo back up to an encrypted cloud remote while its
# siblings keep writing to a local or cloud-synced folder, with no behavioral
# difference between copies of this script. Per ADR-010 in
# a repo holding org property that turns over, that split is deliberate:
# changes hands has different requirements from one person's own records.
DEST_KIND="path"
case "$DEST" in
  rclone:*)
    DEST_KIND="rclone"
    RCLONE_TARGET="${DEST#rclone:}"
    case "$RCLONE_TARGET" in
      *:*) ;;
      *) echo "ERROR: rclone destination must be remote:path, got '$RCLONE_TARGET'" >&2
         echo "       e.g. rclone:my-crypt:my-repo-name" >&2
         exit 1 ;;
    esac ;;
esac

echo "repo:        $REPO_NAME"
echo "destination: $DEST  ($DEST_SRC)"
[ "$DEST_KIND" = "rclone" ] && echo "             rclone remote - encrypted if the remote is a crypt"
echo

# ------------------------------------------------------------------- resolve
RESOLVED=()
for entry in "${DECLARED[@]}"; do
  case "$entry" in
    dirname:*)
      name="${entry#dirname:}"
      while IFS= read -r d; do
        [ -n "$d" ] && RESOLVED+=("${d#./}")
      done < <(find . -type d -name "$name" -not -path './.git/*' 2>/dev/null | sort)
      ;;
    *)
      [ -e "$entry" ] && RESOLVED+=("$entry")
      ;;
  esac
done

TOTAL_FILES=0
for p in ${RESOLVED+"${RESOLVED[@]}"}; do
  if [ -d "$p" ]; then
    n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
  else
    n=1
  fi
  TOTAL_FILES=$((TOTAL_FILES + n))
  printf '  %-48s %s file(s)\n' "$p" "$n"
done

echo
echo "declared: ${#DECLARED[@]} pattern(s) -> resolved: ${#RESOLVED[@]} path(s), $TOTAL_FILES file(s)"

# A backup that reports success having copied nothing is the failure mode this
# whole workspace keeps rediscovering. Zero is always an anomaly worth an exit
# code: either nothing private exists yet, or a declaration has gone stale.
if [ "$TOTAL_FILES" -eq 0 ]; then
  echo
  echo "NOTHING BACKED UP - 0 files matched .private-paths." >&2
  echo "Either no private content exists in this repo yet, or a declared path" >&2
  echo "is wrong. No backup was written. This is deliberately an error rather" >&2
  echo "than a quiet success." >&2
  exit 1
fi

# -------------------------------------------------------------------- tripwire
# Backups protect against loss. They do not TELL you loss happened, and a
# backup you do not know you need is a backup you restore from too late -
# after it has mirrored the deletion, or after you have forgotten what was
# there. This compares the live count against the last recorded one.
#
# It only ever complains about a DECREASE. Private content grows in normal
# use, and a check that fires on growth gets switched off within a week.
if [ -f "$REPO_ROOT/PRIVATE_MANIFEST.md" ]; then
  RECORDED="$(grep -oE '\*\*Total: [0-9]+ file' "$REPO_ROOT/PRIVATE_MANIFEST.md" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
  if [ -n "$RECORDED" ] && [ "$TOTAL_FILES" -lt "$RECORDED" ]; then
    MISSING=$((RECORDED - TOTAL_FILES))
    echo
    echo "########################################################################" >&2
    echo "  PRIVATE FILES HAVE GONE MISSING" >&2
    echo "" >&2
    echo "  PRIVATE_MANIFEST.md recorded $RECORDED file(s). $TOTAL_FILES are present." >&2
    echo "  $MISSING file(s) are gone." >&2
    echo "" >&2
    echo "  DO NOT RUN THIS SCRIPT WITHOUT --check UNTIL YOU KNOW WHY." >&2
    echo "  A normal run mirrors the current state, and the mirror is additive," >&2
    echo "  so your backup still holds them - but confirm that before assuming." >&2
    echo "" >&2
    echo "  Backup location:" >&2
    echo "    $DEST" >&2
    echo "" >&2
    echo "  If the deletion was not intentional, restore with:" >&2
    if [ "$DEST_KIND" = "rclone" ]; then
      # Whoever reads this is having a bad day and will paste what it says.
      # A restore line that is wrong for the configured destination makes the
      # tripwire worse than useless: it detects the disaster correctly and
      # then misdirects the recovery.
      echo "    rclone copy \"$RCLONE_TARGET\" \"$REPO_ROOT\" --progress" >&2
      echo "" >&2
      echo "  THIS REMOTE IS ENCRYPTED. If rclone is not already configured on" >&2
      echo "  this machine, the copy is unreadable without BOTH secrets:" >&2
      echo "    - the crypt password" >&2
      echo "    - the crypt salt (rclone calls it password2)" >&2
      echo "  Both are in the password vault with the remote's own credentials." >&2
      echo "  Filenames are encrypted too, so browsing the storage provider's" >&2
      echo "  web interface will show nothing readable. That is expected." >&2
    else
      echo "    rsync -a \"$DEST/\" \"$REPO_ROOT/\"" >&2
    fi
    echo "" >&2
    echo "  If it WAS intentional, re-run without --check to update the manifest." >&2
    echo "########################################################################" >&2
    exit 1
  fi
  # ---------------------------------------------------- staleness
  # The tripwire above catches files going missing. It cannot catch the
  # backup silently not running, because it never looks at the destination -
  # and that is a property worth keeping, since it means `--check` needs no
  # network and no credentials and can run at every session start.
  #
  # A remote destination makes the silent no-op a real failure mode: an
  # expired OAuth token, a revoked credential or a renamed remote produces a
  # backup that has not run in six weeks while every check still passes.
  #
  # The manifest's own generation timestamp closes that gap with no network.
  # It is not proof the copy succeeded - only that the script completed a run
  # recently enough to be believed.
  #
  # 30 days, because private content here moves on a roughly monthly cadence
  # (the campout field sheet is the regular producer), so a month of silence
  # is plausible in a quiet period and is exactly when nobody would notice a
  # broken backup. Shorter fires during normal quiet spells and gets ignored,
  # which is worse than not checking. Override with PRIVATE_BACKUP_MAX_AGE.
  STALE_DAYS="${PRIVATE_BACKUP_MAX_AGE:-30}"
  GENERATED="$(grep -oE '\*\*Generated:\*\*.*on [0-9]{4}-[0-9]{2}-[0-9]{2}' "$REPO_ROOT/PRIVATE_MANIFEST.md" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  if [ -n "$GENERATED" ]; then
    GEN_EPOCH="$(date -j -f '%Y-%m-%d' "$GENERATED" '+%s' 2>/dev/null || date -d "$GENERATED" '+%s' 2>/dev/null)"
    if [ -n "$GEN_EPOCH" ]; then
      AGE_DAYS=$(( ( $(date '+%s') - GEN_EPOCH ) / 86400 ))
      if [ "$AGE_DAYS" -gt "$STALE_DAYS" ]; then
        echo
        echo "WARNING: last recorded backup run was $GENERATED - $AGE_DAYS days ago." >&2
        echo "         Nothing is missing, but nothing has been backed up recently" >&2
        echo "         either. If the destination is remote, check the credential" >&2
        echo "         has not expired - that failure is silent and this warning" >&2
        echo "         is the only thing that sees it." >&2
        echo "         Run ./scripts/backup-private.sh (no --check) to refresh." >&2
      fi
    fi
  fi

  if [ "$CHECK_ONLY" -eq 1 ]; then
    echo
    echo "tripwire OK: $TOTAL_FILES file(s) present, manifest recorded ${RECORDED:-none}."
    [ -n "$GENERATED" ] && echo "             last run $GENERATED (${AGE_DAYS:-?} days ago, warn over $STALE_DAYS)."
    exit 0
  fi
elif [ "$CHECK_ONLY" -eq 1 ]; then
  echo
  echo "no PRIVATE_MANIFEST.md yet - nothing to compare against."
  echo "Run without --check once to establish a baseline."
  exit 0
fi

# --------------------------------------------------------------- destination checks
if [ "$DRY_RUN" -eq 0 ] && [ "$DEST_KIND" = "path" ]; then
  mkdir -p "$DEST" || { echo "ERROR: cannot create $DEST" >&2; exit 1; }
fi

# Preflight for a remote destination. rsync failing used to print a warning
# per path and let the script reach a cheerful "done" - survivable for a
# local copy you can eyeball, not for a remote you cannot. Fail before
# copying anything rather than half way through.
if [ "$DEST_KIND" = "rclone" ] && [ "$DRY_RUN" -eq 0 ]; then
  if ! command -v rclone >/dev/null 2>&1; then
    echo "ERROR: destination is an rclone remote but rclone is not installed." >&2
    echo "       Install it (brew install rclone) or point .private-backup-dir" >&2
    echo "       at a filesystem path. NOTHING WAS BACKED UP." >&2
    exit 1
  fi
  RCLONE_REMOTE_NAME="${RCLONE_TARGET%%:*}"
  if ! rclone listremotes 2>/dev/null | grep -qx "${RCLONE_REMOTE_NAME}:"; then
    echo "ERROR: rclone remote '${RCLONE_REMOTE_NAME}:' is not configured." >&2
    echo "       Run 'rclone config' and recreate it. The crypt password and" >&2
    echo "       salt are in the password vault. NOTHING WAS BACKED UP." >&2
    exit 1
  fi
  if ! rclone lsd "${RCLONE_REMOTE_NAME}:" >/dev/null 2>&1; then
    echo "ERROR: cannot reach rclone remote '${RCLONE_REMOTE_NAME}:'." >&2
    echo "       Most likely an expired or revoked credential, or no network." >&2
    echo "       This is the failure that is otherwise SILENT - a backup that" >&2
    echo "       has not run for weeks while every other check passes." >&2
    echo "       NOTHING WAS BACKED UP." >&2
    exit 1
  fi
fi

CLOUD_DEST=0
# Three destination shapes, deliberately not collapsed into one message.
# The iCloud/ADP branch below is CORRECT and CURRENT for the personal repos
# (personal repos that never change hands) which stay on a provider with
# Protection. Do not "fix" it to say ADP no longer matters - that is true
# only for repos held by a role that turns over. The split is deliberate.
if [ "$DEST_KIND" = "rclone" ]; then
  echo
  echo "NOTE: destination is an rclone remote. If it is a `crypt` remote, the"
  echo "      content is encrypted before it leaves this machine and the"
  echo "      provider stores ciphertext - which is what makes a general-"
  echo "      purpose cloud account an acceptable home for this material."
  echo
  echo "      That protection is only as good as the keys. The crypt password"
  echo "      AND salt live in the password vault, and there is no provider to"
  echo "      appeal to if they are lost. Losing them loses the backup."
  echo
  echo "      Encryption answers confidentiality. It does NOT make this a"
  echo "      second copy for durability unless the remote is somewhere other"
  echo "      than the machine you are backing up."
else
case "$DEST" in
  *Mobile\ Documents*|*iCloud*|*Dropbox*|*Google\ Drive*|*OneDrive*)
    CLOUD_DEST=1
    echo
    echo "NOTE: destination looks cloud-synced. That is good for durability and"
    echo "      means a third party now stores this content. These repos hold"
    echo "      content that would matter in someone else's hands, so"
    echo "      confirm the provider is end-to-end encrypted (on iCloud that is"
    echo "      Advanced Data Protection, off by default) before relying on it."
    echo
    echo "      End-to-end protection does NOT survive sharing. A shared link or"
    echo "      shared folder hands the content to someone who may not have it"
    echo "      enabled. Keep these trees unshared." ;;
esac
fi

# Same-volume check is meaningless for a remote - there is no local device
# to compare against. Skipped explicitly rather than silently producing
# nothing, so the absence of the usual note is not mistaken for the absence
# of a problem.

SRC_DEV=""; DST_DEV=""
if [ "$DEST_KIND" = "path" ]; then
  SRC_DEV="$(df "$REPO_ROOT" 2>/dev/null | awk 'NR==2{print $1}')"
  DST_DEV="$(df "$DEST" 2>/dev/null | awk 'NR==2{print $1}')"
fi
if [ -n "$SRC_DEV" ] && [ "$SRC_DEV" = "$DST_DEV" ]; then
  echo
  if [ "$CLOUD_DEST" -eq 1 ]; then
    # A cloud folder's local cache always shares the volume, so the raw
    # same-volume test fires and reads as a warning when it is not one. The
    # off-device copy is the provider's, not this disk's.
    echo "NOTE: the destination's local cache is on the same volume as the repo,"
    echo "      which is normal for a synced folder. Disk loss is covered by the"
    echo "      provider's copy, not by this one - so that protection is only as"
    echo "      good as the sync actually completing. Check it has uploaded"
    echo "      before treating this as off-device."
  else
    echo "NOTE: backup is on the same volume as the repo. That covers the failure"
    echo "      that prompted this script - a directory disappearing - but not"
    echo "      disk loss or theft. Point .private-backup-dir at an external"
    echo "      drive or an encrypted cloud folder when convenient."
  fi
fi

# ------------------------------------------------------------------- mirror
if [ "$DRY_RUN" -eq 1 ]; then
  echo
  echo "--dry-run: nothing copied."
else
  echo
  COPIED=0
  FAILED=0
  for p in "${RESOLVED[@]}"; do
    if [ "$DEST_KIND" = "rclone" ]; then
      # `rclone copy`, NEVER `rclone sync`.
      #
      # This mirror is deliberately ADDITIVE - see the header. `rsync -a`
      # without `--delete` does not remove anything from the destination,
      # and `rclone copy` is its equivalent. `rclone sync` deletes from the
      # destination to match the source, which would make the backup
      # faithfully reproduce the exact deletion it exists to survive.
      #
      # One word, and the whole point of the script is gone. Do not
      # "optimise" this into a sync to save remote storage.
      if [ -d "$p" ]; then
        rc_dest="$RCLONE_TARGET/$p"
      else
        rc_dest="$RCLONE_TARGET/$(dirname "$p")"
      fi
      # --create-empty-src-dirs because rclone skips empty directories and
      # rsync does not. No data is lost either way, but a restored tree that
      # is missing a folder invites "what was in there?" at exactly the
      # moment nobody can answer it. An empty directory can also carry
      # intent - a placeholder someone made on purpose.
      if rclone copy "$p" "$rc_dest" --create-empty-src-dirs 2>&1; then
        COPIED=$((COPIED + 1))
      else
        echo "  ERROR: rclone copy failed for $p" >&2
        FAILED=$((FAILED + 1))
      fi
    else
      target="$DEST/$(dirname "$p")"
      mkdir -p "$target"
      if rsync -a "$p" "$target/" 2>/dev/null; then
        COPIED=$((COPIED + 1))
      else
        echo "  WARNING: rsync failed for $p" >&2
        FAILED=$((FAILED + 1))
      fi
    fi
  done
  echo "mirrored $COPIED of ${#RESOLVED[@]} path(s)."

  # A partial backup that exits 0 is the same class of failure as the
  # zero-files guard above: it reports success for something that did not
  # happen. The manifest is written either way, so a later --check would
  # compare against a timestamp from a run that only half worked.
  if [ "$FAILED" -gt 0 ]; then
    echo >&2
    echo "ERROR: $FAILED of ${#RESOLVED[@]} path(s) FAILED TO COPY." >&2
    echo "       This backup is incomplete. Do not treat it as a copy." >&2
    exit 1
  fi

  if [ "$DEST_KIND" = "rclone" ]; then
    echo "backup size: $(rclone size "$RCLONE_TARGET" 2>/dev/null | tail -1)"
  else
    echo "backup size: $(du -sh "$DEST" 2>/dev/null | cut -f1)"
  fi
fi

# ----------------------------------------------------------------- manifest
# --dry-run must not write the manifest. It was doing so before the staleness
# check existed, which was merely untidy: the file is the record of what the
# last real run saw, and a run that copied nothing has no business updating it.
# Once --check started reading the manifest's timestamp to detect a backup that
# has stopped running, the same bug became load-bearing - a --dry-run, which
# copies nothing by definition, reset a 90-day staleness warning to "0 days
# ago". A command that copies nothing silencing the warning that nothing has
# been copied is the exact failure this script exists to prevent.
if [ "$MANIFEST_MODE" != "none" ] && [ "$DRY_RUN" -eq 0 ]; then
  M="$REPO_ROOT/PRIVATE_MANIFEST.md"
  {
    echo "# Private content manifest"
    echo
    echo "**Generated:** \`scripts/backup-private.sh\` on $(date '+%Y-%m-%d %H:%M') \\"
    echo "**Mode:** $MANIFEST_MODE \\"
    echo "**Committed on purpose:** yes"
    echo
    echo "---"
    echo
    echo "This file is committed. The content it describes is not."
    echo
    echo "Gitignored private content has no remote and no history, so if it is lost"
    echo "there is nothing to say what was there. This manifest turns that silent,"
    echo "unbounded loss into a known and scoped reconstruction job. It lists shape,"
    echo "never content."
    echo
    echo "Regenerate it by running \`./scripts/backup-private.sh\`. **Read the diff"
    echo "before committing** - a filename can itself be private."
    echo
    if [ "$MANIFEST_MODE" = "summary" ]; then
      echo "| Path | Files | Size | Newest |"
      echo "|---|---|---|---|"
      for p in "${RESOLVED[@]}"; do
        if [ -d "$p" ]; then
          n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
          sz=$(du -sh "$p" 2>/dev/null | cut -f1)
          nw=$(find "$p" -type f -exec stat -f '%Sm' -t '%Y-%m-%d' {} \; 2>/dev/null | sort | tail -1)
        else
          n=1; sz=$(du -h "$p" 2>/dev/null | cut -f1); nw=$(stat -f '%Sm' -t '%Y-%m-%d' "$p" 2>/dev/null)
        fi
        echo "| \`$p\` | $n | $sz | ${nw:-–} |"
      done
    else
      echo "| File | Size | Modified |"
      echo "|---|---|---|"
      for p in "${RESOLVED[@]}"; do
        if [ -d "$p" ]; then
          find "$p" -type f -not -name '.DS_Store' 2>/dev/null | sort | while IFS= read -r f; do
            echo "| \`$f\` | $(du -h "$f" 2>/dev/null | cut -f1) | $(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null) |"
          done
        else
          echo "| \`$p\` | $(du -h "$p" 2>/dev/null | cut -f1) | $(stat -f '%Sm' -t '%Y-%m-%d' "$p" 2>/dev/null) |"
        fi
      done
    fi
    echo
    echo "**Total: $TOTAL_FILES file(s) across ${#RESOLVED[@]} path(s).**"
  } > "$M"
  echo
  echo "manifest:    PRIVATE_MANIFEST.md ($MANIFEST_MODE) - review the diff before committing"
fi

echo
echo "done."
