---
paths:
  - "docs/**/*.md"
  - "CHANGELOG.md"
---

# Documentation Maintenance Rules

- Keep `docs/` as reference documentation, not always-loaded Claude memory.
- Keep `.claude/CLAUDE.md` short and operational. Do not import large docs with
  `@` unless the team explicitly chooses startup loading.
- Update `CHANGELOG.md` for notable project changes using the existing
  Portuguese Keep a Changelog style.
- Add or update `docs/DECISIONS.md` only for durable architecture decisions,
  contracts, or tradeoffs that future maintainers must understand.
- Add or update `docs/LESSONS.md` for reusable lessons learned from bugs,
  regressions, packaging, CSS, i18n, DwC, performance, or tests.
- Do not edit `docs/archive/` unless the task explicitly concerns archived
  historical material.
- Prefer concise docs that point to the canonical source instead of duplicating
  long implementation details across multiple files.

## Claude Context Files

- `.claude/CLAUDE.md` is the always-loaded router.
- `.claude/rules/*.md` contains path-scoped standing rules.
- `.claude/skills/*/SKILL.md` contains task workflows that load only when
  invoked or automatically selected by Claude.
