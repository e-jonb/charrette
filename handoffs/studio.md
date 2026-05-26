# Context Handoff — Studio

> **Purpose:** Studio-level state. Not project-specific. Update when something about how the Studio itself works changes.

**Last updated:** [YYYY-MM-DD]

---

## Studio Health

[Note the current state of the studio — e.g., "Fully configured and ready to use." or "Organization profile not yet filled in."]

GitHub: [your repo URL, once created]

---

## Active Solutions

| Solution | Workspace | Status | Handoff |
|----------|-----------|--------|---------|

<!-- Add rows as you design solutions:
| ProjectName | personal / professional / business | Active — Phase X.Y next | `handoffs/project-name.md` |
-->

---

## Session Conventions

- **Per-project handoff files** — each project has its own file in `handoffs/`. Don't write to other projects' handoff files.
- **Simultaneous sessions are safe** as long as each session only touches its own `handoffs/[project].md`. The shared Studio files (`solutions/index.md`, `lessons-learned.md`, `organization-profile.md`) are still collision risks — serialize those updates when running parallel sessions.
- **Resume prompt format:** "I'm resuming Studio work on [Project]. Read handoffs/[project].md for context."

---

## Studio Improvements Backlog

[Track ideas for improving how you use charrette here. Examples:]
- [ ] Fill in organization-profile.md with your tech stack defaults
- [ ] Complete first architecture session and verify output quality
- [ ] Add first real lesson to knowledge/lessons-learned.md

---

## Resume Prompt

```
I'm resuming Studio work. Read handoffs/studio.md and the relevant project handoff file.
```
