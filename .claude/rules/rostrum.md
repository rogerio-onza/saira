---
paths:
  - "R/utils_rostrum_*.R"
  - "R/mod_mapping*.R"
  - "R/utils_mapping.R"
  - "tests/testthat/test-utils-rostrum-*.R"
  - "tests/testthat/test-mod-mapping-server.R"
  - "tests/testthat/test-utils-mapping.R"
  - "docs/rostrum_engine.md"
---

# Rostrum And Mapping Rules

- Read `docs/rostrum_engine.md` before changing scoring, stage boundaries,
  aliases, templates, conflict resolution, or explainability.
- Search `docs/DECISIONS.md` for Rostrum, mapping, alias, template, extra term,
  dynamicProperties, and export ADRs before changing contracts.
- Keep stage behavior deterministic and conservative. Do not silently promote
  uncertain mappings to automatic decisions.
- Preserve the `mod_mapping_server()` named-list return contract. Add slots only
  with backwards-compatible defaults and tests.
- Keep heavy mapping logic in pure utilities. `mod_mapping*.R` should manage
  reactivity, UI state, and user feedback.
- When changing schemas or persistence, include migration/compatibility tests
  for `utils_rostrum_db.R` and template round-trips.
- Isolate local alias/template state in tests with environment variables or
  temporary paths so tests do not depend on a user's local SQLite database.

## Validation

- Run targeted Rostrum and mapping tests after behavior changes:
  `Rscript --vanilla -e "devtools::test(filter = 'utils-rostrum|mod-mapping|utils-mapping')"`
