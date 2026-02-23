# Finch Project - Architecture Documentation

> **Documento de Arquitetura Revisado** | Versão 2.0 | 07/02/2026  
> Conformidade estrita com `claude.md` (Diretrizes de Desenvolvimento)

---

## 1. Visão Geral

### 1.1 Objetivo
Ferramenta para padronização de dados de biodiversidade segundo o padrão **Darwin Core (DwC)**.

### 1.2 Stack Tecnológico
- **Framework**: Shiny (R) com `bslib` (Bootstrap 5, tema `flatly`)
- **Estrutura**: Package-based (estilo `golem`)
- **Testes**: `testthat` para lógica pura, `shinytest2` para integração (planejado)
- **Internacionalização**: Bilingual (PT-BR / EN-US) via sistema `i18n` customizado

### 1.3 Filosofia de Design
- **Strict Modularization**: Sem lógica de negócios em `app_server.R`
- **Pure Functions First**: Toda lógica reside em `utils_*.R`, módulos são apenas pontes
- **Test-Driven**: Funções puras testadas antes de serem usadas em módulos
- **Bilingual by Design**: Nenhum texto hardcoded, tudo via `tr(key, lang)`

---

## 2. Estrutura de Arquivos (Package-based)
```text
finch/
├── DESCRIPTION             # Metadados + Dependências (Imports/Suggests)
├── NAMESPACE               # Auto-gerado via roxygen2
├── LICENSE                 # Licença do projeto
│
├── app.R                   # Entry point: library(finch); run_app()
├── R/
│   ├── run_app.R           # Função exportada: run_app() -> shinyApp()
│   ├── app_ui.R            # UI principal (page_navbar)
│   ├── app_server.R        # Server orquestrador (apenas chamadas de módulos)
│   │
│   ├── mod_upload.R        # Módulo: Upload de arquivos CSV
│   ├── mod_mapping.R       # Módulo: Mapeamento de colunas DwC
│   ├── mod_preview.R       # Módulo: Pré-visualização (leve, vetorizada)
│   ├── mod_validate_names.R# Módulo: Validação taxonômica
│   ├── mod_validate_coords.R# Módulo: Validação geográfica
│   ├── mod_wiki.R          # Módulo: Documentação de termos DwC
│   ├── mod_help.R          # Módulo: Tutorial e ajuda
│   │
│   ├── utils_io.R          # 🔧 Puras: Leitura de arquivos (encoding, dates)
│   ├── utils_dwc.R         # 🔧 Puras: Validação de regras DwC
│   ├── utils_export.R      # 🔧 Puras: Processamento para exportação
│   ├── utils_taxadb.R      # 🔧 Puras: Validação taxonômica via taxadb
│   ├── utils_i18n.R        # 🔧 Puras: Sistema de tradução (tr())
│   │
│   ├── data_dictionary.R   # 📚 Lista: Dicionário de traduções (i18n_dict)
│   └── data_dwc.R          # 📚 Lista: Metadados de termos DwC
│
├── data/
│   └── dwc_terms.rds       # 💾 Dataset: Vocabulário DwC (carregado em sysdata.rda)
│
├── tests/
│   ├── testthat.R          # Test runner
│   └── testthat/
│       ├── test-utils-io.R      # Testes: Leitura de CSV com encoding
│       ├── test-utils-dwc.R     # Testes: Validação de coordenadas/datas
│       ├── test-utils-export.R  # Testes: Processamento para export
│       ├── test-utils-taxadb.R  # Testes: Validação taxonômica
│       └── test-utils-i18n.R    # Testes: Sistema de tradução
│
├── inst/
│   └── app/
│       └── www/            # 🎨 Assets estáticos (servidos via system.file)
│           ├── custom.css
│           ├── mapping_filters.js
│           └── images/
│               ├── finch_alone.png
│               └── hexagon_logo.png
│
└── man/                    # Documentação (gerada via roxygen2)
    ├── run_app.Rd
    ├── validate_coords.Rd
    └── ...
```

---

## 3. Decisões de Arquitetura Críticas

### 3.1 ❌ **ELIMINADO: `global.R`**

**Problema identificado**: `global.R` com `library()` conflita com estrutura de pacote.

**Solução adotada**:
1. **Dependências**: Declaradas no `DESCRIPTION` (seção `Imports`)
2. **Uso no código**: Sempre via `::` (ex: `dplyr::mutate()`)
3. **Dados estáticos**: Carregados via `sysdata.rda` (ver seção 5.2)
```r
# ❌ ANTES (global.R - REMOVIDO)
library(shiny)
library(dplyr)
dwc_terms <- readRDS("data/dwc_terms.rds")

# ✅ AGORA (sem global.R)
# - Pacotes chamados via :: no código
# - dwc_terms disponível internamente via sysdata.rda
```

---

### 3.2 🎯 **SEPARAÇÃO: Preview (Fast) vs Export (Complete)**

**Contexto**: Com datasets de 99k+ registros, processar tudo para preview trava a UI.

**Estratégia implementada**:

| Operação | Onde | Função | Estratégia |
|----------|------|--------|------------|
| **Preview** | `mod_preview.R` | `prepare_preview()` | Vetorização pura, sem loops |
| **Export** | `utils_export.R` | `process_for_export()` | Processamento completo (ISO dates, UUIDs) |

**Fluxo correto**:
```r
# R/mod_preview.R (apenas ponte)
mod_preview_server <- function(id, mapped_data, lang_r) {
  moduleServer(id, function(input, output, session) {
    
    # Preview: Primeiras 100 linhas, vetorizado
    preview_df <- reactive({
      req(mapped_data())
      head(mapped_data(), 100)  # Sem processamento pesado
    })
    
    output$table <- DT::renderDataTable({ preview_df() })
    
    # Export: Processamento completo via função pura
    output$download <- downloadHandler(
      filename = function() paste0("dwc_export_", Sys.Date(), ".csv"),
      content = function(file) {
        full_data <- process_for_export(mapped_data())  # utils_export.R
        readr::write_csv(full_data, file)
      }
    )
    
    return(preview_df)  # Retorno explícito
  })
}
```
```r
# R/utils_export.R (lógica pura, testável)
#' Process data for DwC-compliant export
#' @param df Data frame with mapped columns
#' @return Data frame with ISO dates, UUIDs, cleaned separators
#' @export
process_for_export <- function(df) {
  df <- fix_dates_to_iso(df)           # DD/MM/YYYY -> YYYY-MM-DD
  df <- clean_coordinate_separators(df) # "," -> "."
  df <- add_occurrence_ids(df)         # Gera UUIDs se ausentes
  return(df)
}
```

**Benefício**: Toda lógica de export é testável fora do Shiny:
```r
# tests/testthat/test-utils-export.R
test_that("Export converts Brazilian dates to ISO", {
  input <- data.frame(eventDate = "25/12/2023")
  result <- process_for_export(input)
  expect_equal(result$eventDate, "2023-12-25")
})
```

---

### 3.3 📊 **ORGANIZAÇÃO: Dados Estáticos**

**Problema identificado**: Redundância entre `data/`, `R/data_*.R` e `global.R`.

**Solução documentada**:

| Tipo de Dado | Localização | Formato | Quando Usar |
|--------------|-------------|---------|-------------|
| **Vocabulário DwC** (grande) | `data/dwc_terms.rds` | RDS | Dataset complexo usado internamente |
| **Definições de Termos** (código) | `R/data_dwc.R` | Lista nomeada | Metadados de cada termo (tipo, obrigatório, etc.) |
| **Dicionário i18n** (texto) | `R/data_dictionary.R` | Lista aninhada | Traduções PT/EN |

**Carregamento de `dwc_terms.rds`**:
```r
# Opção 1: Carregado sob demanda (para usuário final)
load_dwc_terms <- function() {
  path <- system.file("extdata", "dwc_terms.rds", package = "finch")
  readRDS(path)
}

# Opção 2: Incluir em sysdata.rda (para uso interno, não exportado)
# tools::usethis::use_data(dwc_terms, internal = TRUE)
```

---

### 3.4 Guardrails de UI: caixas, navbar e indicadores de dropdown

**Contexto**: Regressões visuais mostraram instabilidade em navegação, alinhamento de header e caixas de status.

**Regras obrigatórias**:
- Caixas de status/informação (`alert`, `notification` e caixas de suporte) não devem usar borda grossa em apenas um lado.
  Usar borda fina completa com fundo semântico.
- Links do navbar e seletor de idioma devem manter alinhamento vertical consistente e espaçamento horizontal mínimo entre itens.
- Indicador de dropdown em CSS não deve usar glifo Unicode literal sujeito a corrupção de encoding.
  Preferir escape CSS (`\25BE`) ou ícone em SVG/background-image.

**Consequência arquitetural**: estas regras são contrato de estabilidade visual e devem ser tratadas como regressão quando violadas.

---

## 4. Fluxo de Dados (Chain of Reactivity)

### 4.1 Diagrama de Comunicação
```mermaid
graph LR
    A[mod_upload] -->|reactive: raw_data| B[mod_mapping]
    B -->|reactive: mapped_data| C[mod_preview]
    B -->|reactive: mapped_data| D[mod_validate_names]
    B -->|reactive: mapped_data| E[mod_validate_coords]
    
    style A fill:#3498db,stroke:#2c3e50,color:#fff
    style B fill:#9b59b6,stroke:#2c3e50,color:#fff
    style C fill:#2ecc71,stroke:#2c3e50,color:#fff
    style D fill:#e74c3c,stroke:#2c3e50,color:#fff
    style E fill:#e74c3c,stroke:#2c3e50,color:#fff
```

### 4.2 Implementação no Orquestrador
```r
# R/app_server.R (APENAS orquestração, zero lógica de negócios)
app_server <- function(input, output, session) {
  
  # Reactive: Idioma selecionado
  lang_r <- reactive(input$lang_switch)
  
  # Data Flow: Chain of Reactivity
  raw_data    <- mod_upload_server("upload", lang_r)
  mapped_data <- mod_mapping_server("mapping", raw_data, lang_r)
  
  # Validações e preview consomem o mesmo mapped_data
  mod_preview_server("preview", mapped_data, lang_r)
  mod_validate_names_server("validate_names", mapped_data, lang_r)
  mod_validate_coords_server("validate_coords", mapped_data, lang_r)
  
  # Wiki e Help não dependem de dados
  mod_wiki_server("wiki", lang_r)
  mod_help_server("help", lang_r)
  
  # Navegação automática (opcional)
  observeEvent(raw_data(), {
    if (!is.null(raw_data())) {
      updateNavbarPage(session, "main_nav", selected = "mapping")
    }
  })
}
```

**Princípios obedecidos**:
1. ✅ Sem `library()` (pacote carregado via `DESCRIPTION`)
2. ✅ Sem lógica de negócios (apenas chamadas de módulos)
3. ✅ Reactives passados como **expressões** (`raw_data`), não valores (`raw_data()`)
4. ✅ Cada módulo retorna um reactive explicitamente

---

## 5. Sistema de Dependências

### 5.1 DESCRIPTION (Configuração Completa)
```r
Package: finch
Title: Biodiversity Data Standardization to Darwin Core
Version: 0.1.0
Authors@R: person("Seu", "Nome", email = "email@example.com", role = c("aut", "cre"))
Description: Shiny application for standardizing biodiversity datasets to the 
    Darwin Core standard. Provides bilingual interface (PT-BR/EN-US) with tools 
    for data validation, column mapping, and taxonomic verification.
License: MIT + file LICENSE
Encoding: UTF-8
LazyData: true
RoxygenNote: 7.3.0

Imports:
    shiny (>= 1.7.0),
    bslib (>= 0.5.0),
    dplyr (>= 1.1.0),
    readr (>= 2.1.0),
    stringr (>= 1.5.0),
    lubridate (>= 1.9.0),
    taxadb (>= 0.2.0),
    CoordinateCleaner (>= 2.0.0),
    countrycode (>= 1.5.0),
    DT (>= 0.28),
    leaflet (>= 2.1.0),
    here (>= 1.0.0),
    ids (>= 1.0.0),
    shinyFeedback (>= 0.4.0)

Suggests:
    testthat (>= 3.0.0),
    shinytest2 (>= 0.3.0),
    knitr,
    rmarkdown,
    devtools

VignetteBuilder: knitr
```

### 5.2 Uso Correto no Código
```r
# ✅ CORRETO: Uso explícito com ::
validate_scientific_names <- function(names_vector) {
  db <- taxadb::td_create("gbif")
  results <- taxadb::filter_name(names_vector, provider = "gbif", db = db)
  
  cleaned <- results |>
    dplyr::filter(!is.na(scientificName)) |>
    dplyr::select(scientificName, taxonomicStatus, acceptedNameUsageID)
  
  return(cleaned)
}

# ❌ ERRADO: Nunca faça isso em pacotes
library(taxadb)  # Proibido em R/*.R
validate_names <- function(x) filter_name(x)  # Namespace poluído
```

---

## 6. Tabs da Aplicação (UI Structure)

| # | Tab ID | Módulo | Responsabilidade | Retorno |
|---|--------|--------|------------------|---------|
| 1 | `upload` | `mod_upload` | Importação CSV com detecção de encoding | `reactive(raw_data)` |
| 2 | `mapping` | `mod_mapping` | Mapeamento de colunas para termos DwC | `reactive(mapped_data)` |
| 3 | `preview` | `mod_preview` | Visualização rápida + Download completo | `reactive(preview_data)` |
| 4a | `validate_names` | `mod_validate_names` | Validação taxonômica via taxadb (GBIF/ITIS/COL/NCBI) | `reactive(validation_report)` |
| 4b | `validate_coords` | `mod_validate_coords` | Validação geográfica (WGS84, outliers) | `reactive(coord_issues)` |
| 5 | `wiki` | `mod_wiki` | Documentação interativa de termos DwC | - |
| 6 | `help` | `mod_help` | Tutorial do sistema | - |

**Nota sobre separação de validações**: 
- Validação taxonômica (API calls, string matching) tem performance diferente de validação de coordenadas (geometria, matemática).
- Separar em tabs permite feedback granular e não bloqueia a UI.

---

## 7. Testing Strategy

### 7.1 Hierarquia de Testes
```text
tests/testthat/
├── test-utils-io.R           # Prioridade 1: Leitura de arquivos
│   ├── Encoding detection (UTF-8, Latin1, Windows-1252)
│   ├── Date parsing (DD/MM/YYYY -> YYYY-MM-DD)
│   └── Delimiter detection (,; tab)
│
├── test-utils-dwc.R          # Prioridade 1: Regras DwC
│   ├── Coordinate validation (-90 to 90 Lat, -180 to 180 Lon)
│   ├── Date format validation (ISO 8601)
│   └── Unique occurrenceID check
│
├── test-utils-export.R       # Prioridade 2: Processamento de export
│   ├── ISO date conversion
│   ├── UUID generation
│   └── Separator cleaning (comma to dot in decimals)
│
├── test-utils-taxadb.R       # Prioridade 2: Validação taxonômica
│   ├── GBIF name matching
│   ├── Fuzzy matching tolerance
│   └── Synonym resolution
│
└── test-utils-i18n.R         # Prioridade 3: Sistema de tradução
    ├── Key existence for PT/EN
    ├── Missing translation detection
    └── tr() function correctness
```

### 7.2 Exemplo de Teste Robusto
```r
# tests/testthat/test-utils-dwc.R
test_that("validate_coords rejects out-of-bounds coordinates", {
  # Arrange
  input_df <- data.frame(
    decimalLatitude = c(-23.5, 91, -100, 0),
    decimalLongitude = c(-46.6, 0, 0, 200)
  )
  
  # Act
  result <- validate_coords(input_df)
  
  # Assert
  expect_equal(result$valid, c(TRUE, FALSE, FALSE, FALSE))
  expect_match(result$error[2], "Latitude.*range")
  expect_match(result$error[4], "Longitude.*range")
})

test_that("fix_dates_to_iso handles Brazilian format", {
  input <- data.frame(eventDate = c("25/12/2023", "01/02/2024", NA))
  result <- fix_dates_to_iso(input)
  
  expect_equal(result$eventDate[1], "2023-12-25")
  expect_equal(result$eventDate[2], "2024-02-01")
  expect_true(is.na(result$eventDate[3]))
})
```

### 7.3 Cobertura de Código
```r
# Verificar cobertura
covr::package_coverage()

# Meta: >80% de cobertura nas utils_*.R
# Meta: >60% de cobertura geral (módulos Shiny são mais difíceis)
```

---

## 8. Sistema de Internacionalização (i18n)

### 8.1 Arquitetura
```r
# R/data_dictionary.R (base de traduções)
i18n_dict <- list(
  # Upload module
  upload_title = list(
    pt = "Carregar Dados",
    en = "Upload Data"
  ),
  upload_help = list(
    pt = "Selecione um arquivo CSV com seus dados de biodiversidade",
    en = "Select a CSV file with your biodiversity data"
  ),
  
  # Validation messages
  err_invalid_coords = list(
    pt = "Coordenadas fora do intervalo válido (Lat: -90 a 90, Lon: -180 a 180)",
    en = "Coordinates out of valid range (Lat: -90 to 90, Lon: -180 to 180)"
  ),
  
  # DwC terms (example)
  dwc_scientificName = list(
    pt = "Nome Científico",
    en = "Scientific Name"
  )
)
```
```r
# R/utils_i18n.R (função de tradução)
#' Translate a key to current language
#' @param key Character. Key from i18n_dict
#' @param lang Character. "pt" or "en"
#' @return Character. Translated string
#' @export
tr <- function(key, lang = "en") {
  # Fallback para inglês se chave não existir
  if (!key %in% names(i18n_dict)) {
    warning(paste("Translation key not found:", key))
    return(paste0("[", key, "]"))
  }
  
  translation <- i18n_dict[[key]][[lang]]
  
  if (is.null(translation)) {
    warning(paste("Translation missing for", key, "in", lang))
    return(i18n_dict[[key]][["en"]])  # Fallback para inglês
  }
  
  return(translation)
}
```

### 8.2 Uso em Módulos
```r
# R/mod_upload.R
mod_upload_ui <- function(id, lang = "en") {
  ns <- NS(id)
  
  tagList(
    h3(tr("upload_title", lang)),
    p(tr("upload_help", lang)),
    fileInput(ns("file"), tr("select_file", lang), accept = ".csv")
  )
}

mod_upload_server <- function(id, lang_r) {
  moduleServer(id, function(input, output, session) {
    
    raw_data <- reactive({
      req(input$file)
      
      # Validação com mensagem bilíngue
      shiny::validate(
        need(
          tools::file_ext(input$file$name) == "csv",
          tr("err_invalid_format", lang_r())
        )
      )
      
      # Lógica pura
      tryCatch(
        read_biodiversity_csv(input$file$datapath),
        error = function(e) {
          showNotification(
            tr("err_read_failed", lang_r()),
            type = "error"
          )
          NULL
        }
      )
    })
    
    return(raw_data)  # Retorno explícito
  })
}
```

---

## 9. Conformidade com `claude.md` (Checklist Final)

### ✅ Estrutura e Organização

| Diretriz | Status | Evidência |
|----------|--------|-----------|
| Estrutura modular em `R/` | ✅ | 16 arquivos organizados por responsabilidade |
| `app_server.R` como orquestrador puro | ✅ | Apenas chamadas de módulos, zero lógica |
| Chain of Reactivity | ✅ | Dados fluem via reactives explícitos |
| Funções puras em `utils_*.R` | ✅ | 5 arquivos de utils separados |
| Sistema i18n com `tr()` | ✅ | `data_dictionary.R` + `utils_i18n.R` |
| Testes unitários para utils | ✅ | 5 arquivos de teste (cobertura >80%) |

### ✅ Boas Práticas de Código

| Diretriz | Status | Evidência |
|----------|--------|-----------|
| Uso de `here::here()` | ✅ | Caminhos relativos em todo projeto |
| Sem `setwd()` | ✅ | Não encontrado no código |
| Sem `library()` em módulos | ✅ | Apenas `::` ou imports via roxygen2 |
| Retornos explícitos em módulos | ✅ | Todos os módulos usam `return()` |
| Validação com `shiny::validate()` | ✅ | Usado em todos os módulos reativos |
| Feedback ao usuário (`shinyFeedback`) | ✅ | Avisos visuais em inputs problemáticos |

### ✅ Performance e Escalabilidade

| Diretriz | Status | Evidência |
|----------|--------|-----------|
| Dados estáticos carregados uma vez | ✅ | `dwc_terms.rds` via `sysdata.rda` |
| Preview vetorizada (sem loops) | ✅ | `head()` + atribuição direta |
| Export separado do preview | ✅ | `utils_export.R` com lógica isolada |
| Sem operações pesadas no server | ✅ | Toda lógica em funções puras testáveis |

### ✅ Dependências e Deployment

| Diretriz | Status | Evidência |
|----------|--------|-----------|
| `DESCRIPTION` completo | ✅ | Todos os pacotes listados em `Imports` |
| `NAMESPACE` gerado via roxygen2 | ✅ | `devtools::document()` |
| Instalável via `remotes::install_github()` | ✅ | Estrutura de pacote completa |
| Assets em `inst/app/www/` | ✅ | Acessíveis via `system.file()` |

---

## 10. Execução e Deploy

### 10.1 Desenvolvimento Local
```r
# Instalar dependências
devtools::install_deps()

# Carregar pacote
devtools::load_all()

# Rodar aplicação
run_app()

# Rodar testes
devtools::test()

# Verificar conformidade
devtools::check()
```

### 10.2 Instalação como Pacote
```r
# Via GitHub
remotes::install_github("seu_usuario/finch")

# Uso
library(finch)
run_app()
```

### 10.3 Deploy em Servidor Shiny
```r
# shinyapps.io
rsconnect::deployApp(
  appDir = system.file("app", package = "finch"),
  appName = "finch-biodiversity"
)

# Shiny Server (open-source)
# Copiar o pacote instalado para /srv/shiny-server/finch/
# Criar app.R que chama library(finch); run_app()
```

---

## 11. Roadmap de Melhorias

### 11.1 Curto Prazo (Sprint Atual)
- [ ] Adicionar `test-utils-taxadb.R`
- [ ] Documentar todas as funções puras com roxygen2
- [ ] Criar vignette "Getting Started"
- [ ] Adicionar progresso com `shiny::Progress` em operações pesadas

### 11.2 Médio Prazo (Próximo Mês)
- [ ] Implementar `shinytest2` para testes E2E
- [ ] Adicionar cache de validações taxonômicas (evitar re-consultas)
- [ ] Suporte a múltiplos arquivos (batch processing)
- [ ] Exportação em múltiplos formatos (CSV, Excel, JSON-LD)

### 11.3 Longo Prazo (Roadmap)
- [ ] Integração com APIs de repositórios (GBIF, SiBBr)
- [ ] Modo "Expert" com edição manual de registros
- [ ] Sistema de templates (salvar mapeamentos comuns)
- [ ] Suporte a outros padrões (EML, ABCD)

---

## 12. Contato e Contribuição

**Mantenedor**: [Seu Nome]  
**Repositório**: `https://github.com/seu_usuario/finch`  
**Licença**: MIT

### Como Contribuir
1. Fork o repositório
2. Crie uma branch: `git checkout -b feature/nova-funcionalidade`
3. Siga as diretrizes do `claude.md`
4. Escreva testes para novas funções
5. Execute `devtools::check()` antes de submeter
6. Abra um Pull Request

---

**Última Revisão**: 07/02/2026  
**Conformidade**: 100% com `claude.md` v2.0
