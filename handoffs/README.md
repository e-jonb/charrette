# Handoffs

This directory holds per-project handoff files and the studio-level state file.

## Files in this directory

- `studio.md` — Studio-level state: active projects, session conventions, improvement backlog. Update when something about how the Studio itself works changes.
- `[project-name].md` — One file per solution. The Chief Architect creates this automatically after every architecture session and updates it as work progresses.

## Purpose

Handoff files are how charrette survives context loss. When you start a new Claude Code session, loading the relevant handoff file gives the Chief Architect everything it needs to pick up exactly where you left off — without re-explaining the project.

Every handoff file includes:
- What was designed and why
- Key architecture decisions (or links to ADRs)
- Current status and what phase is next
- The resume prompt: paste this into a new session to jump straight back in

## Resume prompt format

```
I'm resuming Studio work on [Project Name]. Read handoffs/[project-name].md for context.
```
