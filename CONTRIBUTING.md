# Contributing to Saira

Thank you for considering a contribution. Saira is a public R/Shiny package
for standardizing biodiversity data to Darwin Core, used by researchers and
institutions integrating with SiBBr and GBIF. This document describes how to
propose changes safely.

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/rogerio-onza/saira.git
cd saira

# 2. Restore the pinned dependency set
R -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv"); renv::restore()'

# 3. Load the package and launch the app to confirm your setup
R -e 'pkgload::load_all(); run_app()'

# 4. Run the test suite
R -e 'devtools::test()'
```

If you are on Debian/Ubuntu, install the GDAL/GEOS/PROJ system libraries first
(see [README.md](README.md) for the full list).

## How to Propose a Change

Saira uses a pull-request workflow on GitHub. Direct commits to `main` are
not accepted — branch protection enforces this on the remote.

1. **Branch off the latest `main`.**

   ```bash
   git checkout main
   git pull
   git checkout -b feature/your-change-name
   ```

   Use one of these prefixes for the branch name:
   - `feature/` for new functionality
   - `fix/` for bug fixes
   - `chore/` for tooling, deps, CI maintenance
   - `docs/` for documentation-only changes
   - `refactor/` for behavior-preserving restructuring

2. **Make your change in small, focused commits.** Saira follows
   [Conventional Commits](https://www.conventionalcommits.org/) for both
   commit messages and PR titles. Allowed prefixes: `feat:`, `fix:`,
   `refactor:`, `docs:`, `test:`, `chore:`, `perf:`. Breaking changes get a
   `BREAKING:` prefix on the PR title.

3. **Validate locally before pushing.** Run the relevant tests and, for UI
   changes, smoke-test the app in both PT and EN.

   ```bash
   # Targeted test file
   R -e "testthat::test_file('tests/testthat/test-utils-export.R')"

   # Full suite
   R -e "devtools::test()"

   # If you edited CSS sources under inst/app/www/css/
   R -e "source('data-raw/build_css.R')"

   # Performance regression (gated by env var)
   RUN_PERF=true R -e "devtools::test(filter = 'performance')"

   # End-to-end tests (requires shinytest2 + browser)
   RUN_E2E=true R -e "devtools::test(filter = 'e2e')"

   # Full release gate (mirrors CI)
   Rscript scripts/release_gate.R
   ```

4. **Push and open a pull request.**

   ```bash
   git push -u origin feature/your-change-name
   gh pr create  # template populates automatically
   ```

   The PR template (in `.github/pull_request_template.md`) will populate the
   body. Fill in the Summary, Why, How-to-test, and Checklist sections.

5. **Wait for CI.** Every push to your PR branch triggers `R CMD check` plus
   the targeted gates from `scripts/release_gate.R`. Never merge a PR with
   failing CI — investigate first.

6. **Address review feedback** with follow-up commits on the same branch.
   Don't force-push during review.

7. **Squash and merge** when approved. This keeps `main` history scannable.

## What to Include

Most PRs should update at least one of:

- **`CHANGELOG.md`** — add an entry under `[Unreleased]` describing the
  user-visible change. We follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
- **`docs/DECISIONS.md`** — for durable architectural decisions (new
  contracts, tradeoffs future maintainers must know).
- **`docs/LESSONS.md`** — for recurring pitfalls discovered during the work.
- **Tests** in `tests/testthat/` — when changing pure functions, mapping
  contracts, export behavior, validation logic, or module server flows.

## What Not to Include

- `library()` calls inside `R/*.R` files — use `pkg::fun()` or roxygen
  imports.
- `setwd()` anywhere — paths must be package-safe via `system.file()`.
- Hardcoded PT/EN strings in UI — use `tr(key, lang)` with keys in
  `inst/extdata/i18n.json`.
- Business logic in `R/app_server.R` — that file is an orchestrator only.
  Put pure functions in `R/utils_*.R` and reactive bridges in `R/mod_*.R`.
- Generated bundle output edits — modify the modular source files under
  `inst/app/www/css/` and rebuild via `data-raw/build_css.R`.

## Reporting Bugs

Open an issue at https://github.com/rogerio-onza/saira/issues with:

- A short reproduction (input CSV snippet or steps to trigger).
- Expected vs actual behavior.
- Your R version (`R.version.string`) and OS.
- The relevant section of the Saira app (Upload, Mapping, Validation, Preview).

## License

By contributing, you agree your contributions are licensed under the MIT
License (see [LICENSE](LICENSE)).
