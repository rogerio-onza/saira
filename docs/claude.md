# Claude Context Organization

This document explains how Claude Code context is organized for Saira. It is a
human-readable reference, not the primary always-loaded instruction file.

## Operational Files

| File | Purpose |
| --- | --- |
| `.claude/CLAUDE.md` | Always-loaded project router with non-negotiable Saira rules and context pointers. |
| `.claude/rules/karpathy-guidelines.md` | Mandatory behavioral guardrails for writing, reviewing, and refactoring code. |
| `.claude/rules/r-package.md` | Path-scoped rules for R package, Shiny, tests, DESCRIPTION, and data-raw work. |
| `.claude/rules/ui-design.md` | Path-scoped rules for UI, CSS, Shiny layout, and design-system work. |
| `.claude/rules/rostrum.md` | Path-scoped rules for Rostrum, mapping, aliases, templates, and mapping tests. |
| `.claude/rules/docs-maintenance.md` | Path-scoped rules for docs and changelog maintenance. |
| `.claude/skills/saira-change/SKILL.md` | Task workflow for implementation, fixes, refactors, reviews, and audits. |

The former standalone coding-standards guide was removed. Its useful
operational content now lives in the Claude router, path-scoped rules, and the
`saira-change` skill.

## Reference Docs

| Task | Reference |
| --- | --- |
| Architecture, package structure, data flow, i18n, tests | `docs/architecture.md` |
| Durable technical decisions and contracts | `docs/DECISIONS.md` |
| Reusable bug lessons and project gotchas | `docs/LESSONS.md` |
| UI tokens, visual system, contrast, component states | `docs/design.md` |
| Encoding, CSV, upload, and export rules | `docs/ENCODING_RULES.md` |
| Rostrum engine, scoring, stages, aliases, templates | `docs/rostrum_engine.md` |
| Future feature ideas | `docs/roadmap.md` |

Read these documents on demand. Do not import them into `.claude/CLAUDE.md`
with `@` unless the team intentionally wants that content loaded at every
Claude session start.

## Maintenance Rules

- Keep `.claude/CLAUDE.md` short enough to act as a router.
- Put standing file-pattern rules in `.claude/rules/`.
- Put task workflows in `.claude/skills/<skill-name>/SKILL.md`.
- Keep `docs/` focused on project documentation and decisions.
- Update this file when the Claude context layout changes.

## Official References

- Claude Code memory: https://code.claude.com/docs/en/memory
- Claude Code skills: https://code.claude.com/docs/en/skills
