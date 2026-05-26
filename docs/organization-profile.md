# Organization Profile

> **Purpose:** This document provides organizational context that applies to ALL solutions built through this Studio. The Chief Architect references this to pre-populate constraints, ensure consistency across solutions, and avoid re-asking questions that have already been answered.
>
> **Instructions:** Fill in this file before your first architecture session. The more complete it is, the less the Studio will re-ask you. Update it over time as your standards evolve — the Studio will prompt you to update it at the end of sessions when something changes.
>
> **Last updated:** [YYYY-MM-DD]
> **Owner:** [Your Name / Team Name]

---

## Development Context

### About This Practice

- **Developer(s):** [Your name, role, and a sentence about what you build]
- **Primary Focus:** [Type of software you build — e.g., PWAs, internal tools, data pipelines, mobile apps]
- **Philosophy:** [Your development philosophy — e.g., "get working software deployed quickly and iterate" vs. "design thoroughly before building"]
- **Approach:** [How you use AI tools in your workflow]

### Workspace Types

Define the types of work you do. Adapt this table to fit your context — add, remove, or rename workspace types as needed.

| Type | Context | Examples | Repo location |
|---|---|---|---|
| Personal | Solo or volunteer tools | [project names] | `~/projects/` |
| Professional | Client engagements | [client names/types] | `~/projects/_professional/` |
| Business | Commercial products | [product names] | `~/projects/_business/` |

> **Professional workspaces:** For client engagements, create a `contexts/[client].md` file with client-specific context. The Studio will load that file instead of this one for professional workspace sessions.

### Development Principles

List the principles that guide how you build. These will influence the Studio's recommendations.

1. [Principle 1 — e.g., "Clarity over cleverness — prefer readable, maintainable solutions"]
2. [Principle 2 — e.g., "Deploy early — working code in production beats perfect code in dev"]
3. [Principle 3 — e.g., "Document as you go — context files keep AI sessions coherent across sessions"]
4. [Add more as needed]

---

## Technical Standards

### Approved Tech Stack

Fill in your preferred technologies. These become the Studio's defaults — it will recommend these and ask you to confirm rather than starting from scratch each session.

**Front-end framework:**
- [e.g., React, Angular, Vue, Svelte — and when you use each]
- [UI styling approach — e.g., Tailwind CSS, CSS Modules, styled-components]

**Back-end / API layer:**
- [Language and framework — e.g., Node.js + Fastify, Python + FastAPI, .NET, Laravel]
- [Type safety approach — e.g., TypeScript strict mode]
- [API pattern — e.g., REST, GraphQL, tRPC]

**Database:**
- [Primary database — e.g., PostgreSQL, MySQL, MongoDB]
- [ORM or query layer — e.g., Prisma, Drizzle, SQLAlchemy]

**Authentication:**
- [Preferred auth approach — e.g., session-based with Lucia v3, JWT, Auth0, Entra ID SSO]
- [OAuth providers you use — e.g., Google, GitHub, Microsoft]

**AI Integration:**
- [If you build AI features: preferred model/provider, key patterns you follow]
- [E.g., Claude API via Anthropic SDK; context assembly pattern for persistent memory]

**PWA / Offline:**
- [If you build PWAs: offline strategy, service worker tooling — e.g., Workbox via vite-plugin-pwa]

**Hosting:**
- [Preferred hosting — e.g., Render.com, Vercel, AWS, Azure, GCP, Railway]
- [Deployment workflow — e.g., two-branch git workflow: main + production]

**Document rendering (optional):**
- [If you render docs from markdown: toolchain — e.g., Pandoc + Typst for Word/PDF]

### API Architecture Rule

- [State your rule — e.g., "Middle-tier API always. No direct browser-to-database calls."]

### Data Protection

- [Any data handling rules — e.g., "No PII in AI prompts, code comments, or logs"]
- [Compliance requirements — e.g., HIPAA, SOC2, GDPR, PCI]

---

## Team Context

### Team Composition

- **Developers:** [Number of developers, roles — e.g., "Solo developer" or "2 FE + 1 BE + 1 tech lead"]
- **AI tools in use:** [Which AI coding tools — e.g., Claude Code, Cursor, Gemini CLI, Copilot]
- **Other tools:** [IDEs, project management, communication]

### GitHub Organization

- **Repo naming convention:** [e.g., lowercase with hyphens: `project-name`]
- **Branch naming convention:** [e.g., `feat/[name]`, `fix/[name]`, `chore/[name]`]
- **PR requirements:** [e.g., one approval required, self-review for solo]
- **Default branch:** [e.g., `main`]

### Communication Style

- [How you write — e.g., "Plain language, no corporate-speak, explain the why alongside the what"]
- [User-facing copy tone — e.g., "Direct, friendly, jargon-free"]

---

## Organizational Defaults

These defaults apply unless a specific solution has documented reason to deviate. Fill these in and the Studio will use them as starting recommendations for every new solution.

- **Frontend:** [framework + language + styling]
- **Backend:** [framework + language + ORM]
- **Database:** [type and provider]
- **API pattern:** [e.g., middle-tier always]
- **Auth:** [default auth approach]
- **AI:** [default model/SDK if applicable]
- **Hosting:** [default host]
- **Repo structure:** [e.g., feature branches → PR → main]
- **Branch strategy:** [e.g., feat/fix/chore branches → PR (N reviews) → main]
- **Documentation:** [e.g., all project docs in `docs/` folder]
- **ADR practice:** [e.g., all significant decisions recorded in `docs/decisions/`]
- **Agent definitions:** [e.g., all agent skills in `docs/agents/`]
- **Tech debt tracking:** [e.g., every repo has a `TECH_DEBT.md`]

---

## Development Patterns

### Established Workflow Patterns

Document patterns that have worked well for you. The Studio will apply these rather than re-discovering them.

**[Pattern Name]:**
- [Description — e.g., "Phase-based development: major features implemented in sequential phases, each with clear deliverables and exit criteria"]

**[Pattern Name]:**
- [Description]

### Migration Strategy

- [Your approach to schema migrations — e.g., "Proper migrations in production; drop/recreate acceptable in beta only"]

---

## Notes & Exceptions

- [Any important caveats or one-off rules — e.g., "This is a solo practice — design for one-developer maintainability"]
- [Known constraints — e.g., "No Windows deployment targets"]
- [Strong preferences — e.g., "TypeScript everywhere, no plain JavaScript"]
