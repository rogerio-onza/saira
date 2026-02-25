# 🐦 Saira — Auditoria de Segurança e Arquitetura

> **Data**: 2026-02-13 | **Baseado em**: `claude.md`, `architecture.md`, `skill.md`

---

## 1. Verificação de Estrutura e Modularização

### 1.1 ❌ CRÍTICO: `source()` em todo o código — Anti-padrão em Pacote R

**Problema**: Todos os 7 módulos, `app_server.R` e `app_ui.R` usam `source(here::here("R", ...))` para carregar dependências internas. São **26 chamadas `source()`** espalhadas pelo código.

**Regra violada**: `architecture.md` §3.1 — "Dependências declaradas no DESCRIPTION, uso via `::` ". Em pacote R, todos os arquivos em `R/` são carregados automaticamente pelo namespace via `pkgload::load_all()` ou `devtools::load_all()`.

**Arquivos afetados**: Todos os `mod_*.R`, `app_server.R`, `app_ui.R`, `utils_i18n.R`

**Solução**: Remover todas as chamadas `source()`. O `pkgload::load_all()` no `app.R` já carrega tudo.

```diff
# R/mod_upload.R (e TODOS os outros módulos)
 mod_upload_server <- function(id, lang_r) {
     shiny::moduleServer(id, function(input, output, session) {
         ns <- session$ns
-        source(here::here("R", "data_dictionary.R"), local = TRUE)
-        source(here::here("R", "utils_i18n.R"), local = TRUE)
-        source(here::here("R", "utils_io.R"), local = TRUE)
-        source(here::here("R", "utils_dwc.R"), local = TRUE)
+        # Functions available via package namespace (pkgload::load_all)
```

---

### 1.2 ⚠️ `app_server.R` contém lógica de UI (não é orquestrador puro)

**Problema**: [app_server.R](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/app_server.R) (L25-55) contém **8 blocos `renderUI()`** para títulos de navegação. Isso é lógica de apresentação, não orquestração.

**Regra violada**: `claude.md` §8 — "app_server.R (APENAS orquestração, zero lógica de negócios)". `architecture.md` §4.2 — "APENAS chamadas de módulos".

**Solução**: Mover os títulos de navegação dinâmicos para um mini-módulo `mod_nav_titles` ou resolvê-los na UI via `uiOutput` gerenciado por `app_ui.R`.

### 1.3 ⚠️ Hardcoded string na navegação de validação

**Arquivo**: [app_server.R:38](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/app_server.R#L38)

```r
# ❌ Hardcoded (não usa i18n)
output$nav_validate_title <- shiny::renderUI({
    shiny::tags$span("Validação")
})
```

**Regra violada**: `claude.md` §9.4 — "Never hardcode text. Use `tr(key, lang())`."

**Solução**:
```r
output$nav_validate_title <- shiny::renderUI({
    shiny::tags$span(tr("nav_validate", lang_r()))
})
```

### 1.4 ⚠️ Hardcoded string na tab "Início"

**Arquivo**: [app_ui.R:65](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/app_ui.R#L65)

```r
# ❌ Hardcoded
shiny::icon("home", class = "fa-solid"),
" Início"
```

**Solução**: Usar `shiny::uiOutput("nav_upload_title")` como nas outras tabs.

---

### 1.5 ⚠️ `<<-` usado em `utils_mapping.R`

**Arquivo**: [utils_mapping.R:825](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/utils_mapping.R#L825)

```r
used[idx[1]] <<- TRUE  # Dentro de pick_first(), closure interna
```

**Regra violada**: `claude.md` §8 — "Avoid `<<-`". Embora seja em closure local (não cross-module), o padrão pode ser refatorado.

**Solução**:
```r
detect_eventdate_roles <- function(col_names) {
    # Usar um environment explícito em vez de <<-
    state <- new.env(parent = emptyenv())
    state$used <- rep(FALSE, length(col_names))
    
    pick_first <- function(mask) {
        idx <- which(mask & !state$used)
        if (length(idx) == 0) return(NA_integer_)
        state$used[idx[1]] <- TRUE
        idx[1]
    }
    # ... rest of function
}
```

---

### 1.6 🔴 Lógica de negócios massiva em `mod_mapping.R`

**Problema**: [mod_mapping.R](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_mapping.R) tem **1365 linhas** e contém lógica de negócios significativa que deveria estar em `utils_mapping.R`:

| Lógica | Linhas | Deveria estar em |
|--------|--------|------------------|
| `sanitize_map_selection()` | 163-182 | `utils_mapping.R` |
| `has_selected_value()` | 159-161 | `utils_mapping.R` |
| `empty_map_values()` / `empty_map_meta()` | 184-199 | `utils_mapping.R` |
| `build_badge_info()` | 219-257 | `utils_mapping.R` |
| `reason_key_from_code()` | 201-217 | `utils_mapping.R` |
| Processamento completo do `processed_data` | 1222-1359 | `utils_mapping.R` |

**Regra violada**: `claude.md` §4.1 — "Write the feature as a pure function in `utils_*.R`". `skill.md` §5.2.2 — "Business logic: `R/utils_*.R` (pure functions, zero Shiny dependencies)".

**Impacto**: A lógica em `processed_data` reactive (~140 linhas) é intestável fora do Shiny.

---

## 2. Detecção de Redundância e Lógica Duplicada

### 2.1 ⚠️ `load_dwc_terms_rds()` chamada repetidamente

**Problema**: A função `load_dwc_terms_rds()` em [utils_dwc.R](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/utils_dwc.R) faz I/O (lê `readRDS()`) e é chamada por:
- `get_dwc_terms()` (L73-75)
- `get_required_dwc_terms()` (L81-83)
- `get_dwc_terms_list()` (L94-126)
- `mod_wiki.R` via `get_dwc_terms()`
- `mod_upload.R` via `get_required_dwc_terms()`
- `mod_mapping.R` via `get_dwc_terms_list()` (em reactive, chamada a cada mudança de idioma)

**Solução**: Cachear o resultado com memoização:

```r
.dwc_terms_cache <- NULL
load_dwc_terms_rds <- function(force = FALSE) {
    if (is.null(.dwc_terms_cache) || isTRUE(force)) {
        # ... existing path resolution ...
        .dwc_terms_cache <<- readRDS(path)
    }
    .dwc_terms_cache
}
```

### 2.2 ⚠️ `parse_dates_to_iso()` em `utils_io.R` vs `fix_dates_to_iso()` em `utils_export.R`

**Sobreposição**: Ambas funções convertem datas de formatos brasileiros para ISO 8601:

| Função | Arquivo | Escopo |
|--------|---------|--------|
| `parse_dates_to_iso()` | `utils_io.R:121-154` | Vetor de strings |
| `fix_dates_to_iso()` | `utils_export.R:85-134` | DataFrame inteiro |

Ambas tentam os mesmos formatos (`%d/%m/%Y`, `%d-%m-%Y`), mas com implementações diferentes.

**Solução**: Manter `parse_dates_to_iso()` como função básica vetorizada e reescrever `fix_dates_to_iso()` para usá-la internamente:

```r
fix_dates_to_iso <- function(df) {
    date_cols <- c("eventDate", "dateIdentified", "modified")
    for (col in date_cols) {
        if (col %in% names(df)) {
            df[[col]] <- parse_dates_to_iso(df[[col]])
        }
    }
    return(df)
}
```

### 2.3 ⚠️ Lógica de validação de coordenadas duplicada

`validate_coords()` em `utils_dwc.R` converte vírgulas com `gsub(",", ".")`, e `clean_coordinate_separators()` em `utils_export.R` faz o mesmo. A limpeza ocorre duas vezes no fluxo de export.

---

## 3. Auditoria de Padrões e Segurança

### 3.1 ✅ Headers obrigatórios

Todos os 16 arquivos `.R` possuem o header obrigatório conforme `skill.md` §1:
```r
# Title: [...]
# Author: Rogério Nunes Oliveira
# Date: [YYYY-MM-DD]
# Version: [X.X]
```

### 3.2 ✅ Sem `library()` dentro de `R/`

Nenhuma chamada `library()` encontrada nos arquivos de `R/`.

### 3.3 ✅ Sem `setwd()` ou caminhos absolutos

Nenhuma chamada `setwd()` encontrada.

### 3.4 ⚠️ Dependências ausentes no DESCRIPTION

| Pacote usado | Onde | No DESCRIPTION? |
|-------------|------|-----------------|
| `jsonlite` | `mod_mapping.R:430` (`jsonlite::toJSON`) | ❌ **Ausente** |
| `utils` | `mod_mapping.R:1153` (`utils::tail`) | ❌ **Implícito** (base) |
| `tools` | `mod_upload.R:304` (`tools::file_ext`) | ❌ **Implícito** (base) |

**Solução**: Adicionar `jsonlite` ao `Imports` do `DESCRIPTION`:
```
Imports:
    ...
    jsonlite (>= 1.8.0),
```

### 3.5 ⚠️ Tratamento de erros incompleto em módulos de validação

**Arquivo**: [mod_validate_names.R:78-83](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_validate_names.R#L78)

```r
# ❌ Hardcoded bilingual strings (não usa tr())
shiny::showNotification(
    if (lang_r() == "pt") {
        "Coluna 'scientificName' não encontrada. Mapeie primeiro."
    } else {
        "'scientificName' column not found. Map it first."
    },
    type = "warning"
)
```

**O mesmo problema** em [mod_validate_coords.R:82-86](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_validate_coords.R#L82) e [mod_validate_names.R:159](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_validate_names.R#L159) e [mod_validate_coords.R:156](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_validate_coords.R#L156).

**Regra violada**: `claude.md` §9.4 — "Never hardcode text."

**Solução**: Adicionar chaves ao `data_dictionary.R` e usar `tr()`:
```r
shiny::showNotification(tr("err_no_scientific_name", lang_r()), type = "warning")
```

### 3.6 ⚠️ Hardcoded strings em `mod_help.R`

**Arquivo**: [mod_help.R:59-155](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_help.R#L59)

Todo o conteúdo de ajuda usa blocos `if (is_pt) { shiny::HTML("...") } else { shiny::HTML("...") }` com texto embutido no código. Isso viola `claude.md` §9.4 mas é um caso pragmático dado o volume de HTML. **Recomendação**: Mover para o dicionário i18n progressivamente ou manter como exceção documentada.

### 3.7 ⚠️ Hardcoded strings em `mod_wiki.R`

**Arquivo**: [mod_wiki.R:28-29](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_wiki.R#L28)

```r
placeholder = "Buscar termo..."  # ❌ Hardcoded em português
```

E também as `choices` do filtro de classes (L38-44) são hardcoded em português.

### 3.8 ⚠️ Hardcoded placeholder em `mod_mapping.R`

**Arquivo**: [mod_mapping.R:891](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_mapping.R#L891)

```r
placeholder = "Ex: Meu Dataset de Biodiversidade"  # ❌ Hardcoded em PT
```

### 3.9 ⚠️ Hardcoded strings no DT de `mod_preview.R`

**Arquivo**: [mod_preview.R:103-109](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_preview.R#L103)

```r
# ❌ Strings inline em vez de tr()
lengthMenu = paste(
    if (lang_r() == "pt") "Mostrar _MENU_ registros" else "Show _MENU_ entries"
),
info = if (lang_r() == "pt") {
    "Mostrando _START_ a _END_ de _TOTAL_ registros"
} else {
    "Showing _START_ to _END_ of _TOTAL_ entries"
}
```

---

## 4. Otimização de Performance

### 4.1 🔴 `sapply()` com loop element-wise em `fix_dates_to_iso()`

**Arquivo**: [utils_export.R:91](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/utils_export.R#L91)

```r
df[[col]] <- sapply(df[[col]], function(x) { ... })
```

**Regra violada**: `skill.md` §7.2 — "Avoid `apply(..., 1, ...)` or `sapply()` in reactive contexts."

Com 99k+ registros, `sapply()` aplicando `as.Date()` + `tryCatch()` em cada elemento será lento.

**Solução**: Vetorizar usando `parse_dates_to_iso()` de `utils_io.R` (ver seção 2.2) ou `lubridate::parse_date_time()`:

```r
fix_dates_to_iso <- function(df) {
    date_cols <- c("eventDate", "dateIdentified", "modified")
    for (col in date_cols) {
        if (col %in% names(df)) {
            df[[col]] <- parse_dates_to_iso(df[[col]])
        }
    }
    return(df)
}
```

### 4.2 ⚠️ `for` loop em `parse_dates_to_iso()` de `utils_io.R`

**Arquivo**: [utils_io.R:133](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/utils_io.R#L133)

O loop `for (i in seq_along(...))` com `for (fmt in formats)` internamente é O(n × m). Pode ser vetorizado:

```r
parse_dates_to_iso <- function(date_vector) {
    result <- rep(NA_character_, length(date_vector))
    remaining <- !is.na(date_vector) & date_vector != ""
    
    formats <- c("%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d", "%d/%m/%y", "%d.%m.%Y")
    
    for (fmt in formats) {
        if (!any(remaining)) break
        parsed <- as.Date(date_vector[remaining], format = fmt)
        success <- !is.na(parsed)
        idx <- which(remaining)[success]
        result[idx] <- format(parsed[success], "%Y-%m-%d")
        remaining[idx] <- FALSE
    }
    
    return(result)
}
```

### 4.3 ⚠️ `for` loop em `build_eventdate_interval()`

**Arquivo**: [utils_mapping.R:916](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/utils_mapping.R#L916)

O loop `for (i in seq_len(nrow(df)))` pode ser parcialmente vetorizado com `vapply()` e vetorização dos campos month/year.

### 4.4 ✅ Preview é eficiente

[mod_preview.R:72](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_preview.R#L72) usa `head(mapped_data_r(), 100)` conforme prescrito por `architecture.md` §3.2.

### 4.5 ⚠️ `dwc_terms.rds` recarregado dentro de reactive

**Arquivo**: [mod_mapping.R:151-153](file:///c:/Users/Admin/OneDrive/Saira%20-%20Claude/saira/R/mod_mapping.R#L151)

```r
dwc_all <- shiny::reactive({
    get_dwc_terms_list(lang_r())  # Recarrega .rds do disco a cada mudança de idioma
})
```

O `.rds` é lido do disco a cada mudança `pt ↔ en`. Como o RDS é estático, deveria ser carregado uma vez.

---

## 5. Cobertura de Testes

### 5.1 📊 Estado Atual

Existem apenas **2 arquivos de teste** + 1 helper:

| Arquivo | Funções testadas |
|---------|-----------------|
| `test-utils-mapping.R` | `utils_mapping.R` (funções de automap, scoring) |
| `test-mod-mapping-server.R` | Lógica reativa do módulo mapping |
| `helper-source-utils.R` | Helper de teste |

### 5.2 🔴 Funções sem testes unitários

| Arquivo | Funções sem teste | Prioridade |
|---------|-------------------|------------|
| **`utils_io.R`** | `read_biodiversity_csv`, `detect_encoding`, `detect_delimiter`, `parse_dates_to_iso` | 🔴 **P1** |
| **`utils_dwc.R`** | `validate_coords`, `validate_occurrence_id`, `get_dwc_terms`, `get_required_dwc_terms`, `get_dwc_terms_list` | 🔴 **P1** |
| **`utils_export.R`** | `process_for_export`, `fix_dates_to_iso`, `clean_coordinate_separators`, `add_occurrence_ids`, `clean_scientific_names`, `abbreviate_license`, `abbreviate_license_column` | 🔴 **P1** |
| **`utils_i18n.R`** | `tr`, `get_languages`, `get_language_name` | ⚠️ **P2** |
| **`data_dictionary.R`** | Validação de todas as chaves PT/EN | ⚠️ **P2** |

**Regra violada**: `claude.md` §7 — Testes são prioridade. `architecture.md` §7 define 5+ arquivos de teste. Atualmente faltam **3 dos 5** prescritos:
- ❌ `test-utils-io.R`
- ❌ `test-utils-dwc.R`
- ❌ `test-utils-export.R`
- ❌ `test-utils-i18n.R`
- ✅ `test-utils-mapping.R`

---

## 📋 Resumo por Severidade

### 🔴 Críticos (afetam padrões fundamentais)
1. **26 chamadas `source()`** — Anti-padrão em pacote R
2. **Lógica de negócios em `mod_mapping.R`** — ~300 linhas de lógica pura misturada
3. **`sapply()` em `fix_dates_to_iso()`** — Gargalo de performance com 99k+ linhas
4. **3 de 5 arquivos de teste ausentes** — Cobertura mínima

### ⚠️ Médios (manutenibilidade)
5. **~15 strings hardcoded** — Violam i18n uniforme
6. **`jsonlite` ausente do DESCRIPTION**
7. **`load_dwc_terms_rds()` sem cache** — I/O repetitivo
8. **Duplicação `parse_dates_to_iso` / `fix_dates_to_iso`**

### ✅ Conformes
- ✅ Headers obrigatórios em todos os arquivos
- ✅ Sem `library()` em `R/`
- ✅ Sem `setwd()` ou caminhos absolutos
- ✅ Preview limita a 100 linhas eficientemente
- ✅ Chain of Reactivity correto em `app_server.R`
- ✅ Retornos explícitos em todos os módulos
- ✅ `tryCatch` + `showNotification` no upload
- ✅ Uso consistente de `::` para pacotes externos

---

## 🗺️ Roadmap de Refatoração Sugerido

| Sprint | Ação | Esforço |
|--------|------|---------|
| **1** | Remover todos os `source()` (26 ocorrências) | 🟢 Baixo |
| **1** | Adicionar `jsonlite` ao DESCRIPTION | 🟢 Baixo |
| **1** | Corrigir strings hardcoded nos módulos de validação | 🟢 Baixo |
| **2** | Criar `test-utils-io.R`, `test-utils-dwc.R`, `test-utils-export.R` | 🟡 Médio |
| **2** | Vetorizar `fix_dates_to_iso()` usando `parse_dates_to_iso()` | 🟡 Médio |
| **2** | Cachear `load_dwc_terms_rds()` | 🟡 Médio |
| **3** | Extrair lógica de `mod_mapping.R` para `utils_mapping.R` | 🔴 Alto |
| **3** | Mover renderUI de navegação de `app_server.R` para módulo dedicado | 🟡 Médio |
| **3** | Migrar strings de `mod_help.R` para `data_dictionary.R` | 🔴 Alto |
