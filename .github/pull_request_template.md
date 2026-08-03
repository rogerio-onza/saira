## Summary
<!-- One line. What this PR does, not how. -->

## Why
<!-- One or two sentences, or a link to the issue. -->

## How to test
<!-- Checklist of commands and manual steps a reviewer can run. -->
- [ ] `Rscript -e "pkgload::load_all('.', quiet = TRUE)"` — clean load
- [ ] `Rscript -e "devtools::test()"` — full suite passes
- [ ] (UI changes only) `Rscript -e "shiny::runApp(saira::run_app(), launch.browser = TRUE)"` — flow X works in both PT and EN
- [ ] (CSS source changes only) `Rscript data-raw/build_css.R` and verify the bundle changed as expected

## Checklist
- [ ] `CHANGELOG.md` entry under `[Unreleased]` describing user-visible change
- [ ] `DESCRIPTION` version bumped (if appropriate)
- [ ] `docs/DECISIONS.md` updated (if the change is architectural)
- [ ] `docs/LESSONS.md` updated (if the work exposed a recurring pitfall)
- [ ] Tests added or updated for changed pure functions, mapping contracts, export behavior, validation logic, or module server flows
- [ ] CSS rebuilt via `data-raw/build_css.R` when CSS source files changed
- [ ] Breaking changes flagged with `BREAKING:` prefix in the PR title
- [ ] Conventional Commit prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, `perf:`) in the PR title

## Notes
<!-- Only what the reviewer would not get from the diff: deferred follow-ups, screenshots, manual verification steps. Delete this section if there is none. -->

🤖 If this PR was authored with [Claude Code](https://claude.com/claude-code), keep the Co-Authored-By trailer on the squash-merge commit.
