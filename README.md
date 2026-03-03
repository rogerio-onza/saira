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

```r
# Install from GitHub (development version)
# install.packages("remotes")
remotes::install_github("sibbr/saira")
```

For full coastal-detail coordinate validation, install the optional high-resolution
Natural Earth data (hosted on R-universe, not CRAN):

```r
install.packages("rnaturalearthhires", repos = "https://ropensci.r-universe.dev")
```

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
2.  Load the package and launch the app in R/RStudio:
    ```r
    pkgload::load_all()
    run_app()
    ```

### Running Tests

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
