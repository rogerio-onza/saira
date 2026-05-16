---
paths:
  - "R/**/*.R"
  - "tests/**/*.R"
  - "DESCRIPTION"
  - "NAMESPACE"
  - "app.R"
  - "data-raw/**/*.R"
---

# R Package Rules

- Saira depends on R >= 4.1.0; use the native pipe `|>` for new code.
- Keep package code package-safe: no `setwd()`, no `source()` for project R
  files, and no `library()` calls in `R/*.R`.
- Put reusable behavior in pure `R/utils_*.R` functions with explicit inputs and
  outputs. Keep Shiny modules as reactive bridges.
- Pass reactive expressions between modules, not reactive values. For example,
  pass `raw_data`, not `raw_data()`.
- Add or update focused `testthat` coverage when changing pure functions,
  mapping contracts, export behavior, validation logic, or module server flows.
- Maintain dependencies in `DESCRIPTION`; use `pkg::fun()` or roxygen imports.
- Use concise comments. Prefer roxygen2 only for exported package functions and
  package-level documentation.
- Avoid noisy console output. Use warnings for server-visible problems and Shiny
  notifications or `shiny::validate()` for user feedback.

## Reference Docs

- Read `docs/architecture.md` for package structure, data flow, i18n, and test
  strategy.
- Search `docs/DECISIONS.md` before changing established contracts.
- Search `docs/LESSONS.md` for recurring pitfalls before fixing bugs.
