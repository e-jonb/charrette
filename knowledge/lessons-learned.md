# Lessons Learned

> Technical patterns, gotchas, and practical wisdom from architecture sessions. Newest entries at top. Each entry tagged with date and source.
>
> **These are starter lessons** included with charrette as a useful foundation. They're opinionated and based on real experience. If any of them don't fit how you work, edit or delete them — they're just markdown. Add your own entries as you build things and learn things.

---

<!-- New entries go here, above the divider. Format:

## [Date] — [Solution Name or General]
**Topic:** [What was learned] \
**Detail:** [The lesson, pattern, or gotcha] \
**Impact:** [How this should influence future recommendations]

-->

## General – In a shared repo, being current with `main` tells you nothing about what is in flight
**Topic:** Multi-machine sync and multi-user sync look like the same problem and are not. The first is staleness, which pulling fixes. The second is collision, which pulling cannot see. \
**Detail:** With one person and one linear history, the only thing that can go wrong is being behind, so `scripts/sync.sh` is the whole answer. Add a second person and the failure changes shape: you can be perfectly current with `main` and still be about to rewrite something a colleague has sitting in an open merge request. `git pull` structurally cannot see unmerged branches, so `sync.sh` will report a clean pull and current pins – truthfully – while three open requests restructure the file you are about to open. That is the same failure as the one `sync.sh` was built for, moved one layer out: a check passing about the wrong thing. The fix is to fetch open merge or pull requests for the selected solution's repo and print the result. Fire it once, after the routing answer exists, not at session start – before a solution is picked there is nothing to scope to, and an unscoped list of everything open in the group is noise. Report three states, not two: open requests, none open, and check-unavailable. Collapsing the third into the second is how this pattern recreates the bug it exists to prevent, because "No open MRs" and "the token expired" then render identically. Name the repo in the output line, since a clean result about the wrong project is indistinguishable from a clean result about the right one. \
**Impact:** Shared-repo Studios add an open MR/PR check to Session Routing in `CLAUDE.md` and a `Repo` column to `solutions/index.md` to feed it. Solo Studios skip it. Wherever it goes in, it reports and never acts, and it gets exercised once against a repo with a known open request before any quiet result from it is believed. \
**Credit:** Developed in a multi-user fork of charrette and contributed back. The repo-name label in the output line came from that fork.

## General – Multi-machine sync: run a sync script, not a bare `git pull`
**Topic:** Working across two machines needs an explicit pull-at-start / push-at-end habit baked into every repo's CLAUDE.md – and the naive one-line version of that instruction is wrong for any repo with submodules \
**Detail:** Without a pull-at-start rule written into the repo, AI sessions on a secondary machine silently start from stale state: the AI reads outdated files, makes decisions on them, and the divergence compounds. Putting it in CLAUDE.md rather than in a personal habit means it fires in every session regardless of which machine is in front of you. But the obvious wording – "run `git pull` before starting any work" – is incomplete, and it fails quietly rather than loudly. **`git pull` reporting "Already up to date" is not evidence the working tree is current.** There are two distinct failures and the fix people reach for only addresses one. (A) The working tree is behind the parent's pin: a plain pull moves the parent's gitlink and leaves the submodule checkout where it was. Recursing fixes this. (B) The parent's pin is behind the submodule's *own* origin: someone pushed upstream and never bumped the pointer here. Recursion does **not** fix B – it faithfully checks out whatever the parent pins, so a stale pin gets checked out stale, accurately, forever. Only an explicit pin-versus-origin comparison catches B, and B is the one that bites: a shared knowledge-base submodule can sit months behind its own origin while every consumer reports a clean, successful pull, so consumers keep serving content whose upstream was corrected long ago. The fix is a `scripts/sync.sh` that pulls recursively and then reports any submodule whose pinned commit is behind its origin. `scripts/sync.sh` in this repo is a working reference implementation – copy it into generated repos as-is. \
**Impact:** Every repo scaffolded through this Studio gets a Multi-Machine Sync section in its CLAUDE.md from day one, plus `scripts/sync.sh`. When retrofitting an existing repo, put the section near the top, before the main workflow instructions, so it is the first thing the AI reads. For a repo with no remote yet, say so explicitly in the section and give the create-a-remote command from the org profile rather than leaving it silent. Private or gitignored content (`_private/` folders, `*.private.md`) cannot sync via git – those files are machine-local by design; accept that or sync those specific folders another way.

**Ready-to-adapt CLAUDE.md section text:**

```markdown
## Multi-Machine Sync

Run `./scripts/sync.sh` before starting any work – not a bare `git pull`.
This repo is used across multiple machines, and a plain `git pull` can
report "Already up to date" while a submodule sits months behind its own
upstream. The script pulls recursively and reports any submodule whose
pinned commit is behind its origin.

At the end of every session, ensure all work is committed and pushed
(`git push origin main`) so the other machine picks up cleanly. If you
changed anything inside a submodule, push there first, then bump and
commit the pointer here – pushing the parent alone leaves the other
machine pointing at a commit it cannot fetch.
```

For a repo with **no submodules**, a one-line `git pull` instruction is still correct – but prefer the script anyway if the repo might ever gain one, so the instruction never has to change again. `scripts/sync.sh` handles the no-submodule case by treating the pull as the whole job.

**Three rules that go with it:**

- **Recurse explicitly in the script**, rather than relying on a `submodule.recurse` git config setting. Config is invisible state that does not travel with the repo – a fresh clone, another machine, or a successor maintainer will not have it.
- **The drift check reports; it never auto-bumps.** Bumping a pointer is a content change to the parent repo, and if that parent deploys anything, it changes what users see. A human who has read the missing commits decides.
- **Record the reason next to any deliberate pin.** "Intentionally pinned" and "drifted and nobody noticed" are indistinguishable from the outside, and that ambiguity is what lets a stale dependency sit unnoticed for months.

## General — Memory graduation: promote durable auto-memory into committed docs
**Topic:** Claude Code's per-project auto-memory (`~/.claude/projects/<repo>/memory/`) is local application state — invisible to git, doesn't sync across your own machines, and invisible to anyone who clones a repo fresh, including a successor who inherits a project \
**Detail:** Auto-memory accumulates genuinely useful knowledge across sessions — confirmed-working patterns, project decisions and their rationale, institutional facts about how a project operates. But it's trapped on whichever machine wrote it. The fix: at the end of a significant work session (or on request), review what got saved to auto-memory that session. Graduate anything that's a confirmed-working pattern or playbook, a project decision plus its reasoning, or an institutional fact a future maintainer needs — write it into the repo's committed docs too, in addition to the memory file, not instead of it. Leave local-only anything that's a personal interaction preference (tone, communication style) or about the human-AI relationship rather than the project. Destination depends on length: short, stable operating rules go straight into CLAUDE.md near the related section; longer-form patterns or multi-step playbooks go into `docs/PLAYBOOK.md` (or whatever this repo's existing equivalent is called — check before assuming one doesn't exist). When something graduates, append a note to the source memory entry — "Graduated to CLAUDE.md on [date]; that file is now authoritative" — so a later edit to CLAUDE.md doesn't leave a stale, contradicting copy sitting in memory with no signal it's been superseded. \
**Impact:** Every solution's generated CLAUDE.md should include a Memory Graduation section (see File Generation Order above). A fresh clone — new machine, or a successor who inherits the project — should be able to reconstruct the accumulated know-how from committed docs alone, without depending on any machine's local Claude Code state.

## General — Repo naming: choose broader when scope might grow
**Topic:** Choose the broader name at scaffold time — renaming repos later is expensive \
**Detail:** When a project is first scaffolded, there's a temptation to name it narrowly (e.g., `user-auth-service` when it might become a full platform). Renaming after content has accumulated means broken links, retraining muscle memory, updating cross-repo references, and potentially broken submodule paths. The narrow name doesn't even buy clarity most of the time. Pattern: when in doubt, pick the more general name. Specificity can come from folder structure, not the repo name. \
**Impact:** At repo-naming time, ask: "could this scope plausibly grow in the next 1–2 years?" If yes, choose the broader name. The narrow name should only win when the scope is strictly bounded by something external (e.g., a single product, a single regulation, a single client engagement that won't expand).

## General — Specialist agent skills are for parallel work, not solo phased development
**Topic:** Specialist agent skills (`frontend.md`, `backend.md`, etc.) are designed for running multiple AI agents in parallel — not for a single agent working through sequential phases \
**Detail:** The `docs/agents/` templates were designed for coordinating multiple AI agents simultaneously — one building API routes while another builds UI, possibly using different tools. They are NOT meant to be used as skill definitions for a single full-stack agent working through sequential phases. The Tactical Architect is the right choice for phased work that spans multiple layers. \
**Impact:** Don't generate specialist agent skills for a solution until there's a concrete plan to run parallel agents. A single Tactical Architect agent handles full-stack phased work well on its own. Revisit specialist agents when the team is ready to coordinate parallel workstreams across multiple AI tools.

## General — Starting prompts must specify commit and deploy intent
**Topic:** Starting prompts in DEVELOPMENT_ROADMAP.md should specify what to commit, how to commit it, and whether to deploy — not leave it up to the AI agent \
**Detail:** Without explicit commit/deploy guidance, AI sessions end with uncommitted changes and require follow-up cleanup before production can be deployed. The starting prompt is the right place to specify: (1) whether changes should be committed at the end of the session, (2) what files to stage, (3) whether to push to origin/main only or also merge to a production branch. These decisions vary by phase. \
**Impact:** Every starting prompt in DEVELOPMENT_ROADMAP.md should include a "Commit and deploy" section at the end. Specify: what to stage and commit (file list or pattern), the commit message format, and the deploy intent. The Studio should verify and sign off on this section when writing the prompt.

## General — Design for user-now vs. user-later separately
**Topic:** When designing a tool that serves a current technical user but will eventually be handed off to a less technical one, these are two different products — don't compromise both by designing one \
**Detail:** When a tool has a future-handoff requirement, the temptation is to design one tool that serves both audiences. That always compromises something. Better framing: design v0 for the user-now (markdown + CLI, or whatever fits their workflow), and explicitly plan v1.0 as a render/UI layer for the user-later. The structured data layer is the durable foundation; the UI is a future concern that earns its right to exist based on actual use. \
**Impact:** When a personal or professional tool has a future-handoff requirement, ask: "who is the user-now and who is the user-later, and how different are they?" If the answer is "very different," design v0 for user-now with a structured-data layer, then plan a UI graduation as a future phase with explicit decision criteria (not "someday" — specific triggers like "12+ months of content" or "handoff within 18 months"). Document the deferral as an ADR.

## General — Archive completed phases to keep DEVELOPMENT_ROADMAP.md lean
**Topic:** As a project matures, DEVELOPMENT_ROADMAP.md accumulates completed phase detail that makes the working document hard to navigate \
**Detail:** Completed phase detail (starting prompts, checklists, exit criteria) is valuable historically but adds bulk. The pattern: create `docs/DEVELOPMENT_ROADMAP_ARCHIVE.md` and move completed phase detail there, leaving only a summary table in the main roadmap. The main file keeps: current-state header, completed phases summary table, active/upcoming phases in full detail, and a lean backlog table. \
**Impact:** When generating output files for new solutions, note in CLAUDE.md or DEVELOPMENT_ROADMAP.md that archiving is the expected pattern once the document exceeds ~1000 lines. The archive split should happen at a natural phase boundary. The Studio chief should do this during planning sessions, not mid-implementation.

## General — Fresh AI sessions for major phases reduce token costs
**Topic:** Starting a new Claude Code session for each major implementation phase dramatically reduces token usage compared to continuing a single long thread \
**Detail:** Long conversation threads in AI tools consume significantly more tokens due to growing context windows. Starting fresh sessions for each major implementation phase keeps context lean. The key is creating handoff documents that carry state between sessions: current phase, what's done, what's next, and critical technical reminders. The DEVELOPMENT_ROADMAP.md starting prompt serves this purpose. \
**Impact:** For multi-phase development, plan for session breaks between major phases. The starting prompt in DEVELOPMENT_ROADMAP.md is not just documentation — it's the context injection that makes fresh sessions viable. Write starting prompts as if the next session has no memory of the previous one.

---

<!-- Add your own entries above this line as you build solutions and learn things -->
