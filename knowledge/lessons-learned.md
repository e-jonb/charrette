# Lessons Learned

> Technical patterns, gotchas, and practical wisdom from architecture sessions. Newest entries at top. Each entry tagged with date and source.
>
> **These are starter lessons** included with charrette as a useful foundation. They're opinionated and based on real experience. If any of them don't fit how you work, edit or delete them — they're just markdown. Add your own entries as you build things and learn things.

---

<!-- New entries go here, above the divider. Format:

## [Date] — [Solution Name or General]
**Topic:** [What was learned]
**Detail:** [The lesson, pattern, or gotcha]
**Impact:** [How this should influence future recommendations]

-->

## General — Repo naming: choose broader when scope might grow
**Topic:** Choose the broader name at scaffold time — renaming repos later is expensive
**Detail:** When a project is first scaffolded, there's a temptation to name it narrowly (e.g., `user-auth-service` when it might become a full platform). Renaming after content has accumulated means broken links, retraining muscle memory, updating cross-repo references, and potentially broken submodule paths. The narrow name doesn't even buy clarity most of the time. Pattern: when in doubt, pick the more general name. Specificity can come from folder structure, not the repo name.
**Impact:** At repo-naming time, ask: "could this scope plausibly grow in the next 1–2 years?" If yes, choose the broader name. The narrow name should only win when the scope is strictly bounded by something external (e.g., a single product, a single regulation, a single client engagement that won't expand).

## General — Specialist agent skills are for parallel work, not solo phased development
**Topic:** Specialist agent skills (`frontend.md`, `backend.md`, etc.) are designed for running multiple AI agents in parallel — not for a single agent working through sequential phases
**Detail:** The `docs/agents/` templates were designed for coordinating multiple AI agents simultaneously — one building API routes while another builds UI, possibly using different tools. They are NOT meant to be used as skill definitions for a single full-stack agent working through sequential phases. The Tactical Architect is the right choice for phased work that spans multiple layers.
**Impact:** Don't generate specialist agent skills for a solution until there's a concrete plan to run parallel agents. A single Tactical Architect agent handles full-stack phased work well on its own. Revisit specialist agents when the team is ready to coordinate parallel workstreams across multiple AI tools.

## General — Starting prompts must specify commit and deploy intent
**Topic:** Starting prompts in DEVELOPMENT_ROADMAP.md should specify what to commit, how to commit it, and whether to deploy — not leave it up to the AI agent
**Detail:** Without explicit commit/deploy guidance, AI sessions end with uncommitted changes and require follow-up cleanup before production can be deployed. The starting prompt is the right place to specify: (1) whether changes should be committed at the end of the session, (2) what files to stage, (3) whether to push to origin/main only or also merge to a production branch. These decisions vary by phase.
**Impact:** Every starting prompt in DEVELOPMENT_ROADMAP.md should include a "Commit and deploy" section at the end. Specify: what to stage and commit (file list or pattern), the commit message format, and the deploy intent. The Studio should verify and sign off on this section when writing the prompt.

## General — Design for user-now vs. user-later separately
**Topic:** When designing a tool that serves a current technical user but will eventually be handed off to a less technical one, these are two different products — don't compromise both by designing one
**Detail:** When a tool has a future-handoff requirement, the temptation is to design one tool that serves both audiences. That always compromises something. Better framing: design v0 for the user-now (markdown + CLI, or whatever fits their workflow), and explicitly plan v1.0 as a render/UI layer for the user-later. The structured data layer is the durable foundation; the UI is a future concern that earns its right to exist based on actual use.
**Impact:** When a personal or professional tool has a future-handoff requirement, ask: "who is the user-now and who is the user-later, and how different are they?" If the answer is "very different," design v0 for user-now with a structured-data layer, then plan a UI graduation as a future phase with explicit decision criteria (not "someday" — specific triggers like "12+ months of content" or "handoff within 18 months"). Document the deferral as an ADR.

## General — Archive completed phases to keep DEVELOPMENT_ROADMAP.md lean
**Topic:** As a project matures, DEVELOPMENT_ROADMAP.md accumulates completed phase detail that makes the working document hard to navigate
**Detail:** Completed phase detail (starting prompts, checklists, exit criteria) is valuable historically but adds bulk. The pattern: create `docs/DEVELOPMENT_ROADMAP_ARCHIVE.md` and move completed phase detail there, leaving only a summary table in the main roadmap. The main file keeps: current-state header, completed phases summary table, active/upcoming phases in full detail, and a lean backlog table.
**Impact:** When generating output files for new solutions, note in CLAUDE.md or DEVELOPMENT_ROADMAP.md that archiving is the expected pattern once the document exceeds ~1000 lines. The archive split should happen at a natural phase boundary. The Studio chief should do this during planning sessions, not mid-implementation.

## General — Fresh AI sessions for major phases reduce token costs
**Topic:** Starting a new Claude Code session for each major implementation phase dramatically reduces token usage compared to continuing a single long thread
**Detail:** Long conversation threads in AI tools consume significantly more tokens due to growing context windows. Starting fresh sessions for each major implementation phase keeps context lean. The key is creating handoff documents that carry state between sessions: current phase, what's done, what's next, and critical technical reminders. The DEVELOPMENT_ROADMAP.md starting prompt serves this purpose.
**Impact:** For multi-phase development, plan for session breaks between major phases. The starting prompt in DEVELOPMENT_ROADMAP.md is not just documentation — it's the context injection that makes fresh sessions viable. Write starting prompts as if the next session has no memory of the previous one.

---

<!-- Add your own entries above this line as you build solutions and learn things -->
