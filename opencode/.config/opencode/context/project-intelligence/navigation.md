<!-- Context: project-intelligence/nav | Priority: high | Version: 1.1 | Updated: 2026-05-19 -->

# Project Intelligence — HBR ERP Admin API

> Start here for quick project understanding. These files bridge business and technical domains.

## Structure

```
/home/kienct/.config/opencode/context/project-intelligence/
├── navigation.md                   # This file - quick overview
├── business-domain.md              # Business context and problem statement
├── technical-domain-backend.md     # Laravel backend API — stack, architecture
├── technical-domain-frontend.md    # Vue 3 admin SPA — stack, patterns
├── business-tech-bridge.md         # How business needs map to solutions
├── decisions-log.md                # Major decisions with rationale
└── living-notes.md                 # Active issues, debt, open questions
```

## Quick Routes

| What You Need | File | Description |
|---------------|------|-------------|
| Understand the "why" | `business-domain.md` | Problem, users, value proposition |
| Backend tech stack | `technical-domain-backend.md` | Laravel API — stack, architecture, patterns |
| Frontend tech stack | `technical-domain-frontend.md` | Vue 3 SPA — stack, components, patterns |
| See the connection | `business-tech-bridge.md` | Business → technical mapping |
| Know the context | `decisions-log.md` | Why decisions were made |
| Current state | `living-notes.md` | Active issues and open questions |
| All of the above | Read all files in order | Full project intelligence |

## Usage

**New Team Member / Agent**:
1. Start with `navigation.md` (this file)
2. Read `technical-domain.md` for stack, patterns, and conventions
3. Follow onboarding checklist in each file

**Quick Reference**:
- Code patterns → `technical-domain.md`
- Business focus → `business-domain.md`
- Decision context → `decisions-log.md`

## Integration

This folder is referenced from:
- `/home/kienct/.config/opencode/context/core/standards/project-intelligence.md` (standards and patterns)
- `/home/kienct/.config/opencode/context/core/system/context-guide.md` (context loading)

## Maintenance

Keep this folder current:
- Run `/add-context --update` when tech stack or patterns change
- Update when business direction changes
- Document decisions as they're made
- Review `living-notes.md` regularly
