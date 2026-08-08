#!/usr/bin/env python3
"""
Markdown convention checker for this repo.

Self-contained on purpose: charrette is meant to be cloned standalone with
no dependency on any other repo, so nothing here reaches outside this
checkout to find it.

Two checks, deliberately handled differently:

  1. HARD BREAKS (auto-fixed)
     Consecutive **Label:** lines with no blank line between them are ONE
     paragraph in CommonMark, so renderers join them onto a single line.
     Metadata header blocks are the only place in these docs with that shape,
     which is why only they break. Purely structural, so it is safe to fix
     silently: adding a line break changes no meaning.

  2. EM DASHES (reported, never auto-fixed)
     House style is en dash. NOT auto-fixed because em dashes can appear
     inside quoted verbatim source material, where rewriting one alters a
     document that may need to match its original. Reported so the author
     decides rather than getting rewritten blind.

Usage:
    md-conventions.py [--fix] [--quiet] FILE...
    md-conventions.py --added-lines BASE_REF FILE...   # CI, diff-scoped

Exit codes:
    0  clean (or --fix resolved everything auto-fixable)
    1  hard-break violations remain (only without --fix)
    2  em dash findings to report
"""
import re
import subprocess
import sys
from pathlib import Path

# Metadata line: **Label:** at column 0. Deliberately does NOT match list
# items ("- **X:**"), blockquotes ("> **X:**"), or table rows ("| **X:** |")
# because those already produce their own line breaks.
META = re.compile(r'^\*\*[^*\n]+:\*\*')
FENCE = re.compile(r'^\s{0,3}(```|~~~)')
INLINE_CODE = re.compile(r'`[^`]*`')
EM_DASH = '—'


def code_fence_map(lines):
    """True for every line inside a fenced code block."""
    inside = [False] * len(lines)
    in_fence = False
    marker = None
    for i, line in enumerate(lines):
        m = FENCE.match(line)
        if m:
            inside[i] = True
            if not in_fence:
                in_fence, marker = True, m.group(1)
            elif line.strip().startswith(marker):
                in_fence, marker = False, None
            continue
        inside[i] = in_fence
    return inside


def find_hard_breaks(lines, fenced):
    """Line indexes that need a trailing backslash. 0-indexed."""
    is_meta = [
        not fenced[i] and bool(META.match(l)) for i, l in enumerate(lines)
    ]
    needs = []
    i = 0
    while i < len(lines):
        if not is_meta[i]:
            i += 1
            continue
        j = i
        while j + 1 < len(lines) and is_meta[j + 1]:
            j += 1
        if j > i:  # a run of 2+; every line but the last needs a break
            for k in range(i, j):
                line = lines[k]
                if not (line.endswith('\\') or line.endswith('  ')):
                    needs.append(k)
        i = j + 1
    return needs


def find_em_dashes(lines, fenced):
    """(line_index, rendered_line) for em dashes in prose only."""
    hits = []
    for i, line in enumerate(lines):
        if fenced[i]:
            continue
        if line.lstrip().startswith('>'):
            continue  # blockquote: quoted source, leave verbatim
        if EM_DASH in INLINE_CODE.sub('', line):
            hits.append((i, line.strip()))
    return hits


def added_line_numbers(path, base_ref):
    """1-indexed line numbers added relative to base_ref. Both CI and the local
    hook use this so neither reports pre-existing content it never touched.

    Runs git in the file's own directory: the hook's cwd is not reliable, and
    these repos are scattered across several checkouts."""
    # Resolve to absolute before handing anything to git. A relative path is
    # relative to OUR cwd, not to the repo we point git at, so the two disagree
    # the moment those differ - and ls-files then reports the file as untracked,
    # silently widening the scope to the whole file.
    path = Path(path).resolve()
    repo_dir = str(path.parent)
    try:
        subprocess.run(['git', '-C', repo_dir, 'ls-files', '--error-unmatch',
                        str(path)], capture_output=True, check=True)
    except subprocess.CalledProcessError:
        return None  # untracked: all content is new, report everything
    try:
        diff = subprocess.run(
            ['git', '-C', repo_dir, 'diff', '-U0', base_ref, '--', str(path)],
            capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError:
        return None
    added, cur = set(), 0
    for line in diff.split('\n'):
        m = re.match(r'^@@ -\S+ \+(\d+)(?:,(\d+))?', line)
        if m:
            cur = int(m.group(1))
            continue
        if line.startswith('+') and not line.startswith('+++'):
            added.add(cur)
            cur += 1
        elif not line.startswith('-') and not line.startswith('\\'):
            cur += 1
    return added


def main():
    argv = sys.argv[1:]
    fix = '--fix' in argv
    quiet = '--quiet' in argv
    base_ref = None
    if '--added-lines' in argv:
        idx = argv.index('--added-lines')
        base_ref = argv[idx + 1]
        argv = argv[:idx] + argv[idx + 2:]
    paths = [Path(a) for a in argv if not a.startswith('--')]

    fixed_count = 0
    break_findings = []
    dash_findings = []

    for p in paths:
        if p.suffix.lower() != '.md' or not p.is_file():
            continue
        try:
            text = p.read_text(encoding='utf-8')
        except (OSError, UnicodeDecodeError):
            continue
        lines = text.split('\n')
        fenced = code_fence_map(lines)

        scope = added_line_numbers(p, base_ref) if base_ref else None

        needs = find_hard_breaks(lines, fenced)
        if scope is not None:
            needs = [k for k in needs if (k + 1) in scope]
        if needs and fix:
            for k in needs:
                lines[k] = lines[k].rstrip() + ' \\'
            p.write_text('\n'.join(lines), encoding='utf-8')
            fixed_count += len(needs)
        elif needs:
            for k in needs:
                break_findings.append((p, k + 1, lines[k].strip()[:70]))

        dashes = find_em_dashes(lines, fenced)
        if scope is not None:
            dashes = [(i, t) for i, t in dashes if (i + 1) in scope]
        for i, t in dashes:
            dash_findings.append((p, i + 1, t[:70]))

    if not quiet and fixed_count:
        print(f'md-conventions: added {fixed_count} hard break(s)',
              file=sys.stderr)

    if break_findings:
        print('\nMarkdown: metadata lines will render joined onto one line.',
              file=sys.stderr)
        print('Consecutive **Label:** lines are one paragraph in CommonMark. '
              'Append " \\" to every line in the run except the last.\n',
              file=sys.stderr)
        for p, n, t in break_findings[:20]:
            print(f'  {p}:{n}  {t}', file=sys.stderr)

    if dash_findings:
        print('\nMarkdown: em dash on a line you just wrote. '
              'House style is en dash.', file=sys.stderr)
        print('Replace it UNLESS this is quoted source material, in which '
              'case leave it verbatim and say so. To show the character '
              'itself, wrap it in backticks.\n', file=sys.stderr)
        for p, n, t in dash_findings[:10]:
            print(f'  {p}:{n}  {t}', file=sys.stderr)
        if len(dash_findings) > 10:
            print(f'  ... and {len(dash_findings) - 10} more', file=sys.stderr)

    if break_findings:
        return 1
    if dash_findings:
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
