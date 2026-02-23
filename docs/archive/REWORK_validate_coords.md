# Rework: Seção de Validação de Coordenadas

## Diagnóstico do Estado Atual

A seção de validação de coordenadas (`mod_validate_coords` + `validate_coords` em `utils_dwc.R`) é funcional em nível básico, mas está significativamente atrás da maturidade alcançada pelos módulos irmãos (`mod_validate_names`, `mod_preview`, `mod_mapping`). Os problemas cobrem arquitetura, UX, cobertura de validação, performance e testes.

---

## Problemas Identificados

### 🔴 Críticos (Arquitetura)

| # | Problema | Impacto |
|---|----------|---------|
| A1 | `validate_coords` só valida limites WGS84. Não detecta zeros suspeitos (lat=0, lon=0), inversão lat/lon, coordenadas idênticas para todos os registros, nem emite erros bilíngues. | Falsos positivos: coords tecnicamente dentro do range mas biologicamente inválidas passam sem alertas |
| A2 | O módulo consome `mapped_data_r` (pipeline completo). Nunca foi alinhado ao ADR-021 (pipeline duplo). Em datasets grandes, a validação pode materializar o pipeline pesado desnecessariamente. | Latência silenciosa |
| A3 | Não há `utils_coords.R` nem lógica pura isolada. Toda a lógica de validação está em `utils_dwc.R`, misturada com lógica de DwC terms, basisOfRecord vocab e cache. | Baixa coesão, difícil de testar isoladamente |
| A4 | O módulo não retorna nenhum reactive (sem `return()`). Viola o contrato explícito exigido por `claude.md` e `architecture.md`. | Impossível encadear resultados para outros módulos |

### 🟠 Relevantes (UX/Feedback)

| # | Problema | Impacto |
|---|----------|---------|
| U1 | Não há estado pré-validação informativo. A aba abre vazia sem orientar o usuário. | Baixo engajamento |
| U2 | Não há feedback imediato ao clicar em Validar. Sem lógica de duas fases `starting → running`. | UX ruim em datasets grandes |
| U3 | Não há modal bloqueante de progresso. O padrão Rostrum existe em `mod_validate_names` e no download. | Inconsistência com o design system |
| U4 | O botão está sempre habilitado. Sem gate leve verificando se colunas estão mapeadas. | Clicar sem dados mapeados e obter apenas um toast |
| U5 | A tabela de issues não tem número de linha (row index). O usuário não consegue localizar o problema no dataset original. | Tabela não-acionável |
| U6 | O stat-box de "Válidas" usa `color: var(--success)` mas `--success` é `#003566` (azul, não verde). | Leitura errada do painel de estatísticas |
| U7 | Sem filtro por tipo de issue. Sem pills de filtro nos resultados. | Tabela difícil de escanear em datasets grandes |
| U8 | Coluna esquerda fica vazia após validação. Stats e controles poderiam ser aproveitados ali para dar contexto permanente. | Espaço desperdiçado, contexto perdido ao rolar |
| U9 | Mapa e tabela empilham verticalmente na direita, forçando scroll constante em monitores 1080p. | Informações-chave ficam escondidas abaixo do fold |

### 🟡 Menores

| # | Problema | Impacto |
|---|----------|---------|
| Q1 | Mensagens de erro em inglês hardcoded (`"Latitude out of range (-90 to 90)"`). Viola o sistema i18n. | I18n violada |
| Q2 | Baixa cobertura de testes: faltam zero-zero, inversão, missing parcial, performance. | Baixa cobertura de regressão |
| Q3 | `suppressWarnings(as.numeric(...))` silencioso. Não registra conversões falhas. | Falha silenciosa |
| Q4 | `renderUI` usado para retornar apenas uma string. Anti-padrão. | DOM desnecessário |
| Q5 | Sem `notify_finch()` local (ADR-034). Notificações podem empilhar. | Inconsistência com ADR-034 |

---

## Proposta de Rework

### Princípios

1. **Pure functions first** (claude.md §4): Toda lógica nova vai para `R/utils_coords.R`.
2. **Test-driven** (claude.md §7): Testes escritos junto com as funções puras.
3. **Bilíngue** (claude.md §3): Nenhum texto hardcoded fora do `data_dictionary.R`.
4. **ADR-021** (pipeline duplo): Gate leve antes de qualquer `observeEvent`.
5. **ADR-027** (duas fases): `starting → running` para feedback imediato.
6. **ADR-029** (pré-validação + filtros): Estado orientativo e pills nos resultados.
7. **ADR-030** (`.finch-table-shell`): Wrapper padrão na tabela de issues.
8. **ADR-034** (notificações estáveis): `notify_finch` local no módulo.
9. **Retorno explícito** (architecture.md §8): Server retorna um reactive.

---

## Layout — Dashboard Lateral (Reconciliado)

### Decisão de Layout

**Grid:** `col-12 col-lg-3` (esquerda) + `col-12 col-lg-9` (direita).

A coluna esquerda age como **painel de controle permanente** — sticky, sempre visível enquanto o usuário explora os resultados. Os stat-boxes migram da direita (onde ficavam enterrados abaixo do mapa) para a esquerda, preenchendo o espaço vazio pós-validação e mantendo contexto numérico sempre à vista.

Na coluna direita, mapa e tabela ficam **lado a lado** (`col-lg-6` + `col-lg-6`): o usuário vê o mapa atualizar à esquerda e a tabela filtrar à direita ao clicar nas pills, sem scroll vertical. A tabela tem colunas curtas (Linha, Issue, Lat, Lon) com `scrollX = TRUE`, compatível com metade da largura.

### Wireframe Final

```
+---------------------------+----------------------------------------------+
|  col-lg-3 (Esquerda)      |  col-lg-9 (Direita)                          |
|  position: sticky         |                                              |
|  top: 1rem                |  [Pills: Todos | Problemas | ...]            |
|                           |                                              |
|  ┌─────────────────────┐  |  ┌─────────────────────┬──────────────────┐  |
|  │ ⚙ Configuração      │  |  │  Mapa Leaflet       │  Tabela de Issues│  |
|  │ Lat: ✓ decimalLat   │  |  │  CartoDB.Positron   │  ┌────────────┐  │  |
|  │ Lon: ✓ decimalLon   │  |  │  Região Neotropical │  │ Linha Issue │  │  |
|  │ [▶ Validar]         │  |  │  ● verde = ok       │  │ 42   lat↑   │  │  |
|  └─────────────────────┘  |  │  ● vermelho = err   │  │ 87   0,0    │  │  |
|                           |  │  ● laranja = 0,0    │  │ 103  ausent │  │  |
|  ┌─────────────────────┐  |  │  ● roxo = invertida │  └────────────┘  │  |
|  │  📊 Estatísticas    │  |  └─────────────────────┴──────────────────┘  |
|  │  2.847 ✓ Válidas    │  |                                              |
|  │    142 ✗ Inválidas  │  |                                              |
|  │     38 ⚪ Ausentes  │  |                                              |
|  │     12 ⚠ Avisos     │  |                                              |
|  └─────────────────────┘  |                                              |
+---------------------------+----------------------------------------------+
```

### Detalhes de UX da Coluna Esquerda

**Estado pré-validação:** O card de configuração mostra o status dos mappings (Lat/Lon) com ícones semânticos (`✓` verde em `--coord-ok`, `✗` muted quando ausente) e o botão de Validar. Abaixo, um hint informativo (`validate-ready-hint`) orienta o usuário.

**Estado pós-validação:** Os stats aparecem abaixo do action card, com valores grandes e cores semânticas:
- Válidas → `--coord-ok` (`#2d6a4f` verde)
- Inválidas → `--error` (`#d62828` vermelho)
- Ausentes → `--text-muted` cinza
- Avisos → `--warning` (`#f77f00` laranja)

Os valores usam `font-family: var(--font-mono)` (IBM Plex Mono) para leitura de números, seguindo as diretrizes do design system.

### Detalhes de UX da Coluna Direita

**Pills horizontais** no topo: filtram mapa (via `leafletProxy`) e tabela simultaneamente. Pill ativa tem `background: var(--active-bg)` + `border-color: var(--primary)`.

**Layout interno lado a lado:**
```
col-lg-6: Mapa Leaflet (height: 420px fixo, min-height: 280px)
col-lg-6: DataTable com max-height: calc(420px + 2rem), overflow-y: auto
```
O `max-height` da tabela acompanha o mapa para manter o fold consistente.

---

## Mudanças Propostas

---

### Camada 1 — Lógica Pura

#### [NEW] `R/utils_coords.R`

```r
# validate_coords_df(df, lat_col, lon_col)
# → data.frame com: .row_index, lat_num, lon_num, valid, issue_type, error_key
#
# issue_type: "ok" | "missing" | "lat_range" | "lon_range" | "zero_zero" | "swapped" | "identical_all"
#
# Funções puras adicionais:
#   count_coords_issues(result_df)   → lista com contadores por issue_type
#   has_coord_columns(df)            → logical
#   detect_coord_columns(df)         → list(lat_col, lon_col) ou NULL
#   build_leaflet_data(result_df, filter) → df com lat_num, lon_num, color, popup_html
```

**Detalhes de validação expandida:**

- **`missing`**: `NA` em lat ou lon.
- **`lat_range`**: lat fora de [-90, 90].
- **`lon_range`**: lon fora de [-180, 180].
- **`zero_zero`**: lat == 0 E lon == 0 (nulo geográfico, suspeito em biodiversidade).
- **`swapped`**: heurística de detecção de inversão lat/lon. Emitido como warning.
- **`identical_all`**: Todas as coordenadas são idênticas.

> [!NOTE]
> A assinatura de `validate_coords(lat, lon)` existente em `utils_dwc.R` é mantida como wrapper legado. O novo `validate_coords_df()` é a função canônica.

---

#### [MODIFY] `R/utils_dwc.R`
- Manter `validate_coords(lat, lon)` como wrapper — não alterar assinatura.
- Adicionar aviso roxygen apontando para `validate_coords_df()`.

---

### Camada 2 — Testes

#### [MODIFY] `tests/testthat/test-utils-dwc.R`
Adaptar o teste de `validate_coords` para verificar `issue_type` em vez do texto de erro hardcoded.

#### [NEW] `tests/testthat/test-utils-coords.R`

| Cenário | Tipo |
|---------|------|
| Lat/lon numérico válido (WGS84) | Positivo |
| Lat/lon com vírgula decimal (`-23,55`) | Positivo |
| Lat fora do range | `lat_range` |
| Lon fora do range | `lon_range` |
| Lat == NA (missing parcial) | `missing` |
| Lon == NA (missing parcial) | `missing` |
| Ambos NA | `missing` |
| lat == 0 e lon == 0 | `zero_zero` |
| Lat e lon possivelmente invertidos | `swapped` |
| Todos os registros com mesma coordenada | `identical_all` |
| Vetor vazio | Retorna df vazio |
| Dataset sem colunas de coord | `has_coord_columns` FALSE |
| `detect_coord_columns` automático | Correto |
| `count_coords_issues` retorna contadores | Contadores |
| Performance: 100k linhas em < 2s | Benchmark |

---

### Camada 3 — Módulo Shiny

#### [MODIFY] `R/mod_validate_coords.R`

**UI — Estrutura do `tagList`:**

```r
mod_validate_coords_ui <- function(id) {
    ns <- shiny::NS(id)
    shiny::tagList(
        shiny::div(
            class = "container-fluid validate-coords-page",
            style = "max-width: 1320px;",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::div(
                class = "row g-4 validate-coords-layout",
                # Coluna Esquerda — sticky, controles + stats
                shiny::div(
                    class = "col-12 col-lg-3 validate-coords-left",
                    shiny::uiOutput(ns("action_card")),
                    shiny::uiOutput(ns("stats_panel"))   # [NOVO] uiOutput próprio
                ),
                # Coluna Direita — pills + mapa/tabela lado a lado
                shiny::div(
                    class = "col-12 col-lg-9 validate-coords-right",
                    shiny::uiOutput(ns("pre_right_hint")),
                    shiny::uiOutput(ns("progress_panel")),
                    shiny::uiOutput(ns("filter_pills")),  # [NOVO] uiOutput próprio
                    shiny::div(
                        class = "row g-3 validate-coords-results-row",
                        shiny::div(
                            class = "col-12 col-lg-6 validate-coords-map-col",
                            shiny::uiOutput(ns("map_panel"))   # [NOVO] uiOutput próprio
                        ),
                        shiny::div(
                            class = "col-12 col-lg-6 validate-coords-table-col",
                            shiny::uiOutput(ns("table_panel"))  # [NOVO] uiOutput próprio
                        )
                    )
                )
            )
        )
    )
}
```

> [!IMPORTANT]
> Os `uiOutput`s separados (`stats_panel`, `filter_pills`, `map_panel`, `table_panel`) substituem o `results_panel` monolítico atual. Isso é obrigatório para que:
> 1. Os stats possam ser renderizados na **coluna esquerda** sem duplicar código.
> 2. O mapa `leafletOutput` possa ter ID próprio sem ficar dentro de `renderUI` condicional.
> 3. A tabela possa ter `max-height` controlado via CSS sem afetar os outros painéis.

**Server:**
- `output$stats_panel` — extração do bloco de stats do `results_panel` atual (linhas 578–600).
- `output$filter_pills` — extração das pills do `results_panel` atual (linhas 549–576).
- `output$map_panel` — wrapper do `leafletOutput` dentro de `bslib::card` (visível apenas pós-validação).
- `output$table_panel` — wrapper do `DT::dataTableOutput` dentro de `.finch-table-shell`.
- Gate leve sem materializar `mapped_data_r()`.
- Duas fases (`starting → running`) via `session$onFlushed`.
- Modal bloqueante no padrão Rostrum.
- `notify_finch()` local com ID estável.
- `return(coord_validation_r)` — reactive explícito.

---

### Camada 3.5 — Mapa Leaflet Interativo

#### Bug de Repetição (Tiling) — Diagnóstico e Correção

> [!WARNING]
> **Causa raiz do bug que você descreveu**: `leaflet::leafletOutput()` sem `height` explícita faz o Leaflet calcular o container como zero e repetir os tiles infinitamente.

**Correção robusta (duas camadas):**
```r
# Camada 1: height explícito no leafletOutput
leaflet::leafletOutput(ns("map"), height = "420px")

# Camada 2: CSS como salvaguarda
# .coords-map-container .leaflet-container { height: 420px; min-height: 200px; }
```

#### Design do Mapa

- **Tile provider**: `CartoDB.Positron` — fundo claro neutro, harmoniza com `--bg-main: #f4f3ee`.
- **View inicial**: Região Neotropical via `fitBounds(-56, -120, 34, -30)`.
- **Quando aparece**: apenas pós-validação (não no estado pré-valid).
- **Atualização via `leafletProxy`**: filtro pills atualiza marcadores sem re-render do tile base.

**Coloração de pontos por `issue_type`:**

| `issue_type` | Cor | Token |
|---|---|---|
| `ok` | `#2d6a4f` verde | `--coord-ok` |
| `lat_range` `lon_range` | `#d62828` vermelho | `--error` |
| `missing` | `rgba(0,29,61,0.35)` cinza | `--coord-missing` |
| `zero_zero` | `#f77f00` laranja | `--warning` |
| `swapped` | `#8b5cf6` roxo | `--coord-swapped` |
| `identical_all` | `#ffc300` amarelo | `--primary` |

**Clustering**: obrigatório em > 500 pontos (performance), desabilitado em datasets pequenos para preservar distribuição.

**Popup por marcador** (bilíngue, gerado no server antes de passar ao Leaflet):
```html
<b>Linha:</b> 1842<br>
<b>Lat:</b> 91.32 <b>Lon:</b> -46.63<br>
<span class="badge-issue-error">lat fora do range</span>
```

---

### Camada 4 — i18n

#### [MODIFY] `R/data_dictionary.R`

Novas chaves (manter todas as existentes `validate_coords_*` sem alteração):

| Chave | PT | EN |
|-------|----|-----|
| `validate_coords_pre_hint_title` | "Configure e valide" | "Configure and validate" |
| `validate_coords_pre_hint_body` | "Mapeie decimalLatitude e decimalLongitude na aba Mapeamento, depois clique em Validar." | "Map decimalLatitude and decimalLongitude in the Mapping tab, then click Validate." |
| `validate_coords_warnings` | "Avisos" | "Warnings" |
| `validate_coords_zero_zero` | "Zero-Zero" | "Zero-Zero" |
| `validate_coords_swapped` | "Invertidas" | "Swapped" |
| `validate_coords_filter_all` | "Todos" | "All" |
| `validate_coords_filter_problems` | "Problemas" | "Problems" |
| `validate_coords_filter_missing` | "Ausentes" | "Missing" |
| `validate_coords_filter_lat` | "Lat inválida" | "Invalid Lat" |
| `validate_coords_filter_lon` | "Lon inválida" | "Invalid Lon" |
| `validate_coords_col_row` | "Linha" | "Row" |
| `validate_coords_col_issue` | "Tipo de issue" | "Issue type" |
| `validate_coords_col_lat` | "Latitude" | "Latitude" |
| `validate_coords_col_lon` | "Longitude" | "Longitude" |
| `validate_coords_badge_missing` | "ausente" | "missing" |
| `validate_coords_badge_lat_range` | "lat fora do range" | "lat out of range" |
| `validate_coords_badge_lon_range` | "lon fora do range" | "lon out of range" |
| `validate_coords_badge_zero_zero` | "zero-zero" | "zero-zero" |
| `validate_coords_badge_swapped` | "possível inversão" | "possible swap" |
| `validate_coords_lat_missing` | "Latitude não mapeada" | "Latitude not mapped" |
| `validate_coords_lon_missing` | "Longitude não mapeada" | "Longitude not mapped" |
| `validate_coords_map_title` | "Distribuição Geográfica" | "Geographic Distribution" |
| `validate_coords_map_subtitle` | "Pontos coloridos por tipo de issue. Clique em um ponto para ver detalhes." | "Points colored by issue type. Click a point to see details." |
| `validate_coords_popup_row` | "Linha" | "Row" |
| `validate_coords_popup_issue` | "Issue" | "Issue" |
| `validate_coords_map_legend_ok` | "Válida" | "Valid" |
| `validate_coords_map_legend_error` | "Inválida" | "Invalid" |
| `validate_coords_map_legend_warning` | "Aviso" | "Warning" |
| `validate_coords_map_legend_missing` | "Ausente" | "Missing" |

---

### Camada 5 — `app_server.R`

#### [MODIFY] `R/app_server.R`
- Capturar o retorno de `mod_validate_coords_server(...)` como `coord_validation_r`.

---

### Camada 6 — `DESCRIPTION`

#### [MODIFY] `DESCRIPTION`

> [!IMPORTANT]
> `leaflet` **não está no `DESCRIPTION` atual**. Precisa ser adicionado em `Imports`. Sem isso, `R CMD check` vai falhar.

```diff
 Imports:
     shiny (>= 1.7.0),
     bslib (>= 0.5.0),
     readr (>= 2.1.0),
     stringr (>= 1.5.0),
     taxadb (>= 0.2.0),
     DT (>= 0.28),
+    leaflet (>= 2.1.0),
     ids (>= 1.0.0),
     here (>= 1.0.0),
     jsonlite (>= 1.8.0)
```

---

### Camada 7 — CSS

#### [MODIFY] `inst/app/www/custom.css`

**Novos tokens semânticos no `:root`:**
```css
--coord-ok:      #2d6a4f;             /* verde - coordenada válida */
--coord-missing: rgba(0, 29, 61, 0.35); /* cinza translúcido - ausente */
--coord-swapped: #8b5cf6;             /* roxo - possível inversão */
```

**Sidebar sticky (coluna de controles):**
```css
/* Sticky sidebar — mantém controles visíveis enquanto usuário explora resultados */
@media (min-width: 992px) {
  .validate-coords-left {
    position: sticky;
    top: 1rem;
    align-self: flex-start;
    max-height: calc(100vh - 2rem);
    overflow-y: auto;
  }
}
```

**Stat-boxes semânticos (compartilhado com validate_names):**
```css
.stat-box-ok    .stat-value { color: var(--coord-ok);  font-family: var(--font-mono); }
.stat-box-error .stat-value { color: var(--error);     font-family: var(--font-mono); }
.stat-box-warn  .stat-value { color: var(--warning);   font-family: var(--font-mono); }
.stat-box-muted .stat-value { color: rgba(0,29,61,0.4); font-family: var(--font-mono); }
```

> [!NOTE]
> `font-family: var(--font-mono)` nos stat-values segue o design.md: "Code/Data: Always monospace font".

**Container do mapa:**
```css
.coords-map-container {
  border-radius: var(--radius-lg);
  overflow: hidden;
  border: 1px solid var(--border-default);
  box-shadow: var(--shadow);
}

.coords-map-container .leaflet-container {
  height: 420px;    /* FIX: sem isso os tiles repetem */
  min-height: 280px;
  width: 100%;
}
```

**Tabela de coordenadas — altura máxima acompanha o mapa:**
```css
.validate-coords-table-col .finch-table-shell {
  max-height: calc(420px + 2.5rem); /* acompanha mapa + header do card */
  overflow-y: auto;
}
```

**Legenda do mapa:**
```css
.coords-map-legend {
  display: flex;
  gap: var(--gap-base);
  flex-wrap: wrap;
  padding: var(--space-3) 0;
  font-size: var(--text-sm);
}

.coords-map-legend-item { display: flex; align-items: center; gap: var(--space-2); }
.coords-map-legend-dot  { width: 12px; height: 12px; border-radius: var(--radius-full); flex-shrink: 0; }
.coords-map-legend-dot-ok      { background: var(--coord-ok); }
.coords-map-legend-dot-error   { background: var(--error); }
.coords-map-legend-dot-warning { background: var(--warning); }
.coords-map-legend-dot-missing { background: var(--coord-missing); }
```

**Pills de filtro — transição suave:**
```css
.coords-filter-pills {
  display: flex;
  flex-wrap: wrap;
  gap: var(--gap-sm);
  margin-bottom: var(--space-4);
}

/* Transição seguindo design.md --transition-colors */
.stream-pill {
  transition: var(--transition-colors), box-shadow 0.2s ease;
}
.stream-pill.active {
  background: var(--active-bg);
  border-color: var(--primary);
  box-shadow: var(--shadow-primary);
}
.stream-pill:hover:not(:disabled):not(.active) {
  background: var(--hover-bg);
  transform: var(--lift-sm);
}
```

---

### Camada 8 — Documentação

#### [MODIFY] `CHANGELOG.md`
Entrada `[0.1.12]`.

#### [MODIFY] `docs/DECISIONS.md`
- **ADR-036**: Separação da lógica de coordenadas para `utils_coords.R` com 6 tipos de issue.
- **ADR-037**: Leaflet na validação de coordenadas. Fix do tiling bug. `leafletProxy`. Clustering > 500. Região Neotropical como view inicial.
- **ADR-038**: Layout `col-lg-3 / col-lg-9` com sidebar sticky. Stats migrados para coluna esquerda. Mapa e tabela lado a lado (`col-lg-6 / col-lg-6`) na coluna direita.

#### [MODIFY] `docs/LESSONS.md`
- **DwC/Biodiversidade**: Zero-zero e inversão lat/lon como issues biológicos.
- **Leaflet**: Container sem `height` explícita causa tiling. Fix: `leafletOutput(height="Xpx")` + CSS. Usar `leafletProxy` para atualização incremental.
- **Shiny/UX**: Coluna de controles com `position: sticky` + `align-self: flex-start` mantém o painel visível durante scroll — não requer JavaScript adicional.

---

## Sequência de Implementação

```
1. DESCRIPTION          (adicionar leaflet)
2. utils_coords.R       (lógica pura + build_leaflet_data)
3. test-utils-coords.R  (≥ 15 cenários)
4. test-utils-dwc.R     (adaptar teste legado)
5. data_dictionary.R    (novas chaves i18n)
6. custom.css           (tokens + sticky sidebar + .coords-map-container)
7. mod_validate_coords.R (UI refatorada + server com uiOutputs separados + mapa)
8. app_server.R         (capturar retorno)
9. CHANGELOG.md + DECISIONS.md + LESSONS.md
```

---

## Plano de Verificação

### Testes Automatizados

```r
devtools::test(filter = "utils-coords")   # nova suite
devtools::test(filter = "utils-dwc")      # regressão wrapper legado
devtools::test(filter = "i18n")           # novas chaves
devtools::test(filter = "css-guardrails") # novos tokens no :root
devtools::check(document = FALSE, manual = FALSE)
```

**Critério de aceite:**
- `test-utils-coords.R` com ≥ 15 cenários passando.
- `test-utils-dwc.R` sem regressão.
- `test-i18n-a11y-keys.R` passando (novas chaves cobertas).
- `test-css-guardrails.R` passando.
- Zero warnings/notes em `devtools::check()`.

### Verificação Manual no Browser

1. Ir para aba "Coordenadas" sem dados mapeados → botão desabilitado, hint visível, **sem mapa, sem stats**.
2. Mapear `decimalLatitude`/`decimalLongitude` → botão habilitado.
3. Rolar a página com resultados → **coluna esquerda permanece visível** (sticky), sem perder contexto dos stats.
4. Clicar "Validar":
   - Feedback imediato (spinner). Modal de progresso.
   - Stats aparecem na coluna esquerda com cores semânticas corretas (verde, não azul).
   - **Mapa renderiza sem repetição de tiles.**
   - View centrada na Região Neotropical.
   - Pontos: verde=ok, vermelho=lat/lon inválida, laranja=zero-zero, roxo=invertida.
   - Popup ao clicar: linha, lat, lon, badge de issue.
   - Pills filtram **mapa e tabela simultaneamente** via `leafletProxy` sem re-render do tile.
5. CSV com lat=0, lon=0 → ponto laranja no 0,0 + badge na tabela.
6. CSV com lat/lon trocados → ponto roxo + badge "possível inversão".
7. Trocar idioma PT↔EN: badges, pills, popups e legenda do mapa mudam.
8. Dataset com 10k+ pontos: clusters no zoom out, expandem no zoom in.
9. Verificar responsividade: em telas < 992px, mapa e tabela empilham verticalmente (Bootstrap `col-12`).
