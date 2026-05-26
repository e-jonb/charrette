# charrette

> A structured AI-assisted solution architecture framework for Claude Code.

**charrette** is a ready-to-use Claude Code workspace that turns your AI assistant into a Chief Architect. It guides you through designing software solutions before you write a single line of code — then generates all the files you need to start building.

The name comes from the architecture term for an intensive collaborative design session. That's exactly what this is.

---

## What It Does

Most people jump straight into building. charrette slows you down for one session to make everything after it faster:

- Asks the right questions about your problem, users, and scope
- Recommends a tech stack with clear rationale
- Captures every decision as an Architecture Decision Record (ADR)
- Generates a complete solution repo scaffold — docs, ADRs, roadmap, agent skills, CLAUDE.md — written directly to disk
- Maintains a knowledge base of lessons learned across projects

It's designed around a **two-tier architecture governance model**: the Chief Architect (this Studio) makes foundational decisions, and a Tactical Architect agent in each solution repo handles implementation-time decisions. Both record ADRs. Neither one codes — they guide the people and agents who do.

---

## Requirements

- [Claude Code](https://claude.ai/code) (the CLI tool)
- A Claude account with API access

That's it. No installs, no dependencies.

---

## Getting Started

### 1. Fork or clone this repo

```bash
git clone https://github.com/your-username/charrette.git my-studio
cd my-studio
```

### 2. Fill in your organization profile

Open `docs/organization-profile.md` and fill in your details. This is the single source of truth for your tech stack preferences, team context, and organizational defaults. The Chief Architect reads this at every session start to avoid re-asking things you've already answered.

### 3. Start Claude Code in this directory

```bash
claude
```

Claude Code will load `CLAUDE.md` automatically and initialize as your Chief Architect.

### 4. Begin a session

Claude will ask you to route your session:

1. Resuming work on an existing solution
2. Starting a new solution
3. Something else

Pick one and follow the conversation.

---

## What Gets Generated

When you complete an architecture session, charrette writes a complete solution repo scaffold directly to disk:

| File | Purpose |
|---|---|
| `docs/decisions/ADR-NNN-*.md` | Architecture Decision Records — one per major decision |
| `docs/SCOPE.md` | MVP features, v2 candidates, explicit out-of-scope |
| `docs/ARCHITECTURE.md` | System design overview |
| `docs/API_SPEC.md` | API contract (if applicable) |
| `docs/DATA_MODEL.md` | Data schema (if applicable) |
| `docs/CODING_STANDARDS.md` | Conventions for the chosen stack |
| `docs/DEVELOPMENT_ROADMAP.md` | Phased build plan with starting prompts per phase |
| `docs/agents/architect.md` | Tactical Architect skill for CLI use |
| `docs/agents/*.md` | Other agent skills (frontend, backend, testing, etc.) |
| `CLAUDE.md` | Project context for Claude Code sessions |
| `README.md` | Project overview |
| `SETUP_GUIDE.md` | Environment setup instructions |
| `docs/DEV_LOG.md` | Initialized with the architecture session summary |
| `docs/TECH_DEBT.md` | Known deferred items |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR template |

---

## How the Studio Stays Current

charrette maintains its own knowledge base across sessions:

- `solutions/index.md` — registry of all solutions you've designed
- `handoffs/[project].md` — per-project state so you can resume any session cold
- `knowledge/lessons-learned.md` — technical patterns and gotchas captured across projects
- `knowledge/business-context.md` — organizational context that surfaces over time

The Chief Architect updates these files after every session. Future sessions load them automatically, so you're never re-explaining your stack preferences or re-learning lessons from past projects.

---

## Starter Lessons Learned

`knowledge/lessons-learned.md` comes pre-loaded with a small set of universally applicable lessons distilled from real architecture sessions. They cover things like:

- When to choose a broader repo name vs. a narrow one
- How to think about specialist agent skills vs. a single full-stack agent
- What starting prompts should specify about commits and deploys
- How to handle tools designed for user-now vs. user-later
- When and how to archive a development roadmap as it grows

**These are opinionated.** If any of them don't fit how you work, edit or remove them. They live in `knowledge/lessons-learned.md` — just delete the entries you disagree with. They're there as a useful starting point, not gospel.

---

## The Two-Tier Architecture Model

charrette uses a deliberate split between two architect roles:

### Chief Architect (this Studio)
- Makes foundational decisions: scope, tech stack, system boundaries, security
- Runs in this repo
- Creates foundational ADRs (ADR-001 through ADR-00N during solution design)
- Handles escalations when tactical decisions have strategic implications

### Tactical Architect (each solution repo)
- Makes implementation-time decisions: design patterns, component structure, API shape
- Runs in the solution repo via the `docs/agents/architect.md` skill
- Creates tactical ADRs during development
- Escalates to the Chief Architect when decisions affect scope or tech stack

This separation keeps strategic decisions out of implementation sessions and gives developers a clear escalation path when something bigger comes up.

---

## Workspace Types

charrette supports three workspace types out of the box. Configure yours in `docs/organization-profile.md`:

| Type | Use for | Client context |
|---|---|---|
| **Personal** | Solo or volunteer tools | None — org profile applies |
| **Professional** | Client engagements | Per-client context file in `contexts/[client].md` |
| **Business** | Commercial products with co-founders | Org profile + product-specific context |

---

## Contributing

PRs welcome. If you've built something with charrette and learned something worth capturing, consider opening a PR to add it to the starter `lessons-learned.md`.

---

## License

MIT — use it freely, including commercially. See [LICENSE](LICENSE).
