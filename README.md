# Saira - Biodiversity Data Standardization 🧬

**Saira** is a Shiny application designed to simplify the standardization of biodiversity datasets to the **Darwin Core (DwC)** standard. It provides a robust, user-friendly interface for researchers and institutions to validate, map, and verify taxonomic data, primarily focused on integration with the **SiBBr** (Sistema de Informação sobre a Biodiversidade Brasileira).

---

## ✨ Key Features

-   **Bilingual Interface**: Supporting both Portuguese (PT-BR) and English (EN-US).
-   **CSV/Excel Support**: Flexible data ingestion for common biodiversity formats.
-   **Interactive Mapping**: Intuitive UI (Rostrum Engine) for mapping local columns to Darwin Core terms.
-   **Taxonomic Verification**: Integration with taxonomic services for name validation.
-   **Data Validation**: Real-time checks for data types, mandatory fields, and coordinate ranges.
-   **Darwin Core Archive Export**: Generates compliant files ready for SiBBr/GBIF publication.

---

## 🚀 Getting Started

### Installation

**Requirements:** R >= 4.1.0.

Two of Saira's dependencies (`florabr`, `faunabr`) are published on the
rOpenSci R-universe, **not** on CRAN. `remotes::install_github()` does not read
the package's `Additional_repositories`, so add the R-universe to your `repos`
**before** installing, otherwise the install fails resolving those two
packages:

```r
# 1. Make CRAN + rOpenSci R-universe both visible:
options(repos = c(
  ropensci = "https://ropensci.r-universe.dev",
  CRAN     = "https://cloud.r-project.org"
))

# 2. Install Saira and all dependencies from GitHub:
# install.packages("remotes")
remotes::install_github("sibbr/saira")
```

**Linux system libraries:** the `sf` dependency needs GDAL, GEOS and PROJ.
Windows and macOS get prebuilt CRAN binaries (nothing to do); on
Debian/Ubuntu install them first:

```bash
sudo apt-get install -y libgdal-dev libgeos-dev libproj-dev libudunits2-dev
```

**First taxonomic check:** `taxadb` downloads a local taxonomic database on
first use (one-time, sizeable, needs network) — the first name-verification
run will take noticeably longer while it caches.

Coordinate validation ships with an embedded `10m` Natural Earth land mask for
the Americas, so `rnaturalearthhires` is optional (it is only in `Suggests`).
Datasets outside that coverage automatically fall back to the global `50m`
reference for the sea check; no extra installation is required for end users.

### Running the Application

```r
library(saira)
run_app()
```

### Development Setup

1.  Clone the repository:
    ```bash
    git clone https://github.com/sibbr/saira.git
    cd saira
    ```
2.  Restore the project library, then load the package and launch the app in R/RStudio:
    ```r
    if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
    renv::restore()
    pkgload::load_all()
    run_app()
    ```

### Running Tests

The commands below assume the project library has already been restored with `renv::restore()`.

```r
devtools::test()
```

Run a specific test file:

```r
devtools::test(filter = "rostrum-stage1")
```

Performance regression suite (disabled by default):

```bash
RUN_PERF=true Rscript -e "devtools::test(filter = 'performance')"
```

End-to-end tests (requires `shinytest2` and a browser):

```bash
RUN_E2E=true Rscript -e "devtools::test(filter = 'e2e')"
```

---

## 📖 Documentation

Detailed documentation can be found in the `docs/` directory:

-   [Architecture Overview](docs/architecture.md): Technical design and module structure.
-   [Design System](docs/design.md): UI/UX principles and component styles.
-   [Rostrum Engine](docs/rostrum_engine.md): Details on the data mapping core.
-   [Roadmap](docs/roadmap.md): Planned features and future vision.

---

## 🗺️ Roadmap

-   **Short-term**: Checklist generator, EML metadata helper, and mapping templates.
-   **Mid-term**: DwC compliance scoring, dataset merger, and analysis dashboards.
-   **Long-term**: Institutional template hub and direct IPT integration.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Built with ❤️ for biodiversity science.
