# Rework: Seção de Validação de Nomes Científicos

## Diagnóstico do Estado Atual

O módulo `mod_validate_names` (v2.2, 866 linhas) é o mais maduro do app. Já implementa:
- Gate leve `validation_gate_r` (ADR-021)
- Duas fases `starting → running` (ADR-027)
- Stream ao vivo com pills de filtro (ADR-029)
- Painel de progresso com barra, fases e falhas de provedor
- `notify_finch()` local com IDs estáveis (ADR-034)
- Retorno explícito `shiny::reactive(validation_result())` (architecture.md §8)
- DataTable com badges coloridos, italic em `scientificName`, `rowCallback`

**O rework deste módulo é cirúrgico, não estrutural.** O foco é resolver lacunas específicas e reformar o layout para eliminar scroll excessivo.

---

## Problemas Identificados

### 🔴 Alta Prioridade

| # | Problema | Impacto |
|---|----------|---------|
| A1 | **Cor semântica errada no stat-box "Válidos"**: `color: var(--success)` — `--success` é `#003566` (azul escuro), não verde. Mesmo bug do módulo de coordenadas. | Stat de "nomes válidos" parece azul/neutro |
| A2 | **Sem download do relatório**: O card de opções menciona "Relatório de falhas disponível após validação", mas **não há `downloadButton`/`downloadHandler` no código**. Promessa quebrada. | Usuário não consegue exportar o relatório prometido |
| A3 | **Stream mostra `query_name` (normalizado), não `input_name`**: O usuário vê `"Puma concolor"` mas inseriu `"puma concolor (Linnaeus)"`. Stream não é rastreável até o dado de origem. | Dificulta identificar qual linha do CSV tem problema |
| A4 | **Layout col-6/col-6 força scroll severo**: `action_card` está na direita; `run_summary`, `stats` e `results` (tabela) estão na esquerda. A divisão arbitrária enterra o conteúdo abaixo do fold. | Usuário rola constantemente entre configuração e resultados |

### 🟠 Relevantes

| # | Problema | Impacto |
|---|----------|---------|
| U1 | **Stream capped em 100 itens**: `stream_window_limit <- 100L`. Em 500+ nomes únicos, a maioria nunca aparece. | Perda de visibilidade em datasets médios |
| U2 | **Sem card de sumário quando TODOS os nomes são válidos**: Retorna um `alert-success` genérico. | Feedback de sucesso total fraco |
| U3 | **Tabela filtra só não-aceitos, sem toggle**: `status_vec != "accepted"` hardcoded. Usuário não consegue ver os aceitos. | Visibilidade parcial dos resultados |

### 🟡 Menores

| # | Problema | Impacto |
|---|----------|---------|
| Q1 | **DRY violation**: `fetch_taxadb_matches` e `query_taxadb_batch` compartilham +50 linhas idênticas de lógica de resolução de `query_name`. | Manutenção duplicada |
| Q2 | **`normalize_scientific_name` sem cobertura para Unicode**: Gêneros com diacríticos, fórmulas híbridas `×`, nomes em UPPERCASE. | Comportamento não documentado |
| Q3 | **`output$results` chama `validation_result()` duas vezes**: redundância reativa. | Recálculos desnecessários |
| Q4 | **`input_name`/`query_name` são as últimas colunas da tabela**: As mais relevantes para diagnóstico ficam escondidas à direita. | Usabilidade baixa |

---

## Proposta de Rework

### Princípios

1. **Pure functions first**: Lógica nova/extraída vai para `utils_taxadb.R`.
2. **Test-driven**: Testes escritos junto com as funções novas/modificadas.
3. **Bilíngue**: Nenhuma string nova hardcoded fora de `data_dictionary.R`.
4. **Não quebrar contratos**: Assinatura pública de `mod_validate_names_server` não muda.
5. **Mínimo de mudança estrutural**: Cirurgia, não rearquitetura.

---

## Layout — Dashboard Lateral (Reconciliado)

### Decisão de Layout

**Grid:** `col-12 col-lg-3` (esquerda) + `col-12 col-lg-9` (direita).

**Para a área de resultados na direita: abas internas via `bslib::navset_card_underline()`.**

**Justificativa da escolha de abas vs. lado-a-lado:**

A tabela de nomes científicos tem colunas longas (`input_name`, `query_name`, `scientificName`, `taxonomicStatus`, `provider_label`). Dividir 50/50 no espaço `col-lg-9` resulta em ~350px por painel em 1080p — insuficiente para os nomes legíveis sem scroll horizontal agressivo. Com `navset_card_underline`, cada aba ocupa 100% da largura disponível (`col-12` dentro do `col-lg-9`), maximizando a legibilidade dos nomes longos e eliminando o scroll vertical da tabela.

O stream de resolução, por sua natureza de "log ao vivo", é mais adequado como segunda aba — o usuário *monitora* durante a validação e *consulta* o histórico depois. Essa separação é semântica e natural.

### Wireframe Final

```
+---------------------------+----------------------------------------------+
|  col-lg-3 (Esquerda)      |  col-lg-9 (Direita)                          |
|  position: sticky         |                                              |
|  top: 1rem                |  ┌─────────────────────────────────────────┐  |
|                           |  │  📊 Resumo + Stats (pós-validação)      │  |
|  ┌─────────────────────┐  |  │  Válidos 2.120 | Inválidos 89 | ...     │  |
|  │ 🗄 Provedores       │  |  └─────────────────────────────────────────┘  |
|  │ [GBIF ✓] [ITIS] ... │  |                                              |
|  └─────────────────────┘  |  ┌─────────────────────────────────────────┐  |
|                           |  │  📋 Resultados │ 🔄 Histórico           │  |
|  ┌─────────────────────┐  |  ├─────────────────────────────────────────┤  |
|  │ ⚙ Opções            │  |  │                                         │  |
|  │ [✓] Remover autores │  |  │  (aba ativa)                            │  |
|  │ [✓] Ignorar quals.  │  |  │                                         │  |
|  │ ─────────────────── │  |  │  Tabela DT: input_name, query_name,     │  |
|  │ [▶ Validar]         │  |  │  validation_status, provider, taxStatus │  |
|  │ [⬇ Baixar CSV]      │  |  │  max-height: 65vh, overflow-y: auto     │  |
|  └─────────────────────┘  |  └─────────────────────────────────────────┘  |
+---------------------------+----------------------------------------------+
```

### Detalhes de UX da Coluna Esquerda

**Agrupamento por função** — todas as configurações de execução ficam unificadas na esquerda:

1. `providers_card` — card de seleção de provedores (taxonômicos)
2. `options_card` — switches de pré-processamento
3. `action_card` — botão Validar + botão Download (migrado da direita)

O `action_card` exibe métricas rápidas (provedores selecionados, opções ativas) antes do botão, mantendo o padrão atual. O botão de download fica no mesmo card, desabilitado pré-validação.

**Sticky sidebar:** A coluna de controles permanece visível enquanto o usuário lê a tabela de resultados — sem perder contexto de configuração.

### Detalhes de UX da Coluna Direita

**Topo — Painel de Contexto (`run_summary` + `stats`):**  
Aparece apenas pós-validação. `run_summary` é um `alert-info` compacto (provedores usados, cancelamentos). `stats` são os três stat-boxes (Válidos, Inválidos, Não-resolvidos) em linha horizontal consolidada com cores semânticas corretas.

**Abas internas via `navset_card_underline`:**
- **Aba 1 — "📋 Resultados Detalhados"**: DataTable full-width com toggle "Mostrar todos" e colunagem reordenada. `max-height: 65vh; overflow-y: auto` para que a tabela role internamente sem rolar a página.
- **Aba 2 — "🔄 Histórico de Resolução"**: Stream ao vivo durante validação; histórico completo após. Pills de filtro no topo da aba.

Durante validação em andamento, a aba de Histórico é ativada automaticamente via `updateTabsetPanel` para que o usuário monitore o stream. Após conclusão, a aba de Resultados é ativada automaticamente via o mesmo mecanismo.

---

## Mudanças Propostas

---

### Camada 1 — `R/utils_taxadb.R`

**1a. Extrair `resolve_query_name_col()` (DRY fix Q1):**

```r
# Função privada — resolve a coluna query_name a partir do resultado de
# taxadb::filter_name(), que não garante nome de coluna fixo.
resolve_query_name_col <- function(matches_df, query_names_chr) {
  # Lógica atualmente duplicada em fetch_taxadb_matches e query_taxadb_batch.
}
```

`fetch_taxadb_matches` e `query_taxadb_batch` ficam com ~10 linhas cada após a extração.

**1b. Adicionar `format_validation_report_for_download()` (novo — para A2):**

```r
# Função pura: data.frame interno → data.frame pronto para CSV download.
# - Colunas renomeadas (DwC-friendly)
# - Status normalizado (não "accepted"/"not_found" raw)
# - input_name incluída como referência ao dado original
# - Sem colunas internas (skip_reason, match_count, row_id, etc.)
format_validation_report_for_download <- function(report_df, lang = "pt") {
  # → data.frame pronto para readr::write_csv()
}
```

---

### Camada 2 — Testes

#### [MODIFY] `tests/testthat/test-utils-taxadb.R`

| Cenário | Função |
|---------|--------|
| Nome com diacríticos (`Müelleria sp.`) | `normalize_scientific_name` |
| Fórmula híbrida (`Mentha × piperita`) | `normalize_scientific_name` |
| Nome todo uppercase (`PUMA CONCOLOR`) | `normalize_scientific_name` |
| Nome com pipe `|` (separador DwC) | `normalize_scientific_name` |
| `format_validation_report_for_download` retorna colunas esperadas | nova função |
| `format_validation_report_for_download` sem colunas internas | nova função |
| `resolve_query_name_col` com `input`, `inputName`, `matched_name` | helper extraído |

---

### Camada 3 — i18n

#### [MODIFY] `R/data_dictionary.R`

| Chave | PT | EN |
|-------|----|-----|
| `validate_names_download_report_btn` | "Baixar Relatório CSV" | "Download CSV Report" |
| `validate_names_download_report_filename` | `"relatorio_validacao_nomes"` | `"name_validation_report"` |
| `validate_names_all_valid_title` | "Todos os nomes foram validados!" | "All names validated!" |
| `validate_names_all_valid_body` | "Nenhum problema encontrado nos nomes científicos." | "No issues found in scientific names." |
| `validate_names_stream_input_name` | "Original" | "Original" |
| `validate_names_table_show_all` | "Mostrar todos" | "Show all" |
| `validate_names_table_show_issues` | "Apenas problemas" | "Issues only" |
| `validate_names_report_col_input` | "Nome original" | "Original name" |
| `validate_names_report_col_query` | "Nome consultado" | "Queried name" |
| `validate_names_tab_results` | "📋 Resultados Detalhados" | "📋 Detailed Results" |
| `validate_names_tab_stream` | "🔄 Histórico de Resolução" | "🔄 Resolution History" |
| `a11y_provider_card_label` | "Selecionar provedor {provider}" | "Select provider {provider}" |

**Manter:** Todas as ~60 chaves `validate_names_*` existentes sem alteração.

---

### Camada 4 — Módulo Shiny

#### [MODIFY] `R/mod_validate_names.R`

**4a. Novo layout da UI:**

```r
mod_validate_names_ui <- function(id) {
    ns <- shiny::NS(id)
    shiny::tagList(
        shiny::div(
            class = "container-fluid validate-names-page",
            style = "max-width: 1320px;",
            shiny::uiOutput(ns("title")),
            shiny::uiOutput(ns("subtitle")),
            shiny::div(
                class = "row g-4 validate-names-layout",
                # Coluna Esquerda — sticky, toda configuração de execução
                shiny::div(
                    class = "col-12 col-lg-3 validate-names-left",
                    shiny::uiOutput(ns("providers_card")),
                    shiny::uiOutput(ns("options_card")),
                    shiny::uiOutput(ns("action_card"))   # migrado da direita
                ),
                # Coluna Direita — contexto + abas de resultados
                shiny::div(
                    class = "col-12 col-lg-9 validate-names-right",
                    shiny::uiOutput(ns("pre_right_hint")),
                    shiny::uiOutput(ns("progress_panel")),
                    shiny::uiOutput(ns("run_summary")),   # compacto, pós-validação
                    shiny::uiOutput(ns("stats")),         # stat-boxes horizontais
                    shiny::uiOutput(ns("results_tabs"))   # [NOVO] navset com abas
                )
            )
        )
    )
}
```

> [!IMPORTANT]
> `action_card` migra da coluna direita para a esquerda. `run_summary` e `stats` migram da esquerda para a direita (topo). `results` é substituído por `results_tabs` com `bslib::navset_card_underline`.

**4b. Fix de cor semântica nos stat-boxes (A1):**

```diff
-shiny::div(class = "stat-box", shiny::div(class = "stat-value", style = "color: var(--success);", valid_count), ...)
+shiny::div(class = "stat-box stat-box-ok", shiny::div(class = "stat-value", valid_count), ...)
```

Usar classe CSS em vez de `style` inline — alinha com design system e guard-rails de CSS.

**4c. Download do relatório (A2) — dentro do `action_card`:**

```r
# UI (dentro do action_card, após o botão Validar):
shiny::downloadButton(ns("download_report"),
  label = tr("validate_names_download_report_btn", lang_r()),
  class = "btn-outline-primary w-100 mt-2",
  disabled = !isTRUE(has_validation_output()))

# Server:
output$download_report <- shiny::downloadHandler(
  filename = function() {
    paste0(tr("validate_names_download_report_filename", lang_r()), "_",
           format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
  },
  content = function(file) {
    report <- validation_result()
    shiny::req(report)
    df <- format_validation_report_for_download(report, lang = lang_r())
    readr::write_csv(df, file, na = "")
  }
)
```

> [!NOTE]
> Desabilitado antes de validar. Habilita automaticamente quando `has_validation_output()` for TRUE.

**4d. `input_name` no stream (A3):**

```r
# Após o div de query_name, mostrar nome original quando diferente:
shiny::div(class = "validation-stream-name", row$query_name[[1]]),
if (!identical(row$input_name[[1]], row$query_name[[1]]))
  shiny::div(class = "validation-stream-input-name",
             tr("validate_names_stream_input_name", lang_r()), ": ",
             row$input_name[[1]])
```

**4e. Abas de resultados via `navset_card_underline` (A4):**

```r
output$results_tabs <- shiny::renderUI({
  report <- validation_result()
  if (is.null(report) || !is.data.frame(report) || nrow(report) == 0L) return(NULL)

  bslib::navset_card_underline(
    id = ns("results_nav"),
    # Aba 1: Tabela de resultados
    bslib::nav_panel(
      title = tr("validate_names_tab_results", lang_r()),
      bslib::input_switch(ns("show_all_results"),
                          tr("validate_names_table_show_all", lang_r()),
                          value = FALSE),
      shiny::div(class = "finch-table-shell validate-names-table-shell",
                 DT::dataTableOutput(ns("issues_table")))
    ),
    # Aba 2: Stream de resolução
    bslib::nav_panel(
      title = tr("validate_names_tab_stream", lang_r()),
      shiny::uiOutput(ns("stream_panel"))
    )
  )
})
```

**4f. Troca automática de aba:**

```r
# Durante validação → ativar aba de Histórico
shiny::observe({
  if (isTRUE(rv$running) || isTRUE(rv$starting)) {
    bslib::nav_select("results_nav", tr("validate_names_tab_stream", lang_r()), session = session)
  }
})

# Pós-validação → ativar aba de Resultados
shiny::observe({
  if (!isTRUE(rv$running) && !isTRUE(rv$starting) && isTRUE(has_validation_output())) {
    bslib::nav_select("results_nav", tr("validate_names_tab_results", lang_r()), session = session)
  }
})
```

**4g. Expandir `stream_window_limit` para 250 (U1):**

```diff
-stream_window_limit <- 100L
+stream_window_limit <- 250L
```

**4h. Card de sucesso total estruturado (U2):**

```r
# Dentro da aba de Resultados, quando nrow(issues) == 0:
bslib::card(
  class = "validate-names-card validate-all-valid-card",
  bslib::card_body(
    shiny::div(class = "validate-all-valid-icon", shiny::icon("circle-check")),
    shiny::div(class = "validate-all-valid-title", tr("validate_names_all_valid_title", lang_r())),
    shiny::div(class = "validate-all-valid-body",  tr("validate_names_all_valid_body",  lang_r()))
  )
)
```

**4i. Toggle "Mostrar todos" na tabela (U3):**

```r
# No renderDataTable, usar o toggle para decidir o filtro:
report <- validation_result()
shiny::req(report)
status_vec <- tolower(as.character(report$validation_status %||% character(0)))
status_vec[is.na(status_vec)] <- "not_found"
issues <- if (isTRUE(input$show_all_results)) report else report[status_vec != "accepted", , drop = FALSE]
```

**4j. Fix dupla chamada reativa em `output$results` (Q3):**

```r
# Usar variável local para evitar dupla dependência reativa:
report <- validation_result()
shiny::req(report)
# Usar `report` em todo o resto do bloco.
```

**4k. Reordenar colunas da tabela (Q4):**

```diff
-keep_cols <- c("scientificName", "validation_status", "provider_label", "taxonomicStatus", "query_name", "input_name")
+keep_cols <- c("input_name", "query_name", "validation_status", "provider_label", "taxonomicStatus")
```

---

### Camada 5 — CSS

#### [MODIFY] `inst/app/www/custom.css`

**Sidebar sticky (compartilhado com validate_coords):**
```css
@media (min-width: 992px) {
  .validate-names-left,
  .validate-coords-left {
    position: sticky;
    top: 1rem;
    align-self: flex-start;
    max-height: calc(100vh - 2rem);
    overflow-y: auto;
  }
}
```

**Stat-boxes semânticos (compartilhado com validate_coords — definir uma vez):**
```css
/* Usar classes em vez de style inline — alinha com design.md §anti-patterns */
.stat-box-ok    .stat-value { color: var(--coord-ok);             font-family: var(--font-mono); }
.stat-box-error .stat-value { color: var(--error);                font-family: var(--font-mono); }
.stat-box-warn  .stat-value { color: var(--warning);              font-family: var(--font-mono); }
.stat-box-muted .stat-value { color: rgba(0, 29, 61, 0.4);        font-family: var(--font-mono); }
```

> [!NOTE]
> `font-family: var(--font-mono)` nos stat-values aplica IBM Plex Mono, seguindo design.md: "Code/Data: Always monospace font". Os valores numéricos das estatísticas são dados científicos.

**Tabela de nomes — altura máxima interna:**
```css
.validate-names-table-shell {
  max-height: 65vh;
  overflow-y: auto;
}
```

**Card de validação total bem-sucedida:**
```css
.validate-all-valid-card { text-align: center; padding: var(--space-8); }
.validate-all-valid-icon  {
  font-size: var(--text-2xl);
  color: var(--coord-ok);
  margin-bottom: var(--space-4);
}
.validate-all-valid-title {
  font-size: var(--text-lg);
  font-weight: var(--weight-semibold);
  font-family: var(--font-mono);  /* design.md: headings usam mono */
  color: var(--text-primary);
  margin-bottom: var(--space-2);
}
.validate-all-valid-body {
  font-size: var(--text-base);
  color: rgba(0, 29, 61, 0.6);  /* design.md: muted text */
}
```

**Label "Original" no stream:**
```css
.validation-stream-input-name {
  font-size: var(--text-xs);
  color: rgba(0, 29, 61, 0.6);  /* design.md: muted text token */
  margin-top: var(--space-1);
  font-style: italic;
}
```

**Stats horizontais consolidados (pós-validação, na direita):**
```css
/* Stats na direita ficam em linha horizontal compacta */
.validate-names-right .stats-container {
  display: flex;
  flex-wrap: wrap;
  gap: var(--gap-sm);
  margin-bottom: var(--space-4);
}

.validate-names-right .stat-box {
  flex: 1 1 auto;
  min-width: 80px;
}
```

> [!NOTE]
> `--coord-ok` e `--error` precisam estar presentes no `:root` (definidos no rework de coordenadas). Se implementado antes do rework de coords, adicionar esses tokens ao `:root` aqui.

---

### Camada 6 — Testes de Regressão do Módulo

#### [MODIFY] `tests/testthat/test-mod-validate-names-server.R`

| Cenário | O que testa |
|---------|-------------|
| Download handler retorna CSV com colunas esperadas | `output$download_report` |
| Stat-box de válidos usa classe `stat-box-ok` | A1 fix |
| Show-all toggle altera filtro da tabela | 4i |
| `stream_window_limit` com > 250 itens mostra os 250 mais recentes | 4g |
| Card all-valid aparece quando todos aceitos | 4h |
| UI usa `navset_card_underline` para resultados | 4e |

---

### Camada 7 — Documentação

#### [MODIFY] `CHANGELOG.md`
Adicionar à entrada `[0.1.12]` (mesma versão do rework de coords).

#### [MODIFY] `docs/DECISIONS.md`
- **ADR-038** (compartilhado): Layout `col-lg-3 / col-lg-9` com sidebar sticky para ambos os módulos de validação.
- **ADR-039**: `navset_card_underline` para resultados de validação de nomes. Justificativa: nomes científicos longos requerem largura total para leitura. Abas são semanticamente corretas: "monitorar stream" vs. "revisar tabela" são tarefas distintas. Troca automática de aba via `bslib::nav_select` durante e após validação.
- **ADR-040**: Download de relatório de validação de nomes. Função pura `format_validation_report_for_download()`. Colunas DwC-friendly + `input_name` como referência ao dado original.

#### [MODIFY] `docs/LESSONS.md`
- **Shiny/Reactive**: Evitar chamar o mesmo reactive duas vezes no mesmo output — usar variável local.
- **R/Package**: Funções auxiliares privadas com sufixo `_col` como padrão de DRY sem expor API pública.
- **Shiny/UX**: `bslib::nav_select()` permite troca programática de aba em `navset_card_underline`. Usar para guiar o usuário durante fluxos assíncronos (validação → stream → resultados).
- **Design**: Stat-boxes com valores numéricos devem usar `font-family: var(--font-mono)` — números são dados, seguem a regra "Code/Data: Always monospace".

---

## Sequência de Implementação

```
1. utils_taxadb.R         (resolve_query_name_col + format_validation_report_for_download)
2. test-utils-taxadb.R    (edge cases normalize + testes do download)
3. data_dictionary.R      (novas chaves i18n, incluindo validate_names_tab_*)
4. mod_validate_names.R   (4a–4k: novo layout UI + fixes funcionais)
5. custom.css             (sticky sidebar + stat-box classes + all-valid card + stream-input-name)
6. test-mod-validate-names-server.R (regressão dos fixes)
7. CHANGELOG.md + DECISIONS.md + LESSONS.md
```

---

## Plano de Verificação

### Testes Automatizados

```r
devtools::test(filter = "utils-taxadb")        # + novos edge cases
devtools::test(filter = "mod-validate-names")   # + novos cenários
devtools::test(filter = "i18n")                 # novas chaves cobertas
devtools::test(filter = "css-guardrails")       # novos tokens no :root
devtools::check(document = FALSE, manual = FALSE)
```

**Critério de aceite:**
- Todos os testes existentes passando sem regressão.
- Novos cenários de `normalize_scientific_name` (Unicode, híbrido, UPPERCASE) passando.
- `format_validation_report_for_download` testada com colunas esperadas e sem colunas internas.
- `test-css-guardrails.R` passando com novos tokens.
- Zero warnings/notes em `devtools::check()`.

### Verificação Manual no Browser

1. Ir para aba "Nomes Científicos" sem mapeamento → gate desabilitado. **Botão Download desabilitado.**
2. Mapear `scientificName` → botão Validar habilitado. Coluna esquerda mostra providers, options e action no mesmo painel.
3. Rolar a página → **coluna esquerda permanece fixada** (sticky).
4. Clicar Validar (GBIF default):
   - **Aba "🔄 Histórico" ativa automaticamente.**
   - Stream mostra nome original de forma secundária quando diferente do normalizado.
   - Com 500+ nomes: stream mostra até 250 itens (não 100).
5. Pós-validação:
   - **Aba "📋 Resultados" ativa automaticamente.**
   - Stat-box "Válidos" é **verde** (não azul).
   - **Botão Download habilitado** → CSV com `input_name`, `query_name`, `validation_status`, colunas DwC.
   - Toggle "Mostrar todos" → tabela inclui aceitos.
   - Toggle "Apenas problemas" → tabela só mostra não-aceitos.
   - Tabela tem largura total, nomes longos são legíveis sem scroll horizontal desnecessário.
6. CSV com todos os nomes aceitos → **card de sucesso** com ícone e título (IBM Plex Mono).
7. Trocar idioma PT↔EN: botão de download, tabs, card all-valid e label "Original" no stream mudam.
8. Verificar responsividade: em telas < 992px, coluna esquerda e direita empilham (Bootstrap `col-12`), abas continuam funcionando.
