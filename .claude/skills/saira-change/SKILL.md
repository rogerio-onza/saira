---
name: saira-change
description: Use when implementing, fixing, refactoring, reviewing, or auditing the Saira R/Shiny package. Guides targeted context discovery across architecture docs, ADRs, lessons, design, encoding, and Rostrum references without loading all docs upfront.
---

# Saira Change Workflow

Use this workflow for implementation, bug fixes, refactors, reviews, and audits
inside the Saira project.

## Start

1. Check `git status --short` and avoid overwriting unrelated user changes.
2. For any code implementation, fix, refactor, review, or audit, apply
   `.claude/rules/karpathy-guidelines.md` before editing or assessing code.
3. Read `.claude/CLAUDE.md` and the matching `.claude/rules/*.md` files if they
   are not already in context.
4. Search before reading long docs. Prefer `rg` for relevant symbols, ADR
   numbers, module names, terms, and bug keywords.

## Load Context On Demand

- R/Shiny/package structure: read targeted sections of `docs/architecture.md`.
- Durable decisions and contracts: search `docs/DECISIONS.md`.
- Repeated pitfalls or bug patterns: search `docs/LESSONS.md`.
- UI, CSS, colors, typography, spacing, and visual states: read
  `docs/design.md`.
- Encoding, upload, CSV/XLSX/export rules: read `docs/ENCODING_RULES.md`.
- Rostrum mapping, scoring, aliases, templates, and stage behavior: read
  `docs/rostrum_engine.md`.
- Future-facing features only when asked: read `docs/roadmap.md`.

Do not load every document by default. Load the smallest section that answers
the task.

## Implement

- Keep business logic in pure utilities and call it from modules.
- Keep app wiring in `R/app_server.R`; do not add business logic there.
- Preserve i18n through `tr()` and `inst/extdata/i18n.json`.
- Keep changes narrow and compatible with existing module contracts.
- Update `DESCRIPTION`, tests, CSS build output, docs, or data artifacts when
  the behavior change requires them.

## Verify

- Run the narrowest meaningful test first.
- For R/package changes, at least confirm `pkgload::load_all()` unless the task
  is documentation-only.
- For CSS source changes, rebuild CSS and run CSS guardrail tests.
- For docs-only Claude routing changes, verify no stale imports or active
  references to removed docs remain.

## Document

- Add a changelog entry for notable changes.
- Update `docs/DECISIONS.md` for new durable architecture decisions.
- Update `docs/LESSONS.md` when the work exposes reusable lessons or gotchas.
