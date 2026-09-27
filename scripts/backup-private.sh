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
      echo "                   Exit 0 OK, 1 files missing or config broken, 3 an"
      echo "                   external: source cannot be seen on this machine."
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
  external:sm-drive       a source OUTSIDE the repo, by label

An `external:` label needs a location, and that goes in `.private-sources`,
which is gitignored:

  sm-drive = /absolute/path/to/the/folder

This file is tracked and that one is not, on purpose. An absolute path in a
tracked file is wrong on every machine but the one that wrote it - including
your own second machine - and it fails quietly, resolving to nothing while the
run still reports success. The declaration is shared; the location is local.

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
#
# RESOLVED holds source paths. RESOLVED_AS holds where each one lands under the
# destination. For everything except an `external:` label the two are the same,
# which is why this was a single array until labels existed.
#
# `external:<label>` exists because a source outside the repo cannot have its
# location committed. `.private-paths` is TRACKED, so an absolute path in it is
# wrong on every machine but the one that wrote it - including the owner's own
# second machine, since these repos sync across more than one. The location
# lives in `.private-sources`, which is gitignored, and the label is what both
# the tracked declaration and the backup layout use.
#
# The destination layout is part of the restore contract: `<dest>/<label>/...`
# is stable no matter whose laptop ran the script, which is what makes a path
# in RECOVERY.md mean the same thing on any machine.
RESOLVED=()
RESOLVED_AS=()
# 1 where the source is an `external:` label, 0 otherwise. Only external
# sources can be empty for a reason other than having no content - see the
# per-source guard below.
RESOLVED_EXT=()

# External sources this machine cannot see right now, and why. Only ever
# populated under --check; a real run stops instead. See "Can't see is not
# lost" below the tripwire.
UNSEEN=()
UNSEEN_WHY=()

# `.private-sources` is the source-side twin of `.private-backup-dir`: one
# `label = path` per line, `#` comments, `~` expanded. Read lazily so a repo
# declaring no external labels never needs the file to exist.
# Logical size, not allocated blocks. `du` reports blocks, and a cloud-evicted
# file has none - a 2 MB file that the provider has offloaded reads as 0 B,
# verified 2026-09-23 with Optimize Mac Storage on. That made the manifest's
# size column swing with whatever happened to be evicted, and it ruled out any
# size-based check, because one built on `du` would cry wolf every time the
# provider reclaimed space. `stat -f %z` is the file's real size and is stable
# under eviction.
logical_size() {
  local b
  if [ -d "$1" ]; then
    b=$(find "$1" -type f -exec stat -f '%z' {} \; 2>/dev/null | awk '{s+=$1} END {print s+0}')
  else
    b=$(stat -f '%z' "$1" 2>/dev/null || echo 0)
  fi
  awk -v b="${b:-0}" 'BEGIN{
    if (b>=1073741824) printf "%.1fG", b/1073741824;
    else if (b>=1048576) printf "%.1fM", b/1048576;
    else if (b>=1024) printf "%.0fK", b/1024;
    else printf "%dB", b}'
}

lookup_source() {
  local want="$1" line key val
  [ -f .private-sources ] || return 1
  while IFS= read -r line; do
    line="${line%%#*}"
    case "$line" in *=*) ;; *) continue ;; esac
    key="$(printf '%s' "${line%%=*}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    val="$(printf '%s' "${line#*=}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [ "$key" = "$want" ]; then
      printf '%s' "${val/#\~/$HOME}"
      return 0
    fi
  done < .private-sources
  return 1
}

for entry in "${DECLARED[@]}"; do
  case "$entry" in
    dirname:*)
      name="${entry#dirname:}"
      while IFS= read -r d; do
        [ -n "$d" ] && { RESOLVED+=("${d#./}"); RESOLVED_AS+=("${d#./}"); RESOLVED_EXT+=(0); }
      done < <(find . -type d -name "$name" -not -path './.git/*' 2>/dev/null | sort)
      ;;
    external:*)
      label="${entry#external:}"
      # `live` and `archive` are structural names in the destination layout.
      # A label using either would write into the archive tree or be shadowed
      # by it, silently.
      case "$label" in
        live|archive)
          echo "ERROR: 'external:$label' uses a reserved name." >&2
          echo "       'live' and 'archive' are structural directories in the" >&2
          echo "       backup layout. Pick a different label." >&2
          exit 1 ;;
      esac
      # A label becomes a path segment under the destination, so it has to be
      # a plain name. Tested 2026-09-27: `external:../escape` exited 0 and
      # wrote OUTSIDE the destination entirely, and `external:.` dropped files
      # into the destination root beside the structural directories. Both
      # silent. The reserved-name guard above caught the two names it knew
      # about; it did not catch a label that was shaped like a path.
      case "$label" in
        ""|.|..|*/*|.*)
          echo "ERROR: 'external:$label' is not a usable label." >&2
          echo "       A label becomes a directory name inside the backup, so it" >&2
          echo "       must be a plain name - letters, digits, dash, underscore." >&2
          echo "       No slashes, and not '.' or '..': those would write outside" >&2
          echo "       the backup directory or into its root, silently." >&2
          exit 1 ;;
      esac
      if ! src="$(lookup_source "$label")"; then
        if [ "$CHECK_ONLY" -eq 1 ]; then
          UNSEEN+=("$label"); UNSEEN_WHY+=("not mapped in .private-sources on this machine")
          continue
        fi
        # Never a skip. A declared-but-unmapped label resolving silently to
        # nothing is the exact failure this mechanism was built to remove;
        # reintroducing it as the fix would be worse than not having it.
        #
        # No prompt, either. This script runs unattended - CLAUDE.md has the
        # assistant run it at session end and sync.sh runs --check at session
        # start - so a prompt hangs or gets answered by tooling. And a human
        # prompted for a path at the end of a long session will paste
        # something plausible, which backs up the wrong tree and writes that
        # into the manifest as the new baseline. The message is the guidance.
        echo >&2
        echo "ERROR: '.private-paths' declares external:$label but nothing maps it." >&2
        echo >&2
        echo "  Add this line to .private-sources in the repo root:" >&2
        echo >&2
        echo "      $label = /absolute/path/to/the/folder" >&2
        echo >&2
        echo "  That file is gitignored on purpose. The declaration is tracked so" >&2
        echo "  every machine agrees the source exists; the location is local" >&2
        echo "  because it differs per machine and per person." >&2
        echo >&2
        echo "  NOTHING WAS BACKED UP." >&2
        exit 1
      fi
      if [ ! -e "$src" ]; then
        if [ "$CHECK_ONLY" -eq 1 ]; then
          UNSEEN+=("$label"); UNSEEN_WHY+=("mapped to $src, which does not exist")
          continue
        fi
        echo >&2
        echo "ERROR: external:$label maps to a path that does not exist." >&2
        echo >&2
        echo "      $label = $src" >&2
        echo >&2
        echo "  Fix the mapping in .private-sources, or remove external:$label" >&2
        echo "  from .private-paths if this source is gone for good." >&2
        echo >&2
        echo "  If the path looks right, check whether a cloud folder has" >&2
        echo "  finished syncing - the folder can be absent on a fresh machine." >&2
        echo >&2
        echo "  NOTHING WAS BACKED UP." >&2
        exit 1
      fi
      RESOLVED+=("$src"); RESOLVED_AS+=("$label"); RESOLVED_EXT+=(1)
      ;;
    *)
      [ -e "$entry" ] && { RESOLVED+=("$entry"); RESOLVED_AS+=("$entry"); RESOLVED_EXT+=(0); }
      ;;
  esac
done

# Two sources landing on the same name. RESOLVED_AS is where each source goes
# under the destination, so a repeat means two sources written into one
# folder. Tested 2026-09-27 with `external:_private` beside `dirname:_private`:
# the external copy overwrote in-repo files at the same relative path,
# --backup-dir filed the real in-repo content under archive/ on every run,
# live/ held whichever source copied last, and the manifest got two rows with
# one label, breaking the per-source sum the tripwire relies on. Exit 0, counts
# reconciled, nothing looked wrong. Also catches one label declared twice.
#
# UNSEEN labels are included so --check catches the collision even on a
# machine where the external source is not mapped yet. Plain loops, because
# bash 3.2 has no associative arrays.
ALL_AS=(${RESOLVED_AS+"${RESOLVED_AS[@]}"} ${UNSEEN+"${UNSEEN[@]}"})
DUPES=()
a=0
while [ "$a" -lt "${#ALL_AS[@]}" ]; do
  b=$((a + 1))
  while [ "$b" -lt "${#ALL_AS[@]}" ]; do
    [ "${ALL_AS[$a]}" = "${ALL_AS[$b]}" ] && DUPES+=("${ALL_AS[$a]}")
    b=$((b + 1))
  done
  a=$((a + 1))
done
if [ "${#DUPES[@]}" -gt 0 ]; then
  echo >&2
  echo "ERROR: more than one declared source lands on the same name:" >&2
  for d in "${DUPES[@]}"; do echo "         $d" >&2; done
  echo >&2
  echo "  Each source becomes a folder of that name inside the backup, so these" >&2
  echo "  would be written into one folder, overwriting each other silently." >&2
  echo "  Rename the external: label, or remove the repeated line from" >&2
  echo "  .private-paths." >&2
  echo >&2
  echo "  NOTHING WAS BACKED UP." >&2
  exit 1
fi

TOTAL_FILES=0
EMPTY_PATHS=()
i=0
for p in ${RESOLVED+"${RESOLVED[@]}"}; do
  if [ -d "$p" ]; then
    # NOT filtering .DS_Store here, deliberately. Excluding it is tidier and
    # was tried on 2026-09-27 - it changed one repo's count from 391 to 375
    # and tripped "PRIVATE FILES HAVE GONE MISSING" on a repo holding SSNs,
    # because the recorded baseline counted them. Changing what counts as a
    # file silently re-baselines every repo's tripwire. Not worth it.
    n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
  else
    n=1
  fi
  TOTAL_FILES=$((TOTAL_FILES + n))
  [ "$n" -eq 0 ] && [ "${RESOLVED_EXT[$i]}" -eq 1 ] && EMPTY_PATHS+=("${RESOLVED_AS[$i]}")
  if [ "$p" = "${RESOLVED_AS[$i]}" ]; then
    printf '  %-48s %s file(s)\n' "$p" "$n"
  else
    printf '  %-48s %s file(s)\n' "${RESOLVED_AS[$i]} -> $p" "$n"
  fi
  i=$((i + 1))
done

echo
echo "declared: ${#DECLARED[@]} pattern(s) -> resolved: ${#RESOLVED[@]} path(s), $TOTAL_FILES file(s)"

# A backup that reports success having copied nothing is the failure mode this
# whole workspace keeps rediscovering. Zero is always an anomaly worth an exit
# code: either nothing private exists yet, or a declaration has gone stale.
if [ "$TOTAL_FILES" -eq 0 ] && [ "${#UNSEEN[@]}" -eq 0 ]; then
  echo
  echo "NOTHING BACKED UP - 0 files matched .private-paths." >&2
  echo "Either no private content exists in this repo yet, or a declared path" >&2
  echo "is wrong. No backup was written. This is deliberately an error rather" >&2
  echo "than a quiet success." >&2
  exit 1
fi

# PER-SOURCE zero for `external:` sources, which the total above cannot see.
# With _private at 89 files and an external source at 0, the total is 89 and
# nothing trips - so the external source is silently not backed up while the
# run reports success. That is a live case on a fresh machine where a cloud
# folder exists but has not finished syncing: `[ -e ]` passes and there is
# nothing inside.
#
# EXTERNAL ONLY, and that scope is the fix for a regression. The first version
# (2026-09-27) applied this to every resolved path, and `dirname:_private` is a
# glob: in one repo it matched a per-person `_private` folder (2 files) and
# two empty placeholders, one waiting for a second person. Judging each glob match
# as its own declaration failed a healthy repo at every session start. An
# in-repo folder cannot be mid-sync; empty there is a normal state, and the
# whole-total guard above still catches a repo where everything is empty.
#
# The first version also said a legitimately empty source should be
# undeclared. That was wrong: undeclare `documents/` and its first real file
# is silently not backed up, which is worse than the bug.
#
# No override flag. An override is a thing someone sets during one sync hiccup
# and never removes, which makes it a diligence control - the category ADR-010
# rejected Cryptomator over.
#
# Under --check an empty external source is not an error but a source this
# machine cannot see yet. It joins UNSEEN and is reported with exit 3. A real
# run still stops here, which is the property that matters: nothing is copied
# and no manifest is written from a machine missing a source.
if [ "$CHECK_ONLY" -eq 1 ] && [ "${#EMPTY_PATHS[@]}" -gt 0 ]; then
  for e in "${EMPTY_PATHS[@]}"; do
    UNSEEN+=("$e"); UNSEEN_WHY+=("exists but holds no files")
  done
  EMPTY_PATHS=()
fi
if [ "${#EMPTY_PATHS[@]}" -gt 0 ]; then
  echo
  echo "ERROR: external source(s) resolved to ZERO files:" >&2
  for e in "${EMPTY_PATHS[@]}"; do echo "         $e" >&2; done
  echo >&2
  echo "  The other sources have content, so the total looks healthy and" >&2
  echo "  nothing else would have caught this. A source that resolves to" >&2
  echo "  nothing is not backed up." >&2
  echo >&2
  echo "  Most likely: a cloud folder that has not finished syncing, a" >&2
  echo "  mapping in .private-sources pointing one level too high, or a" >&2
  echo "  declaration that has outlived its content." >&2
  echo >&2
  echo "  NOTHING WAS BACKED UP." >&2
  exit 1
fi

# ------------------------------------------------------ can't see is not lost
# Under --check, an `external:` source that is unmapped, absent or empty on
# this machine is reported with exit 3, not 1. sync.sh runs --check at session
# start and treats 1 as "stop all work", which is right for files that have
# gone missing and wrong for a Drive folder that needs five more minutes to
# sync. The action is different, so the signal is different.
#
# The count comparison below then covers only the sources that ARE visible,
# using the per-source table the manifest has carried since 2026-09-27. A
# source you cannot see would otherwise read as every one of its files gone.
report_unseen() {
  local k=0
  echo
  echo "------------------------------------------------------------------------" >&2
  echo "  EXTERNAL SOURCE NOT VISIBLE ON THIS MACHINE" >&2
  echo "" >&2
  while [ "$k" -lt "${#UNSEEN[@]}" ]; do
    echo "    external:${UNSEEN[$k]} - ${UNSEEN_WHY[$k]}" >&2
    k=$((k + 1))
  done
  echo "" >&2
  echo "  Nothing is known to be lost. Do NOT run the backup until this clears:" >&2
  echo "  a real run stops here anyway rather than record a smaller baseline." >&2
  echo "" >&2
  echo "  If a cloud folder is still syncing, wait and re-run --check. If this" >&2
  echo "  machine has never been set up, add the mapping to .private-sources." >&2
  echo "  Other work in this repo is fine." >&2
  echo "------------------------------------------------------------------------" >&2
}

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
  SCOPE_NOTE=""
  if [ "${#UNSEEN[@]}" -gt 0 ]; then
    if grep -q '^| Source | Files |' "$REPO_ROOT/PRIVATE_MANIFEST.md"; then
      # Sum the recorded counts of every source NOT in UNSEEN. A source that
      # was recorded and has since vanished outright is still summed, so it
      # still reads as loss - only the ones this machine cannot see drop out.
      RECORDED="$(UNSEEN_LIST="$(printf '%s\n' "${UNSEEN[@]}")" awk '
        BEGIN { n = split(ENVIRON["UNSEEN_LIST"], u, "\n"); for (i = 1; i <= n; i++) if (u[i] != "") drop[u[i]] = 1 }
        /^\| Source \| Files \|/ { t = 1; next }
        t && /^[[:space:]]*$/ { exit }
        t && /^\| `/ { split($0, f, "|"); lab = f[2]; gsub(/^[[:space:]]*`|`[[:space:]]*$/, "", lab)
                       c = f[3]; gsub(/[[:space:]]/, "", c); if (!(lab in drop)) sum += c }
        END { print sum + 0 }' "$REPO_ROOT/PRIVATE_MANIFEST.md")"
      SCOPE_NOTE=" (sources visible on this run)"
    else
      # A manifest from before the per-source table has only a total, and the
      # total includes the source we cannot see. Comparing against it would
      # report that source's every file as missing. Say so rather than guess.
      echo
      echo "NOTE: count comparison SKIPPED. PRIVATE_MANIFEST.md predates the" >&2
      echo "      per-source table, so it cannot be split to exclude the source" >&2
      echo "      that is not visible. The next real run adds the table." >&2
      RECORDED=""
    fi
  fi
  if [ -n "$RECORDED" ] && [ "$TOTAL_FILES" -lt "$RECORDED" ]; then
    MISSING=$((RECORDED - TOTAL_FILES))
    echo
    echo "########################################################################" >&2
    echo "  PRIVATE FILES HAVE GONE MISSING" >&2
    echo "" >&2
    echo "  PRIVATE_MANIFEST.md recorded $RECORDED file(s)$SCOPE_NOTE. $TOTAL_FILES are present." >&2
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
    [ "${#UNSEEN[@]}" -gt 0 ] && report_unseen
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
    if [ -z "$RECORDED" ] && [ "${#UNSEEN[@]}" -gt 0 ]; then
      # Never print "OK" for a comparison that did not happen.
      echo "tripwire NOT RUN: $TOTAL_FILES file(s) present, no per-source baseline to compare."
    else
      echo "tripwire OK: $TOTAL_FILES file(s) present, manifest recorded ${RECORDED:-none}$SCOPE_NOTE."
    fi
    [ -n "$GENERATED" ] && echo "             last run $GENERATED (${AGE_DAYS:-?} days ago, warn over $STALE_DAYS)."
    if [ "${#UNSEEN[@]}" -gt 0 ]; then report_unseen; exit 3; fi
    exit 0
  fi
elif [ "$CHECK_ONLY" -eq 1 ]; then
  echo
  echo "no PRIVATE_MANIFEST.md yet - nothing to compare against."
  echo "Run without --check once to establish a baseline."
  if [ "${#UNSEEN[@]}" -gt 0 ]; then report_unseen; exit 3; fi
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
  # Dated archive for superseded versions. Additive copy already means a
  # DELETED file survives - it is simply never removed from the destination.
  # It does nothing for a file CLOBBERED by a bad edit, where the backup
  # faithfully copies the damage over the good copy, and that is the commoner
  # mistake. --backup-dir moves the version being replaced into a dated folder
  # instead of overwriting it.
  #
  # The archive is a SIBLING of the live tree, never inside it. rclone refuses
  # an overlap outright ("destination and parameter to --backup-dir mustn't
  # overlap", exit 7), which the FAILED check below turns into a hard stop.
  # Timestamp, not just the date. Tested 2026-09-27: with a date-only key, two
  # bad edits on the SAME DAY each followed by a backup run left the original
  # unrecoverable - the second run's archive write overwrote the first's, and
  # `grep -rl` found zero surviving copies. CLAUDE.md has the assistant run this
  # at session end, and there is routinely more than one session in a day, so
  # that is the normal case rather than an edge one.
  #
  # It still sorts and reads as a date, so "the version from before yesterday"
  # works exactly as before.
  ARCHIVE_DATE="$(date '+%Y-%m-%dT%H%M%S')"
  idx=0
  for p in "${RESOLVED[@]}"; do
    as="${RESOLVED_AS[$idx]}"
    idx=$((idx + 1))
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
      # Destination is the LABEL, not the source's own path. An external
      # source must not reproduce a home-directory layout in the backup:
      # two machines would build two parallel trees in one remote, and
      # every path in RECOVERY.md would depend on whose laptop ran it.
      if [ -d "$p" ]; then
        rc_dest="$RCLONE_TARGET/live/$as"
      else
        rc_dest="$RCLONE_TARGET/live/$(dirname "$as")"
      fi
      # Per-label, because --backup-dir is relative to THIS copy's destination.
      # A single shared archive/<date> strips the label and lands the file at
      # archive/<date>/sub/b.txt, so two sources clobbering the same relative
      # path collide and an archive path stops mirroring its live path.
      # Tested 2026-09-27: it did exactly that until this line named the label.
      if [ -d "$p" ]; then
        rc_archive="$RCLONE_TARGET/archive/$ARCHIVE_DATE/$as"
      else
        rc_archive="$RCLONE_TARGET/archive/$ARCHIVE_DATE/$(dirname "$as")"
      fi
      # --create-empty-src-dirs because rclone skips empty directories and
      # rsync does not. No data is lost either way, but a restored tree that
      # is missing a folder invites "what was in there?" at exactly the
      # moment nobody can answer it. An empty directory can also carry
      # intent - a placeholder someone made on purpose.
      if rclone copy "$p" "$rc_dest" --create-empty-src-dirs --backup-dir "$rc_archive" 2>&1; then
        COPIED=$((COPIED + 1))
      else
        echo "  ERROR: rclone copy failed for $p" >&2
        FAILED=$((FAILED + 1))
      fi
    else
      # Trailing slashes on both sides: copy the CONTENTS of the source into
      # <dest>/<label>. Equivalent to the old `rsync -a src dest/` for a
      # repo-relative path, and the only form that honours a label whose name
      # differs from the source's basename.
      if [ -d "$p" ]; then
        target="$DEST/$as"; mkdir -p "$target"; src_arg="$p/"
        rs_archive="$DEST/archive/$ARCHIVE_DATE/$as"
      else
        target="$DEST/$(dirname "$as")"; mkdir -p "$target"; src_arg="$p"
        rs_archive="$DEST/archive/$ARCHIVE_DATE/$(dirname "$as")"
      fi
      # Same clobber protection as the rclone branch. rsync's --backup-dir is
      # relative to the DESTINATION when given a relative path, so this is
      # always absolute.
      #
      # The layout differs from rclone's on purpose. rclone needs live/
      # because it refuses a --backup-dir overlapping its destination
      # (exit 7). rsync has no such restriction, so the current copy stays
      # where it has always been - at <dest>/<label>/ - and the archive is a
      # sibling at <dest>/archive/. Moving existing local backups under a new
      # live/ prefix would strand their existing
      # content at the old paths, additive and therefore never cleaned up,
      # where a future restore could grab the stale copy. Not worth the
      # symmetry. RECOVERY.md states both layouts.
      mkdir -p "$(dirname "$rs_archive")"
      if rsync -a --backup --backup-dir="$rs_archive" "$src_arg" "$target/" 2>/dev/null; then
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

  # Prune empty archive directories. The mkdir above is unconditional and has
  # to be: tested 2026-09-27, rsync given a --backup-dir whose parent does not
  # exist archives NOTHING and says nothing about it, so creating it eagerly is
  # the only safe order. The cost is a directory per run whether or not anything
  # was superseded, and with a timestamped key that is one per run rather than
  # one per day. Since recovery means "list the archive, pick a version", a
  # listing that is mostly empty directories is a listing nobody can use.
  if [ "$DEST_KIND" != "rclone" ] && [ -d "$DEST/archive" ]; then
    find "$DEST/archive" -type d -empty -delete 2>/dev/null
    [ -d "$DEST/archive" ] || true
  fi

  if [ "$DEST_KIND" != "rclone" ] && [ -d "$DEST/archive" ]; then
    rs_arch_n="$(find "$DEST/archive" -type f 2>/dev/null | wc -l | tr -d ' ')"
    [ "${rs_arch_n:-0}" -gt 0 ] && echo "archive:     $rs_arch_n superseded version(s) under archive/"
  fi

  if [ "$DEST_KIND" = "rclone" ]; then
    # live/ only. Including the archive would overstate the current backup,
    # and the archive grows without bound by design.
    echo "backup size: $(rclone size "$RCLONE_TARGET/live" 2>/dev/null | tail -1)"
    arch_n="$(rclone size "$RCLONE_TARGET/archive" 2>/dev/null | grep -oE 'Total objects: [0-9]+' | grep -oE '[0-9]+')"
    [ -n "${arch_n:-}" ] && [ "$arch_n" -gt 0 ] && echo "archive:     $arch_n superseded version(s) under archive/"
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
    echo "**Written by:** $(hostname -s 2>/dev/null || echo unknown) \\"
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
    echo "## Sources resolved on this run"
    echo
    echo "Recorded by name, not only by count. Two machines that resolve different"
    echo "sets produce a *named* difference here rather than a quietly lower total,"
    echo "which is what a bare number could never tell you. If a source you expect"
    echo "is missing from this list, that is the finding."
    echo
    # The --check tripwire parses this table back: it starts at the header row
    # below and ENDS AT THE FIRST BLANK LINE after it. Keep the blank `echo`
    # after the loop, and keep the header text exact, or the per-source
    # comparison silently reads the wrong rows.
    echo "| Source | Files |"
    echo "|---|---|"
    mi=0
    for p in "${RESOLVED[@]}"; do
      as="${RESOLVED_AS[$mi]}"; mi=$((mi + 1))
      if [ -d "$p" ]; then
        n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
      else
        n=1
      fi
      echo "| \`$as\` | $n |"
    done
    echo
    if [ "$MANIFEST_MODE" = "summary" ]; then
      echo "| Path | Files | Size | Newest |"
      echo "|---|---|---|---|"
      si=0
      for p in "${RESOLVED[@]}"; do
        as="${RESOLVED_AS[$si]}"; si=$((si + 1))
        if [ -d "$p" ]; then
          n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
          sz=$(logical_size "$p")
          nw=$(find "$p" -type f -exec stat -f '%Sm' -t '%Y-%m-%d' {} \; 2>/dev/null | sort | tail -1)
        else
          n=1; sz=$(logical_size "$p"); nw=$(stat -f '%Sm' -t '%Y-%m-%d' "$p" 2>/dev/null)
        fi
        echo "| \`$as\` | $n | $sz | ${nw:-–} |"
      done
    else
      echo "| File | Size | Modified |"
      echo "|---|---|---|"
      fi_=0
      for p in "${RESOLVED[@]}"; do
        as="${RESOLVED_AS[$fi_]}"; fi_=$((fi_ + 1))
        if [ -d "$p" ]; then
          find "$p" -type f -not -name '.DS_Store' 2>/dev/null | sort | while IFS= read -r f; do
            echo "| \`$as${f#$p}\` | $(logical_size "$f") | $(stat -f '%Sm' -t '%Y-%m-%d' "$f" 2>/dev/null) |"
          done
        else
          echo "| \`$as\` | $(logical_size "$p") | $(stat -f '%Sm' -t '%Y-%m-%d' "$p" 2>/dev/null) |"
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
