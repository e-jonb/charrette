# Co-Architecture Question Flow Template

> **Purpose:** This document defines the structured conversation flow that guides every new solution architecture session. The Studio's CLAUDE.md references this flow to ensure consistent, thorough solution scoping before any code is written.

---

## How This Flow Works

Each new chat in this Studio follows a phased conversation. The architect (Claude) guides the user through progressive discovery, confirming understanding at each phase gate before advancing. The flow adapts based on solution complexity — a simple DevOps script gets the "light path" while a full PWA gets the complete treatment.

**Key Principle:** Ask, don't assume. Every decision should be explicit and documented.

---

## Architect Role Distinction: Studio vs. CLI

This framework uses **two architect roles** that operate at different levels. It is critical that developers (and the AI agents themselves) understand which architect to engage and when.

### Chief Architect — Studio Repo (Claude Code)

| Attribute | Detail |
|---|---|
| **Where** | Solution Architect Studio repo — Claude Code session |
| **Role** | Strategic design and solution scoping |
| **When to use** | New solutions, major architectural pivots, scope changes, technology decisions that affect multiple components, strategic questions |
| **Context available** | Studio repo context: CLAUDE.md, org profile, question flow, knowledge base, solutions index |
| **Outputs** | Solution files written directly to disk, solutions index updates, knowledge base entries, ADR records for foundational decisions |
| **Analogy** | The architect who designs the building before construction starts |

### Tactical Architect — CLI (Claude Code, Gemini, Codex, Cursor, etc.)

| Attribute | Detail |
|---|---|
| **Where** | CLI tool or IDE during active development |
| **Role** | Tactical architecture guidance during implementation |
| **When to use** | In-flow questions: "Should this be a separate service?", "What pattern for this data flow?", component design, API shape decisions, resolving implementation trade-offs |
| **Context loaded** | `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/decisions/`, `docs/SCOPE.md`, `docs/API_SPEC.md`, `docs/DATA_MODEL.md` |
| **Outputs** | New/updated ADR files in `docs/decisions/`, updates to `ARCHITECTURE.md`, scoped prompts for coding agents, `docs/DEV_LOG.md` entries |
| **Analogy** | The lead engineer on the construction site making structural calls in real-time |

### Decision Routing Guide

Developers should use this guide to determine which architect to engage:

**Stay in CLI (Tactical Architect):**
- "What design pattern should I use for this component?"
- "Should this API endpoint be sync or async?"
- "How should I structure the state management for this feature?"
- "Should I split this into two services or keep it in one?"
- "What's the right error handling approach here?"
- Implementation-level decisions that don't change the overall system shape

**Return to Studio Repo (Chief Architect):**
- "We need to add a new major feature that wasn't in the original scope"
- "The chosen auth approach isn't working — should we change providers?"
- "We need to rethink the data model fundamentally"
- "Should we switch from monolith to microservices?"
- "The tech stack choice is causing problems — should we pivot?"
- Decisions that change scope, technology, or system boundaries

**Rule of thumb:** If the decision would require updating `docs/SCOPE.md` or changing a foundational ADR, go to the Studio repo. If it only affects `docs/ARCHITECTURE.md` details or creates a new tactical ADR, the CLI architect can handle it.

### Handoff Between Architects

When a developer returns from the Studio to the CLI after a strategic decision:

1. The Studio session should produce a **prompt for the CLI architect** that includes the decision made and rationale, which docs need updating, and implementation guidance for the coding agents.
2. The developer pastes this prompt into the CLI architect agent session.
3. The CLI architect updates the relevant docs and produces scoped prompts for the coding agents.

When a CLI architect determines a question is strategic:

1. The CLI architect should say: *"This decision affects [scope/foundation]. I recommend taking this to the Studio repo architecture session (Chief Architect). Here's what to bring:"*
2. It generates a summary of the current context and the specific question.
3. The developer takes this to the Studio repo, gets direction, and returns.

---

## Phase 0: Triage — What Are We Building?

**Goal:** Determine solution complexity to select the right path.

### Questions:
1. **"What do you need to build? Give me the elevator pitch — one or two sentences."**
2. **"Is this a full application (web app, PWA, API service) or a utility/script (DevOps, automation, one-off tool)?"**

### Routing Logic:
- **Full Application** → Continue to Phase 1 (Full Path)
- **Utility/Script** → Jump to Light Path (see below)
- **Unclear** → Ask clarifying follow-up before routing

---

## FULL PATH: Phases 1–6

### Phase 1: Problem & Purpose

**Goal:** Establish the "why" before the "what." Understand the problem space, users, and success criteria. Reference org context (from `docs/organization-profile.md`) to connect this solution to the broader business.

### Questions:
1. **"Who are the primary users of this solution? Internal team, external customers, or both?"**
2. **"What problem does this solve for them? What are they doing today without it?"**
3. **"What does success look like? How will you know this solution is working?"**
4. **"Are there any existing systems this needs to integrate with or replace?"**
   - Cross-reference with org context: known systems, infrastructure, SSO provider, etc.
5. **"Any hard constraints I should know about upfront?"** (budget, timeline, compliance, hosting limitations, etc.)
   - Cross-reference with org context: approved tech, security requirements, hosting environment

### Phase Gate:
> Summarize back: "Here's what I understand about the problem and purpose: [summary]. I've noted the following org-level constraints that apply: [relevant items from org context]. Does this capture it correctly, or should we adjust anything?"

---

### Phase 2: Scope & Features

**Goal:** Define MVP boundaries clearly. Separate must-haves from nice-to-haves. Explicitly name what's out of scope.

### Questions:
1. **"Let's define the MVP — what are the absolute must-have features for a first usable version?"**
   - Guide with categories if needed: user management, core workflows, data entry/output, notifications, reporting
2. **"What features would be great to have in v2 but aren't blockers for launch?"**
3. **"Is there anything that might seem related but is explicitly NOT part of this solution?"**
   - Capture out-of-scope items — these prevent scope creep later
4. **"Does this need to work offline or in limited connectivity?"** (PWA-specific)
5. **"Any role-based access needs? Who can see/do what?"**

### Phase Gate:
> Present a structured scope summary:
> - **MVP Features:** [list]
> - **v2 Candidates:** [list]
> - **Out of Scope:** [list]
>
> "Does this scope feel right? Too ambitious for MVP? Anything missing?"

---

### Phase 3: Technical Architecture

**Goal:** Make key technology decisions with rationale. This phase produces the backbone of the architecture document and the first ADR records.

> **Note:** Cross-reference `docs/organization-profile.md` before asking tech questions. Your org defaults should pre-answer many of these. Confirm rather than re-ask: "Based on your org standards, I'll go with [X] — does that still apply here?"

### Questions:

#### Front-End
1. **"For the front-end: based on this project's needs and your org defaults, I'd recommend [framework] because [reasons]. Does that align, or do you have a strong preference?"**
   - Reference your org's framework preference from `docs/organization-profile.md`
   - Whatever is chosen, record the rationale as an ADR
2. **"For UI styling — confirm we're using [org default] for styling, or is there a reason to deviate?"**
3. **"Will this be a PWA with offline capabilities, installability, push notifications?"**

#### Back-End
4. **"What does the back-end need to do? APIs only, background processing, real-time features?"**
5. **"Language/framework preference for the API layer?"** (Node/Express, Python/FastAPI, .NET, Laravel, etc.)
   - Reference org defaults from organization-profile.md
6. **"Any serverless vs. traditional hosting preference?"**

#### API Architecture
7. **"Who will use this tool? Internal users only, or external users too (customers, vendors, partners)?"**
   - **External-facing:** Middle-tier API is **mandatory**. No secrets in browser-accessible code.
   - **Internal-only:** Middle-tier API is **highly recommended** for consistency and future-proofing, but not strictly required. If skipping it, record the reasoning as an ADR.
   - Present the recommendation with trade-offs and let the user decide.

#### Data Layer
8. **"What kind of data are we storing? Relational, document-based, or both?"**
9. **"Expected data volume — small (thousands of records), medium (hundreds of thousands), or large (millions+)?"**
10. **"Any existing database we need to connect to?"**

#### Authentication & Security
11. **"How will users authenticate?"**
    - Cross-reference with org context: confirm the org default auth approach is right here
12. **"Any compliance requirements?"** (HIPAA, SOC2, PCI, etc.)
    - Cross-reference with org context: organizational compliance posture

#### Infrastructure
13. **"Where will this be hosted?"** (cloud provider preference, on-prem, etc.)
    - Cross-reference with org context: preferred hosting and any existing infrastructure
14. **"Any existing infrastructure we should leverage?"**

### ADR Generation:
Each major decision in this phase generates an ADR record. At minimum:
- ADR-001: Front-end framework selection
- ADR-002: Back-end technology selection
- ADR-003: API architecture approach (middle-tier vs. direct, with rationale)
- ADR-004: Database/data layer selection
- ADR-005: Authentication approach
- ADR-006: Hosting/infrastructure approach

Additional ADRs as needed for significant choices (state management, caching strategy, etc.)

### Phase Gate:
> Present the technical architecture as a structured summary:
> - **Front-End:** [framework] + [UI library] — because [rationale] (→ ADR-001)
> - **Back-End:** [framework/language] — because [rationale] (→ ADR-002)
> - **API Architecture:** [middle-tier / direct] — because [rationale] (→ ADR-003)
> - **Database:** [type/provider] — because [rationale] (→ ADR-004)
> - **Auth:** [approach] (→ ADR-005)
> - **Hosting:** [approach] (→ ADR-006)
> - **Key Integrations:** [list]
>
> "Does this architecture feel right? Any concerns or preferences I should adjust?"

---

### Phase 4: Development Strategy

**Goal:** Define how the work will be executed — phasing, agent roles (including both architect levels), parallel work boundaries, and GitHub structure.

### Questions:

#### Phasing
1. **"I'd recommend building this in the following phases: [proposed phases based on architecture]. Does this sequencing make sense?"**
   - Phase 1 is typically: project scaffolding + core data model + auth
   - Phase 2: primary feature workflows
   - Phase 3: secondary features, polish, PWA optimization
   - Phase 4: testing, documentation, deployment prep
2. **"Which phase has the most unknowns or risk? We should tackle that early."**

#### Agent Roles & Parallel Work
3. **"Based on this architecture, I'd set up the following coding agents: [proposed roles]. Sound right?"**
   - Always include: **Tactical Architect** (CLI-level, for in-flow decisions)
   - Other typical roles: Frontend Agent, Backend/API Agent, Database Agent, Testing Agent, DevOps Agent
   - Not every solution needs all roles — match to complexity
4. **"For parallel work: once the API contract is defined, frontend and backend can develop simultaneously. Are there other areas where parallelism makes sense?"**
5. **"Which coding tool do you plan to use primarily for each type of work?"**
   - Map tools to roles (e.g., Claude Code for architecture-sensitive work, other tools for specific domain work)

#### GitHub Structure
6. **"For GitHub, I'll include the standard repo setup. Any naming conventions or org-level patterns I should follow?"**
   - Cross-reference with org context: existing GitHub conventions
   - Branch naming: `feat/[feature-name]`, `fix/[issue-name]`, `chore/[task-name]`
   - PR-based merges to `main`
   - Protected `main` branch (when CI/CD is added)
7. **"Any existing repo templates or patterns from other projects we should stay consistent with?"**

### Phase Gate:
> Present development plan summary including the architect escalation model (CLI vs Studio) and confirm before generating outputs.
>
> The phasing decisions made here feed directly into `docs/DEVELOPMENT_ROADMAP.md` — a file generated in Phase 5 that gives developers an ordered build plan with deliverables, exit criteria, and a starting prompt for each phase. Capture enough detail about phase goals, sequencing rationale, and risk areas to produce that document.

---

### Phase 5: Verification & Output Generation

**Goal:** Final confirmation, then produce all deliverables.

### Verification Prompt:
> "Before I generate your solution package, let me confirm everything:
>
> **Solution:** [name and one-line description]
> **Problem:** [what it solves]
> **Users:** [who uses it]
> **MVP Scope:** [feature summary]
> **Tech Stack:** [full stack summary]
> **Architecture Decisions:** [count] ADRs recorded
> **Development Phases:** [phase summary]
> **Agent Roles:** [roles and tools — including Tactical Architect for CLI]
> **GitHub Setup:** [branch strategy and structure]
> **Org Constraints Applied:** [relevant items from org context]
>
> Ready to generate? Or do you want to adjust anything?"

### Outputs to Generate:
Once confirmed, write the following files directly to the target solution directory:

**Step 1: Ask for the target location.**
> "What should I name this solution, and where should I create it? Default: `~/projects/[solution-name]`"

**Step 2: Create the directory structure and write all files.**

**Core Files (always):**
- `SETUP_GUIDE.md` — Step-by-step instructions to initialize the development environment
- `docs/ARCHITECTURE.md` — Living system architecture document (current state of the system)
- `docs/SCOPE.md` — Solution purpose, MVP features, out-of-scope items
- `docs/decisions/ADR-001-[topic].md` through `ADR-NNN-[topic].md` — Individual architecture decision records
- `docs/DEVELOPMENT_ROADMAP.md` — Phased build plan: ordered phases with goals, deliverables, exit criteria, risk notes, and a starting prompt per phase
- `docs/DEV_LOG.md` — Initialized with architecture session summary as first entry
- `docs/TECH_DEBT.md` — Initialized with known shortcuts or deferred decisions
- `docs/CODING_STANDARDS.md` — Language/framework conventions, linting rules, naming patterns
- `CLAUDE.md` — Project-level context file for Claude Code CLI sessions (includes org context subset)
- `README.md` — Project README with setup, architecture overview, and team conventions
- `.github/PULL_REQUEST_TEMPLATE.md` — Standardized PR template

**Agent Skill Files (in `docs/agents/`):**
- `architect.md` — **Always generated.** The Tactical Architect agent for CLI use. Includes the escalation guide for when to return to the Studio.
- `frontend.md` — When the solution has a front-end
- `backend.md` — When the solution has a back-end/API layer
- `database.md` — When the solution has significant data modeling
- `testing.md` — Always recommended
- `devops.md` — When CI/CD or infrastructure work is planned

**Conditional Files:**
- `docs/API_SPEC.md` — When the solution has APIs
- `docs/DATA_MODEL.md` — When the solution has a data layer

**Step 3: Report what was created** — list all files written and a brief summary.

**Step 4: Offer to initialize Git:**
> "Want me to initialize Git, make the first commit, and create the GitHub repo? (Requires `gh` CLI for remote repo creation.)"

### Output Format Note:
All files are written directly to disk as markdown, structured in the standard repo layout. The SETUP_GUIDE.md should include tool-specific instructions for the coding tools you use (Claude Code, Gemini CLI, Codex CLI, Cursor, VS Code, etc.).

---

### Phase 6: Studio Housekeeping

**Goal:** Update the studio's knowledge base and solution registry so future sessions benefit from what was learned.

### Required Actions:
At the end of every architecture session, always do:

1. **Update `solutions/index.md`** — Append the new solution with name, date, tech stack, and key decisions.

2. **Create `handoffs/[solution-name].md`** — Every solution gets a handoff file. No exceptions. Include: what was designed, key ADRs (or design decisions), repo location and structure, current status, what's next, and the resume prompt. Also add the project to the active projects table in `handoffs/studio.md`.

3. **Ask about knowledge capture:**
> "Did anything come up in this session that's worth capturing for future reference? Business context I should remember, or technical lessons that would help next time?"
If yes, append to `knowledge/lessons-learned.md` or `knowledge/business-context.md` as appropriate.

4. **Ask about org profile updates:**
> "Should any of what we discussed update the organization profile? New systems, changed standards, updated team info?"
If yes, edit `docs/organization-profile.md` directly.

5. **Offer next steps:**
> "Your solution is ready at `[target directory]`. Next steps:
> 1. `cd [target directory]` and review the generated files
> 2. If you didn't already, run `git init && git add . && git commit -m 'Initial architecture scaffold'`
> 3. Create the GitHub repo and push
> 4. Follow SETUP_GUIDE.md to set up your dev environment
> 5. Start coding using the agent skill definitions in `docs/agents/`
>
> For strategic architecture questions later, come back to this studio repo. For tactical questions, the Tactical Architect agent in your solution repo handles those."

---

## LIGHT PATH: Utility Scripts & Small Tools

**For:** DevOps scripts, sys admin tools, automation utilities, one-off tools

### Questions (Condensed):
1. **"What does this script/tool need to do?"**
2. **"What language?"** (PowerShell, Python, Bash, etc.)
3. **"Where does it run?"** (local machine, server, CI pipeline, scheduled task)
4. **"Any inputs/outputs?"** (files, APIs, databases, CLI arguments)
5. **"Any error handling or logging needs?"**
6. **"Should this live in its own repo or in an existing repo's `scripts/` folder?"**

### Outputs (Condensed):
- Brief `README.md` for the script
- The script file itself (or a starter template)
- Usage examples
- If in existing repo: placement instructions

---

## ADR (Architecture Decision Record) Format

Each decision record follows this template and lives in `docs/decisions/`:

**Filename convention:** `ADR-NNN-[short-kebab-description].md` (e.g., `ADR-001-frontend-framework.md`)

```markdown
# ADR-NNN: [Decision Title]

**Status:** Accepted | Superseded by ADR-XXX | Deprecated
**Date:** [YYYY-MM-DD]
**Decided by:** [Chief Architect (Studio) | Tactical Architect | Team Discussion]

## Context
[What is the issue or question that prompted this decision? What constraints exist?]

## Options Considered
1. **[Option A]** — [Brief description, pros, cons]
2. **[Option B]** — [Brief description, pros, cons]
3. **[Option C]** — [Brief description, pros, cons] (if applicable)

## Decision
[Which option was chosen and why. Be specific.]

## Consequences
- **Positive:** [What this enables or improves]
- **Negative:** [What trade-offs, limitations, or risks this introduces]
- **Follow-up needed:** [Any actions triggered by this decision]

## Related
- Relates to: [other ADR numbers, if any]
- Supersedes: [older ADR number, if this replaces a previous decision]
```

### ADR Rules:
- **ADRs are append-only.** Never edit an old ADR's decision. If a decision changes, create a new ADR that supersedes the old one.
- **Both architects create ADRs.** The Chief Architect (Studio) creates foundational ADRs during solution design. The Tactical Architect creates tactical ADRs during implementation.
- **Every ADR records who decided.** The "Decided by" field distinguishes between strategic decisions (Studio) and tactical decisions (CLI). This helps developers understand the weight and context of each decision.
- **Number sequentially.** Use a simple incrementing number. Gaps are fine (if an ADR is drafted but not accepted, skip the number).

---

## Context Handoff Protocol

When the user requests a context handoff (at any point in the conversation), generate a **`CONTEXT_HANDOFF.md`** file containing:

```markdown
# Context Handoff: [Solution Name]
**Generated:** [date]
**Session Summary:** [1-2 sentence overview of what was covered]

## Decisions Made
- **ADR-001 [topic]:** [choice] — because [rationale]
- **ADR-002 [topic]:** [choice] — because [rationale]
...

## Current State
- **Phase Completed:** [which phases were finished]
- **Current Phase:** [where we are]
- **Blockers/Open Questions:** [any unresolved items]

## Key Context
[Paste or reference the most important architectural decisions, scope boundaries, and technical choices]

## Org Context Applied
[Which organizational constraints, standards, or systems were factored into decisions]

## Next Steps
1. [What to do next]
2. [And then]
...

## Files Generated
- [List of any files/artifacts produced in this session]

## Prompt to Resume
> Paste this into a new chat to resume:
> "I'm continuing an architecture session for [Solution Name]. Here is the context handoff from the previous session: [paste CONTEXT_HANDOFF.md contents]. Please review and confirm your understanding, then we'll continue from [next phase/step]."
```

---

## Agent Skill Definition Template

Each agent skill file follows this structure (stored in `docs/agents/`):

```markdown
# Agent: [Role Name]
**Tool:** [Claude Code / Gemini CLI / Codex CLI / Cursor]
**Scope:** [What this agent is responsible for]

## Context Files (Load These)
- `CLAUDE.md` (or equivalent project context)
- `docs/ARCHITECTURE.md` — [specific sections relevant to this agent]
- [Other relevant docs]

## Context Files (Do NOT Load)
- [Files outside this agent's scope — keeps context window clean]

## Primary Tasks
1. [Task type this agent handles]
2. [Another task type]

## Conventions & Rules
- [Coding standards specific to this agent's domain]
- [Framework-specific patterns to follow]
- [Common mistakes to watch for]

## Escalation Rules
- **Handle directly:** [types of decisions this agent can make autonomously]
- **Escalate to Tactical Architect:** [types of questions that need architectural input]
- **Escalate to Chief Architect (Studio):** [types of questions that need strategic input — should be rare for coding agents; they'd go through the Tactical Architect first]

## Prompt Template
> Use this prompt to initialize a session with this agent:
> "[Role-specific prompt that loads the right context and sets behavioral expectations]"

## Handoff Protocol
- **Receives from:** [Which agent/phase provides input]
- **Delivers to:** [Which agent/phase consumes output]
- **Artifacts produced:** [What this agent creates — code files, docs, tests, etc.]
```

---

## Tactical Architect — Special Definition

The Tactical Architect is unique because it operates *between* the coding agents and the Chief Architect. Its skill definition includes additional responsibilities:

```markdown
# Agent: Tactical Architect
**Tool:** Claude Code (preferred — best multi-file reasoning) or similar
**Scope:** Tactical architectural decisions during implementation, documentation stewardship, coding agent coordination

## Context Files (Load These)
- `CLAUDE.md`
- `docs/ARCHITECTURE.md`
- `docs/decisions/` (all ADR files)
- `docs/SCOPE.md`
- `docs/API_SPEC.md` (if exists)
- `docs/DATA_MODEL.md` (if exists)
- `docs/TECH_DEBT.md`
- `docs/DEV_LOG.md` (recent entries)

## Context Files (Do NOT Load)
- Source code files (unless specifically needed to answer an architecture question)
- Test files
- Config/build files

## Primary Tasks
1. Answer architectural questions from developers or other agents during implementation
2. Create new ADR records for tactical decisions (using the ADR template)
3. Update `docs/ARCHITECTURE.md` when decisions change the system design
4. Update `docs/DEV_LOG.md` with significant architectural events
5. Generate scoped prompts for coding agents after architectural decisions
6. Identify when a question exceeds tactical scope and needs Chief Architect input

## Decision Authority
**This agent CAN decide:**
- Design patterns for specific components
- API endpoint structure and naming
- Data flow between existing components
- Error handling strategies
- Code organization within established boundaries
- Whether to create a new module vs. extend an existing one

**This agent CANNOT decide (escalate to Chief Architect (Studio)):**
- Adding or removing major components or services
- Changing the technology stack
- Expanding or contracting MVP scope
- Modifying authentication or security architecture fundamentally
- Any decision that would require updating `docs/SCOPE.md`

## Escalation Protocol
When a question is beyond this agent's authority:
1. Tell the developer: "This is a strategic decision that affects [scope/foundation]. I recommend taking it to the Studio repo architecture session."
2. Generate a context summary for the developer to bring to the Studio including the current state of the relevant component/system, the specific question or trade-off, options identified (if any), and which ADRs and docs are relevant.
3. When the developer returns with the Chief Architect's direction, update the relevant docs and produce implementation prompts.

## Prompt Template
> "You are the Tactical Architect for [project name]. Your job is to make tactical architectural decisions during implementation, keep the architecture docs accurate, and coordinate coding agents. You have authority over design patterns, component structure, and implementation approaches within the established architecture. For decisions that change scope, technology, or system boundaries, you escalate to the Chief Architect (Studio). Always record decisions as ADRs. Always update ARCHITECTURE.md when the system design changes. When answering questions, reference specific ADRs and architecture docs to ground your reasoning."
```

---

## Guiding Principles (Embedded in All Phases)

These principles should guide every recommendation:

1. **Sequential first, parallel later** — Get the first feature working end-to-end before parallelizing work across agents.
2. **Isolated context per agent** — Each agent sees only what it needs. Don't dump the entire codebase into every session.
3. **Markdown is the shared brain** — All decisions, architecture, and context live in version-controlled markdown files, not in chat history.
4. **Two-tier architecture governance** — Strategic decisions go through the Studio; tactical decisions happen in the CLI. Both are recorded as ADRs with clear attribution.
5. **Each LLM for what it does best** — Claude for architecture and multi-file reasoning, other tools for code generation and debugging.
6. **Test before you trust** — AI-generated code must be verified. Include testing expectations in every agent skill.
7. **Update docs with every significant change** — Architecture docs, ADRs, dev log, and tech debt should reflect reality at all times.
8. **Branch isolation** — Every feature gets its own branch. PRs are the merge mechanism. No direct pushes to main.
9. **Clear, incremental prompts** — Break complex tasks into specific, scoped instructions rather than asking for "build the whole thing."
10. **Context handoff readiness** — Any session should be able to produce a handoff document at any time.
11. **Tool-agnostic core, tool-specific edges** — Context files work universally; setup instructions include tool-specific variants.
12. **Org context flows down, not sideways** — Organizational standards live in the Studio repo and get distilled into repo-level context. Individual repos don't define org policy.
