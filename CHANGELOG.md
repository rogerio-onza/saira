# Changelog

All notable changes to Saira are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Changed
- **Help site (`website/`): landing page polish + full tutorial rewrite (PT-BR/EN).** The landing hero gets a denser floating-node animation and a single-line subtitle; the provisional blue-dot logo is removed (navbar brand mark and favicon, now an italic "S"); "Ver no GitHub" buttons become "Download". The "O que é" copy is tightened and the Features section is rebuilt from six generic steps into **three strong, concrete highlights** (import → validate → export) with before→after proof chips. The six tutorials (and their English mirrors) are expanded to cover the app's real features — encoding/separator detection, Wildlife Insights / Camtrap DP ingestion, mapping templates and the `basisOfRecord` assistant, the three name-validation providers (Flora do Brasil, Fauna do Brasil, GBIF), the transposed/swap/country-fill coordinate corrections, sensitive-species generalization and the DwC-A/EML export pipeline. The tutorial content column widens from 820px to 960px, and decorative em-dashes are removed from body copy across tutorials, FAQ and glossary.
- **README rewritten for non-R users, bilingual.** The README now leads with a plain-language Portuguese (PT-BR) section explaining what Saíra does, a 4-step "how it works" table, and a beginner-oriented "Primeiros passos" that walks a non-programmer through installing R + RStudio, pasting the install block, and launching the app — followed by a full English (EN-US) mirror of every section. Developer/clone/test instructions moved to a secondary "For developers" section. No visual assets added.
- **License changed from MIT to GPL-3.** `DESCRIPTION` now declares `License: GPL-3` (matching `bdc`); the MIT `LICENSE` stub is removed and `LICENSE.md` carries the full GNU GPL v3.0 text. `CONTRIBUTING.md`, `README.md`, and `docs/architecture.md` updated accordingly. The maintainer is the sole copyright holder, so the relicense is clean.
- **Help site: install/upload tutorials corrected to match the app, with real screenshots.** Tutorial 01 gains a step-by-step install walkthrough (R from CRAN, RStudio, and — made explicit — Rtools on Windows for the from-source GitHub install) using captured screenshots, plus direct CRAN/Posit links; the install snippet drops the `remotes` fallback in favour of `pak` alone and the section now follows the prerequisites narratively ("now that R is installed…"). Tutorial 02 is brought in line with what the upload module actually does: Excel/`.xlsx` (unsupported) removed from the formats table and intro; the steps no longer claim a row preview or encoding/separator/sheet controls (the app auto-detects and shows only a row/column/size summary); the sample-CSV download is promoted to a prominent callout; and the encoding tip shows real mojibake (`SÃ£o Paulo`) in inline code instead of an HTML entity that rendered as correct text. Tutorial figures now display at natural size (no upscaling blur).

### Fixed
- **Help site: callouts now show a distinct tinted background per type.** The per-type `--cc` colour was declared on `.callout-tip` / `.callout-warning` / … (specificity 0,1,0) but lost to the base `.callout.callout-style-default { --cc: … }` (0,2,0), so every callout fell back to the default teal and only the title/icon colour varied. Raising the per-type selectors to `.callout.callout-<type>` lets the semantic colour win, so tip/warning/important/note backgrounds read green/amber/red/teal as intended (and the temporary left-accent border is dropped).
- **Help site navbar no longer scatters its items, and the dark-mode theme toggle shows the moon.** Quarto's stock theme adds two auto-margins (`.ms-auto` on the nav list and `margin-left:auto` on `#quarto-search`) and a child-combinator rule that zeroes the brand's push-right margin, spreading the brand, links, search and toggles across the bar. Matching that `(0,3,0)` specificity and neutralising the stray auto-margins groups the nav links, search and theme/language toggles together on the right, with the brand on the left. Separately, `theme-dark.scss` imported `_saira-rules.scss` *after* its sun/moon override, so the shared default (sun visible) won — the `@import` now precedes the override so dark mode correctly shows the moon icon.

## [0.6.0] - 2026-06-04

### Added
- **Transposed-coordinate correction in the coordinate validation tab.** After validation, Saira flags records whose latitude/longitude are swapped or sign-flipped and, when a transformation makes the point fall inside the informed country, offers a one-click "Correct transposed coordinates" action (preview of verbatim → corrected). Corrections are applied at export and the originals are preserved in `verbatimLatitude`/`verbatimLongitude`. Reimplements the core of `bdc::bdc_coordinates_transposed()` on Saira's bundled Natural Earth country layer (no `bdc` dependency); engine in `coords_transposed_corrections()` / `apply_coords_correction_payload()`.
- **Country-from-coordinates fill in the coordinate validation tab.** After validation, Saira flags records with a blank `country` but valid coordinates and offers a one-click "Fill country from coordinates" action that derives the country from a point-in-polygon lookup (no value for points in the sea; existing country values are never overwritten). Applied at export. Reimplements the core of `bdc::bdc_country_from_coordinates()` on the bundled Natural Earth layer (no `bdc` dependency); engine in `coords_country_from_coordinates()` / `apply_country_fill_payload()`.
- **Combined "swap lat/lon + fill country" action** for the hard case where `country` is blank *and* the verbatim point falls in the sea (a strong lat/lon-swap signal that neither the transposed check — no country to aim at — nor the plain country fill — point at sea — can resolve alone). Only the lat/lon swap is tried (no sign flips), so the result is unambiguous: when the swapped point lands in exactly one country, the card fixes the coordinates and fills that country together. Engine in `coords_swap_and_fill()`.
- **Mapping guide v2 + faithful "Import template" restore.** The exported `mapping_guide_<date>.txt` is now `# saira:mapping:v2`: mappings grouped by DwC class, a dedicated **constants** section (`= value -> term`) capturing typed/selected values (`datasetName`, `license`, `language`), a separator legend, coverage stats, and a `saira_version` line. Importing the `.txt` via the Mapping sidebar's **Import template** button now rebuilds the exact mapping in the cards — multi-column concatenations and constants included — by matching the guide's source columns to the loaded dataset, and still seeds personal aliases for cross-dataset auto-mapping. The parser reads both v1 and v2.
- **Mapping: `taxonRank` and `specificEpithet` lock when `scientificName` is mapped.** These two terms are inferred from `scientificName` at export (`build_processed_mapping_df`), so once `scientificName` is mapped (manually or by auto-mapping) their cards now show a locked notice (`fa-dna` icon + "auto-inferred from scientificName") instead of a column selector, mirroring the `occurrenceID` UUID lock. New i18n key `taxon_auto_derived` (PT/EN). `genus` is also inferred but remains mappable.

### Changed
- **Default column-mapping term set is now the "Rede Felinos do Brasil" occurrence template.** `inst/extdata/dwc_terms.rds` is rebuilt from the template's 51 terms (xlsx order; typos `decimaLatitude` and trailing-space `family ` corrected) plus 13 curated extras kept in the default — `year`/`month`/`day`, `catalogNumber`, `collectionCode`, `taxonRank`, `kingdom`, `phylum`, `scientificNameAuthorship`, `rightsHolder`, `verbatimLatitude`/`verbatimLongitude`, `fieldNotes` — 64 terms total. Four niche terms (`disposition`, `preparations`, `infraspecificEpithet`, `verbatimIdentification`) drop from the default but remain available via "Add term". Term classes now follow TDWG so the by-class UI groups coherently (e.g. `eventDate`, `year`/`month`/`day` and sampling terms under Event); `dwc_full_catalog.rds` is re-ordered to keep base terms first. Reproducible via `data-raw/build_dwc_terms.R`.

### Fixed
- **Mapping guide: concatenated columns no longer collapse to the last one on re-import.** A composite (`year + month + day -> eventDate`) was previously split into competing 1:1 aliases, so auto-map kept only one column. The new faithful restore preserves the concatenation; `import_mapping_guide_to_aliases()` now skips constant rows and the guide parser is robust to column names containing `-`.
- **Mapping: free-text `datasetName` no longer re-renders while typing.** `is_field_mapped()` read `input$custom_datasetName` reactively inside the `mapping_ui` renderUI, so the debounced text value arriving mid-typing invalidated the whole UI and blurred the field. That single free-text read is now isolated; the checkbox/date custom inputs (`license`, `language`, `modified`) stay reactive so their "mapped" border still updates live on toggle.
- **Mapping: category headers no longer hide behind the sticky class pill bar.** Added `scroll-margin-top` to `.category-header` (the scroll-to-class anchors) so `scrollIntoView` (triggered by the "Todos"/category pills) lands the header below the sticky `.mapping-class-pillbar` instead of behind it.
- **Upload: a DwC-terms load failure now surfaces as a warning** instead of a silent `message()` in the `get_dwc_terms()` error handler (`mod_upload`), per the project's server-visible-problem convention.

## [0.5.0] - 2026-05-25

### Added
- **Offline-first UI**: Source Serif 4 and Space Mono web fonts are now vendored at `inst/app/www/vendor/fonts/` (latin + latin-ext subsets only — 8 woff2 files, ~440KB). FontAwesome 6.5.1 is vendored at `inst/app/www/vendor/fontawesome/` (CSS + 4 woff2 files; TTF fallbacks dropped since every modern browser supports woff2 — ~310KB). Saira now renders with full typography and icons without any internet connection. Combined vendor footprint: ~976KB.
- New test `test-app-ui-fonts.R` asserts the UI references local paths and contains zero CDN references (offline-first guardrail).

### Changed
- `R/app_ui.R`: removed all `<link>` references to `fonts.googleapis.com`, `cdnjs.cloudflare.com`, and the corresponding `<link rel="preconnect">` hints. Replaced with local stylesheet links to `www/vendor/fonts/source-fonts.css` and `www/vendor/fontawesome/css/all.min.css`.
- `DESCRIPTION` Imports: `shiny (>= 1.7.0)` bumped to `shiny (>= 1.8.1)` so the package can adopt `shiny::ExtendedTask` in a follow-up PR. renv-pinned environments are unaffected.
- Google Fonts CSS rewritten to use relative filenames (was `https://fonts.gstatic.com/...`); FontAwesome CSS stripped of `.ttf` fallback `url()` clauses to match the trimmed webfonts directory.

### Notes
- **ExtendedTask async migration deferred** to a follow-up PR. The offline-first asset bundling is the bigger user-facing benefit (the app works in air-gapped / low-bandwidth juror environments); wrapping the export and `validate_coords` handlers in `ExtendedTask` is a substantive module refactor that warrants its own focused PR. The Shiny version bump in this PR enables that work without forcing a dependency change later.
- Saira loads ~976KB of vendor assets on the first visit, then 0KB on subsequent visits (browser cache + the v0.5.0 cache-buster from PR-1). The previous CDN approach was ~0KB to ship but ~1MB+ per first visit from third-party origins.

## [0.4.1] - 2026-05-25

### Added
- **GitHub Actions CI workflow** at `.github/workflows/R-CMD-check.yml`. Runs on push and pull-request to `main`: sets up R release, installs Imports-only via pak (Suggests including `rnaturalearthhires` from rOpenSci R-universe are added explicitly through `extra-packages`), then runs `rcmdcheck::rcmdcheck(args = c("--no-manual"))`.
- **PR template** at `.github/pull_request_template.md` so `gh pr create` auto-populates the Summary / Why / How-to-test / Checklist sections (mirrors `CONTRIBUTING.md`).
- **`release_gate.R` exposed for CI** via `.gitignore` exception. The rest of `scripts/` remains private; only the public release-gate script ships.
- **Performance regression tests for DwC-A export bundle** in `tests/testthat/test-performance-regression.R`: 20k rows under 3s, 100k rows under 12s (both gated by `RUN_PERF=true`).
- `profvis (>= 0.3.0)` in `DESCRIPTION` Suggests for ad-hoc profiling.

### Notes
- After merging, enable branch protection on `main` in GitHub Settings → Branches: require pull request before merging + require the `R-CMD-check` workflow to pass before merging.
- Pre-existing perf budgets at lines 88 / 121 / 137 of `test-performance-regression.R` are over budget on the maintainer's WSL hardware; they remain gated by `RUN_PERF=true` and do not affect CI. Budget tuning is out of scope for this PR.

## [0.4.0] - 2026-05-25

### Added
- **Full Darwin Core Archive (DwC-A) export.** The ZIP bundle now lays out a GBIF/IPT-compatible archive with `occurrence.txt`, `meta.xml`, and `eml.xml` at the archive root. The hand-rolled EML 2.1.1 document includes title, creator/contact, pubDate, abstract, license-aware intellectualRights, methods step, and **auto-computed** geographic bounding box (from `decimalLatitude`/`decimalLongitude`) and temporal range (from `eventDate`). XML generation uses `xml2` directly to avoid the `EML` package's transitive `jqr` → system `jq` dependency. New pure helpers in `R/utils_export.R`: `build_meta_xml()`, `build_eml_xml()`, `compute_dataset_extents()`, `dwc_term_uri()`, `build_dwca_bundle()`.
- **Deterministic occurrenceID via UUID v5.** New `generate_occurrence_ids()` dispatches strategy based on anchor presence: when the data has `institutionCode` AND one of (`catalogNumber`, `eventID`, `recordNumber`), missing IDs are filled with deterministic UUID v5 via `uuid::UUIDfromName()` using the RFC 4122 URL namespace plus `saira-occurrence:<institutionCode>|<anchor>` as the name. Same combination always produces the same UUID across machines and re-exports — republishing to GBIF appears as updates instead of new records. When the anchor is absent, falls back to random UUID v4 (current behavior). User-supplied IDs are always preserved verbatim. Strategy is recorded in an `id_strategy` attribute on the data frame and surfaced in the mapping guide. `add_occurrence_ids()` kept as a backward-compatible alias.
- **New `Identifier Strategy` section in `mapping_guide.txt`** (PT/EN), explaining which strategy was used and the GBIF republication consequence of each.
- New dependencies in `DESCRIPTION` Imports: `uuid (>= 1.1.0)` and `xml2 (>= 1.3.0)`. Both are pure-R / no system C libraries — chosen over the heavier `EML` package which would have forced `jqr`/`jq` on all users.
- 16-test suite `tests/testthat/test-utils-export-dwca.R` (55 expect calls): deterministic-vs-random UUID dispatch, user-supplied preservation, partial-anchor mixing, eventID/recordNumber fallback, DwC/DC term URI mapping, meta.xml shape and id-index, bbox/date extent derivation, EML structure (defaults and overrides), DwC-A bundle layout including extras, strategy section emission, attribute preservation through the export pipeline.

### Changed
- **Export bundle layout changed.** The dated `dwc_export_<YYYY-MM-DD>.csv` is replaced by `occurrence.txt` at the archive root (DwC-A core file). The `.xlsx` mirror and `mapping_guide.txt` remain (dated). `sensitive_real_coords_*.csv` stays out of `meta.xml` so it is never advertised as part of the DwC-A core. **BREAKING** for scripts that grep for `dwc_export_<date>.csv` in the ZIP — they need to read `occurrence.txt` instead.
- `process_for_export()` now preserves the `id_strategy` attribute through canonical column ordering; `process_for_export_with_unmapped()` likewise preserves it across `cbind` with extra raw columns.
- README updated: the DwC-A capability is now real (no longer a roadmap item).

### Notes
- **UI metadata form deferred** to a follow-up PR. v0.4.0 ships with sensible defaults for the EML editable fields (title="Saira export YYYY-MM-DD", creator empty with "Unknown" surname placeholder, license="CC0-1.0", auto abstract). Users wanting to customize can either edit `eml.xml` post-download or wait for the form in a subsequent release.

## [0.3.2] - 2026-05-25

### Added
- **`apply_geodetic_datum()`** in `R/utils_export.R` populates `geodeticDatum = "EPSG:4326"` on export for rows with finite, in-range `decimalLatitude`/`decimalLongitude` and no pre-existing datum. Rows with invalid coordinates or a user-supplied datum are untouched.
- **`convert_country_code_to_alpha2()`** in `R/utils_export.R` performs the alpha-3 → alpha-2 conversion at the export boundary. Saira's internal pipeline keeps `countryCode` in ISO alpha-3 ("BRA") so `CoordinateCleaner::cc_coun()` continues to work; the DwC export now emits the alpha-2 form ("BR") that Darwin Core requires.
- **Vendored Lottie player JS** at `inst/app/www/vendor/lottie/lottie-player.js`. The Home-tab splash animation no longer depends on the `unpkg.com` CDN.
- **PR workflow documentation**: new `.claude/rules/pull-request-workflow.md` (standing rules for Claude) and `CONTRIBUTING.md` (public-facing PR guide). `.claude/CLAUDE.md` references the rule under "Always".

### Changed
- **CSS/JS cache-buster** in `R/app_ui.R` now uses `utils::packageVersion("saira")` instead of `as.integer(Sys.time())`. Cache invalidates on release rather than per-session — see ADR-027 for the historical rationale; the trade-off (no automatic bust on intra-version CSS rebuilds during dev) is acceptable since devs hard-refresh anyway and `data-raw/build_css.R` is an explicit step.
- `process_for_export()` now calls `apply_geodetic_datum()` and `convert_country_code_to_alpha2()` between license abbreviation and canonical column ordering.
- **README** wording: "Darwin Core Archive Export" softened to "Darwin Core export bundle" with a note that the formal DwC-A (meta.xml + eml.xml) packaging lands in v0.4.0. Camera-Trap line now marks `camtrapdp` as an explicit optional install.

### Fixed
- **Stale CI claim removed from CHANGELOG v0.2.0**: the entry `- **CI**: .github/workflows/test.yml with GitHub Actions.` (former line 350) was inaccurate — `.github/workflows/` was never delivered. Workflow lands in v0.4.1.

## [0.3.1] - 2026-05-21

### Fixed
- **Verbatim coordinate fields no longer carry prose on masked rows.** `mask_sensitive_coordinates()` was writing the `informationWithheld` sentence into `verbatimLatitude` / `verbatimLongitude` / `verbatimCoordinates` for sensitive species — invalid Darwin Core, since verbatim coordinate fields must hold coordinates or nothing. Those three fields are now blanked on masked rows; the locality/remarks leak fields (`footprintWKT`, `locality`, `verbatimLocality`, `georeferenceRemarks`, `locationRemarks`) still receive the replacement wording (Chapman sec. 3 anti-reversal). See ADR-098.
- **`informationWithheld` uses the pipe multi-value separator.** The PT/EN strings joined two clauses with `/` and `;`; they now join with ` | `, matching Saira's multi-value separator convention. Key `sensitive_information_withheld` in `i18n.json`.
- **Private real-coordinates CSV no longer mojibake.** The `sensitive_real_coords_*.csv` companion file had a corrupted comment header (`# Arquivo privado â€" ...`). `writeLines()` was wrapping the content in `enc2utf8()`, which double-encoded the `tr()` string; removed the wrapper so the UTF-8 bytes are written raw via `useBytes = TRUE`, matching the sibling mapping-guide file.
- **Infinite re-render loop when typing the `datasetName`.** The mapping `renderUI` (`output$mapping_ui`) depended reactively on `rv$map_meta`, which the custom-value observers rewrite on every keystroke — re-creating every input widget and feeding a loop that froze the app. The `rv$map_meta` read in the card builder is now isolated, so typing a custom value no longer re-renders the field grid.

### Changed
- **Coordinate masking is now a deliberate opt-in, not the default** (ADR-098, supersedes the "masking on by default" stance of ADR-092/094). The Preview-tab masking panel defaults to "Not sensitive — publish unmasked". The "Recommended" badge on the Extreme tier was removed — no masking level is recommended by default — along with the `sensitive_card_recommended` key. The "Not sensitive" card lost its warning styling (alert icon + `--warning` palette) and now reads as the calm default; the High and Extreme cards instead show a soft-carmim policy-impact alert when selected. New i18n keys `sensitive_panel_guidance` (standing callout) and `sensitive_policy_warning` (in-card alert); `sensitive_panel_lead` reworded. Rationale: generalized coordinates can mislead future analyses and public conservation policy, so masking must be a conscious decision for threatened species. CSS in `17-sensitive-panel.css`; bundle regenerated (zero new `!important`, count holds at 11).

## [0.3.0] - 2026-05-21

### Added
- **Camtrap DP ingestion** (ADR-095). New upload mode switch on the Data card that accepts a Frictionless Data Package ZIP (`datapackage.json` + `deployments.csv` + `media.csv` + `observations.csv`) and converts it internally to Darwin Core Occurrence Core via `camtrapdp::write_dwc()` before joining the existing mapping/validation/export pipeline. `convert_camtrap_to_dwc_occurrence()` captures the invisible list-of-dataframes return that `write_dwc()` provides (per the `camtrapdp` v0.5.0 manual, p.25) instead of reading the CSV back from disk — faster and independent of the upstream file naming. The success notification is explicit that `write_dwc()` keeps only `observationType = "animal"` rows (humans, vehicles, blanks and unclassified observations are dropped per the camtrapdp standard, manual p.25) so users can reconcile the count with the original package. The dropzone hint and the required-fields panel adapt to the active mode; the existing CSV and mapping-guide flows remain untouched when the switch is off. `R/utils_camtrap.R` (pure helpers: `is_camtrap_dp_zip()`, `read_camtrap_dp_zip()`, `convert_camtrap_to_dwc_occurrence()`) keeps Shiny out of the conversion path so it stays testable. `camtrapdp` is declared in **Suggests** (mirrors `rnaturalearthhires`) because it pulls heavy system dependencies (`libjq-dev` for `jqr` -> `EML`); a translatable error is shown if the user activates the mode without having it installed. New i18n keys: `upload_camtrap_toggle`, `upload_camtrap_dropzone_hint`, `upload_camtrap_expected_files_title`, `upload_camtrap_success`, `err_camtrap_invalid_zip`, `err_camtrap_pkg_missing`.
- **Camtrap mode — broadened input scope** (ADR-096, extends ADR-095). The mode now also accepts ZIPs that do NOT contain `datapackage.json`, since most real-world camera-trap projects (Wildlife Insights in particular) ship the data as loose CSVs without the Frictionless descriptor. Two new shapes are detected and normalized into the existing `camtrapdp::write_dwc()` pipeline: (a) **loose Camtrap DP CSVs** — ZIP with `deployments.csv` + `observations.csv` (+ optional `media.csv`) using the official Camtrap DP column names; Saira synthesizes a minimal Frictionless descriptor in tempdir so `camtrapdp::read_camtrapdp()` can still parse it; (b) **Wildlife Insights export** — ZIP with WI's proprietary CSVs (`deployments.csv` + `cameras.csv` + `projects.csv` + `images_*.csv`); `wi_to_camtrap_csv()` joins/renames WI columns into the full canonical Camtrap DP 1.0.2 column set (derives `observationType` from `is_blank` + `genus == "Homo"` + missing taxonomy + Vehicle mentions; cascades `scientificName` from `genus`/`species` → `family` → `order` → `class`; maps `identified_by == "Computer Vision"` to `classificationMethod = "machine"`; rescales `cv_confidence` from 0–100 to 0–1 when needed), then runs through the synthetic-descriptor path. Source detection (`detect_camtrap_source()`) returns `"datapackage_zip"` / `"camtrap_csv_zip"` / `"wildlife_insights_zip"` / `NA`; the success notification appends the detected source label. New helpers in `R/utils_camtrap.R`: `detect_camtrap_source()`, `synthesize_camtrap_descriptor()`, `wi_to_camtrap_csv()` plus internal `wi_parse_timestamp()`, `wi_derive_observation_type()`, `wi_build_scientific_name()`. `is_camtrap_dp_zip()` kept as a back-compat shim so the upload-module branch needed no callsite renames. New i18n keys: `upload_camtrap_source_camtrap`, `upload_camtrap_source_wi`, `err_camtrap_wi_columns_missing`. Reworded i18n: `upload_camtrap_dropzone_hint`, `upload_camtrap_expected_files_title`, `upload_camtrap_success`, `err_camtrap_invalid_zip` (dropped the "datapackage.json required" framing). The expected-files panel renders two grouped chip lists (Camtrap DP CSVs vs Wildlife Insights). Tests in `tests/testthat/test-utils-camtrap.R` rewritten (11 blocks): structural detection of all three sources, WI normalizer correctness (observationType / scientificName / classificationMethod / probability scaling / camera make+model join), synthesized descriptor profile + resources, and three end-to-end round-trips (descriptor / loose CSV / WI export) that skip cleanly when `camtrapdp` is not installed or the camtrap-dp profile URL is offline. Full suite: 3876 PASS, 0 FAIL.
- **Skip Saira masking when the publisher already generalized coordinates** (ADR-095). `mask_sensitive_coordinates()` now leaves a row fully untouched when either `coordinateUncertaintyInMeters >= 1000` **or** `dataGeneralizations` is non-empty — coordinates and any pre-existing metadata are preserved, and the row is not added to the researcher's private `_real_coordinates.csv` companion (we do not have the originals). The `dataGeneralizations` signal is guaranteed by `camtrapdp::write_dwc()` per its v0.5.0 manual (p.26: "dwc:dataGeneralizations: set if x$coordinatePrecision is defined"), which covers Chapman category 4 generalization (`round_coordinates(x, 3)` → ~150 m uncertainty, below the 1000 m numeric threshold). New return slot `n_skipped_already_masked` plus i18n key `sensitive_skipped_already_masked` for transparency in future report UIs. Threshold lives as `SENSITIVE_ALREADY_MASKED_THRESHOLD_M`.
- `R/utils_camtrap.R` listed in DESCRIPTION Collate. Bumped Saira version to **0.3.0** (feature + new optional dependency).
- CSS: minimal `.upload-mode-toggle` rule in `inst/app/www/css/13-upload.css` (zero `!important`); bundle regenerated.

### Fixed
- **Wildlife Insights ZIP produced empty Preview and disabled Validation tabs.** `camtrapdp::write_dwc()` filters by `observationLevel == gbifIngestion$observationLevel` (default `"event"`) intersected with `observationType == "animal"`. Our WI synthesizer wrote rows with `observationLevel = "media"` and never set `gbifIngestion$observationLevel`, so `write_dwc()` filtered everything out — the WI export silently returned an occurrence frame with 0 rows but 41 columns. The mapping tab still rendered column names (so it looked OK), but Preview, Validation and Export saw an empty data frame and went into "no data" states. `read_camtrap_dp_zip()` now sets `pkg$gbifIngestion$observationLevel <- "media"` on the WI branch so `write_dwc()` exports the media-level animal observations as occurrences. Two related spec violations were fixed at the same time: (a) `wi_to_camtrap_csv()` was emitting `observationID = image_id`, but WI permits multiple identifications per image (real datasets have ~0.3% duplicate `image_id`s — e.g., the same image classified as both `Mazama` and `Blank`); IDs are now suffixed `<image_id>-obs-<seq>` so `occurrenceID` is unique downstream; (b) `media.csv` is now deduplicated by `image_id` to satisfy the Camtrap DP requirement that `mediaID` be unique. `eventID` is set to `image_id` instead of `deployment_id` — each image is a discrete detection event; collapsing 24k observations into 33 deployment-level events would have erased per-image temporal granularity. Added fail-fast guardrail: `convert_camtrap_to_dwc_occurrence()` now raises a translatable error (`err_camtrap_empty_occurrence`) when the resulting occurrence frame is empty, so users see "no animal occurrences extracted" instead of a silently-broken downstream pipeline. Tests: 4 new regression tests (gbifIngestion observation level, unique IDs + deduplicated media, duplicate-image_id handling, empty-occurrence error path) and existing tests updated to assert the new ID shape. Verified on the real Wildlife Insights ZIP fixture (24,273 images → 8,550 unique animal occurrences, all `occurrenceID` unique, all key DwC columns 100% populated). Full suite: 3949 PASS, 0 FAIL.
- Restore the "Preview tab is fast" contract (ADR-020 / LESSONS:31). The masking overview card in `mod_preview.R` was forcing the heavy `processed_data_r` reactive to materialise just to count sensitive records, which blocked every tab switch (~1 min on large datasets). `mod_mapping_server()` now exposes a lightweight `sensitive_overview_input_r` projection (scientificName + coords from raw data + the user's mapping); `mod_preview_server()` consumes it instead of `download_data_r()`.
- Sensitive-species masking section in the Preview tab redesigned as a decision-first configuration panel: the four Chapman 2020 tiers render as selectable cards in a horizontal grid (Categoria / Name / grid in degrees / approximate km / geographic impact), with a `Recomendada` badge on **Category 1 (Extrema, 1°)** — the most conservative tier, which is the appropriate default for sensitive-species coordinates — and a strong selected state (accent border + cyan→accent gradient + inset accent shadow + lift, keyboard-focusable). The "Não sensível" opt-out is demoted to a dashed single-line card with muted (design-system harmonized) icon and text by default; the warning palette is reserved for its selected state to flag the gravity of the choice. The reference table moved into a native `<details>` disclosure (muted summary so it does not compete with the cards). Affected-record count is now an inline mono chip in the header. Layout-system fix: the panel overrides Shiny's default `.shiny-input-container { width: 300px }` cap so the radio group fills the panel; cards target the actual Bootstrap 3 markup that Shiny `radioButtons()` emits (`.radio > label > input + span`), use a `min-height: 168 px` (140 px on mobile) for consistent presence, and a 2 px border that never shifts the layout between states. The `Recomendada` badge is absolutely positioned so it never displaces sibling content. Grid responds to 4 → 2 → 1 columns at 992 px / 600 px. New i18n keys: `sensitive_panel_records_chip`, `sensitive_panel_lead`, `sensitive_card_num_{extreme,high,medium,low}`, `sensitive_card_name_{extreme,high,medium,low}`, `sensitive_card_impact_{extreme,high,medium,low}`, `sensitive_card_recommended`, `sensitive_card_optout`, `sensitive_disclosure_title`. `sensitive_gen_extreme` and `sensitive_gen_low` updated to reflect the new recommended tier.

### Changed
- Flatten the sensitive-species masking UI to Chapman 2020 Table 7 (5 global tiers: Extreme 1°, High 0.1°, Medium 0.01°, Low 0.001°, Not sensitive). The user picks one tier that applies uniformly to every sensitive record; the MMA threat category no longer governs the grid (it remains as a visual hint on the "Sensitive" pill in Validation > Names). The "Disable masking" checkbox is gone — the "Not sensitive" tier replaces it. Per-species `sensitive=TRUE/FALSE` override in Validation > Names is preserved; the modal no longer offers a per-species category picker.
- `mask_sensitive_coordinates()` signature: `scheme=` → `generalization=` (with values `extreme`/`high`/`medium`/`low`/`not_sensitive`). `sensitive_resolve()` no longer requires a `category` column in the payload (legacy payloads carrying one are still tolerated for display).
- i18n: replaced `sensitive_scheme_*` / `sensitive_disable_label` / `sensitive_category_label` / `sensitive_cat_full_*` / `sensitive_coords_withheld_short` / `sensitive_coords_withheld` keys with `sensitive_generalization_label` and `sensitive_gen_{extreme,high,medium,low,not_sensitive}` plus `sensitive_grid_unmasked`.

---

## [0.2.6] - 2026-05-19

### Added
- Graduated sensitive-species generalization following the Chapman 2020 (GBIF) *Current Best Practices for Generalizing Sensitive Species Occurrence Data* four-category method (ADR-092, supersedes the single-level / no-UI parts of ADR-090). `data-raw/generate_sensitive_species.R` now also parses the MMA threat category; `inst/extdata/sensitive_species.rds` gains a `category` column (VU/EN/CR/CR (PEX), deduped keeping the most restrictive).
- `R/utils_sensitive.R`: `sensitive_category_for()`, `sensitive_scheme_levels()`, `sensitive_grid_for_category()`, `sensitive_resolve()`. `mask_sensitive_coordinates()` now takes `decisions`, `scheme` and `enabled`: each record is generalized to the grid its category maps to under the chosen scheme (conservative: CR (PEX)→1°, CR→0.1°, EN→0.01°, VU→0.001°), `coordinatePrecision` is filled, and coordinate-leaking text (`verbatimLatitude`/`verbatimLongitude`/`verbatimCoordinates`/`footprintWKT`/`locality`/`verbatimLocality`/`georeferenceRemarks`/`locationRemarks`) is replaced with the withheld notice instead of being left able to reverse the masking (Chapman sec. 3).
- `R/mod_validate_names.R`: per-species sensitivity editor on the Validation > Names tab. The "Sensitive" pill shows the category and is clickable; non-listed species get a "+ mark" affordance. A modal lets the researcher mark/unmark any resolved name and set its category (unmarking an MMA species shows a custodian warning). Decisions ride a new `attr(result_r, "sensitivity_payload")`, mirroring the existing review payload.
- `R/mod_preview.R`: a masking panel (shown only when sensitive records are present) with the three named schemes (Conservative / Category 1 without coordinates / High caution), the live category→grid table, and a disable toggle. The export reads the per-species decisions and the chosen scheme.
- i18n keys: `sensitive_coords_withheld`, `validate_names_table_col_sensitive`, `sensitive_mark_label`, `sensitive_unmark_mma_warning`, `sensitive_panel_title`, `sensitive_panel_records`, `sensitive_scheme_label`, `sensitive_scheme_conservador`, `sensitive_scheme_cat1_omit`, `sensitive_scheme_cautela`, `sensitive_disable_label`, `sensitive_table_caption`, `sensitive_category_label`, `sensitive_saved_toast`, `btn_save`.

### Changed
- `sensitive_data_generalizations` i18n string now names the threat category and the per-record grid (3 format args).
- `inst/extdata/sensitive_species.rds` regenerated with the `category` column (4455 taxa, unchanged count). A pre-0.2.6 RDS without `category` still loads (every taxon treated as CR with a warning).

---

## [0.2.5] - 2026-05-18

### Added
- `R/utils_i18n.R`: `format_count(n, lang)` formats an integer with a locale-aware thousands separator without emitting an R warning (`PT: 1.234.567`, `EN: 1,234,567`). Exported and tested in `test-utils-i18n.R`.
- `R/utils_mapping.R`: pure `build_term_value()` function extracted from `build_processed_mapping_df` that encapsulates the per-term switch (basisOfRecord, occurrenceStatus, dynamicProperties, eventDate 4-col, 1-col, multi-col). Used by both the export pipeline and the mapping card preview helper.
- `R/mod_mapping.R`: `processed_preview_for_term()` helper that calls `build_term_value()` on a head-slice of the data frame to generate the card preview using the real processed value (matching the Preview tab), resolving the `eventDate` 4-col "September, September" bug.
- `R/mod_mapping.R` + `inst/extdata/i18n.json`: an "All" pill (`class_pill_all`) on the sticky class pill bar. The pill is pure navigation: clicking it scrolls to the first rendered class section by reusing the existing `saira-mapping-scroll-to-class` handler, via a dedicated `observeEvent(input$class_pill_all, ...)`. i18n key `mapping_pill_all` (Todos / All).
- `R/mod_mapping.R` + `inst/app/www/css/14-mapping.css`: sticky pill bar at the top of the mapping panel, with one pill per DwC class plus the "All" pill, reusing the `.stream-pill` primitive. Pills are pure navigation: clicking a pill scrolls `.mapping-scroll-container` to that class section (inline `saira-mapping-scroll-to-class` handler with a `requestAnimationFrame` retry to wait for re-render). Replaces the previous sidebar category checkboxes (ADR-089).
- `inst/app/www/css/14-mapping.css`: `.mapping-required-header` header plus `.mapping-required-count` badge on the required-fields card (shows `n/total`; the `.is-complete` modifier switches to `--success-bg` when all required terms are mapped).
- `inst/app/www/css/14-mapping.css`: `.mapping-required-sidebar` block, rendering required-field pills in a vertical column inside the sidebar (280px) with a discreet header and full-width chips.
- Sensitive/threatened species coordinate masking (ADR-090). `data-raw/redlist_brasil_mma.md` (Brazil National MMA list, Ordinance 443/2014, flora + fauna) plus `data-raw/generate_sensitive_species.R` generate `inst/extdata/sensitive_species.rds` (4455 taxa). New pure `R/utils_sensitive.R`: `load_sensitive_species()`, `flag_sensitive_species()`, `generalize_coord()`, `mask_sensitive_coordinates()`. A species whose resolved `scientificName` is on the list gets a "Sensitive" pill on the Validation > Names tab; on export its coordinates are snapped to a 0.1-degree grid (~11 km) with `dataGeneralizations`, `informationWithheld` and `coordinateUncertaintyInMeters` filled in, and the export ZIP bundle gains a `sensitive_real_coords_<date>.csv` holding the true coordinates (researcher's private control, kept out of the IPT).
- i18n keys `validate_names_status_badge_sensitive`, `sensitive_data_generalizations`, `sensitive_information_withheld`, `sensitive_real_coords_notice`.
- i18n key `mapping_card_sample_prefix` (ex.: / e.g.:).
- `tests/testthat/test-utils-mapping.R`: 5 tests for `build_term_value()` covering single-column, multi-column, eventDate 4-col, basisOfRecord, and the equivalence contract with `build_processed_mapping_df`.
- `tests/testthat/test-utils-sensitive.R` (46 tests) plus extensions in `test-mod-validate-names-server.R` and `test-utils-export.R`.

### Changed
- `R/mod_mapping.R`: category pills are now pure navigation. Clicking a pill scrolls to its section, with no visibility-filter toggle. All sections always render so the scroll anchor is always in the DOM. Removed `selected_classes_rv` and its initialization observer.
- `R/mod_mapping.R` + `inst/app/www/css/14-mapping.css`: required-field pills (`required_fields_strip`) migrated from the `card_header` to the sidebar, replacing the two statistics cards (Mapped Fields / Total DwC Fields). The new layout is vertical and organized to fit the 280px sidebar.
- `R/mod_mapping_cards.R` / `R/mod_mapping.R`: the card preview now calls `processed_preview_for_term()` instead of `preview_values_for_column(first_col)`, showing the processed value (matching the Preview tab) for every mapped standard term.
- `R/mod_validate_names.R`: the report table gains a hidden `.is_sensitive` column (derived from the resolved `scientificName` via `flag_sensitive_species`) and the `scientificName` renderer shows the "Sensitive" pill below the name. `R/mod_preview.R`: the download handler calls `mask_sensitive_coordinates()` on the assembled `full_data` before writing CSV/XLSX and attaches the real-coordinates file to the ZIP when masked rows exist (byte-identical no-op when there are none).
- `inst/app/www/css/14-mapping.css`: `.mapping-required-sidebar` aligned to the card system (`--radius-lg` + `--shadow-sm` + `--border-light`). `.mapping-required-chip` chips now use a tinted background (`--success-bg` / `--warning-bg`), `--text-primary` text and a colored icon, fixing a WCAG AA failure (green/amber as text color = 2.77:1; rule already canonical in `docs/design.md`).
- `inst/app/www/css/14-mapping.css`: `.mapping-class-pillbar` now has rounded corners (`--radius`), a full border and `--shadow-sm` (it was previously a square-cornered rectangle with only a `border-bottom`).
- `inst/extdata/i18n.json`: keys `mapping_class_filter_all`, `stats_mapped_fields`, `stats_total_dwc_fields` removed (no longer referenced in code).

### Removed
- `R/mod_mapping.R`: outputs `mapped_count`, `total_fields`, `label_mapped_fields`, `label_total_fields` and the two `div.stats-box` elements in the sidebar (replaced by the required-field pills).
- `inst/app/www/css/14-mapping.css`: rules `.stats-box`, `.stats-number`, `.stats-label` (no longer referenced in the HTML after the statistics cards were removed).
- The `readiness_checklist` panel removed from the Preview tab.

### Fixed
- `R/utils_mapping.R`: `rostrum_stage1_run_term_map()` ignored `stage1_parallel_strategy` and always used `future::multisession`. Fixed: `"multisession"` -> `future::multisession`, `"multicore"` -> `future::multicore` (fork, inherits the parent process namespace; falls back to multisession if the platform does not support it). The `rostrum_options()` contract was updated to accept `"multicore"` (ADR-091).
- `R/mod_upload.R`: `format(nrow(df), big.mark = ".")` emitted the warning `'big.mark' and 'decimal.mark' are both '.'`. Replaced with `format_count(nrow(df), lang_r())`, a new helper in `R/utils_i18n.R` with correct locale grouping (PT: `1.234.567`; EN: `1,234,567`).
- `R/mod_mapping.R` + `inst/app/www/css/14-mapping.css`: the mapping card preview overflowed the card horizontally with long text (e.g. a column mapped to `occurrenceRemarks`). Root cause: a min-content blowup of the `.two-column-layout` grid (item with `min-width: auto`) prevented the existing `text-overflow: ellipsis` on `.field-card-sample` from taking effect. Fix: `min-width: 0` on `.field-card` (structural, no `!important`) plus reducing the preview to a single processed example (`processed_preview_for_term(..., 1L)` instead of 3) shown on one line with an ellipsis, so the cards stay short and uncluttered.

### Tests
- `tests/testthat/test-utils-rostrum-stage1.R`: the parallel parity block was split in two: `multisession` (skips under `pkgload::load_all()`, runs under `devtools::check()`) and `multicore` (runs under `load_all()` on Linux via fork, skips on Windows). Resolves the 3 pre-existing failures definitively without requiring `devtools::install()`.
- `tests/testthat/test-utils-brproviders.R`: the failed-download call is wrapped in `expect_warning("corrupted zip")`, asserting the intentional warning contract instead of leaking it as noise.
- `tests/testthat/test-utils-io.R`: the mixed-encoding CSV call is wrapped in `expect_warning("retrying with alternative encoding")`, asserting the intentional encoding-recovery path.
- `tests/testthat/test-utils-dwc.R`: `vapply(...)` calls in `expect_setequal` wrapped in `unname()`, fixing the testthat 3.x `expect_setequal() ignores names` warning.
- `tests/testthat/test-mod-mapping-server.R`: the "class pills drive visibility filter..." test rewritten to verify pure-navigation behavior (anchor always present, no section removed after a click).
- `tests/testthat/test-utils-mapping.R`: 5 new `build_term_value` tests.

### Documentation
- `docs/DECISIONS.md`: ADR-089 (class pills, required-fields strip, card preview, stats-box context).
- `docs/LESSONS.md`: lesson on the card preview, which must show the *processed* value (`build_term_value`), not the raw column; use `processed_preview_for_term` to avoid a regression.
- Reorganization of the Claude context and `.claude/rules/karpathy-guidelines.md`.

---

## [0.2.3] - 2026-05-11

### Fixed
- `R/mod_mapping.R:625-639`: the `input[[map_<term>]]` -> `rv$map_values[[term]]` sync observer left the old value intact when the user cleared the field (the client returns `input = NULL`, not `""`). As a result, terms mapped via automap (especially via alias) persisted in the export even after the user cleared the selection on the card. Fix: distinguish `is.null(input)` at initial load (no-op; `rv$map_values` was already empty) from `is.null(input)` after a clear (treat as `""` and proceed down the `build_manual_meta(has_value = FALSE)` path).
- `R/utils_export.R:18-21 + 102-117`: `apply_name_review_payload()` injected `validacao_manual` and `motivo_revisao` into every export, even with no manual review performed. Policy reverted (ADR-088 reverts ADR-051): these two columns never appear in the `.csv`/`.xlsx` again. `scientificName` corrections (replacement when the user marks "Correct") still apply silently; traceability lives in the bundle's `mapping_guide.txt` (ADR-087).

### Tests
- `tests/testthat/test-mod-mapping-server.R`: new test pinning Bug A. `session$setInputs(map_type = NULL)` after a prior selection clears `rv$map_values$type` and marks `rv$map_meta$type$status = "MANUAL"`. Uses `withr::local_envvar(SAIRA_USER = ...)` to isolate from the local `rostrum.sqlite`.
- `tests/testthat/test-utils-export.R`: 5 `apply_name_review_payload()` tests rewritten to assert the absence of `validacao_manual` / `motivo_revisao` in the output (they previously asserted presence). The `scientificName` replacement invariants (correction across multiple occurrences, fallback to original_name when corrected is empty) are preserved.

### Documentation
- `docs/DECISIONS.md`: ADR-088 partially reverts ADR-051 by removing the audit columns from the export. The name replacement is kept; traceability moves to `mapping_guide.txt`.
- `docs/LESSONS.md:141`: the old bullet ("always emit audit cols") replaced by its opposite (never emit audit cols, traceability lives in mapping_guide.txt). New bullet documenting the `input[[id]] == NULL` after a `selectInput` clear gotcha (vs NULL at initial load).

---

## [0.2.2] - 2026-05-10

### Added
- `R/utils_export.R`: `process_for_export_with_unmapped(df_processed, raw_data, map_values)` wraps `process_for_export()` and `cbind`s the raw columns that were NOT the source of any mapping at the end of the data frame. Previously those columns disappeared from the exported CSV; they are now preserved at the end so the user can edit them manually after uploading to the IPT (ADR-087).
- `R/utils_export.R`: `write_xlsx_text_only(df, path)` writes `.xlsx` via `writexl::write_xlsx()` with ALL cells coerced to `character` before writing. It survives a double-click in Excel without corrupting ISO dates (`2024-01-15` instead of `15/01/2024`), leading zeros, or scientific notation on large numbers (ADR-087).
- `R/utils_export.R`: `build_mapping_guide_txt(map_values, raw_data, lang, ...)` produces dual-purpose plain text with the magic header `# saira:mapping:v1`, bilingual PT/EN instructions, a list of `Column -> Term` pairs, the list of missing required DwC terms, and the list of unused raw columns. No embedded data; mapping vocabulary only (PII-safe) (ADR-087).
- `R/utils_rostrum_templates.R`: `is_saira_mapping_guide(path)` (detects the magic header by reading only line 1, safe for large CSVs); `parse_mapping_guide_txt(path)` (extracts metadata from `#` lines and `source -> term` pairs from the body, silently ignores bare lines without `->`, warns only on malformed lines containing `->`); `import_mapping_guide_to_aliases(payload, conn = NULL, scope = "personal", user_id = NULL)` (calls `rostrum_upsert_alias()` per pair with `confidence = 1.0`, `reviewed = TRUE`; idempotent: re-importing does not duplicate; `colA + colB` compositions become independent aliases) (ADR-087).
- `R/mod_preview.R`: `downloadHandler` now emits `dwc_export_<date>.zip` with 3 files (IPT-ready CSV, Excel-safe XLSX, mapping_guide.txt) via `zip::zipr()`. The loading modal gains an explicit "Cancel" button in PT/EN that resets `is_exporting(FALSE)` to unblock the UI without violating `easyClose = FALSE` (ADR-009 preserved). The error fallback wraps the error CSV in a `.zip` so the file name matches the extension (ADR-087).
- `R/mod_mapping.R`: a 4th "Import template" button in the sidebar (`btn-outline-secondary`, grouped with "Add term" as an auxiliary action). It opens a modal with a `fileInput` for `.txt`; on confirm it validates the magic header, parses it and populates `rostrum_aliases` via `import_mapping_guide_to_aliases()`. A new `map_values_r = shiny::reactive(rv$map_values)` slot in the `mod_mapping_server` return list (ADR-054 extended), consumed by `mod_preview_server` to generate the `mapping_guide.txt` at export time (ADR-087).
- `R/mod_upload.R`: the `fileInput` now accepts `.txt` in addition to `.csv`; a new `file_kind()` reactive classifies the upload as `data`/`guide`/`invalid` via `is_saira_mapping_guide()`. When it is a guide, a confirmation modal opens with the pair count and an "Import" button; on confirm it calls `import_mapping_guide_to_aliases()` and keeps `raw_data()` as `NULL` so it is not confused with data (ADR-087).
- `R/utils_mapping.R`: `map_occurrence_status_values()` converts binary presence/absence representations (`0/1`, `sim/nao`, `yes/no`, `presente/ausente`, `present/absent`, `TRUE/FALSE`) to the DwC literals `present` / `absent` on export. Convention: `0 = absent`, `1 = present`. Unrecognized values pass through. A dedicated branch in `build_processed_mapping_df()` (alongside `basisOfRecord`) triggers the transformation when the user maps `occurrenceStatus`.
- `inst/extdata/dwc_terms.rds`: the `occurrenceStatus` term (class: Occurrence) added to the base set (50 -> 51 terms), so it now appears natively on the mapping card without needing to be added as an extra term. Reproducible patch in `data-raw/add_occurrence_status_to_base.R` (idempotent).
- `R/utils_export.R`: `dwc_canonical_class_order()`, `dwc_canonical_preferred_terms()` and `order_columns_dwc_canonical()` define a canonical order for exported/preview columns, reading each term's `class` via `get_dwc_full_catalog()` (217 terms) and ordering by (class priority, preferred term within the class, position in the catalog, original position). Result: `occurrenceID` leads the spreadsheet, the Taxon block starts with `scientificName` followed by the hierarchy (kingdom -> genus -> specificEpithet -> taxonRank), and `decimalLatitude/Longitude` lead Location. Extra terms added during the session fall into the correct semantic block automatically; non-DwC columns are preserved at the end.
- `R/utils_mapping.R`: a dedicated handler for `dynamicProperties` that composes two or more CSV columns into strict TDWG JSON per row (`{"key1":"value1","key2":"value2"}`, no spaces, with correct JSON escaping of `"`, `\\`, control characters and multi-byte UTF-8 preserved). Vectorized pure functions: `derive_dynprops_key()` (lowercase + `iconv ASCII//TRANSLIT` + `[^a-z0-9]+` -> `_`, fallback `field`), `json_escape_string()` with a fast path when there is no special character, and `build_dynamic_properties_json(df, cols, keys)` returning `character(nrow(df))`. Rows where all columns are empty produce `""` (not `"{}"`); keys that collide after normalization emit a single `warning()` and the first column wins (the rest are discarded).
- `R/mod_mapping_cards.R`: a dedicated branch for `dynamicProperties` in `build_field_card()`. In addition to the standard multi-column `selectInput`, it shows a `.dynprops-keys-block` block with one `textInput` per selected column, showing the auto-derived key as a placeholder and allowing a user override.
- `R/mod_mapping.R`: a new `rv$dyn_props_keys` slot (named list `column -> key override`), a reactive observer that syncs the `dynprops_key_*` inputs into `rv$dyn_props_keys`, propagation via `build_mapped_result -> build_processed_mapping_df(dyn_props_keys = ...)`, and a reset together with the rest of the mapping state when `raw_data_r()` changes.
- `R/mod_mapping.R`: the "Add term" modal now renders terms grouped by DwC class via Shiny's native `<optgroup>` (`choices = list(group = c(...))`), in canonical TDWG order (`Record-level, Occurrence, Organism, MaterialEntity, MaterialSample, Event, Location, GeologicalContext, Identification, Taxon, MeasurementOrFact, ResourceRelationship`), with terms alphabetical within each group. The modal uses `size = "l"` to accommodate the list. The `<optgroup>` labels reuse the existing `category_label()` for PT/EN translation.
- `inst/extdata/i18n.json`: 3 new keys for the `dynamicProperties` card (`dynprops_keys_header`, `dynprops_help`, `dynprops_key_placeholder` with `sprintf` format for the auto-key); the "Add term" modal placeholder (`modal_add_term_placeholder`) updated to reflect the new grouping.
- `inst/app/www/css/14-mapping.css`: a `.dynprops-keys-block` block with a left border in `var(--accent)`, mono font on the keys and column source, and typography consistent with the design system; bundle regenerated via `data-raw/build_css.R`. No new `!important` (count stays at 11/13).
- `inst/extdata/dwc_full_catalog.rds`: full catalog of the TDWG recommended terms (`dwc:` + `dcterms:`, ~217 terms) generated by `data-raw/build_dwc_full_catalog.R`. Schema identical to `dwc_terms.rds`; deduplication by namespace priority (`dwc:` > `dcterms:` > `dc:`); base terms appear first, extras sorted alphabetically (ADR-081).
- `R/utils_dwc.R`: `get_dwc_full_catalog()` (in-memory cache via `create_rds_cache`), `get_active_dwc_terms(extra)` and `get_active_dwc_terms_list(extra, lang)` to combine the base set with extras added on demand during the session, keeping the `get_dwc_terms()`/`get_dwc_terms_list()` schema for consumer backward compatibility (ADR-082).
- `R/mod_mapping.R`: the "Add term" button in the sidebar opens a modal with a `selectizeInput` populated by the full catalog (minus already-active terms); `confirm_add_term` inserts into `rv$extra_terms`; `confirm_reset` clears the state to return to the base set (ADR-082).
- `R/utils_rostrum_templates.R`: `rostrum_extra_terms_from_template()` identifies which terms in a template payload need to be pre-activated before application: a pure, testable function for future template-application flows via the UI (ADR-082).
- 6 new keys in `inst/extdata/i18n.json` for the Add term button (`btn_add_term`, `modal_add_term_title`, `modal_add_term_label`, `modal_add_term_placeholder`, `btn_confirm_add_term`, `notif_term_added`) and 6 keys for the additional DwC classes (`class_geologicalcontext`, `class_materialentity`, `class_materialsample`, `class_measurementorfact`, `class_organism`, `class_resourcerelationship`).
- `inst/extdata/i18n.json`: 15 new PT/EN keys for the ZIP bundle + alias round-trip (ADR-087): `preview_export_cancel`, `preview_export_cancelled`, `upload_guide_detected_title`, `upload_guide_detected_message`, `upload_guide_import_btn`, `upload_guide_cancel_btn`, `upload_guide_success`, `upload_guide_invalid`, `upload_guide_failed`, `btn_import_template`, `modal_import_template_title`, `modal_import_template_help`, `modal_import_template_label`, `modal_import_template_confirm`, `modal_import_template_no_file`, `modal_import_template_invalid_magic`, `modal_import_template_success`.
- `data-raw/generate_ne_land_10m_americas.R`: one-shot script to generate `inst/extdata/ne_land_10m_americas.rds` from the Natural Earth physical `land` `10m` layer. The generator accepts `NE_LAND_10M_ZIP` to reuse an already-downloaded zip, dissolves the landmass, builds a buffered coverage geometry, and saves `ref`, `coverage_ref`, `coverage_boxes` and `meta` into a compressed `.rds` (ADR-078).
- `inst/extdata/ne_land_10m_americas.rds`: an embedded `10m` reference of the Americas shipped with the package, allowing GitHub installations to run `cc_sea(scale = 10)` without a runtime download and without a hard dependency on `rnaturalearthhires` (ADR-078).
- `inst/extdata/ne_land_10m_americas_source.md`: a short provenance, generation and license record for the embedded spatial artifact.

### Changed
- `R/mod_preview.R`: the `mod_preview_server()` signature gains optional `raw_data_r` and `map_values_r` parameters (both `NULL` by default for backward compatibility). When passed, they are consumed ONLY inside the `downloadHandler` `content` callback (non-reactive), with no spurious reactive dependencies. `R/app_server.R`: wiring updated to pass `raw_data` and `mapping_result$map_values_r`.
- `R/mod_preview.R`: `shiny::outputOptions(output, "download_real", suspendWhenHidden = FALSE)` added after the `downloadHandler` to force the URL to be sent to the client even when the `downloadButton` is inside a `display:none;` wrapper. This pattern already existed in `mod_mapping.R:553` for `file_uploaded`. See the "Fixed" entry and LESSONS.md (ADR-087).
- `R/utils_rostrum_engine.R`: `rostrum_apply_alias_overrides()` now promotes `user_id = ""` -> `"anonymous"` before calling `rostrum_lookup_alias()`, mirroring the promotion `rostrum_upsert_alias()` already performs on insert (`R/utils_rostrum_db.R:470-472`). See the "Fixed" entry (ADR-087).
- `DESCRIPTION`: new dependencies `writexl (>= 1.4.0)` and `zip (>= 2.3.0)` in `Imports`. `renv.lock` synced.
- `docs/ENCODING_RULES.md`: rule 4 extended; the export bundle may include a companion `.xlsx` via `writexl::write_xlsx()` with all cells coerced to `character` before writing; the main CSV remains UTF-8 without BOM (ADR-087).
- `R/utils_export.R`: `process_for_export()` now calls `order_columns_dwc_canonical()` as the final step, ensuring the downloaded CSV follows the canonical DwC order. `R/utils_preview.R`: `prepare_preview_data()` applies the same reordering so the preview table mirrors what will be exported, avoiding a preview vs download mismatch.
- `R/utils_mapping.R`: `build_processed_mapping_df()` gains a `dyn_props_keys = list()` parameter and dispatches `dynamicProperties` to the dedicated JSON handler before the generic single-column branch. Consequence: a `dynamicProperties` mapped to a single column now produces `{"column":"value"}` instead of the raw value. Rationale: emitting a raw value in the dynamicProperties field was already invalid per TDWG, so this is a semantic correction, not a functional regression. Rostrum templates saved with a single-column dynamicProperties still load; after application the handler applies the JSON format automatically. Templates do not yet persist `dyn_props_keys` (out of scope for this delivery; auto-derivation remains in effect until manual application).
- `R/mod_wiki.R`: the Wiki tab now uses `get_dwc_full_catalog()` (217 terms / 12 classes) instead of the 50-term base set; the examples column is removed (ADR-083); `applyPageLength` fixed to `table.page.len(len).draw(false)` to recompute pagination correctly after a page-size change; `class_tr_keys` and `classSlugMap` (JS) extended to cover all 12 catalog classes, with `classSlugMap` now generated dynamically in R and injected via `jsonlite::toJSON` to avoid future drift (ADR-081/083).
- `R/mod_mapping.R`: the `dwc_all` reactive now calls `get_active_dwc_terms_list(extra = rv$extra_terms, lang = lang_r())`; `all_filter_categories` moved from a hardcoded variable to a reactive derived from `unique(dwc_all()$category)`; auto-map degrades `AUTO -> SUGERIDO` for extra terms (not calibrated by Rostrum); `class_tr_keys_map` extended to the 12 classes (ADR-082).
- `inst/app/www/css/02-navbar.css`: the rule `.nav-title-container:has(.nav-title-dynamic:not(:empty)) .nav-title-static { display: none; }` moved from the `custom.css` bundle (where it had been edited directly in a prior commit) to the source module, ensuring the rule survives bundle regenerations by `data-raw/build_css.R`. Without this rule the navigation titles appeared duplicated ("Mapeamento Mapeamento", "Coordenadas Coordenadas").
- `inst/app/www/css/08-wiki.css`: 6 `.wiki-filter-pill[data-filter="..."]` rules (dot + active) and 6 `.wiki-class-badge--{slug}` rules added for the full-catalog classes, keeping visual consistency with the base set (ADR-081/082).
- `R/utils_coords.R`: `coords_load_ne_land(scale = 10)` no longer depends on `rnaturalearth::ne_download()` on the main path and reads the embedded artifact via `system.file("extdata", "ne_land_10m_americas.rds", package = "saira")`. For `scale = 50/110`, local loading now uses `rnaturalearth::ne_countries(type = "map_units")`, eliminating the runtime download in the sea test (ADR-078).
- `R/utils_coords.R`: `coords_cc_sea_flagged()` was rewritten to partition the dataset into two execution lanes: points within the Americas coverage use the local `10m` reference with a geographic crop; points outside the coverage use the global `50m` fallback only for those indices. The pipeline preserves cardinality and no longer downgrades the whole run because of localized slowness (ADR-078).
- `R/utils_coords.R`: the implicit `120s` timeout was removed. `SAIRA_CC_SEA_TIMEOUT` is now opt-in; without the environment variable set, the flow does not install `setTimeLimit()` and does not treat normal execution duration as a functional error (ADR-078).
- `R/utils_coords.R`: `coords_crop_land_ref()` now crops the `10m` reference to the bbox of the points with a `2`-degree margin before `cc_sea()`, reducing the point-in-polygon cost on regional datasets without changing the final diagnostic result.
- `R/saira-package.R`: `.onLoad()` still pre-warms `coords_load_ne_land(10L)`, but now warming a local reference embedded in the package instead of a download-dependent path.

### Fixed
- **Critical export bug** (ADR-087): clicking Download produced the app's entire HTML saved as `dwc_export_<date>.csv`, with the progress modal stuck at 90% and the UI frozen. Root cause: the `downloadButton` in `mod_preview.R` is inside `<div style="display: none;">` and Shiny suspends hidden outputs by default (`suspendWhenHidden = TRUE`), so the `<a href>` was empty. Clicking an `<a href="" download="dwc_export_xxx.csv">` makes the browser download the current URL (the app page itself) with the `.csv` name. The endpoint was never called, so `download_finish_channel` never reached the client, the modal stuck at 90%, and `is_exporting(FALSE)` (which lives in the `finally` of the never-called callback) never fired. One-line fix: `shiny::outputOptions(output, "download_real", suspendWhenHidden = FALSE)` after the `downloadHandler`. The modal also gained a "Cancel" button as defense in depth.
- **Collateral bug in the alias system** (ADR-087): `rostrum_apply_alias_overrides()` looked up aliases with `user_id = ""` (empty `SAIRA_USER` env), but `rostrum_upsert_alias()` promotes `""` -> `"anonymous"` on save. The mismatch made the visibility filter in `rostrum_list_aliases_for_column:780` reject all personal aliases as `user_id_norm = NA`. Result: aliases saved via `rostrum_record_alias_override` (manual column selection) OR `import_mapping_guide_to_aliases` (the .txt round-trip) were invisible to the engine during automap in sessions without `SAIRA_USER` set. The personal alias system had been broken for months until the user tested the round-trip and noticed automap "ignored" the imported .txt. Fix: `rostrum_apply_alias_overrides()` also promotes `""` -> `"anonymous"` before the lookup.
- Wiki and Preview appeared frozen after `fac0f7b` expanded the DwC catalog (50 -> 217 terms / 6 -> 12 classes / a 12-pill toolbar). The two tabs' content overflowed the viewport (at high `pageLength` on Preview, or on the Wiki at pageLength=25/50/100), but `bslib::page_navbar(fillable = TRUE)` confines the body in `height: 100vh; overflow: hidden`, hiding the footer (info + pagination) below the fold with no scroll possible. Fixed with a single CSS rule in `inst/app/www/css/12-overrides.css` using `:has(.wiki-module)` and `:has(.preview-page)` to free `overflow-y: auto` only on these two tabs, preserving the viewport-bound contract of Validate Names/Coords (`calc(100vh - 166px)`). The marker class `preview-page` added to the `mod_preview_ui` container (`wiki-module` already existed). Tables return to the v0.2.0 behavior: they grow naturally with the selected `pageLength`, the DT internal horizontal scroll (`scrollX = TRUE`) is intact, and pagination and the DT header sit at the top of the visible records. Zero new `!important` (the bundle count returns to 11).
- Navigation titles appeared duplicated in the header and in the validation submenus ("Saira Saira", "Mapeamento Mapeamento", "Coordenadas Coordenadas"). The CSS rule that hid the static fallback lived only in `inst/app/www/custom.css` (commit `97b7cf7`) and was lost when the bundle was regenerated by `data-raw/build_css.R`. The rule now lives in `inst/app/www/css/02-navbar.css` and is protected by a guardrail in `tests/testthat/test-css-guardrails.R`.
- A WSL regression where `cc_sea(scale = 10)` hit the time limit (`Error: reached elapsed time limit`) and dropped the entire analysis to `scale = 50`. The real cause was the combination of a fixed `timeout` + a heavy `10m` reference + inadequate geometry loading; the new flow keeps `10m` local within the Americas and only uses `50m` outside the embedded coverage.
- Systematic false sea positive in French Guiana: the first generation of the embedded artifact cropped the physical layer with political coverage (`countries10` / `CONTINENT`), excluding an overseas territory tied to France. The generator was fixed to crop the physical `land 10m` directly by an Americas geographic mask, restoring correct land coverage in that region (ADR-078).

### Tests
- `tests/testthat/test-utils-mapping.R`: 8 new tests for `derive_dynprops_key`, `json_escape_string` (including the BEL control character and multi-byte UTF-8) and `build_dynamic_properties_json` (single col, multi col, NA per row, key override, fallback to auto when override invalid, escaping of `"` `\\` `\n`, key collision with warning, missing column, integration via `build_processed_mapping_df` confirming dispatch before the single-column branch).
- `tests/testthat/test-mod-mapping-server.R`: 2 new `testServer` tests covering (a) a user key override propagates to `processed_data_r()` in JSON format and blanking restores auto-derivation; (b) reset of `rv$dyn_props_keys` when `raw_data_r()` changes.
- `tests/testthat/test-performance-regression.R`: a new `RUN_PERF=true` benchmark requiring `< 0.5s` for `build_dynamic_properties_json` on 100k rows x 4 columns (real ~0.2s on the dev machine).
- `tests/testthat/test-i18n-a11y-keys.R`: 4 new keys for `dynamicProperties` (`dynprops_keys_header`, `dynprops_help`, `dynprops_key_placeholder`) and the updated `modal_add_term_placeholder` covered by the PT/EN presence test.
- `tests/testthat/test-utils-dwc.R`: 7 new tests covering `get_dwc_full_catalog()` (schema, superset of the base set, PT preservation) and `get_active_dwc_terms`/`get_active_dwc_terms_list` (no extras, with a valid extra, dedup with base, invalid extra outside the catalog).
- `tests/testthat/test-utils-rostrum-templates.R`: 4 tests for `rostrum_extra_terms_from_template()` covering the separation of terms to activate and unknown terms.
- `tests/testthat/test-css-guardrails.R`: a new assertion that fails if the rule `nav-title-container:has(.nav-title-dynamic:not(:empty)) .nav-title-static` disappears from the bundle, preventing the duplicate-titles regression in future CSS rebuilds.
- `tests/testthat/test-i18n-a11y-keys.R`: 12 new keys (6 from the Add term button and 6 from the on-demand DwC classes) covered by the PT/EN presence/resolution test.
- `tests/testthat/test-utils-coords.R`: a new regression battery covering loading of the embedded reference, the in-memory cache, `10m Americas` vs `50m global` routing, fallback when the artifact does not exist, crop invariance, opt-in timeout via `SAIRA_CC_SEA_TIMEOUT`, and French Guiana samples.
- `tests/testthat/test-mod-validate-coords-server.R`: the module flow kept green with `seas_scale = 10L`, confirming the change was confined to the coordinates engine and did not require any change to the current UI.
- `tests/testthat/test-utils-export.R`: 7 new tests for the ZIP bundle (ADR-087): `process_for_export_with_unmapped()` preserves unmapped columns at the end / no-op when there are no extras / tolerates `NULL`; `write_xlsx_text_only()` produces a round-trip-readable `.xlsx` with `character` types, ISO dates intact, leading zeros preserved, large numbers not turned into scientific notation; `build_mapping_guide_txt()` emits the magic header + pairs + NO embedded data (anti-PII-leak) + PT/EN switching + the missing-required flag.
- `tests/testthat/test-utils-rostrum-templates.R`: 8 new tests for the alias round-trip (ADR-087): magic detection, parse with metadata + pairs, rejection without magic, silent skip of bare lines (unmapped columns), warning only on lines with malformed `->`, idempotency of `import_mapping_guide_to_aliases` (re-importing does not duplicate), splitting of `colA + colB` compositions, `build -> writeLines -> parse` round-trip preserves pairs, end-to-end with `rostrum_lookup_alias`; a regression test for the SAIRA_USER collateral bug (imports with the default user and verifies `run_rostrum_engine` returns `status = "ALIAS"` with `context = list()`).
- `tests/testthat/test-mod-mapping-server.R`: isolation via `withr::local_envvar(c(SAIRA_USER = paste0("test_isolation_", as.integer(Sys.time()))))` in the test "v1 auto-map applies metadata and manual override becomes EDITADO", necessary because the alias collateral-bug fix made the test inherit state from the dev's real `~/.local/share/saira/rostrum.sqlite`. The smoke test's `expect_named` updated to include the `map_values_r` slot.

### Documentation
- `README.md`: coordinate-validation documentation updated to explain that `scale = 10` in the Americas is now embedded in the package and that points outside that coverage use an automatic fallback to `50m`, with no extra installation of `rnaturalearthhires`.
- `docs/DECISIONS.md`: ADR-086 (dynamicProperties as strict TDWG JSON composition, with an auto-derived key and a user override); ADR-078 (embedded `land 10m` mask); ADR-081 (full DwC catalog separated from the base set); ADR-082 (on-demand mapping via `rv$extra_terms`); ADR-083 (removal of the wiki examples column + the pageLength selector fix).
- `docs/LESSONS.md`: new lessons recorded on embedded spatial artifacts, the opt-in timeout, the error of cropping the physical `land` layer by a political boundary, and the "DwC / On-Demand Catalog (2026-05-06)" set covering pitfalls of `[[` on a named vector, deduplication by TDWG namespace, the separation of catalog and base set, the `AUTO -> SUGERIDO` downgrade for extras, literal-example truncation, and the `draw('page')` -> `draw(false)` fix.
- `docs/DECISIONS.md`: ADR-087, export as a ZIP bundle (IPT-ready CSV + Excel-safe XLSX + mapping_guide.txt) with a round-trip via aliases. Covers: (1) the critical export bug fix (suspendWhenHidden on a hidden downloadButton), (2) the 3-file ZIP bundle with unmapped columns preserved and a text-only XLSX to survive a double-click in Excel, (3) the alias round-trip via `mapping_guide.txt` with a magic header + parse + population of `rostrum_aliases`, (4) the collateral `SAIRA_USER` empty/anonymous mismatch between upsert and lookup.
- `docs/architecture.md`: a new section 3.2.1 "Export ZIP bundle" detailing the 3 bundle files, the generator-function table, and the critical warning about `outputOptions(suspendWhenHidden = FALSE)` for a hidden `downloadButton`.
- `docs/LESSONS.md`: 3 new bullets covering (a) `outputOptions(suspendWhenHidden = FALSE)` being mandatory for outputs hidden via `display:none;`, (b) the silent `""` -> `"anonymous"` promotion mismatch between `rostrum_upsert_alias` and `rostrum_apply_alias_overrides` that hid personal aliases for months, (c) module tests using the default `rostrum_connect()` inheriting state from the dev's real `~/.local/share/saira/rostrum.sqlite` and requiring isolation via `withr::local_envvar(c(SAIRA_USER = ...))`.

---

## [0.2.1] - 2026-03-06

### Added
- `tests/testthat/test-utils-rostrum-engine.R`: 10 integration tests for the `run_rostrum_engine()` orchestrator, covering the return contract, synonym mapping, graceful degradation with unrecognized columns, manual overrides, and error handling (BP-02).
- `tests/testthat/test-utils-common.R`: 38 new unit tests covering `create_rds_cache()`, `is_blank_value()`, `normalize_for_matching()` and `tokenize_for_matching()`, core functions used across the codebase that lacked test coverage (BP-01).
- `.onLoad()` in `R/saira-package.R`: pre-warming of `load_dwc_terms_rds()` and `coords_load_aliases()` at package startup, eliminating latency spikes on first use of the mapping engine and coordinate validation (P-05).
- A global `shiny.error` handler in `run_app.R` that raises unhandled errors as `warning()` to the server log system, making silent failures visible (B-03).

### Changed
- `R/app_server.R`: missing-slot diagnostics from `mod_mapping` converted from `message()` to `warning()` to respect `skill.md` ("strictly necessary" for console output) and to ensure visibility in production logs without polluting stdout (C-01).
- `R/utils_rostrum_db.R`, `R/utils_coords.R`, `R/mod_mapping.R`, `R/utils_brproviders.R`: 8 diagnostic error `message()` calls converted to `warning()` for the same reasons (C-03 through C-06).
- `R/utils_taxadb.R`: provider-failure accumulation in `run_taxadb_cascade()` refactored from `rbind()` in a loop to list accumulation + `do.call(rbind, ...)` at the end, eliminating unnecessary data.frame copies on each iteration (P-01).
- `DESCRIPTION`: `rnaturalearthhires` moved from `Imports` to `Suggests`, as it is an optional dependency with an explicit fallback in `utils_coords.R:453-454`; `sf`, `rnaturalearth` and `rnaturalearthdata` remain in `Imports` as they are validated as required at runtime (A-01).

### Changed (Priority C)
- `R/utils_taxadb.R`: the duplicated `query_name` resolution logic extracted from `fetch_taxadb_matches()` and `query_taxadb_batch()` into the private helper `resolve_query_name_col()`, eliminating ~25 copied lines and centralizing the maintenance point (4.4).
- `R/mod_validate_coords.R`: `filtered_result_r` received `|> shiny::bindCache(coord_validation_r(), active_filter())` to cache filtering results across reactive cycles, avoiding reprocessing the data.frame when the user toggles between already-visited filters (2.2).
- `R/mod_validate_names.R`: `effective_report` received `|> shiny::bindCache(validation_result(), rv$manual_reviews, input$remove_authors, input$ignore_qualifiers)` to cache the enriched report while none of the dependencies change (2.2).
- `R/utils_common.R`: `normalize_for_matching()` and `tokenize_for_matching()` received complete `@param`/`@return` roxygen2 blocks (4.5).
- `data-raw/build_css.R`: the header expanded with instructions on when to run the script and how to use it, preventing stale styles in the `custom.css` bundle (3.5).
- `inst/app/www/css/02-navbar.css`: all 5 navbar `!important` declarations received inline comments explaining which Bootstrap/bslib/Flatly rule they override (D-03).
- `inst/app/www/css/13-upload.css`: all 5 progress-bar `!important` declarations received inline comments explaining the Shiny behavior they force (D-03).
- `DESCRIPTION`: version bumped from `0.1.0` to `0.2.1`, syncing with the real CHANGELOG history (0.2.0 = Rostrum rework, 0.2.1 = quality audit).

### Not implemented (documented technical blocker)
- `2.3 DT proxy`: the `dataTableProxy + replaceData()` pattern is infeasible in `mod_validate_names` and `mod_validate_coords` because the cell HTML badges are generated inline via `tr(diag_label_key(x), lang_r())`; any language change invalidates the cell content, not just the headers. This would require a full re-render anyway, eliminating the proxy's benefit. Kept as a future architecture item if the translations migrate to CSS/JavaScript.

### Fixed
- `inst/app/www/css/03-buttons.css`: `.btn-success` changed from `color: var(--bg-card)` (white, contrast 3.08:1, fails WCAG AA) to `color: var(--text-primary)` (contrast 4.43:1, passes WCAG AA). `design.md` documented the value as 4.7:1, which was incorrect; the document will be updated (D-01).
- `inst/app/www/css/00-tokens.css`: `--coord-swapped` changed from `#8b5cf6` (contrast 3.81:1, fails WCAG AA) to `#6d28d9` (contrast 6.4:1, passes WCAG AA comfortably). The color is not part of the bird palette, so the adjustment has no impact on visual identity (D-02).
- `R/utils_export.R`: `apply_name_review_payload()` added a `warning()` to the silent return when `df` is not a data.frame, preventing caller bugs from going unnoticed (B-01).


- `data-raw/generate_rostrum_synonyms.R`: a reproducible generator for the DwC synonyms bundle with an inline curated PT+EN table. Covers 27 new uncovered terms (`type`, `disposition`, `preparations`, `occurrenceRemarks`, `kingdom`, `phylum`, `class`, `order`, `family`, `genus`, `specificEpithet`, `infraspecificEpithet`, `taxonRank`, `scientificNameAuthorship`, `verbatimIdentification`, `identificationQualifier`, `vernacularName`, `identifiedBy`, `country`, `stateProvince`, `county`, `locality`, `locationRemarks`, `verbatimLatitude`, `verbatimLongitude`, `fieldNotes`, `habitat`) and reinforces 6 thin terms (`eventDate`, `recordedBy`, `basisOfRecord`, `catalogNumber`, `collectionCode`, `institutionCode`). Bundle regenerated: 29 -> 147 entries, 19 -> 46 unique terms. Correction: `"species"` (en, 0.93) and `"especie"` (pt, 0.93) moved to `scientificName` (they were missing/wrong); `specificEpithet` loses the `"especie"` alias (semantically wrong for Brazilian data) (ADR-073).
- `rostrum_sync_synonyms()` (internal) in `utils_rostrum_db.R`: continuous synchronization of the `source = "v1_rds"` bundle into `rostrum_synonyms` with a per-process hash gate. INSERT new ones, UPDATE changed confidence, SET `active = 0` for removed ones. Never touches `rostrum_aliases` or other sources (ADR-073).
- 7 new test cases in `tests/testthat/test-utils-rostrum-db.R` covering all sync scenarios: empty database, idempotency via the hash gate, new synonyms, deactivation of removed ones, isolation of other sources, preservation of `rostrum_aliases`, and engine integration.
- Static fallback text for the 8 navigation tab titles (`nav_home`, `nav_mapping`, `nav_preview`, `nav_validate`, `nav_validate_names`, `nav_validate_coords`, `nav_wiki`, `nav_help`): the titles now appear immediately on initial load with no white flash, keeping the pt/en language switch via the CSS `:has(.nav-title-dynamic:not(:empty)) .nav-title-static { display: none }` (ADR-075).
- `<link rel="preconnect">` for `fonts.googleapis.com`, `fonts.gstatic.com` and `cdnjs.cloudflare.com` in the `<head>` of `app_ui()`, reducing DNS+TCP+TLS latency for CDN font resources (ADR-076).
- `.onLoad()` in `R/saira-package.R` that pre-warms the i18n dictionary cache when the package loads, eliminating the 74 KB disk read on the critical UI-build path (ADR-076).

### Changed
- `run_rostrum_engine()`: replaces the `rostrum_seed_synonyms_if_empty(conn)` call with `rostrum_sync_synonyms(conn)` in the synonym-loading flow. The database converges automatically with the current bundle on every new session; `rostrum_seed_synonyms_if_empty` remains available as a public API (ADR-073).

### Fixed
- `data-raw/generate_rostrum_synonyms.R` / `inst/extdata/dwc_synonyms_v1.rds`: two semantically wrong aliases in the synonyms bundle fixed (ADR-077):
  - `"especie"` (pt) was in `specificEpithet` (0.90); in Brazilian data, "especie" columns contain the full binomial, not just the epithet; moved to `scientificName` (0.93).
  - `"species"` (en) was missing from the bundle; with no synonym hit, the lookup fell into token overlap with a 0.55 score (zero tokens in common between `["species"]` and `["scientific", "name"]`); added to `scientificName` (0.93).
- Navigation tab titles were blank for ~200-500ms on first load because they depended exclusively on `uiOutput` + `renderUI` with no initial content.

- BR taxonomic validation with a confirmation fallback to `GBIF`:
  - `florabr`/`faunabr` now automatically finalize only `accepted` names;
  - BR results `synonym`, `ambiguous` and `not_found` proceed to a confirmation attempt at `GBIF`;
  - the final consolidation preserves the most informative result per `query_name`, avoiding a downgrade to `not_found` when BR already returned a better finding;
  - `utils_taxadb` tests extended to cover the new cascade and consolidation rule.
- Rostrum engine wave 3 (Stage 2 + Stage 3.5):
  - composition of `scientificName` from `genus + specificEpithet` (with optional support for `infraspecificEpithet` and `scientificNameAuthorship`);
  - a circularity guard by `composed_from` lineage to prevent feedback between rules;
  - composition of `eventDate` in strict ISO (`YYYY`, `YYYY-MM`, `YYYY-MM-DD`) with calendar/leap-year validation;
  - a post-conflict fallback to `verbatim*` (`decimalLatitude`, `decimalLongitude`, `eventDate`) without overwriting an already-mapped target.
- New `tests/testthat/test-utils-rostrum-stage2.R` suite covering:
  - composition/scientificName (presence, skip on existing mapping, skip on manual override, circularity guard);
  - composition/eventDate (complete, partial, invalid and leap year);
  - Stage 3.5 fallback to `verbatim*`.
- Rostrum engine wave 4 (full Stage 3):
  - a deterministic multi-criteria resolver per candidate (score, validation, type, completeness, specificity and tokenization), with an alphabetical final tie-break;
  - legitimate ambiguity with a float-safe comparison (`gap < ambiguity_gap - sqrt(eps)`);
  - mapping of the loser to a related `verbatim*` term with a minimum-score guard and a free target.
- New `tests/testthat/test-utils-rostrum-stage3.R` suite covering conflicts, ambiguity, determinism and loser fallback.
- Rostrum engine wave 5 (local learning in SQLite):
  - an alias API with transactional upsert (`BEGIN IMMEDIATE`), auditable events and precedence lookup (`personal > institution > public`);
  - learning-capture functions (`rostrum_record_alias_confirmation`, `rostrum_record_alias_override`);
  - batch rollback per session with `undo_session_aliases(conn, run_id)`.
- New `tests/testthat/test-utils-rostrum-aliases.R` suite covering persistence, deprecation, precedence and update without duplication.
- Rostrum engine wave 6 (Templates V3 - JSON + SQLite):
  - a JSON payload validator with checks for required fields, types, duplicate items and a version window (`utils::compareVersion()`);
  - a future `app_min_version` rejects the template; a past `app_max_version` emits a warning but loads;
  - export (`rostrum_export_template_json`) and import (`rostrum_import_template_json`) with transactional SQLite persistence;
  - template application with a score override to 1.0 and `TEMPLATE` status, inserted in the pipeline AFTER Stage 1 and BEFORE Stage 2;
  - detection and logging of conflicts between a template and a heuristic suggestion;
  - a local catalog with filters by `institution_id` and `use_case` (`rostrum_list_template_catalog`);
  - a `.badge-template` badge in purple `#8e44ad` in the CSS; i18n keys `rostrum_badge_template` and `rostrum_reason_template_override` (PT/EN);
  - schema migration v1 -> v2 adding the `use_case` column with backward compatibility.
- New `tests/testthat/test-utils-rostrum-templates.R` suite covering validation, version, export/import, priority and catalog.
- Rostrum engine wave 7 (V4+ hardening, performance and rollout):
  - a debug mode via `options(saira.rostrum.debug = TRUE)` with `message()` logging at critical pipeline points;
  - timing fields `stage1_ms`, `stage2_ms`, `stage3_ms` in the `run_rostrum_engine()` return and in the `rostrum_runs` table;
  - optional Stage 1 parallelization with `future`/`furrr` via the `stage1_parallel = FALSE` feature flag (off by default); determinism validated between `sequential` and `multisession` modes;
  - legacy removal: `run_automap_v1()` and the `enable_automap_v1` toggle removed; tests updated;
  - `adapt_synonyms_v1_to_v2()` kept for one more release as a safety net.
- New `tests/testthat/test-performance-regression.R` suite with thresholds: Stage 1 < 7.5s, Stage 2 < 2s, Stage 3 < 0.5s, full pipeline < 8s (gated by `RUN_PERF=true`).
- Completion of PR-1.2 (migration of synonyms to SQLite):
  - `rostrum_seed_synonyms_if_empty(conn, v1_path)`: populates `rostrum_synonyms` in SQLite from the legacy RDS on first run (idempotent, transactional);
  - `rostrum_load_synonyms_from_db(conn)`: reads active synonyms from SQLite, returning a V1-compatible format (`name_score`, `lang`) for direct use in `sanitize_synonyms_table()`;
  - `run_rostrum_engine()` now tries SQLite first when a `conn` is available, with a fallback to the V1 RDS if the table is empty;
  - 4 new tests in `test-utils-rostrum-db.R`: seed with 2 rows, idempotency, V1-compatible output format, NULL return on an empty table.
- Persistent caching of the BR providers with version governance:
  - `brprovider_ensure_data()` with a synchronous bootstrap on the first download and an asynchronous background update when a local cache already exists;
  - per-provider metadata in `<provider>.meta.json` with `local_version`, `remote_version_last_seen`, `last_checked_at`, `last_updated_at`, `status`, `last_error` and `retry_after_at`;
  - a per-provider lock (`<provider>.update.lock`) to avoid concurrency across multiple clicks/sessions;
  - atomic cache write with `<provider>.rds.tmp` + swap to `<provider>.rds` + a `<provider>.rds.bak` backup.
- Remote version discovery via the official IPT page (`ipt.jbrj.gov.br`) with segmented comparison of numeric versions.
- Status observability for the UI:
  - functions `brprovider_cache_status()`/`brprovider_cache_statuses()`;
  - per-provider badges (`up_to_date`, `update_in_progress`, `update_failed`, `never_downloaded`);
  - a notification when a background update completes.
- New test suites/cases:
  - `tests/testthat/test-utils-brproviders.R` (version, lock, bootstrap, fallback, rollback and update polling);
  - `tests/testthat/test-utils-taxadb.R` (integration of `brprovider_ensure_data()` into the state machine);
  - `tests/testthat/test-mod-validate-names-server.R` (status badges in the configuration panel).

### Fixed
- `R/utils_brproviders.R`: the "Update failed" badge persisted in the providers panel even after a successful validation with a local cache available. `brprovider_cache_status()` already reverted `never_downloaded -> up_to_date` when `has_data = TRUE`, but the equivalent block for `update_failed -> up_to_date` was missing; a symmetric block added after the existing rule.
- `R/mod_validate_names.R`: provider status badge text (`Up to date`, `Updating...`, `Update failed`, `Not downloaded`) and background-update completion notifications were hardcoded in English, ignoring the selected language; migrated to `tr()` with 6 new i18n keys (`validate_names_provider_status_*` and `validate_names_provider_notify_*`).
- `R/utils_brproviders.R`: the faunabr/florabr download did not occur when `verbose = FALSE`. `get_faunabr()` and `get_florabr()` internally condition the `httr::GET` block on `verbose = TRUE`; `brprovider_download_data()` now always passes `verbose = TRUE` to both packages, decoupling saira's verbosity from the provider's.
- `R/utils_brproviders.R`: the faunabr artifact check verified `taxon.txt` (an intermediate file extracted from the zip) instead of `CompleteBrazilianFauna.gz` (the final output of `get_faunabr()` read by `load_faunabr()`); fixed to reflect the real artifact.
- `R/utils_brproviders.R`: the call to `faunabr::get_faunabr()` wrapped in `withCallingHandlers()` that converts zip-extraction warnings (`error 1 in extracting from zip`, `cannot open`) into a `stop()` with a descriptive message and a network instruction.
- `R/utils_taxadb.R`: the dbplyr deprecation warning (`check_from argument of tbl_sql() is deprecated as of dbplyr 2.5.0`) suppressed with `withCallingHandlers()` on both `taxadb::filter_name()` calls; an upstream issue in taxadb/dbplyr, non-blocking but noisy in the console.
- `R/mod_mapping.R`: the SQLite connection (`rostrum_connect()`) was not created in the module, so database aliases and templates were never applied; `conn` is now initialized in `mod_mapping_server()` and passed to `run_rostrum_engine()`.
- `R/mod_mapping.R`: manual mapping overrides were not recorded as aliases; the manual-change observer now calls `rostrum_record_alias_override()`.
- `R/mod_mapping.R`: confirming an AMBIGUOUS choice did not save a learning alias; the `confirm_ambiguity_choice` observer now calls `rostrum_record_alias_confirmation()` or `rostrum_record_alias_override()` depending on the choice.
- `R/utils_taxadb.R`: the BR provider initialization gate was switched to `brprovider_ensure_data()`; when a remote update fails but a local cache exists, validation proceeds with the best available cache without interrupting the user.
- `R/utils_brproviders.R`: metadata status now preserves `update_failed` even without a local cache, allowing correct UI feedback after a bootstrap failure.

### Changed
- `R/utils_rostrum_engine.R`: Stage 2 stopped being a passthrough and now generates composed output with `explain_json`/`composed_from_json`.
- `R/utils_rostrum_engine.R`: orchestrator degradation adjusted to a correct fallback (`Stage 2` failure -> the final result preserves `Stage 1`).
- `R/utils_mapping.R`: `build_eventdate_interval()` vectorized (row-by-row loop removed), keeping the functional contract of the legacy interval parser.
- `R/utils_rostrum_engine.R`: `run_rostrum_engine(..., conn=...)` now applies alias overrides before stages 2/3, preserving legacy behavior without a SQLite connection.
- `R/mod_mapping.R`: `reason_code` mapping updated for the new `verbatim*` fallback codes in badges/tooltips.

### Fixed
- `app_ui()`: `tags$head(...)` moved out of `bslib::page_navbar()` via `tagList`, eliminating the invalid navigation-items warning in R CMD check.
- Non-ASCII in `R/app_ui.R`, `R/app_server.R`, `R/mod_upload.R` and `R/utils_export.R` replaced by `\uXXXX` escapes (portability).
- `man/mod_preview_server.Rd` and `man/validate_coords_cc_df.Rd` regenerated via `devtools::document()` to eliminate a codoc mismatch.
- E2E (`test-e2e-flows.R`): `app_dir` replaced by `shiny::shinyApp()`; the `RUN_E2E=true` gate added to isolate the suite in a dedicated step.
- `R/utils_rostrum_engine.R`: fixes in Stage 3 tie-break and fallback to avoid an ambiguity race and ensure deterministic behavior on repetitions.

---

## [0.2.0] - 2026-02-28

### Added
- **Modular CSS**: `custom.css` split into 17 domain modules (`inst/app/www/css/`), with a deterministic build script (`data-raw/build_css.R`) and header/completeness guardrails.
- **Externalized i18n**: dictionary migrated from an inline R list (1810 lines) to `inst/extdata/i18n.json` (601 keys), with a loader+cache in `data_dictionary.R` and inline BOM removal.
- **Coverage tests**: `test-mod-wiki-server.R` (5 tests), `test-mod-help-server.R` (8 tests), `test-mod-upload-server.R` expanded from 1 to 7 tests.
- **E2E with shinytest2**: the `test-e2e-flows.R` suite with 4 flows (upload+mapping, wiki, help+search, language switch).
- **Release gate**: `scripts/release_gate.R` with 5 steps (unit, CSS, i18n, E2E, R CMD check).
- `R/utils_common.R` with `is_blank_value()` extracted from `utils_mapping.R` (DRY).

### Changed
- **`mod_mapping_server` contract**: the return migrated from a `reactive` with `attr()` to an explicit `list()` with 4 slots (`processed_data_r`, `preview_data_r`, `validation_gate_r`, `validation_gate_coords_r`).
- `app_server.R` updated to consume the `list()` with a defensive fallback.
- `mod_mapping.R` refactored: the `basisOfRecord` assistant extracted to `mod_mapping_basis_assistant.R`, the UI/automap blocks to `mod_mapping_cards.R` and `mod_mapping_loading.R`. Line count from 1834 to ~1150.
- `data_dictionary.R` rewritten from 1810 to 61 lines (JSON loader).
- The `custom_language_choices` closure removed; logic inlined in `mod_mapping_cards.R`.

### Fixed
- `custom_language_choices` not found at runtime after extraction to `mod_mapping_cards.R`.
- `strip_bom()` unavailable at source time due to alphabetical loading order; BOM removal inlined in `data_dictionary.R`.

### Documentation
- `docs/DECISIONS.md`: ADR-054 (list contract), ADR-055 (modular CSS), ADR-056 (i18n JSON).
- `docs/LESSONS.md`: lessons on load order, CSS build, i18n cache.
- `docs/ENCODING_RULES.md`: rule 9 for `i18n.json`.

### Tests
- Total suite: **2659 PASS, 0 FAIL** (baseline was 2604, +55 new tests).

---

## [0.1.31] - 2026-02-28

### Changed
- `R/app_server.R`: language reactivity with a 150ms debounce and a startup bypass via a `reactiveVal` flag.
- `R/utils_coords.R`: vectorized country fuzzy matching (batch `adist`) with a resilient `tryCatch`. `normalize_country_token` with an explicit `iconv(from = "UTF-8")`.

### Tests
- `test-coords-country-to-iso3.R`: 5 new tests, a regression snapshot, adversarial, ambiguity, a 50+ heterogeneous batch, and a budget with diverse unrecognized tokens.

### Documentation
- `docs/DECISIONS.md`: new ADR-053 on the 150ms debounce and fuzzy batch.

---

## [0.1.30] - 2026-02-27

### Changed
- The sea test (`cc_sea`) resolution migrated from `scale = 110` (1:110M, ~10km) to `scale = 10` (1:10M, ~1km), using high-resolution data from the `rnaturalearthhires` package.
- Automatic fallback to `scale = 50` when `rnaturalearthhires` is not installed.
- Leaflet marker clustering (`markerClusterOptions`) removed in the `validate_coords` tab; points now render individually at their real positions.
- Marker radius adapted to dataset size: 6px (<=2000 points) or 4px (>2000 points) for performance.
- An alert chip (`alert-warning`) added to the map legend informing that coastal points may be incorrectly flagged by the sea test.
- The cluster note removed (clustering eliminated).

### Added
- `rnaturalearthhires` added to `Suggests` in `DESCRIPTION` with `Additional_repositories: https://ropensci.r-universe.dev`.
- A new i18n key `validate_coords_sea_precision_note` (PT/EN) for the sea precision alert chip.

### Documentation
- `docs/DECISIONS.md`: new ADR-052 formalizing the `seas_scale` migration and clustering removal.
- `docs/LESSONS.md`: new lessons on the Natural Earth convention, `rnaturalearthhires` and clustering vs individual points.

## [0.1.29] - 2026-02-27

### Fixed
- The manual review modal in the `validate_names` tab did not open and blocked the screen:
  - `hidden.bs.modal` in the `lifecycle_script` was registered on a child element (`div#review_modal_root`) instead of the `.modal` ancestor; DOM events bubble upward and never reached the listener, preventing the cleanup of `body.vn-review-open` and leaving the backdrop active permanently.
  - `resolve_review_target()` returned `NULL` silently when `rv$stream_df` became stale between render and click, with no user feedback.

### Changed
- `resolve_review_target()` now tries `rv$stream_df` first and falls back to `validation_result()` when the stream does not contain the clicked name.
- `observeEvent(input$open_review_target)` now shows a warning notification and runs a defensive backdrop cleanup (`vnCleanupBackdrop`) when the target cannot be resolved.
- The `vnCleanupBackdrop` JS handler registered in the module UI to remove residual `body.vn-review-open`, backdrops and `modal-open` state.
- A new i18n key `validate_names_review_target_not_found` added in `data_dictionary.R`.

## [0.1.28] - 2026-02-27

### Added
- Inline manual review flow in the `validate_names` tab for problematic names (`Not found`, `Ambiguous`, `Synonym`):
  - a `Review` button per problematic card;
  - a single reusable modal with two modes (`quick confirmation` and `editing`);
  - a celebratory empty state with an `Export` CTA (navigates to the Preview tab).
- A new reactive manual-review payload attached to the `mod_validate_names_server` return via a `review_export_payload` attribute.
- A new pure export layer in `R/utils_export.R`:
  - `apply_name_review_payload()` adds `validacao_manual` and `motivo_revisao` columns for all rows;
  - applies manual confirmations/corrections per normalized `query_name`, including replacing `scientificName` across all occurrences.

### Changed
- `mod_preview_server()` received an optional `name_review_payload_r = NULL` parameter and now applies manual reviews before `process_for_export()`.
- `app_server()` now wires `mod_validate_names_server()` to `mod_preview_server()` via the manual-review payload.
- `build_validation_report()` in `R/utils_taxadb.R` now keeps `query_name` and `input_name` in the final report to support traceability of reviews.
- The report table in `validate_names` now:
  - sorts reviews to the top by `reviewed_at` desc;
  - shows a `Manual Rev.` badge for corrections;
  - shows a secondary italic line with the replacement name.

### Fixed
- Problematic counters/filters in `validate_names` now consider only the canonical statuses (`not_found`, `ambiguous`, `synonym`) and discount already-reviewed names.
- The `Unresolved` state and count update reactively after each review decision.

### Tests
- `test-mod-validate-names-server.R` expanded to cover the manual review flow (confirm/correct), effective ordering and the final empty state.
- `test-utils-export.R` expanded to cover defaults, confirmation without editing, corrections with/fallback of the reason and propagation to repeated occurrences.
- `test-mod-preview-server.R` expanded to validate compatibility with the new optional payload parameter.
- `test-utils-i18n.R` updated with the new `validate_names_review_*` keys.
- `test-css-guardrails.R` updated with a `prefers-reduced-motion` guardrail and a selector/token for the `.vn-review-*` namespace.

## [0.1.27] - 2026-02-26

### Changed
- The `validate_names` tab adjusted to local full-width, matching the spatial pattern of the `validate_coords` tab, without changing the tri-column contract:
  - the hardcoded shell width limit removed from `mod_validate_names_ui()`;
  - local CSS contracts added for `.validate-names-page` (`width: 100%`, `max-width: none`) and for the contextual `tab-pane` (`padding-left/right: 0`).
- The tri-column layout preserved without a contract change:
  - the configuration panel stays fixed at `240px`;
  - the report panel stays fixed at `340px`;
  - the per-viewport height token (`--validate-names-header-offset`) kept.
- The name-validation report table refined to reduce the visual compression of the 3 columns:
  - explicit per-column distribution in the `DT::datatable` (`scientificName` prioritized, `status` compact, `taxonomicStatus` intermediate);
  - a new `taxonomicStatus` rendering with controlled wrapping;
  - cell and width adjustments to reduce aggressive truncation of `scientificName`.

### Tests
- `tests/testthat/test-css-guardrails.R` expanded to validate the new full-width contract of `validate_names`:
  - presence of `.validate-names-page` with `max-width: none`;
  - presence of `.tab-content > .tab-pane:has(.validate-names-page)` with `padding-left/right: 0`.
- Existing tri-column guardrails (`240px`/`340px` + per-viewport height) kept.

### Documentation
- `docs/DECISIONS.md`: new ADR-050 formalizing the safe width adjustment for `validate_names` with the tri-column layout preserved.
- `docs/LESSONS.md`: new lessons on the decompression strategy with a full-width shell and explicit column distribution in a fixed panel.

## [0.1.26] - 2026-02-24

### Changed
- Global rename of the project to `saira` in technical identifiers and branding:
  - `DESCRIPTION::Package` to `saira`
  - namespace references (`package =`, `asNamespace`, `getFromNamespace`, `library`, `test_check`) updated
  - UI/documentation/README text updated to `Saira`
  - the shared standardized table class set to `.saira-table-shell`
- Assets renamed to the new prefix:
  - `inst/app/www/images/saira.svg`
  - `inst/app/www/images/saira_alone.svg`
  - `inst/app/www/images/saira_alone.png`
  - `inst/app/www/lottie/lottieflow-loading-07-saira.json`
- Wave 1 implemented:
  - created `.editorconfig` and `.gitattributes` with a UTF-8/LF contract
  - `DESCRIPTION` with encoding fixes (`\\uXXXX`) and minimum versions for `sf`, `rnaturalearth`, `rnaturalearthdata`
  - `# Author:` headers standardized in ASCII to `Rogerio Nunes Oliveira`
  - new `docs/ENCODING_RULES.md`
  - `.Rbuildignore` updated to ignore infrastructure artifacts (`.editorconfig`, `.gitattributes`, `.Rprofile`, `renv`, `renv.lock`)
- Wave 2 implemented:
  - `R/utils_io.R` received `strip_bom()`
  - `detect_delimiter()` now reads in UTF-8, removes the BOM and handles an empty first line with a `,` fallback
  - removed `options(encoding = "UTF-8")` from `app.R` and `R/run_app.R`
- Wave 3 implemented:
  - `R/mod_upload.R` now protects `get_dwc_terms()` with `tryCatch` and a safe fallback on RDS failure
  - `R/app_server.R` now logs reactive fallbacks and ends the session with a cleanup log (`[Saira] ...`)
  - `force` validation consolidated into the canonical `validate_force_flag()` (`utils_coords` and `utils_mapping` delegate to it)
  - `renv` initialized with a versioned `renv.lock`

### Added
- A new test suite `tests/testthat/test-mod-upload-server.R` covering the resilient startup of `mod_upload_server()` when `get_dwc_terms()` fails.
- New I/O tests for BOM/delimiter:
  - `strip_bom()` removes the BOM correctly
  - `detect_delimiter()` with a BOM and an empty file
- New `force` validation tests:
  - `load_dwc_synonyms_v1(force = ...)`
  - `coords_load_aliases(force = ...)`

### Documentation
- `docs/DECISIONS.md`: new ADRs for the global `Saira` rename and the encoding/BOM/defense hardening.
- `docs/LESSONS.md`: new lessons on renaming a package with no legacy compatibility, BOM in the delimiter and a defensive startup fallback.

## [0.1.25] - 2026-02-24

### Changed
- The `validate_names` tab refactored to a tri-column shell:
  - a fixed left column (`240px`) for configuration (providers, toggles and the action);
  - a flexible center column for the stream of processed names;
  - a fixed right column (`340px`) for the tabular report.
- `R/mod_validate_names.R` reorganized for the new outputs:
  - `config_panel`
  - `stream_panel`
  - `report_panel`
  - `report_table`
- The provider selector migrated to stacked cards with an active state and priority-1 highlighting.
- The action panel consolidated with:
  - a primary `Validate Names` button,
  - mini-stats (providers/options),
  - a progress bar with phase/batch/provider metadata.
- The center stream got a dedicated layout with visible filter pills (`All`, `Problematic only`, `Not found`, `Ambiguous`, `Synonyms`) and items colored by status.
- The right report now uses an external toolbar (search + `Show N`) synced via a JS callback with `DT::datatable`.
- `inst/app/www/custom.css` expanded with a local `.vn-*` namespace to avoid cross-module side effects and with new badge utilities (`badge-success`, `badge-warning`, `badge-error`, `badge-info`, `badge-muted`).
- New i18n keys added for the v3 name-validation UI text (action, progress, stream and report).

### Fixed
- Semantic contrast of the report table by status aligned with `design.md`:
  - synonym (`info-bg`),
  - ambiguous (`warning-bg`),
  - not found (`error-bg`),
  - accepted/ignored (`#ffffff`).

### Tests
- `tests/testthat/test-mod-validate-names-server.R` expanded to cover classification of the report buckets (`valid`, `invalid`, `unresolved`, `total`).
- `tests/testthat/test-utils-i18n.R` updated to require and resolve the new `validate_names_*` keys of the v3 UI.
- `tests/testthat/test-css-guardrails.R` expanded with tri-column layout guardrails (`height token`, `fixed widths 240/340`).

### Documentation
- `docs/DECISIONS.md`: new ADR on the tri-column contract of the `validate_names` tab and syncing external controls with `DT`.
- `docs/LESSONS.md`: new lessons on a tri-column shell with viewport height and delegated binding to an external DataTable toolbar.

## [0.1.24] - 2026-02-24

### Changed
- Global typographic migration to `design-v5`: `Cormorant Garamond` (serif) + `Space Mono` (mono), preserving the v4 palette, layout and interactions.
- `R/app_ui.R` updated to:
  - use the v5 `font_collection` in `bs_theme` (`base_font`/`heading_font` serif and `code_font` mono);
  - explicitly load the official v5 Google Fonts URL in the `head`.
- `inst/app/www/custom.css` updated with the v5 typographic foundation:
  - removal of the old IBM Plex `@import`;
  - new tokens `--font-serif`, `--font-mono` and the alias `--font-sans -> --font-serif`;
  - body/headings/labels/code/buttons aligned to the new typographic contract.
- IBM typographic hardcodes removed from the local modules (`wiki`, `help`, `upload`, `mapping`, `preview`, `validate_names`, `validate_coords`) in favor of CSS tokens.
- A legibility guardrail for compact coordinate diagnostics added with a `letter-spacing` and `tabular nums` adjustment, without changing the components' geometry/layout.
- `docs/design.md` updated to the content of `design_v5.md` as the official design system reference.

### Tests
- `tests/testthat/test-css-guardrails.R` expanded to block a regression of hardcoded IBM `font-family` and to validate the v5 typographic tokens.
- A new suite `tests/testthat/test-app-ui-fonts.R` added to validate:
  - injection of the v5 Google Fonts in `app_ui`;
  - the absence of old IBM references in `bs_theme`;
  - retention of `custom.css` with cache-busting.

### Documentation
- `docs/DECISIONS.md`: new ADR on the v5 typographic migration strategy with compatibility aliases and anti-regression guardrails.
- `docs/LESSONS.md`: new lessons on avoiding hardcoded font families in CSS and validating mono legibility at small sizes.

---

## [0.1.23] - 2026-02-24

### Fixed
- `help` tab: definitive alignment of the magnifying glass in the search field anchored to the relative wrapper `.help-search-input-wrap`, keeping the icon inside the box at all breakpoints.
- The magnifying glass positioning stabilized with a fixed box (`14x14`), `left: 13px`, `top: 50%` and `transform: translateY(-50%)`, combined with `padding-left: 42px` on the input to avoid collision with the text.
- Shiny/Bootstrap spacing interference removed in the search card (`.shiny-input-container` and `.control-label` with `margin-bottom: 0`), ensuring a consistent baseline between the icon and the placeholder.

---

## [0.1.22] - 2026-02-23

### Changed
- Complete redesign of the `help` tab with a new two-column layout (`content + sticky sidebar`) and a wrapper expanded to `max-width: 1400px`.
- `R/mod_help.R` refactored to:
  - replace the `bslib::accordion` with a custom accordion with semantic toggles (`aria-expanded`) and a dedicated visual structure;
  - adopt 4 final help sections (`Darwin Core`, `FAQ`, `Accepted formats`, `Multiple-value separator`);
  - move the search to an isolated card and the header to an editorial card;
  - add a sidebar with `Author`, `Report a bug`, `Useful links` and `Built with` cards.
- A new client-side asset `inst/app/www/help-accordion.js` with event delegation to open/close accordion items while keeping compatibility with UI re-render.
- `R/app_ui.R` updated to load `www/help-accordion.js` with cache-busting in the same pattern as the other assets.
- `inst/app/www/custom.css` received a new Help-scoped block (`.help-module`) with full styles for the layout, accordion, FAQ grid, separator demo and sidebar cards.

### i18n
- `R/data_dictionary.R` expanded with new PT/EN Help keys:
  - header and search (`help_header_*`, `help_search_placeholder`, `help_empty_state`);
  - sections and content (`help_section_*`, `help_dwc_*`, `help_faq_*`, `help_formats_*`, `help_separator_*`);
  - sidebar (`help_author_*`, `help_bug_*`, `help_links_*`, `help_stack_*`);
  - accessibility (`a11y_help_bug_link`, `a11y_help_external_link`).

### Tests
- i18n suites updated to require and resolve the new Help keys:
  - `tests/testthat/test-utils-i18n.R`
  - `tests/testthat/test-i18n-a11y-keys.R`

### Documentation
- `docs/DECISIONS.md`: new ADR formalizing the Help redesign with a custom accordion and a sticky sidebar.
- `docs/LESSONS.md`: new lessons on the local CSS scope of Help and resilient accordion behavior with event delegation.

---

## [0.1.21] - 2026-02-23

### Fixed
- `wiki` tab: the DataTable external toolbar callback rebuilt with delegated events and a per-module namespace, restoring real-time search sync and the class chip filter.
- `wiki` tab: the `Show` selector fixed to apply `pageLength` correctly (including `15`) and to reposition to the first page when the count changes.
- `wiki` tab: the table shell adjusted for continuous rounding on the top and bottom corners.

---

## [0.1.20] - 2026-02-23

### Changed
- Complete redesign of the `wiki` tab with a new header card, a unified toolbar (search + count selector + class filters) and a table layout aligned to design system v4.
- `R/mod_wiki.R` restructured to:
  - replace the simple `title/subtitle` with a header card with dynamic metrics (`50 terms`, `12 required`, `6 classes`);
  - use external search/filter/page-length controls synced with the DataTables API;
  - render `Term`, `Class`, `Definition`, `Example` and `Required` via row/header callbacks to apply badges and styles without changing the module's public signature.
- `inst/app/www/custom.css` received a Wiki-scoped block (`.wiki-module`) covering:
  - the header card and stat pills;
  - the toolbar card and per-class pills with themed active states;
  - a custom thead with a sort icon, zebra/hover in `tbody`, class/required badges and a pagination footer wrapper.
- The Wiki link contract updated to the official generic cycle URL: `https://sibbr.gov.br` (subtitle and term links).

### i18n
- New keys added in `R/data_dictionary.R` for the new Wiki header/toolbar text:
  - `wiki_header_eyebrow`, `wiki_header_link_label`
  - `wiki_stats_terms_label`, `wiki_stats_required_label`, `wiki_stats_classes_label`
  - `wiki_show_label`, `wiki_records_label`
  - `a11y_wiki_page_length_label`
- Existing Wiki text refined:
  - `wiki_subtitle` updated to official-documentation copy;
  - `wiki_search_placeholder` expanded to search by term/definition/example;
  - `wiki_class_all` shortened to `Todas` / `All`.

### Tests
- i18n suites updated to cover the new Wiki keys:
  - `tests/testthat/test-utils-i18n.R`
  - `tests/testthat/test-i18n-a11y-keys.R`

### Documentation
- `docs/DECISIONS.md`: new ADR formalizing the visual/functional contract of the Wiki with external controls and a local CSS scope.
- `docs/LESSONS.md`: new lesson on using an external toolbar in DataTables with a footer wrapper without altering the internal pagination.

---

## [0.1.19] - 2026-02-23

### Fixed
- Visual regression of the header after the design-v4 rollout:
  - more spacing between navigation items;
  - adjusted link padding to avoid a "box glued" to the text;
  - vertical alignment of the language selector with the other navbar items.
- Fine-tuning of the language selector in the header (desktop/tablet):
  - the `selectInput` width widened to `150px`, aligned to the inner padding;
  - the select `padding-right` and `background-position` adjusted to avoid the arrow colliding with the text;
  - the mobile fallback kept compact via the `@media (max-width: 767.98px)` breakpoint.
- Fix for the application of header styles to the real `page_navbar` markup:
  - spacing/padding overrides updated for `ul.navbar-nav > li > a` (in addition to `.nav-link`);
  - the navbar language selector changed to `selectize = FALSE`, eliminating the arrow overlapping the text.
- `validate_coords` tab: the configuration card renders again before upload:
  - the lightweight validation gates (`validation_gate` and `validation_gate_coords`) now treat the `shiny.silent.error` from `req(input$file)` as a `no_data` state;
  - the validate button stays blocked until the existing readiness rules are met (`status == ok`).
- Regression of the dropdown indicator in the mapping tab:
  - the encoding-sensitive glyph replaced with a safe CSS escape (`content: '\25BE'`), eliminating the garbled (mojibake) caret rendering.
- Removed the last remaining case of a thick one-sided border on a styled box, reinforcing the thin full-border standard.

### Documentation
- `docs/architecture.md`: a section on mandatory visual guardrails for boxes, the navbar and dropdown indicators added.
- `docs/DECISIONS.md`: new `ADR-040` formalizing the anti-regression visual contract.
- `docs/LESSONS.md`: reinforced CSS lessons on one-sided borders, dropdown-arrow encoding and navbar alignment.

---

## [0.1.18] - 2026-02-22

### Changed
- Complete rework of the design system to `design-v4`, with migration of the app's main palette to the new identity (`primary/accent/success/warning/error/info`) and retention of the base background `#f4f3ee`.
- The `app_ui` `bs_theme` aligned to v4 keeping `bootswatch = "flatly"` to reduce the risk of a functional regression.
- `inst/app/www/custom.css` updated with v4 tokens, new semantic form/navbar tokens, shadows/focus rings and compatibility for the existing components (`buttons`, `alerts`, `badges`, `stream pills`, `status badges`, `coord badges`).
- Coordinate diagnostic colors aligned to v4 in `R/utils_coords.R` to keep consistency between the table, badges and map.
- The mapping tab empty state moved from hardcoded inline styles to CSS classes (`mapping-empty-state`, `mapping-empty-icon`).

### Fixed
- Pre-existing failures of the `test-css-guardrails` suite:
  - removed use of undefined CSS tokens;
  - removed excess `!important` (the hard guardrail limit);
  - removed `opacity: 0.45` from DataTables disabled pagination.
- Pre-existing failures of the `test-i18n-a11y-keys` suite with the addition of the 9 missing keys to the dictionary.

### Accessibility
- Inputs without a visible label received accessible labels:
  - the navbar language selector;
  - the file upload;
  - the help search;
  - the Wiki search and class filter;
  - the target selects in the `basisOfRecord` assistant.
- The mapping sidebar got semantic labels for the action and filter sections.

### Documentation
- `docs/design.md` overwritten by the content of `design-v4.md`, officially consolidating the new app design.

### Tests
- `devtools::test()` green (`PASS 1900`, `FAIL 0`).

---

## [0.1.17] - 2026-02-22

### Changed
- The `validate_coords` map repositioning now uses dynamic framing by the points shown in the active filter:
  - removed the fixed South America `fitBounds` on initialization;
  - default initialization with `setView(0, 0, zoom = 2)`;
  - after plotting markers, `leafletProxy` computes the real bounds (`min/max` of `lat_num/lon_num`) and applies `fitBounds`.
- Single-point handling added to the coordinates map:
  - when all visible points collapse to the same lat/lon pair, the app uses `setView(..., zoom = 8)` instead of a degenerate `fitBounds`.

### Fixed
- Avoided regional bias on the map after validation (previously the initial focus always returned to a fixed bounding box).
- Improved visual focus after a pill/filter change, keeping the map centered on the subset actually displayed.

---

## [0.1.16] - 2026-02-22

### Changed
- The `validate_coords` loading modal now renders the animation web component with explicit HTML (`<lottie-player ...>`) instead of `shiny::tags$` for a custom tag.
- The validation start flow in `observeEvent(rv$start_requested)` became resilient to modal visual failures:
  - `showModal()` protected by `tryCatch`;
  - `rv$run_requested <- TRUE` preserved even on a UI error;
  - a fallback warning added (`validate_coords_modal_fallback`).
- The loading icon/animation size halved in the coordinates modal (`.coords-loading-lottie`: `90x70`).
- The coordinates map basemap updated to offer a choice between:
  - `providers$OpenStreetMap` (default)
  - `providers$Esri.WorldImagery` (optional via the layer control)

### Fixed
- Fatal error on the coordinate validation click: `attempt to apply non-function` when opening the modal with `lottie-player`.
- A UX regression where validation appeared to "take long" because it aborted before the real processing when the modal failed.

### Tests
- `devtools::test(filter='mod-validate-coords-server')` green (`PASS 16`, `FAIL 0`), including a new regression test for a `showModal()` failure.

---

## [0.1.15] - 2026-02-22

### Changed
- Removed `cc_coun` (country mismatch) from the diagnostic pipeline of the `validate_coords` tab.

---

## [0.1.14] - 2026-02-22

### Added
- Country alias artifact externalized in `inst/extdata/country_aliases.rds` (initial seed with frequent aliases), replacing the dependency on a hard-coded dictionary in code
- A reproducible script `data-raw/generate_country_aliases.R` to generate and update `country_aliases.rds`
- New internal functions in `R/utils_coords.R` to support the new flow:
  - `resolve_country_aliases_path()` to resolve the `.rds` path in a development environment and an installed package
  - `coords_sanitize_aliases_table()` to validate/sanitize the `alias`/`iso3c` structure
  - `coords_load_aliases()` with a session cache for a single read of the `.rds`
  - `coords_build_fuzzy_reference()` with a cache of the multilingual reference used in the fuzzy fallback
- A new dedicated test suite `tests/testthat/test-coords-country-to-iso3.R` covering the resolution layers, negative cases and a performance budget

### Changed
- `coords_country_to_iso3()` rewritten as a 5-layer cascade:
  - strict `iso3c`
  - strict `iso2c`
  - multilingual CLDR via `countrycode::codelist` + `custom_dict`
  - custom aliases via the `.rds`
  - conservative fuzzy matching
- Country conversion now deduplicates unique values, resolves in batch and re-expands to the original vector, preserving cardinality and order
- `coords_alias_map()` kept for backward compatibility, but it became a wrapper around the `.rds` (no internal hard-code)
- `validate_coords_cc_df()` now automatically inherits the new country resolution behavior via `coords_country_to_iso3()`
- `.Rbuildignore` updated to ignore `data-raw/` in the package build

### Fixed
- Relevant reduction of `country_unresolved` for heterogeneous entries (PT/EN/ES, acronyms, abbreviations and minor typos)
- Hardened fuzzy matching to reduce false positives: a minimum length, a maximum relative distance, a requirement for a single best match and a margin to the second-best candidate

### Tests
- `devtools::test(filter = "coords-country-to-iso3|utils-coords")` green
- `devtools::test(filter = "mod-validate-coords-server|mod-mapping-server")` green

---

## [0.1.13] - 2026-02-21

### Added
- New canonical coordinates engine in `R/utils_coords.R` with `validate_coords_cc_df(df, lat_col, lon_col, country_col, profile, seas_scale)` using `CoordinateCleaner` as the main engine
- `country -> ISO3` conversion with a resolution chain (`iso3c -> iso2c -> country.name`) and a minimal alias map to reduce mapping failures
- A deterministic final per-row diagnostic (`diagnostic` + `diagnostic_family`) with no record exclusion, preserving cardinality (`nrow(out) == nrow(in)`)
- Execution profiles in the coordinates engine:
  - `complete`: `capitals`, `centroids`, `countries`, `equal`, `gbif`, `institutions`, `seas`, `zeros`
  - `fast`: `countries`, `equal`, `seas`, `zeros`
- Legacy post-processing after `CoordinateCleaner` preserved for:
  - `swapped` (possible lat/lon inversion)
  - `identical_all` (all complete coordinates identical)
- A new lightweight coordinates gate contract in `mod_mapping` with `country` support:
  - `coords_status`, `has_data`, `lat_col`, `lon_col`, `country_col`, `has_lat`, `has_lon`, `has_country`
  - granular states: `no_data`, `ok`, `missing_lat`, `missing_lon`, `missing_country`, `missing_multiple`
- A new coordinates module test suite: `tests/testthat/test-mod-validate-coords-server.R`

### Changed
- The `validate_coords` tab migrated to a real full-width layout:
  - removal of the fixed `max-width` on the container
  - main grid `col-lg-2` (left) + `col-lg-10` (right)
  - results area in `50/50` (`col-lg-6` map + `col-lg-6` table)
- The validation execution flow reworked to use `validate_coords_cc_df(...)` exclusively on the validate click
- The coordinates UI gate now blocks execution until `lat/lon/country` is mapped
- The validation action card got a profile selector (`Complete`/`Fast`)
- The coordinates tab pills migrated to diagnostic families:
  - `all`, `problems`, `validity`, `country`, `sea`, `zero_equal`, `reference`
- The diagnostic table expanded to 6 columns:
  - `Row`, `Diagnostic`, `Latitude`, `Longitude`, `Country`, `ISO3`
- The map legend aligned to the new per-family diagnostic contract, keeping the cluster note to avoid a wrong color interpretation
- `DESCRIPTION` updated to include spatial dependencies in `Imports`:
  - `CoordinateCleaner`, `countrycode`, `sf`, `rnaturalearth`, `rnaturalearthdata`
- `NAMESPACE` updated to export `validate_coords_cc_df`

### Fixed
- The internal reactive flow of coordinate validation adjusted to run correctly on the first trigger and in a test environment (`testServer`)
- The coordinate conversion warning observer hardened to handle missing attributes in mocked scenarios
- The coordinates tab filter tests adjusted to the official UI behavior (default post-validation filter at `problems`)

### Tests
- Updated coverage of `tests/testthat/test-utils-coords.R` for the full CC pipeline:
  - decimal parsing with a comma
  - resolved and unresolved `country`
  - `validity_missing` and `validity_bounds`
  - mapping of CC flags to families/diagnostic
  - diagnostic priority
  - `swapped` and `identical_all`
  - cardinality guarantee
- Updated gate coverage in `tests/testthat/test-mod-mapping-server.R` with `country_col` and granular states
- New tab integration coverage in `tests/testthat/test-mod-validate-coords-server.R`:
  - block without `country`
  - execution with `lat/lon/country`
  - profile switch
  - per-family filters affecting the data stream

---

## [0.1.12] - 2026-02-21

### Added
- A dedicated lightweight coordinates gate in `mod_mapping` (`validation_gate_coords`) with a `coords_status/lat_col/lon_col` contract
- Wiring in `app_server` to pass the coordinates gate to `mod_validate_coords`
- The `validate_coords` tab layout reorganized into separate panels (`stats_panel`, `filter_pills`, `map_panel`, `table_panel`) with a `col-lg-3/9` grid
- Sticky sidebar styles and semantic classes for coordinate statistics (`stat-box-ok/error/warn/muted`)

### Changed
- `validate_coords` (legacy wrapper) now delegates to `validate_coords_df`, keeping the signature and adding `issue_type/error_key` to the return
- The coordinates tab now uses an explicit gate via the optional parameter in `mod_validate_coords_server(..., validation_gate_r = NULL)`
- `DESCRIPTION` updated with `leaflet (>= 2.1.0)` in `Imports`

### Fixed
- A missing `leaflet` dependency that could break `R CMD check`
- Decoupled enabling of coordinate validation from the heavy `mapped_data` path when the lightweight gate is available
- The "Valid" visual signal in the coordinates tab aligned to a semantic class (`stat-box-ok`) instead of an inconsistent inline color

---

## [0.1.11] - 2026-02-21

### Added
- Robust drag-and-drop upload on the homepage with `upload-dropzone.js` loaded in `app_ui` with cache-busting
- Central copy inside the dropzone with two i18n lines (`upload_dropzone_hint` and `upload_max_size`)
- CSS classes dedicated to the full-surface dropzone (`upload-dropzone-copy`, `upload-dropzone-max-size`) and states (`is-dragover`, `has-file`)
- Missing CSS classes for the `validate_coords` tab to support cards, pills, issue badges and the map legend (`validate-coords-card`, `coords-gate-*`, `coords-filter-pills`, `coord-issue-badge-*`, `coords-map-legend-*`)

### Changed
- The Upload homepage restored to the large-dropzone pattern with a fully clickable area, a centered hint and an opaque CSV watermark in the background
- The "Maximum file size" block moved from the hints list into the dropzone, alongside the drag/drop instruction
- The upload hint text updated to a single action instruction ("drag/drop or click")
- `mod_validate_coords` now validates the gate contract received by attribute before using it (`coords_status/lat_col/lon_col`); when the contract does not exist, it applies a safe fallback on `mapped_data_r()`

### Fixed
- A drag-and-drop regression in browsers with `dataTransfer.types` lacking uniform `includes` support; file detection now covers `contains/indexOf/item`
- A homepage visual regression where the native `fileInput` box reappeared next to the custom dropzone; the native visual wrapper is now removed on bind and the real input is reattached to the container
- A functional regression in the `validate_coords` tab in scenarios where the names `validation_gate` was improperly reused and blocked the validate button
- A visual regression in the `validate_coords` tab due to classes referenced in the module without a definition in the stylesheet

---

## [0.1.10] - 2026-02-19

### Added
- A shared CSS class `.saira-table-shell` for a consistent DataTables visual pattern across the whole app
- New DataTable i18n keys in coordinate validation (search/length/info/empty/zero/pagination)
- A documented technical guideline for using `.saira-table-shell` in new tables (`docs/LESSONS.md`) and a formal architecture decision (`ADR-030`)

### Changed
- The preview table style applied consistently to the `validate_names`, `validate_coords` and `wiki` tables (header, search, length menu and pagination)
- Table wrappers unified to use `.saira-table-shell` in all modules with `DT::datatable`
- `lengthMenu` standardized to `10/25/50/100` in the name-validation, coordinate-validation and wiki tables
- The Wiki table now opens with 10 rows per page to align with the app's visual and navigation pattern

### Fixed
- Dimension/style inconsistency in the "Show _MENU_ records" dropdown outside the Preview tab
- Visual divergence of the pagination buttons (Previous/Next) between the app's tables

---

## [0.1.9] - 2026-02-19

### Added
- Horizontal filter pills in the DwC Wiki with translated classes and a visual active state, including `Identification` to keep full class coverage
- Visual rendering of the `Required` column in the Wiki with badges (`required`/`optional`)
- New Wiki i18n keys for badges and complete DataTable language (length/info/empty/zero/pagination)

### Changed
- Wiki search unified into the custom top field, with integration via the DataTables API (`table.search(...).draw()`)
- The Wiki class filter migrated to the DataTables column API (`table.column(1).search(...).draw()`), synced with the hidden compatibility dropdown
- The Wiki `DT::datatable` updated to a complete PT/EN `language`

### Fixed
- Redundant search filters in the Wiki (the default DataTables filter hidden within the Wiki table scope)
- Improved Wiki table scannability with a dedicated row hover and required badges

---

## [0.1.8] - 2026-02-19

### Added
- A server-side filter in the name-validation stream with pills and per-status counters (`all`, `problems`, `not_found`, `ambiguous`, `synonym`, `ignored`)
- A new pre-validation UX state in the right column with a guiding hint to start validation
- New name-validation i18n keys for:
  - the pre-validation hint
  - stream filters
  - table column labels
  - status badges
  - complete DataTable language
- New regression tests:
  - `test-mod-validate-names-server`: coverage of the stream filter/count logic and the post-completion default filter
  - `test-utils-i18n`: coverage of the new name-validation tab keys

### Changed
- The `validate_names` tab layout reorganized to move the action section to the right column and keep the left column focused on providers + options
- Provider cards compacted (smaller `min-height` + reduced padding) to improve vertical fit on desktop
- Validation options reorganized in a 2-column grid on the desktop viewport
- The validation results table (not-accepted items) updated with:
  - translated and colored badges for `validation_status`
  - `scientificName` in italic in display mode
  - a `rowCallback` to apply highlight classes per status
  - complete PT/EN language in the DataTable
- The default stream filter after validation completes set to `problems` (actionable items)

### Fixed
- Wasted space in the initial state of the validation tab (an empty stream with no actionable information)
- Low scannability post-validation due to too many `accepted` items in the stream by default
- Difficult reading of the results table due to a raw status with no visual badge and no complete localization

---

## [0.1.7] - 2026-02-19

### Changed
- The homepage (`upload` tab) compacted to reduce total height and improve fit on the desktop viewport:
  - A single block of upload hints (`upload-hints-compact`) replaces the separate specifications, privacy and recommendation blocks
  - The "How it works" flow migrated to a horizontal layout with 4 compact cards and visual separators between steps
- The homepage's required DwC fields aligned with the same functional reference used in the Preview tab (`scientificName`, `eventDate`, `decimalLatitude`, `decimalLongitude`, `basisOfRecord`, `occurrenceID`)
- The homepage required list restructured to direct per-category display (no tab clicking), with always-visible groups: `Record-level`, `Occurrence`, `Taxon`, `Location`
- Added URL versioning for `www/custom.css` in `app_ui` to reduce the risk of stale cache after visual changes

### Fixed
- Inconsistency between the required fields shown on the homepage and the readiness criteria of the Preview tab
- A homepage UX regression where tab-based exploration hid required terms and increased reading friction
- Possible persistence of old CSS in the browser after a local deploy due to static asset caching

---

## [0.1.6] - 2026-02-16

### Added
- A new lightweight name-validation readiness gate exposed by `mod_mapping_server` as the internal attribute `validation_gate` on the returned reactive (`status`, `has_data`, `scientific_col`)
- A new optional parameter `validation_gate_r` in `mod_validate_names_server` to receive the lightweight readiness signal without depending on the full mapped dataset
- New regression tests:
  - `test-mod-mapping-server`: coverage of the `validation_gate` contract and transitions (`no_data -> missing_scientific -> ok`)
  - `test-mod-validate-names-server`: coverage of the lightweight path ensuring `quick_inputs()`/`can_run_validation()` do not call `mapped_data_r()` when `validation_gate_r` is present

### Changed
- Wiring in `app_server` to propagate `validation_gate` from the mapping module to the name-validation module
- `quick_inputs()` in `mod_validate_names` now prioritizes `validation_gate_r` and uses `mapped_data_r()` only as a compatibility fallback
- The interface documentation of `mod_validate_names_server` updated to reflect the new optional parameter
- The `Validate names` click flow restructured into two phases (`starting` -> `running`) to allow an immediate UI repaint before the heavy step

### Fixed
- Latency to enable the `Validate names` button after mapping `scientificName` and returning to the validation tab
- Unnecessary heavy recomputation before the `Validate names` click in the UI readiness path
- A UX regression where the validation tab appeared "frozen" just to decide the button's enabled state
- Lack of visual feedback on the `Validate names` click; the user now gets immediate feedback (spinner/in-progress state) even when the heavy preparation takes time

---

## [0.1.5] - 2026-02-15

### Added
- A name-validation tab with a blocking modal in the Rostrum pattern during taxonomic validation, including an estimated progress bar by phases
- A persistent summary in name validation indicating consulted providers, failed providers and an explicit consolidation-by-unique-scientific-names notice
- A new suite `tests/testthat/test-mod-validate-names-server.R` covering the provider controls and a resilient partial-failure flow

### Changed
- The taxonomic-validation provider selector migrated from `selectizeInput` to `checkboxGroupInput`, with a fixed order `GBIF > ITIS > COL > NCBI` and a default of `GBIF`
- The taxonomic-validation total message updated to reflect consolidation by unique names

### Fixed
- `run_taxadb_cascade()` now handles per-provider errors individually, records failures in a `provider_failures` attribute and continues the cascade with the remaining providers
- The `Validate Names` button flow now shows consistent feedback even without mapped data (silent `req` removed), opening the loading modal before the heavy steps and returning an explicit warning when `mapped_data` is empty/missing

---

## [0.1.3] - 2026-02-15

### Added
- A lightweight required-fields checklist in the Preview tab with colored chips (`.preview-readiness-chip-ok` / `.preview-readiness-chip-missing`) for `scientificName`, `eventDate`, `decimalLatitude`, `decimalLongitude`, `basisOfRecord` and `occurrenceID`

### Changed
- The preview table aligned to `design.md`: redesigned pagination (compact buttons, consistent active state), a smaller search box/length menu and a dedicated visual container
- The Preview DataTable now opens with `10` records per page (`pageLength = 10`, `lengthMenu = 10/25/50/100`)
- The required-fields checklist evolved from chips to status cards (no chips), with a white panel and beige inner cards
- The required cards now use only enlarged state icons (no `present/absent` text): missing with a hollow red icon, present with a filled green icon
- The Preview download button received an elegant hover with a slight elevation, an accent shadow and a visible focus
- The Preview table header adjusted to the design system solid blue and the pagination given a blue theme (removing the inherited green in the page control)
- The Preview download flow now uses a confirmation before export and a visual progress modal in the Rostrum pattern, keeping `process_for_export()` intact

### Fixed
- The "Download Full CSV" button in the Preview without an icon duplication (`downloadButton` now with a text label + an explicit `icon`)
- The count selector in "Show _MENU_ records" in the Preview DataTable with padding/alignment adjusted to avoid the arrow overlapping the value
- `mod_preview_server` tests updated to cover the readiness checklist and the duplicate-icon regression on the download button
- The Preview download validation modal now presents the missing required fields in a white card over a beige background

---

## [0.1.4] - 2026-02-15

### Added
- A new layer `R/utils_taxadb.R` with normalization, deduplication, cascade and taxonomic-report construction via `taxadb::filter_name()`
- A name-validation tab with a provider selector, name-cleaning options, per-status statistics and report download
- New tests `tests/testthat/test-utils-taxadb.R` covering normalization, cascade and result merging
- ADR-024 recording the deduplication and provider cascade in taxonomic validation

### Changed
- `DESCRIPTION` includes `taxadb` in `Imports`
- `docs/architecture.md` and `docs/skill.md` updated for `filter_name()` and the supported providers
- The validation table with per-status visual classes and complete DataTable localization

### Fixed
- The taxonomic cascade now aligns columns before the `rbind`, avoiding an error when results vary between providers

---

## [0.1.2] - 2026-02-15

### Added
- A new utility layer `R/utils_preview.R` with pure functions to prepare the preview and compute readiness (`prepare_preview_data`, `compute_preview_readiness`)
- A readiness panel in the Preview tab with 4 metrics (records, coordinates, date, unique IDs) and a visual required-fields checklist
- New Preview i18n keys for the panel, export progress and complete DataTable language (empty/zero/pagination)
- New tests `tests/testthat/test-utils-preview.R` and `tests/testthat/test-mod-preview-server.R` covering the pure logic and the module contract

### Changed
- `mod_preview` refactored to use pure preview functions, a dynamic `downloadButton` via `renderUI` and `withProgress` on export
- The Preview empty state evolved to a visual card with an icon/title/message
- The Preview DataTable improved with truncation of long cells + a tooltip, `autoWidth = FALSE` and highlighting of 100%-empty columns in the full dataset
- The `occurrenceID` policy in the panel: unique IDs considered OK when absent/empty due to the automatic-generation fallback at export
- Dedicated Preview CSS added in `inst/app/www/custom.css` (panel/chips/empty state/empty columns/tooltip/responsive)
- The mapping pipeline split into two channels: `processed_data` (full) and `preview_data` (light, over `head(raw_data, 100)`), with wiring in `app_server` to use the light preview in the table and the full data in download/validations

### Fixed
- Fragility of the Preview download label (removal of a nested `uiOutput` inside `downloadButton`)
- A pre-existing `basisOfRecord` test in `tests/testthat/test-utils-dwc.R` adjusted for accent-robust comparison
- Heavy recomputation in the Preview flow: the table stopped depending on the full mapped dataset and now uses a dedicated light channel, keeping full processing only on explicit actions (download/validation)
- The Preview tab simplified at runtime (title, subtitle, download button, table), with no readiness-panel execution during navigation

---

## [0.1.1] - 2026-02-14

### Changed
#### Wave 3 - date performance
- `parse_dates_to_iso()` refactored to per-format vectorized parsing with strict masks
- The `DD/MM/YY` rule with a dynamic cutoff by the current year (`YY <= current year (2 digits) -> 20YY`, else `19YY`)
- `fix_dates_to_iso()` now delegates parsing to `parse_dates_to_iso()` on the `eventDate`, `dateIdentified` and `modified` columns

#### Wave 6 - expanded regression coverage in critical utils
- Existing suites (`utils_io`, `utils_dwc`, `utils_export`, `utils_i18n`) were expanded instead of recreated
- Coverage now includes direct scenarios for reading/delimiter/encoding, coordinate and occurrenceID validation, license normalization, coordinate cleaning, occurrenceID generation/preservation and i18n fallbacks
- No public signature change in the tested functions

#### Wave 4 - mod_mapping modularization
- `mod_mapping`'s `processed_data` centralized in the pure function `build_processed_mapping_df()` in `R/utils_mapping.R`
- Pure state/mapping helpers extracted to `R/utils_mapping.R` (`has_selected_value`, `sanitize_map_selection`, `default_meta`, `empty_map_values`, `empty_map_meta`, `build_manual_meta`)
- `mod_mapping_server()` kept its signature and return (`reactive(data.frame)`), preserving the reactive wiring and UI behavior

#### Wave 5 - static DwC artifact caching
- `load_dwc_terms_rds()` now supports `force = FALSE/TRUE` with an in-process cache and explicit invalidation
- `load_dwc_synonyms_v1()` now supports `force = FALSE/TRUE` with an in-process cache when `path = NULL`
- Legacy `data/` fallbacks removed for `dwc_terms.rds` and `dwc_synonyms_v1.rds`; loading standardized in `inst/extdata`
- Internal cache state/reset helpers added for test isolation (`*_cache_state()`, `reset_*_cache()`)

#### basisOfRecord Mapping Assistant (V1 complete)
- A new dedicated assistant in the `basisOfRecord` card with a per-raw-cell-value mapping modal
- The official vocabulary with 8 GBIF/TDWG terms incorporated into `R/utils_dwc.R` with PT/EN labels and descriptions
- `basisOfRecord` now uses a single source column and final processing with one value per row (or empty), with no concatenation
- Auto-suggestion via a case-insensitive exact match for canonical terms (e.g. `humanobservation` -> `HumanObservation`)
- A modal with a `Do not map` option, `X/Y` progress, compact pagination and a live 5-row preview
- `build_processed_mapping_df()` extended with `basis_of_record_map` to apply row-wise mapping before the generic flow

### Fixed
- Export semantics preserved for non-empty invalids: the raw value kept in `fix_dates_to_iso()`
- `NA` and an empty string still result in `NA` in the export date columns
- A portability warning from non-ASCII in `R/data_dictionary.R`, `R/mod_help.R` and `R/utils_i18n.R` eliminated via Unicode escapes (`\\uXXXX`), keeping the functional behavior
- The `basisOfRecord` assistant: removed the continuous observer of the table selects (syncing is now by snapshot on `Previous/Next/Save`) to avoid a reactive cascade
- The `basisOfRecord` assistant preview optimized to map only the 5 displayed rows and compute the unmapped count via a vectorized lookup
- The `basisOfRecord` assistant modal adjusted to keep the footer visible in the viewport, with internal scroll in the body and a more compact internal table
- The `basisOfRecord` assistant modal harmonized with the mapping tab: a white surface (`bg-card`), dropdowns styled like the mapping fields, headers in solid blue and table borders in the same pattern as the mapping fields
- The `basisOfRecord` assistant pagination simplified: the textual `Page X of Y` counter removed between the `Previous` and `Next` buttons
- The `basisOfRecord` assistant tables (mapping and preview) adjusted with a white cell background, consistent blue headers and a stable `scrollbar-gutter` to avoid the scrollbar overlapping
- The `basisOfRecord` assistant table dropdowns migrated to `selectize = FALSE` to reduce initialization cost in the modal
- The `basisOfRecord` assistant table: the sticky header reinforced with layer/paint isolation to prevent values from scrolling behind the header
- Functions `normalize_basis_of_record_key`, `sanitize_basis_of_record_term` and `sanitize_basis_of_record_map` vectorized (`normalize_basis_of_record_keys`, `sanitize_basis_of_record_terms`) to eliminate element-wise `vapply`/`for` on 96k+ rows; call sites updated in `extract_basis_of_record_unique_entries`, `map_basis_of_record_values`, `get_effective_basis_of_record_map` and the assistant preview

### Added
- New regression tests: `tests/testthat/test-utils-io.R` and `tests/testthat/test-utils-export.R`
- A 100k benchmark script: `tests/bench/benchmark_dates_onda3.R`
- A Wave 3 comparative report: `docs/archive/benchmark_onda3_2026-02-14.md`
- New Wave 4 regression tests in `tests/testthat/test-utils-mapping.R` and `tests/testthat/test-mod-mapping-server.R`
- A new suite `tests/testthat/test-utils-dwc.R` covering cache/invalidation/consistency of `dwc_terms`
- New synonym cache scenarios in `tests/testthat/test-utils-mapping.R`
- New Wave 6 scenarios in `tests/testthat/test-utils-io.R`, `tests/testthat/test-utils-dwc.R`, `tests/testthat/test-utils-export.R` and `tests/testthat/test-utils-i18n.R`

---

## [0.1.0] - 2026-02-13

### Added
- **Rostrum auto-mapping (beta)**: A proprietary automatic mapping engine with scoring by name + content
- **Confidence badges**: Visual indicators (`AUTO`, `SUGERIDO`, `MANUAL`, `EDITADO`) on mapped fields
- **Synonyms table**: Support for synonyms via `dwc_synonyms_v1.rds` for fuzzy matching
- **Blocking loading**: A modal with progress, rotating phrases and contextual icons during auto-map
- **Rostrum toggle**: A `bslib::input_switch` switch to enable/disable the V1 engine
- **License abbreviation**: CC URLs -> short labels (`CC0`, `CC-BY`, `CC-BY-NC`) in preview and export
- **Automated tests**: `test-utils-mapping.R` (58 tests) and `test-mod-mapping-server.R` (16 tests)

### Fixed
#### Wave 2 - consistent i18n
- `app_server` uses `tr("nav_validate", lang_r())` and the initial tab uses `tr("nav_home", lang_r())`
- `mod_validate_names` and `mod_validate_coords` remove `if (lang == "pt")` conditionals for warnings/success
- `mod_wiki` with a placeholder, class filter and table headers translated via `tr()`
- `mod_preview` with DataTable text (`search`, `lengthMenu`, `info`) externalized in the dictionary
- `mod_mapping` with placeholders and category/language labels bound to the dictionary
- A new test `tests/testthat/test-utils-i18n.R` validating keys and PT/EN resolution for Wave 2

#### Complementary release adjustments
- Badges disappearing after unchecking/rechecking categories (isolated read -> reactive)
- `scientificName` accepted multiple columns (now a single selection)
- Literal `NA` in the exported CSV -> empty cells with `readr::write_csv(na = "")`
- Category filter: an empty selection showed all cards (now shows none)
- The phantom `Organism` category removed from the filter

#### Wave 1 - package/deploy stability
- `shiny::toJSON` -> `jsonlite::toJSON` (compatibility)
- Package/deploy stability: removal of `source()` in `R/*.R`
- A test helper compatible with the check tarball (no local path to `R/*.R`)
- `DESCRIPTION`: `jsonlite` added to `Imports`
- `mod_preview`: `head(...)` replaced by `utils::head(...)`
- `utils_i18n::tr()`: resolution of `i18n_dict` via environment/namespace without `source()`

---

## [0.0.5] - 2026-02-12

### Added
- **Special fields in mapping**: `datasetName` (dropdown + text), `modified` (checkbox + calendar), `license` (CC checkboxes), `language` (`pt`/`en`/`es` checkboxes)
- **Standardized DwC concatenation**: `;` as the input separator, ` | ` as the output
- **eventDate parser**: 4 columns -> `YYYY-MM/YYYY-MM` with a fallback to the raw value
- **Visual mapping indicator**: A green border on mapped cards, no orange bar
- Pure functions: `normalize_semicolon_tokens`, `collapse_mapped_values`, `build_eventdate_interval`, `detect_eventdate_roles`, `parse_month_to_number`
- Derivation functions: `extract_scientific_name_components`, `fill_missing_character_values`, `replace_na_with_blank`

### Fixed
- Invisible category headers: undefined CSS variables `--primary-dark`, `--text-muted`, `--border`
- Category header redesigned (dark blue gradient with high contrast)
- A re-render bug resetting selections in custom fields (fixed with `isolate(input$...)`)
- A forced single selection for `license` and `language` via a server-side `observeEvent`

---

## [0.0.4] - 2026-02-09

### Changed
- Final typographic scale: `--text-xs: 0.75rem` up to `--text-2xl: 1.75rem`
- Navbar title larger than card headers (`--text-2xl` vs `--text-lg`)
- Increased card header padding
- DwC fields in a horizontal (flex) layout instead of a 4-column grid
- Required DwC fields with compact boxes and adequate padding

### Fixed
- Corrupted encoding in `data_dictionary.R` (accented characters restored)

---

## [0.0.3] - 2026-02-09

### Added
- A Data Quality Dashboard after upload (empty columns, detected types)
- A success notification in green (`#2d6a4f`)
- Alerts and notifications in bold

### Changed
- Nav "Upload" -> "Home" with the `fa-home` icon
- Base font increased to `1rem`
- Stats boxes in full width (`flex: 1 1 0`)
- The upload input group with the button/field connected (no gap)

### Removed
- The footer with the funding logos (Observatorio, Zhouse, Humanize)

---

## [0.0.2] - 2026-02-08

### Added
- A hexagonal logo in the navbar (72px)
- FontAwesome 6.5.1 CDN (classic solid)
- A two-column layout on the home: Data (5) + Welcome (7)
- A visual workflow with 4 steps (Upload -> Mapping -> Validation -> Export)
- A privacy alert: "All data processed locally"
- 50+ i18n strings in `data_dictionary.R`
- ~200 lines of CSS for new components

### Fixed
- Upload button: illegible text (yellow on yellow) -> explicit colors with `!important`
- Compacted statistics cards -> padding restored
- Upload limit: 500 MB (previously no defined limit)
- Upload button: icon-only (40x40px) with synced height

---

## [0.0.1] - 2026-02-08

### Fixed
- `DESCRIPTION`: empty lines between sections removed
- `DESCRIPTION`: the `here` dependency added to Imports
- `app_ui.R`: `nav_spacer()` -> `bslib::nav_spacer()` (namespace)
- `utils_dwc.R`: incompatible vector count (`rep("Taxon", 15)` -> `14`)
