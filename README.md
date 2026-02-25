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

### Prerequisites

You will need **R** and the following R packages installed:

```r
install.packages(c("shiny", "bslib", "readr", "stringr", "DT", "ids", "here", "jsonlite"))
```

### Running the Application

1.  Clone the repository:
    ```bash
    git clone https://github.com/rogerio-onza/saira.git
    cd saira
    ```
2.  Run the app in R/RStudio:
    ```r
    shiny::runApp()
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
