# Saira - Future Roadmap 🚀

This document outlines the strategic evolution of the **Saira** Biodiversity Data Standardization tool.

---

## 📅 Short-term (Next 2-4 Sprints)

### 1. Species List (Checklist) Generator 🧬
- **Objective**: Generate a "Checklist" (Taxon Core) from occurrences.
- **Details**: Collapse unique species, fetch higher taxonomy, and export in the SiBBr format.
- **Value**: Avoid manual Excel hacks to create species lists.

### 2. EML Metadata Helper (Basic) 📄
- **Objective**: Create the "companion" metadata file for the dataset.
- **Details**: A simple form to fill in Title, Abstract, Contacts, and Methods. Exports a companion text or JSON file (convertible to EML).
- **Value**: Completes the package for SiBBr publication (Data + Metadata).

### 3. Rostrum V3: Mapping Templates 🤖
- **Objective**: Implement the JSON template system.
- **Details**: "Save/Load Mapping" to lock institutional structures.
- **Value**: Reliability and zero-effort mapping for recurring data.

---

## 📊 Mid-term (Next 6-12 Months)

### 4. DwC Compliance Score (The "Grade") 🏆
- **Objective**: real-time feedback on data quality.
- **Details**: A progress indicator showing how many mandatory/recommended DwC fields are populated and valid.
- **Value**: Gamifies and guides the user toward better data standards.

### 5. Dataset Merger (Append Tool) 🧩
- **Objective**: Join multiple files into one DwC package.
- **Details**: Upload two CSVs, ensure they follow the same DwC mapping, and append them safely.
- **Value**: Consolidates fragmented digitalized collections.

### 6. Interactive Data Dashboard 📈
- **Objective**: A dedicated "Analysis" tab.
- **Details**: Maps, cluster visualization, and taxonomic distribution charts.
- **Value**: Immediate insight into the standardized dataset.

### 5. Outlier Detection Engine 📍
- **Objective**: Identify geographic and temporal anomalies.
- **Details**: 
  - Cross-check coordinates with `stateProvince` using `CoordinateCleaner`.
  - Detect dates outside of historical collector ranges.
- **Value**: automated scientific vetting.

### 7. Conversor de GMS para Decimal 📍
- **Objective**: Assist in digitizing legacy data.
- **Details**: A utility to convert Degrees, Minutes, Seconds (e.g., 23°30'S) to Decimal (-23.5) during the mapping or validation phase.
- **Value**: Extremely common pain point in herbarium/collection digitalization.

### 8. Relatório de Qualidade (PDF/HTML) 📄
- **Objective**: Offline data audit.
- **Details**: A downloadable report summarizing the "DwC Compliance Score", listing specific missing fields and coordinate outliers.
- **Value**: Formal documentation for curators and project leads.

---

## 🌐 Long-term (Vision)

### 9. Darwin Core Archive (DwC-A) Packager 📦
- **Objective**: Generate the "Gold Standard" of biodiversity data.
- **Details**: Instead of just a CSV, the app generates the full `.zip` containing `occurrence.txt`, `meta.xml`, and the `eml.xml`.
- **Value**: Professional-grade publication readiness.

### 10. Institutional Template Hub 🏛️
- **Objective**: A centralized cloud/local library of mapping templates.
- **Details**: Pre-configured templates for SiBBr, Reflora, INPA, and other major nodes.
- **Value**: Standards-as-a-service.

### 11. Direct API Integration (IPT Connector) 📡
- **Objective**: Push data directly to a repository.
- **Details**: Push standardized data and metadata to an IPT instance via API.
- **Value**: Seamless end-to-end biodiversity data workflows.
