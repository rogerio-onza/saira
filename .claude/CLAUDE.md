# Saira Project Instructions

## Project

Saira is an R package-based Shiny application for standardizing biodiversity
datasets to Darwin Core. The UI is bilingual (PT-BR/EN-US); code, comments, and
tests should stay in English.

## Always

- Keep the package structure: no `global.R`, no monolithic `server.R`, and no
  `source()` calls for project R files.
- Put business logic in pure `R/utils_*.R` functions. Shiny modules in
  `R/mod_*.R` should bridge UI/reactivity to pure functions.
- Keep `R/app_server.R` as an orchestrator that wires modules and passes
  reactives; do not add business logic there.
- Use `package::function()` or roxygen imports in `R/*.R`; do not call
  `library()` inside package R files.
- Use `tr(key, lang)` and `inst/extdata/i18n.json` for user-facing UI text.
- Never use `setwd()`. Prefer package-safe paths and `system.file()` for
  installed resources.
- Use the native R pipe `|>` for new R code.
- For any task that writes, reviews, or refactors code, apply
  `.claude/rules/karpathy-guidelines.md` before making changes.
- Treat `docs/` as reference material. Read only the relevant document or
  section instead of importing all docs at session start.

## Context Router

| Task | Read first |
| --- | --- |
| R/Shiny/package changes | `.claude/rules/r-package.md`, then relevant sections of `docs/architecture.md` and `docs/DECISIONS.md` |
| UI, CSS, layout, visual states | `.claude/rules/ui-design.md`, `docs/design.md`, and visual guardrail ADRs |
| Rostrum, mapping, aliases, templates | `.claude/rules/rostrum.md`, `docs/rostrum_engine.md`, and Rostrum ADRs |
| Encoding, upload, export bundle | `docs/ENCODING_RULES.md` and upload/export ADRs |
| Recurring bug or technical decision | Search `docs/LESSONS.md` and `docs/DECISIONS.md`; update them when the change creates reusable knowledge |
| Documentation-only changes | `.claude/rules/docs-maintenance.md` |

Use the `saira-change` project skill for implementation, fixes, refactors,
reviews, or audits that need this routing workflow.

## Validation Commands

- Load package: `Rscript --vanilla -e "pkgload::load_all('.', quiet = TRUE); cat('load_all OK\n')"`
- Target one test file: `Rscript --vanilla -e "pkgload::load_all('.', quiet = TRUE); testthat::test_file('tests/testthat/test-utils-io.R')"`
- Run package tests: `Rscript --vanilla -e "devtools::test()"`
- Rebuild CSS after source CSS edits: `Rscript data-raw/build_css.R`
- Check docs routing after Claude instruction edits: `rg -n "@../docs/(claude|skill)\\.md|docs/skill\\.md|skill\\.md" .claude docs --glob '!docs/archive/**'`
