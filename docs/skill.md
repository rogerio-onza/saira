---
name: r-developer-skills
description: Comprehensive R development guidelines for analysis scripts and Shiny applications. Covers code style, modularization, safety protocols, spatial analysis stack, and package development best practices following Mastering Shiny principles.
license: MIT
---

**Version**: 2.0  
**Author**: Rogério Nunes Oliveira  
**Last Updated**: 2026-02-07  
**Tags**: R, Shiny, spatial-analysis, package-development, best-practices

**Compatibility**:
- R >= 4.0.0
- Shiny >= 1.7.0
- terra >= 1.7.0
- tidyverse >= 2.0.0

---

# R Developer Skills & Preferences (Analysis + Shiny)

## 1. File Headers & Metadata (MANDATORY)
Every script must start exactly with this block:
```r
# Title: [Objective of the script]
# Author: Rogerio Nunes Oliveira
# Date: [YYYY-MM-DD format, e.g., 2026-02-06]
# Version: [1.0]
```

---

## 2. Code Style & Formatting

### 2.1 Comments
- **Concise, single-line, objective**. Avoid verbose documentation unless explaining complex math/algorithms.
- **Exception for Packages**: Use roxygen2 documentation for exported functions (see Section 8).

### 2.2 Naming Conventions
- **Variables & Functions**: `snake_case` exclusively
- **NO ALL CAPS** (except for `TRUE`, `FALSE`, `NULL`)
- **Functions**: Verbs (`calculate_density`, `validate_coords`)
- **Objects**: Nouns (`population_data`, `mapped_data`)

### 2.3 The Pipe
- **Preference**: `%>%` (magrittr/dplyr) for consistency with Tidyverse
- **Native pipe** `|>`: Only when zero dependencies are required or explicitly requested

### 2.4 Visual Separators
- **PROHIBITED**: `======`, `######`, `-----` in code
- **Allowed**: 
  - Standard Markdown headers in `.md` files
  - Logical spacing (single blank lines)
  - Section comments with simple `#` prefix

**Example**:
```r
# ✅ ALLOWED
# Data Loading Section

# ❌ PROHIBITED
# ============== Data Loading Section ==============
```

### 2.5 Console Output (Critical Rule)
Avoid `cat()`, `print()`, and `message()` unless **strictly necessary** for:
- Critical warnings about data integrity
- Progress indicators in long-running operations (>30 seconds)
- Explicit debugging requested by user
- **Exception**: Use `shiny::showNotification()` or `shinyFeedback` in Shiny apps for user feedback

---

## 3. Safety & Protocol

### 3.1 Unknown Packages
- **DO NOT hallucinate syntax** for unfamiliar libraries
- **Stop and ask**: *"Please provide the documentation or example usage for [Package Name] before I proceed."*

### 3.2 Dependencies
- Always verify package availability before suggesting code
- In package development: List ALL dependencies in `DESCRIPTION` under `Imports` or `Suggests`
- In scripts: Load packages explicitly at the top or use `::` notation

---

## 4. Technology Stack

### 4.1 Spatial Analysis (Geocomputation)
- **Primary**: `terra` for raster and vector operations
- **Secondary**: `sf` for:
  - Complex geometric operations (faster/simpler than terra)
  - Integration with `leaflet`, `ggplot2::geom_sf`
  - Explicit user request or legacy compatibility
- **Avoid**: `sp` (deprecated) unless absolutely required

### 4.2 Data Visualization
- **Base**: `ggplot2` for standard plots
- **Statistical**: `ggstatsplot` for quick statistical summaries with visuals
- **Composition**: `patchwork` for multi-plot layouts
- **Colors**: `rcartocolor` palettes (default aesthetic choice)
- **Interactive**: 
  - `plotly` for interactive plots
  - `leaflet` for interactive maps
  - `DT` for interactive tables in Shiny

### 4.3 Data Manipulation
- **Core**: `dplyr`, `tidyr`, `stringr`, `forcats`, `lubridate`
- **I/O**: 
  - `vroom` (large CSVs)
  - `readr` (standard CSVs)
  - `readxl` (Excel)
  - `terra` (geospatial)
  - `arrow` (Parquet/large datasets)

---

## 5. Engineering Philosophy

### 5.1 General R Scripts
- **Pure Functions**: Encapsulate logic. Minimize global variables.
- **Paths**: Use `here::here()` for all file paths. **Never** use `setwd()` or absolute paths.
- **Explicit Imports**: Use `package::function()` for clarity in production code.

### 5.2 Shiny Applications (Mastering Shiny + claude.md principles)

#### 5.2.1 Strict Modularization
- **Always use Shiny Modules** for components
- **No monolithic `server.R`**: Server should only orchestrate modules
- **Pattern**: Each module returns a reactive explicitly
```r
# ✅ CORRECT
mod_example_server <- function(id, data_r, lang_r) {
  moduleServer(id, function(input, output, session) {
    processed_data <- reactive({
      req(data_r())
      # ... logic
    })
    
    return(processed_data)  # EXPLICIT RETURN
  })
}
```

#### 5.2.2 Separation of Concerns (Critical)
- **UI logic**: `R/app_ui.R` or `R/mod_*_ui.R`
- **Server orchestration**: `R/app_server.R` (calls modules only)
- **Business logic**: `R/utils_*.R` (pure functions, zero Shiny dependencies)
- **Module logic**: `R/mod_*.R` (bridge between UI and utils)

**Example Structure** (from claude.md):
```r
# R/utils_dwc.R (Pure function - testable)
#' @export
validate_coords <- function(lat, lon) {
  valid <- lat >= -90 & lat <= 90 & lon >= -180 & lon <= 180
  return(valid)
}

# R/mod_validate.R (Shiny bridge)
mod_validate_server <- function(id, data_r, lang_r) {
  moduleServer(id, function(input, output, session) {
    validation_result <- reactive({
      req(data_r())
      
      # Call pure function
      validate_coords(
        data_r()$decimalLatitude, 
        data_r()$decimalLongitude
      )
    })
    
    return(validation_result)
  })
}
```

#### 5.2.3 Chain of Reactivity (from architecture.md)
```r
# R/app_server.R (Orchestrator ONLY)
app_server <- function(input, output, session) {
  lang_r <- reactive(input$lang_switch)
  
  # Data flows through modules
  raw_data    <- mod_upload_server("upload", lang_r)
  mapped_data <- mod_mapping_server("mapping", raw_data, lang_r)
  mod_preview_server("preview", mapped_data, lang_r)
  
  # Pass reactive EXPRESSION (raw_data), not VALUE (raw_data())
}
```

#### 5.2.4 Testability
- Write functions that can be tested independently of reactive context
- All business logic must be in `utils_*.R` files with unit tests

---

## 6. Error Handling & Validation

### 6.1 Scripts
- **Early Validation**: Use `stopifnot()` or explicit checks at script start
- **I/O Protection**: Wrap critical operations in `tryCatch()`:
```r
data <- tryCatch(
  vroom::vroom("data.csv"),
  error = function(e) stop("Failed to read data: ", e$message)
)
```

### 6.2 Shiny (from claude.md)
- **Input Validation**: Use `req()` to prevent computation on NULL inputs
- **User Feedback**: Use `shiny::validate()` with bilingual messages:
```r
validate(
  need(nrow(data_r()) > 0, tr("err_empty_data", lang_r()))
)
```
- **Error Handling Pattern**:
```r
clean_data <- reactive({
  req(data_r())
  
  shiny::validate(
    need(nrow(data_r()) > 0, tr("err_empty_data", lang_r()))
  )
  
  tryCatch({
    process_data(data_r())  # Pure function from utils_*.R
  }, error = function(e) {
    warning(paste("Processing failed:", e$message))
    showNotification(tr("err_processing", lang_r()), type = "error")
    NULL
  })
})
```

- **Silent Failures**: PROHIBITED. Always provide feedback via `showNotification()` or `shinyFeedback`

---

## 7. Performance Considerations

### 7.1 General
- **Data Size**: Use `data.table` or `arrow` for datasets >1M rows
- **Profiling**: Use `profvis` to identify bottlenecks before optimization

### 7.2 Shiny Optimization (from architecture.md)
- **Vectorization**: Avoid `apply(..., 1, ...)` or `sapply()` in reactive contexts
  - ✅ Use: `df$new_col <- df$col1 + df$col2` (vectorized)
  - ❌ Avoid: `df$new_col <- sapply(1:nrow(df), function(i) df$col1[i] + df$col2[i])`
- **Preview vs Export** (critical pattern):
  - Preview: Fast, vectorized, first 100 rows
  - Export: Complete processing via pure function in `utils_export.R`
- **Cache**: Use `bindCache()` for expensive computations
- **Reactivity**: 
  - Use `reactiveVal()` instead of `reactiveValues()` for single values
  - Use `debounce()` for user inputs that trigger heavy computations

---

## 8. Package Development Metadata

### 8.1 When to Use roxygen2
- **Analysis Scripts**: NEVER use roxygen2. Use simple comment headers.
- **R Packages**: ALWAYS document exported functions with roxygen2.

### 8.2 roxygen2 Template (Packages Only)
```r
#' Validate Geographic Coordinates
#'
#' Checks if latitude and longitude values are within valid ranges.
#'
#' @param lat Numeric vector of latitude values
#' @param lon Numeric vector of longitude values
#'
#' @return Logical vector indicating valid coordinates
#'
#' @examples
#' validate_coords(c(-23.5, 91), c(-46.6, 0))
#'
#' @export
validate_coords <- function(lat, lon) {
  lat >= -90 & lat <= 90 & lon >= -180 & lon <= 180
}
```

### 8.3 Key Components
- `@param`: Parameter descriptions
- `@return`: What the function returns
- `@examples`: Executable examples (tested by `R CMD check`)
- `@export`: Makes function available to package users
- `@importFrom pkg func`: Import specific functions (alternative to `::`)

### 8.4 Building Documentation
```r
# Generate documentation
devtools::document()

# Preview documentation
?validate_coords
```

**Scripts ≠ Packages**: A script with helper functions is still just a script. Only add package infrastructure when building an actual R package for distribution/reuse.

---

## 9. Code Organization

### 9.1 General Projects (Analysis Scripts)
```
project/
├── R/
│   ├── 01_data_cleaning.R
│   ├── 02_analysis.R
│   └── utils_plot.R       # Shared helper functions
├── data/
│   ├── raw/               # Never modified
│   └── processed/         # Outputs from scripts
├── outputs/
│   ├── figures/
│   └── tables/
└── README.md              # Optional, for complex projects
```

### 9.2 Shiny Package Structure (from claude.md & architecture.md)
```
saira/
├── DESCRIPTION            # Package metadata + dependencies
├── NAMESPACE              # Auto-generated via roxygen2
├── LICENSE
├── app.R                  # Entry point: library(saira); run_app()
├── R/
│   ├── run_app.R          # Exported function to launch app
│   ├── app_ui.R           # Main UI
│   ├── app_server.R       # Server orchestrator (ONLY module calls)
│   ├── mod_*.R            # Shiny modules
│   ├── utils_*.R          # Pure functions (business logic)
│   └── data_dictionary.R  # i18n translations (list)
├── data/
│   └── *.rds              # Static datasets
├── inst/
│   └── app/www/           # Static assets (CSS, JS, images)
├── tests/
│   └── testthat/
│       └── test-utils-*.R # Unit tests for pure functions
└── man/                   # Documentation (auto-generated)
```

**Critical Rule**: NO `global.R` in package structure. Use `DESCRIPTION` for dependencies.

---

## 10. Package Development (Shiny Apps)

### 10.1 Dependencies (from architecture.md)

#### DESCRIPTION File
```r
Imports:
    shiny (>= 1.7.0),
    bslib (>= 0.5.0),
    dplyr (>= 1.1.0),
    taxadb (>= 0.2.0)  # All runtime dependencies here

Suggests:
    testthat (>= 3.0.0),  # Only for developers
    knitr,
    rmarkdown
```

#### In Code: Use `::` Exclusively
```r
# ✅ CORRECT (package development)
validate_names <- function(names_vector) {
  db <- taxadb::td_create("gbif")
  results <- taxadb::filter_name(names_vector, provider = "gbif", db = db)
  
  cleaned <- results |>
    dplyr::filter(!is.na(scientificName)) |>
    dplyr::select(input, scientificName)
  
  return(cleaned)
}

# ❌ PROHIBITED in packages
library(taxadb)
library(dplyr)
validate_names <- function(x) { ... }
```

### 10.2 Installation & Loading
```r
# User installs once
remotes::install_github("user/saira")

# Dependencies (taxadb, dplyr, etc.) are installed AUTOMATICALLY
# User NEVER needs to install them manually

# Usage
library(saira)
run_app()
```

---

## 11. Testing Strategy (from claude.md)

### 11.1 What to Test
- ✅ **Pure functions** in `utils_*.R` (100% priority)
- ✅ **Data transformations** (dates, coordinates, encoding)
- ✅ **Validation logic** (DwC rules, taxonomic checks)
- ⚠️ **Shiny reactivity** (only if using `shinytest2`)

### 11.2 Test Structure
```r
# tests/testthat/test-utils-dwc.R
test_that("validate_coords rejects out-of-bounds values", {
  # Arrange
  input <- data.frame(
    lat = c(-23.5, 91, -100),
    lon = c(-46.6, 0, 0)
  )
  
  # Act
  result <- validate_coords(input$lat, input$lon)
  
  # Assert
  expect_equal(result, c(TRUE, FALSE, FALSE))
})
```

### 11.3 Running Tests
```r
# Run all tests
devtools::test()

# Check package integrity
devtools::check()

# Coverage report
covr::package_coverage()
```

---

## 12. Internationalization (i18n) for Shiny

### 12.1 Structure (from claude.md)
```r
# R/data_dictionary.R
i18n_dict <- list(
  upload_title = list(pt = "Carregar Dados", en = "Upload Data"),
  err_invalid = list(pt = "Dados inválidos", en = "Invalid data")
)

# R/utils_i18n.R
tr <- function(key, lang = "en") {
  if (!key %in% names(i18n_dict)) {
    warning("Translation key not found: ", key)
    return(paste0("[", key, "]"))
  }
  i18n_dict[[key]][[lang]] %||% i18n_dict[[key]][["en"]]
}
```

### 12.2 Usage in Modules
```r
mod_upload_ui <- function(id, lang = "en") {
  ns <- NS(id)
  tagList(
    h3(tr("upload_title", lang)),  # Bilingual text
    fileInput(ns("file"), tr("select_file", lang))
  )
}

mod_upload_server <- function(id, lang_r) {
  moduleServer(id, function(input, output, session) {
    shiny::validate(
      need(input$file, tr("err_no_file", lang_r()))  # Dynamic translation
    )
  })
}
```

**Critical Rule**: NEVER hardcode text. Always use `tr(key, lang)`.

---

## 13. Prohibited Practices

### 13.1 Universal (Scripts + Packages)
- ❌ `attach()` or modifying search path
- ❌ `setwd()` in scripts (use `here::here()` or RStudio projects)
- ❌ Unnamed chunks in long pipelines (use intermediate variables)
- ❌ Polluting console with unnecessary `cat()`/`message()`
- ❌ ALL CAPS variable names (except R constants)
- ❌ Visual separators (`======`, `------`, `######`) in code

### 13.2 Package-Specific
- ❌ `library()` calls in `R/*.R` files (use `::` or roxygen2 imports)
- ❌ `global.R` in package structure
- ❌ Business logic inside Shiny modules (must be in `utils_*.R`)
- ❌ Passing reactive VALUES (`data()`) instead of EXPRESSIONS (`data`) between modules
- ❌ Silent failures in Shiny (always provide user feedback)

---

## 14. Workflow Summary

### For Analysis Scripts
1. Create header with metadata
2. Load packages at top
3. Use `here::here()` for paths
4. Write helper functions as needed (no roxygen2)
5. Keep it simple - one file if possible

### For Shiny Packages (following claude.md)
1. **Isolate Logic**: Write pure function in `utils_*.R`
2. **Test Logic**: Create unit test in `tests/testthat/`
3. **Build Module**: Create `mod_*.R` calling the pure function
4. **Wire UI**: Add module UI to `app_ui.R`
5. **Wire Server**: Call module in `app_server.R`
6. **Verify**: Run `devtools::check()` before commit

---

## 15. Decision Tree: When to Use What
```
Is this a standalone analysis/script?
├─ YES → Use simple header, helper functions OK, NO roxygen2
└─ NO → Is this a Shiny app?
    ├─ YES → Is it meant to be installed as a package?
    │   ├─ YES → Full package structure (claude.md)
    │   │         - DESCRIPTION with Imports
    │   │         - Roxygen2 for utils_*.R
    │   │         - Tests for all pure functions
    │   │         - NO global.R
    │   └─ NO → Simple shiny app (app.R + server.R + ui.R)
    │             - Can use library() at top
    │             - Optional global.R for static data
    └─ NO → Are you distributing reusable functions?
        ├─ YES → Create R package (full docs, tests)
        └─ NO → Keep as script collection
```

---

## 16. Compatibility Matrix

| Aspect | Solo Scripts | Shiny Packages (saira) | General R Packages |
|--------|--------------|------------------------|---------------------|
| Header | ✅ Mandatory | ✅ Mandatory | ✅ Optional (roxygen2 header) |
| roxygen2 | ❌ Never | ✅ For utils_*.R | ✅ For all exported functions |
| `library()` | ✅ At top | ❌ Never (use ::) | ❌ Never (use ::) |
| `global.R` | N/A | ❌ Prohibited | N/A |
| Tests | ⚠️ Optional | ✅ Mandatory for utils | ✅ Mandatory |
| DESCRIPTION | ❌ No | ✅ Yes | ✅ Yes |
| `here::here()` | ✅ Yes | ✅ Yes | ✅ Yes |
| Console output | ⚠️ Sparingly | ❌ Use shiny feedback | ⚠️ Sparingly |
| Visual separators | ❌ Never | ❌ Never | ❌ Never |

---

**Last Updated**: 2026-02-07  
**Compatibility**: 100% with `claude.md` v2.0 and `architecture.md` v2.0
