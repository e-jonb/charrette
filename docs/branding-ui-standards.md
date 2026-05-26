# Branding & UI Standards — Default Guidelines

> **Purpose:** This document provides baseline brand and UI standards for solutions without project-specific branding. Each solution may override these with its own branding document.
>
> **When to use:** Any solution that has a UI but no project-specific brand guide.
> **When to skip:** Backend-only services, scripts, APIs without a front-end, or solutions with their own branding docs.
>
> **Note:** Solution-specific branding (colors, typography, voice) should be documented in the solution's own `docs/BRANDING.md` or equivalent file.

---

## Default Design Principles

### 1. Mobile-First Design
- **Primary assumption:** Users on phones checking info on the go
- **Touch-friendly targets:** Minimum 44x44px for all interactive elements
- **Offline-first capability:** Where relevant, design for scenarios with no connectivity
- **Fast loading:** Optimize for mobile networks

### 2. Progressive Complexity
- **Hide complexity, reveal progressively**
- **Default views:** Show essential information only
- **Advanced features:** Accessible via "Show more" or settings
- **Role-appropriate interfaces:** Different users see different dashboards

### 3. Accessibility First
- **Target:** WCAG 2.1 Level AA compliance
- **Color contrast:** 4.5:1 minimum for body text, 3:1 for large text
- **Keyboard navigation:** All interactive elements accessible via keyboard
- **Screen reader support:** Proper semantic HTML, ARIA labels where needed

---

## Default Color System

When no project-specific branding exists, use these neutral defaults:

| Color Name | Hex | Usage | CSS Variable |
|---|---|---|---|
| **Primary Blue** | `#2563EB` | Primary actions, links, focus states | `--color-primary` |
| **Success Green** | `#16A34A` | Success states, completed items | `--color-success` |
| **Warning Amber** | `#D97706` | Warnings, pending items | `--color-warning` |
| **Danger Red** | `#DC2626` | Errors, destructive actions | `--color-danger` |
| **Info Cyan** | `#0891B2` | Informational messages | `--color-info` |
| **Dark Gray** | `#1F2937` | Primary text | `--color-text` |
| **Medium Gray** | `#6B7280` | Secondary text | `--color-text-secondary` |
| **Light Gray** | `#E5E7EB` | Borders, dividers | `--color-border` |
| **Background** | `#F9FAFB` | Page backgrounds | `--color-bg` |
| **White** | `#FFFFFF` | Card backgrounds, inputs | `--color-surface` |

### CSS Variables (Include in Every Web Project)
```css
:root {
  --color-primary: #2563EB;
  --color-success: #16A34A;
  --color-warning: #D97706;
  --color-danger: #DC2626;
  --color-info: #0891B2;
  --color-text: #1F2937;
  --color-text-secondary: #6B7280;
  --color-border: #E5E7EB;
  --color-bg: #F9FAFB;
  --color-surface: #FFFFFF;
}
```

---

## Default Typography

### Font Stack (System Fonts for Performance)
```css
:root {
  --font-sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  --font-mono: "SF Mono", Monaco, "Cascadia Code", "Roboto Mono", Consolas, monospace;
}

body {
  font-family: var(--font-sans);
  line-height: 1.6;
}
```

### Type Scale
| Element | Size | Weight |
|---|---|---|
| H1 | 2rem (32px) | 600 (semibold) |
| H2 | 1.5rem (24px) | 600 |
| H3 | 1.25rem (20px) | 600 |
| H4 | 1rem (16px) | 600 |
| Body | 1rem (16px) | 400 (regular) |
| Small | 0.875rem (14px) | 400 |
| Caption | 0.75rem (12px) | 400 |

---

## Spacing System

8px base unit (Tailwind-compatible):

| Token | Value | Tailwind |
|---|---|---|
| XS | 4px | `p-1` |
| S | 8px | `p-2` |
| M | 16px | `p-4` |
| L | 24px | `p-6` |
| XL | 32px | `p-8` |
| XXL | 48px | `p-12` |

---

## Component Standards

### Buttons
**Primary:**
- Background: `var(--color-primary)`
- Text: White
- Padding: 12px 24px
- Border radius: 6px

**Secondary:**
- Background: Transparent
- Text: `var(--color-primary)`
- Border: 1px solid `var(--color-primary)`

**Danger:**
- Background: `var(--color-danger)`
- Text: White

### Cards
- Background: White
- Border: 1px solid `var(--color-border)`
- Border radius: 8px
- Shadow: `0 1px 3px rgba(0,0,0,0.1)`
- Padding: 16px

### Forms
- Input height: 40px (touch-friendly)
- Border: 1px solid `var(--color-border)`
- Border radius: 6px
- Focus state: Blue border + subtle shadow
- Error state: Red border + error message below
- Labels: Above input, font-weight 500

---

## Responsive Breakpoints

| Breakpoint | Width | Target |
|---|---|---|
| Mobile | < 640px | Primary target |
| Tablet | 640px - 1024px | Secondary |
| Desktop | > 1024px | Administrative tasks |

### Mobile Layout
- Single column
- Bottom navigation (4-5 items max)
- Full-width cards
- Stack form fields vertically

### Desktop Layout
- Sidebar navigation for admin sections
- Multi-column layouts where appropriate
- Data tables (not card views)

---

## Accessibility Checklist (Mandatory)

Every UI must meet these requirements:

- [ ] All text meets WCAG AA contrast ratios (4.5:1 body, 3:1 large text)
- [ ] Interactive elements have visible focus states
- [ ] Images have alt text
- [ ] Headings follow proper hierarchy (H1 → H2 → H3, no skipping)
- [ ] Minimum touch target: 44x44px
- [ ] No information conveyed by color alone
- [ ] Keyboard navigation works for all interactive elements
- [ ] Form inputs have associated labels

---

## Content Voice & Tone

### Writing Principles
- **Clear and concise** — Active voice, short sentences, no jargon
- **User-friendly** — Acknowledge constraints, positive tone
- **Action-oriented** — Clear CTAs, obvious next steps

### Example Microcopy

**Buttons:**
- ✅ "Save Changes" (clear action)
- ❌ "Submit" (vague)

**Empty states:**
- ✅ "No events yet. Create your first event to get started."
- ❌ "No records found."

**Errors:**
- ✅ "We couldn't save your changes. Check your connection and try again."
- ❌ "Error 500: Internal server error."

**Success messages:**
- ✅ "Changes saved successfully."
- ❌ "Operation successful."

---

## Loading & Empty States

### Loading Indicators
- **Inline:** Spinner next to button text, button disabled
- **Page:** Skeleton screens showing structure with gray placeholders
- **Lists:** Show 3-5 skeleton list items

### Empty States
- Relevant icon
- Descriptive message
- Primary action button
- Optional help link

---

## What NOT to Do

- ❌ Use colors that fail contrast checks
- ❌ Make touch targets smaller than 44x44px
- ❌ Skip focus states on interactive elements
- ❌ Use jargon in user-facing copy
- ❌ Convey information by color alone
- ❌ Skip semantic HTML in favor of divs
- ❌ Ignore keyboard navigation

---

## Quick Reference for Frontend Development

Before starting UI work:
1. ✅ Set up CSS variables (colors, typography)
2. ✅ Configure Tailwind if using
3. ✅ Set up 8px spacing system
4. ✅ Determine if project has specific branding (check for `docs/BRANDING.md`)

During development:
1. ✅ Maintain WCAG AA contrast on all text
2. ✅ Keep touch targets ≥ 44x44px
3. ✅ Test keyboard navigation
4. ✅ Write clear, jargon-free copy

Before delivery:
1. ✅ Run accessibility audit
2. ✅ Test responsive behavior
3. ✅ Verify focus states work
4. ✅ Check loading and empty states
