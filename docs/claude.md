# Finch Project - Biodiversity Data Standardization Tool

## 1. Project Overview
**Goal**: Standardize biodiversity data to **Darwin Core (DwC)**.  
**Stack**: Shiny (R), Package-based structure (`golem`-style), `testthat`, `bslib`, `shinyFeedback`.  
**Languages**: **Bilingual UI** (PT-BR / EN-US) | Code/Comments in **English**.  
**Philosophy**: Strict Modularization. No monolithic `server.R`.

---

## 2. File Structure
We follow the R Package structure. All logic and module definitions live in `R/`.
```text
finch/
├── CHANGELOG.md            # What changed and when (Keep a Changelog format)
├── DESCRIPTION             # Package dependencies
├── app.R                   # Launch script: pkgload::load_all(); run_app()
├── R/
│   ├── app_ui.R            # Main UI definition (calls modules)
│   ├── app_server.R        # Main Server (orchestrates modules, zero logic)
│   ├── run_app.R           # Shiny app launcher
│   ├── mod_upload.R        # Module: Import & encoding check
│   ├── mod_mapping.R       # Module: Column mapping to DwC
│   ├── mod_preview.R       # Module: Data preview & export
│   ├── mod_validate_names.R  # Module: Scientific name validation
│   ├── mod_validate_coords.R # Module: Coordinate validation
│   ├── mod_wiki.R          # Module: DwC terms reference
│   ├── mod_help.R          # Module: Help & FAQ
│   ├── utils_io.R          # Pure: File reading, encoding, delimiter detection
│   ├── utils_dwc.R         # Pure: DwC definitions, coordinate validation
│   ├── utils_mapping.R     # Pure: Auto-mapping scoring, concatenation, eventDate
│   ├── utils_export.R      # Pure: Date conversion, license abbreviation, UUIDs
│   ├── utils_i18n.R        # Pure: Translation helpers
│   └── data_dictionary.R   # Translation strings (i18n_dict list)
├── tests/
│   ├── testthat/           # Unit tests for R/utils_*.R
│   └── testthat.R          # Test runner
├── data/
│   ├── dwc_terms.rds       # Reference vocabulary (static)
│   └── dwc_synonyms_v1.rds # Synonym table for auto-mapping
├── inst/app/www/           # Static assets (CSS, images)
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

1. **Dictionary**: `R/data_dictionary.R` contains a named list:
```r
i18n_dict <- list(
  upload_title = list(pt = "Carregar Dados", en = "Upload Data"),
  error_fmt = list(pt = "Formato inválido", en = "Invalid format")
)
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

We test logic, not Shiny interactivity (unless using shinytest2).

- `test-utils-io.R`: Can we read a Latin1 CSV correctly?

- `test-utils-dwc.R`: Does `validate_coords(-91, 0)` return FALSE?

- `test-i18n.R`: Do all dictionary keys exist for both PT and EN?

---

## 8. Communication between Modules

Avoid global variables (`<<-`) or `reactiveValues` passed everywhere.

### Pattern: Chain of Reactivity

- `mod_upload` returns `reactive(raw_data)`.

- `mod_mapping` takes `raw_data`, returns `reactive(mapped_data)`.

- `mod_validate` takes `mapped_data`, returns `reactive(report)`.

### Orchestrator: app_server
```r
# R/app_server.R
server <- function(input, output, session) {
  lang <- reactive(input$lang_switch)
  
  # Data Flow
  raw_d <- mod_upload_server("upload", lang)
  
  # Note: Pass the reactive EXPRESSION (raw_d), not the value (raw_d())
  map_d <- mod_mapping_server("map", data = raw_d, lang = lang)
  
  mod_validate_server("valid", data = map_d, lang = lang)
}
```

---

## 9. Common Mistakes to Avoid

1. **No setwd()**: Never use `setwd()` in the code. Use `here::here()` or relative paths.

2. **Heavy Data in Server**: Do NOT load large static datasets (like a 50MB taxonomy backbone) inside server or modules. Load them in `global.R` so they are loaded once into RAM and shared across user sessions.

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