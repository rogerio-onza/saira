# Saira Project - Biodiversity Data Standardization Tool

## 1. Project Overview
**Goal**: Standardize biodiversity data to **Darwin Core (DwC)**.  
**Stack**: Shiny (R), Package-based structure (`golem`-style), `testthat`, `bslib`, `shinyFeedback`.  
**Languages**: **Bilingual UI** (PT-BR / EN-US) | Code/Comments in **English**.  
**Philosophy**: Strict Modularization. No monolithic `server.R`.

---

## 2. File Structure
We follow the R Package structure. All logic and module definitions live in `R/`.
```text
saira/
├── CHANGELOG.md            # What changed and when (Keep a Changelog format)
├── DESCRIPTION             # Package dependencies
├── app.R                   # Launch script: pkgload::load_all(); run_app()
├── R/
│   ├── app_ui.R            # Main UI definition (calls modules)
│   ├── app_server.R        # Main Server (orchestrates modules, zero logic)
│   ├── run_app.R           # Shiny app launcher
│   ├── saira-package.R     # @importFrom declarations (roxygen2-managed)
│   ├── mod_upload.R        # Module: Import & encoding check
│   ├── mod_mapping.R       # Module: Column mapping to DwC
│   ├── mod_mapping_cards.R       # Sub-module: Mapping card UI builder
│   ├── mod_mapping_loading.R     # Sub-module: Auto-map loading modal
│   ├── mod_mapping_basis_assistant.R  # Sub-module: BasisOfRecord assistant
│   ├── mod_preview.R       # Module: Data preview & export
│   ├── mod_validate_names.R  # Module: Scientific name validation
│   ├── mod_validate_coords.R # Module: Coordinate validation
│   ├── mod_wiki.R          # Module: DwC terms reference
│   ├── mod_help.R          # Module: Help & FAQ
│   ├── utils_io.R          # Pure: File reading, encoding, delimiter detection
│   ├── utils_dwc.R         # Pure: DwC term loading, basisOfRecord vocab
│   ├── utils_mapping.R     # Pure: Scoring, synonyms, sanitization, composition
│   ├── utils_export.R      # Pure: Date conversion, license abbreviation, UUIDs
│   ├── utils_preview.R     # Pure: Preview readiness, download validation
│   ├── utils_common.R      # Pure: Shared helpers (is_blank_value, normalization)
│   ├── utils_coords.R      # Pure: Coordinate validation (CoordinateCleaner)
│   ├── utils_taxadb.R      # Pure: Taxonomic validation (taxadb cascade)
│   ├── utils_i18n.R        # Pure: Translation helpers
│   ├── utils_rostrum_engine.R    # Pure: Auto-mapping engine (multi-stage)
│   ├── utils_rostrum_db.R        # Pure: Rostrum SQLite persistence
│   ├── utils_rostrum_templates.R # Pure: Template import/export
│   ├── utils_rostrum_contracts.R # Pure: Data frame contract validation
│   └── data_dictionary.R   # i18n dictionary loader (from inst/extdata/i18n.json)
├── tests/
│   ├── testthat/           # 31 test files covering utils, modules, e2e
│   └── testthat.R          # Test runner
├── inst/
│   ├── extdata/            # Static data files
│   │   ├── i18n.json       # Translation dictionary (PT/EN)
│   │   ├── dwc_terms.rds   # Darwin Core term definitions
│   │   ├── dwc_synonyms_v1.rds  # Synonym table for auto-mapping
│   │   └── country_aliases.rds  # Country name aliases for coords
│   └── app/www/            # Static assets (CSS, JS, images)
└── docs/                   # Project documentation
    ├── architecture.md     # Architecture reference
    ├── claude.md           # THIS FILE — AI guidelines
    ├── skill.md            # Coding standards & style
    ├── design.md           # Design system tokens
    ├── DECISIONS.md        # Architecture Decision Records (ADRs)
    ├── LESSONS.md          # Reusable lessons by theme
    ├── rostrum_engine.md   # Auto-mapping engine spec
    └── archive/            # Superseded plans & logs
```

## 3. Bilingual Strategy (i18n)

Dynamic switching (PT <-> EN) without page reload.

### Implementation Rules

1. **Dictionary**: `inst/extdata/i18n.json` contains all translations. `R/data_dictionary.R` loads and caches this JSON at startup:
```json
{
  "upload_title": { "pt": "Carregar Dados", "en": "Upload Data" },
  "error_fmt": { "pt": "Formato inválido", "en": "Invalid format" }
}
```

2. **Helper**: `tr(id, lang)` in `R/utils_i18n.R` retrieves the string.

3. **State**: `app_server` maintains `input$selected_lang`. This reactive is passed to every module.

4. **Usage**: `h3(tr("upload_title", lang_r()))` inside `renderUI`.

---

## 4. Development Workflow (Strict Cycle)

To prevent creating a "Distributed Monolith", follow this cycle:

1. **Isolate Logic**: Write the feature as a pure function in `R/utils_*.R`.
   - Input: Dataframe/String. Output: Dataframe/Result. No Shiny dependencies.

2. **Test Logic**: Write a unit test in `tests/testthat/`.

3. **Build Module**: Create `R/mod_[name].R`. Use `moduleServer` to call the pure function.

4. **Wire UI**: Add the module's UI to `R/app_ui.R`.

5. **Wire Server**: Call the module in `R/app_server.R` and handle return values.

---

## 5. Coding Patterns

### A. The "Pure" Module Pattern & User Feedback

Modules act as bridges. We use `shiny::validate` or `shinyFeedback` to communicate errors, rather than silent failures.
```r
# R/mod_example.R
mod_example_server <- function(id, data_r, lang_r) {
  moduleServer(id, function(input, output, session) {
    
    # 1. Reactive Validation (Shiny side)
    clean_data <- reactive({
      req(data_r()) # Ensure upstream data exists
      
      # Validate inputs before calling heavy logic
      shiny::validate(
        need(nrow(data_r()) > 0, tr("err_empty_data", lang_r()))
      )
      
      # 2. Call Business Logic (Pure side)
      # Wrap in tryCatch for unexpected errors not caught by validation
      tryCatch({
        calculate_metrics(data_r()) # From utils_stats.R
      }, error = function(e) {
        # Log error to console/server logs
        warning(paste("Metric calc failed:", e$message))
        
        # Give user friendly feedback via shinyFeedback or Notification
        showNotification(tr("err_calculation", lang_r()), type = "error")
        NULL
      })
    })
    
    # 3. Output (UI side)
    output$plot <- renderPlot({
      req(clean_data())
      make_plot(clean_data(), title = tr("plot_title", lang_r()))
    })
    
    # 4. Explicit Return
    return(clean_data) 
  })
}
```

### B. Robust File Reading (Bilingual Context)

Brazilian data often has encoding issues (Windows-1252 vs UTF-8).

- **Rule**: `utils_io.R` must attempt to detect encoding or allow user override via a dropdown in `mod_upload`.

- **Dates**: Always convert "DD/MM/YYYY" (PT) to "YYYY-MM-DD" (DwC/ISO).

---

## 6. Darwin Core (DwC) Rules & Validation Feedback

The app enforces data quality for biodiversity repositories.

### Validation Logic (utils_dwc.R)

- **occurrenceID**: Check uniqueness.

- **eventDate**: Refuse ambiguous dates (e.g., "02/03/2020"). Require ISO format for export.

- **Coordinates**: Handle comma decimals ("-23,55"). Validate WGS84 bounds.

- **Taxonomy**: `scientificName` is mandatory.

### UI Feedback Strategy

- Use `shiny::validate()` inside render functions to stop execution gracefully if rules aren't met.

- Use `shinyFeedback::feedbackWarning()` on specific inputs (e.g., highlighting the "Latitude" column selector if the selected column contains text).

---

## 7. Testing Strategy (Priority)

We test logic, not Shiny interactivity (unless using shinytest2). The suite has **31 test files** covering:

- `test-utils-*.R`: Pure function tests (io, dwc, mapping, export, coords, taxadb, preview)
- `test-utils-rostrum-*.R`: Rostrum engine stages (stage1, stage2, stage3, aliases, templates, db, contracts)
- `test-mod-*-server.R`: Module server tests (upload, mapping, preview, validate names/coords, wiki, help)
- `test-performance-regression.R`: Performance benchmarks
- `test-css-guardrails.R`: CSS class/structure consistency
- `test-i18n-*.R`: Translation key coverage and accessibility
- `test-e2e-flows.R`: End-to-end data flow integration

---

## 8. Communication between Modules

Avoid global variables (`<<-`) or `reactiveValues` passed everywhere.

### Pattern: Chain of Reactivity

- `mod_upload` returns `reactive(raw_data)`.

- `mod_mapping` takes `raw_data`, returns a **named list** of reactives (ADR-054):
  - `processed_data_r`, `preview_data_r`, `validation_gate_r`, `validation_gate_coords_r`
  - `rostrum_decisions_r`, `rostrum_explain_r`, `rostrum_run_stats_r`

- `mod_validate_*` takes the relevant slots from the mapping result.

### Orchestrator: app_server
```r
# R/app_server.R
server <- function(input, output, session) {
  lang <- reactive(input$lang_switch)
  
  raw_d <- mod_upload_server("upload", lang)
  
  # Note: Pass the reactive EXPRESSION (raw_d), not the value (raw_d())
  mapping_result <- mod_mapping_server("map", data = raw_d, lang = lang)
  
  # mapping_result is a named list of reactives (ADR-054)
  mod_preview_server("preview", mapping_result$preview_data_r, lang)
  mod_validate_names_server("names", mapping_result$processed_data_r, lang,
    validation_gate_r = mapping_result$validation_gate_r)
  mod_validate_coords_server("coords", mapping_result$processed_data_r, lang,
    validation_gate_r = mapping_result$validation_gate_coords_r)
}
```

---

## 9. Common Mistakes to Avoid

1. **No setwd()**: Never use `setwd()` in the code. Use `here::here()` or relative paths.

2. **Heavy Data in Server**: Do NOT load large static datasets repeatedly inside modules. Use `sysdata.rda` or the ADR-014 cache factory `create_rds_cache()` for lazy loading (see `utils_common.R`) so data is loaded once per process.

3. **No library() calls in modules**: Use `::` (e.g., `dplyr::mutate`) or define in `global.R`/`DESCRIPTION`.

4. **UI Text**: Never hardcode "Selecione o arquivo". Use `tr("select_file", lang())`.

5. **Monolithic Server**: If `app_server.R` has logic other than calling modules, refactor it.

---

## 10. Documentation Maintenance

The project uses 3 living documents in `docs/`. **Keep them updated after every change.**

### CHANGELOG.md (root)
Format: [Keep a Changelog](https://keepachangelog.com/). Grouped by version and type.
- **Bug corrigido?** → Add under `### Corrigido`
- **Nova feature?** → Add under `### Adicionado`
- **Comportamento alterado?** → Add under `### Alterado`
- **Algo removido?** → Add under `### Removido`

### docs/LESSONS.md
Indexed by **theme** (R packages, CSS, i18n, DwC, performance, tests). NOT chronological.
- **Learned something reusable?** → Add to the matching theme section
- **New theme?** → Create a new `##` section

### docs/DECISIONS.md
Lightweight ADRs (Architecture Decision Records).
- **Made a significant technical decision?** → Create a new `## ADR-NNN: Title`
- Include: Date, Context, Decision, Alternatives considered (if any), Consequences

---

**Use this file as the strict guideline for all code generation.**