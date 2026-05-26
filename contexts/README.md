# Contexts

This directory holds client or project-specific context files for **professional workspace** sessions.

## When to use this

If you do client work (consulting, contract, agency), create one file here per client:

```
contexts/
├── acme-corp.md
├── startup-xyz.md
└── ...
```

## What goes in a context file

A client context file is similar in structure to `docs/organization-profile.md` but scoped to a specific client engagement. Include:

- Client name, industry, and brief description
- Their tech environment (existing systems, approved tools, cloud provider)
- Team and stakeholder context
- Compliance or security requirements specific to this engagement
- Any constraints unique to this client (budget, timeline, vendor relationships)
- Notes that should influence architecture recommendations for this client

## How the Studio uses it

For solutions with `workspace: professional` in `solutions/index.md`, the Chief Architect loads `contexts/[client].md` **instead of** `docs/organization-profile.md`. This keeps client-specific context separate from your general org defaults.

## Privacy note

Client context files may contain sensitive information. Add specific files to `.gitignore` if needed:

```
contexts/acme-corp.md
```

Or use the naming convention `contexts/[client].private.md` — any file matching `*.private.md` is already gitignored by default.

## Example structure

```markdown
# Client Context — [Client Name]

**Industry:** [e.g., Healthcare, Finance, Retail]
**Engagement type:** [e.g., Staff augmentation, project-based, retainer]

## Their Environment
- Cloud: [AWS / Azure / GCP / on-prem]
- Auth: [e.g., Entra ID, Okta]
- Existing systems: [list]

## Constraints
- [Budget, timeline, compliance requirements]

## Team Context
- [Who we're working with, decision makers, technical contacts]

## Notes
- [Anything else that should influence architecture recommendations]
```
