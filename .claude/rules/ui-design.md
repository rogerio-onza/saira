---
paths:
  - "R/app_ui.R"
  - "R/mod_*.R"
  - "inst/app/www/**/*.css"
  - "inst/app/www/**/*.js"
  - "docs/design.md"
---

# UI And Design Rules

- Read `docs/design.md` before changing colors, typography, spacing, component
  states, CSS tokens, or Shiny layout.
- Keep the operational UI compact and task-focused. Saira is a scientific data
  tool, not a marketing site.
- All visible UI text must use `tr(key, lang)` and keys in
  `inst/extdata/i18n.json`; avoid hardcoded PT/EN strings in modules.
- Put reusable CSS in the modular source files under `inst/app/www/css/` and
  rebuild the bundle with `Rscript data-raw/build_css.R`.
- One-off CSS rules should live with the originating module when that is the
  established pattern; do not patch generated bundle output directly.
- Preserve DataTable and page-scroll guardrails. Search `docs/DECISIONS.md` for
  UI, CSS, navbar, Wiki, Preview, and validation tab ADRs before changing
  layout constraints.
- Keep controls stable across desktop and mobile: no overlapping text, no
  layout shift from dynamic labels, and no oversized decorative cards around
  app surfaces.

## Validation

- After CSS changes, run `Rscript data-raw/build_css.R`.
- Run the relevant UI/CSS tests, especially `tests/testthat/test-css-guardrails.R`
  when changing CSS structure or generated bundles.
