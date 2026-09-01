# Solutions Index

> Registry of all solutions designed through this Studio. Newest at top. The Chief Architect reads this at session start to inform recommendations with precedent.

---

| Date | Solution | Repo | Workspace | Format | Stack | Key Decisions | Status |
|---|---|---|---|---|---|---|---|

<!-- New entries go at the top of the table. Format:
| YYYY-MM-DD | Solution Name | GROUP/project or owner/repo, or `local` | personal / professional / business | Full App / Script / API / Personal Workspace | Stack Summary | Brief: key ADRs and notable choices | Active / Maintenance / Retired |
-->

---

## The Repo Column

`Repo` holds the solution's project path on whichever VCS you use – `owner/repo` on GitHub, `GROUP/project` on GitLab. It exists so the open MR/PR check at solution load knows what to ask about; see Session Routing in `CLAUDE.md`.

Write `local` for a solution that has no remote yet. That is a meaningful value, not a blank: it tells the architect to say the check was skipped and why, rather than printing a clean result that only means nothing was asked.

---

## Cross-Cutting Decisions

> Decisions that apply across multiple solutions. Add entries here as patterns emerge from building real things.

<!-- Format:

### [Pattern Name]
**Established:** [date, from which solution] \
**Pattern:** [What the pattern is] \
**Applied to:** [Which solutions use it] \
**Notes:** [Any caveats or evolution of the pattern]

-->
