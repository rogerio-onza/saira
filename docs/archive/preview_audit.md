# Auditoria e Melhorias da Aba de Pré-visualização

## Contexto

A aba **Pré-visualização** (`mod_preview.R`, 122 linhas) é a interface onde o usuário inspeciona a tabela DwC montada antes de exportar. Após auditoria completa do código, CSS, i18n e fluxo de dados, identificamos **9 pontos de melhoria** organizados em 6 ondas.

> [!IMPORTANT]
> A aba atual está funcional mas minimalista: mostra título/subtítulo, botão de download e `DT::datatable` com 100 linhas. Não há dashboard de qualidade, feedback de progresso no export, nem CSS dedicado para a aba.

---

## Achados da Auditoria

### Problemas Identificados

| # | Área | Problema | Severidade |
|---|------|----------|------------|
| 1 | **UI/UX** | Sem painel de resumo (stats) antes da tabela — o usuário não sabe quantos campos foram mapeados, quantas linhas tem o dataset, etc. | Alta |
| 2 | **UI/UX** | Botão de download usa `uiOutput` dentro de `downloadButton` para o label — renderização frágil; ícone + texto podem não aparecer | Média |
| 3 | **UI/UX** | Sem indicadores visuais de qualidade por coluna (colunas vazias, colunas com muitos NAs) | Média |
| 4 | **UX** | Sem feedback de progresso durante export de datasets grandes (download silencioso) | Média |
| 5 | **i18n** | Faltam chaves DT: `paginate.first`, `paginate.last`, `paginate.next`, `paginate.previous`, `emptyTable`, `zeroRecords` | Baixa |
| 6 | **CSS** | Nenhum CSS dedicado para a aba Preview — tabela usa estilos genéricos de DataTables | Baixa |
| 7 | **Performance** | O reactive `preview_data` roda `abbreviate_license_column()` em cada invalidação, mas como já processa apenas 100 linhas, impacto é mínimo ✅ | Nenhuma |
| 8 | **Testes** | Sem testes para `mod_preview` — sem cobertura de lógica de preview ou export | Média |
| 9 | **Design** | O empty state ("Nenhum dado para visualizar") é muito simples — sem ícone grande, sem orientação de próximo passo | Baixa |

### Pontos Positivos (já corretos) ✅

- Separação Preview (fast, 100 rows) vs Export (complete) — ADR-002
- License abbreviation via pure function (`abbreviate_license_column`) — ADR-008
- DataTable labels bilíngues (`search`, `lengthMenu`, `info`)
- Chain of Reactivity respeitada: recebe `mapped_data` do `mod_mapping`
- Retorno explícito (`return(preview_data)`)
- Export usa `readr::write_csv(na = "")` — LESSONS.md

---

## Proposed Changes

### Onda 1 — Painel de Prontidão para Exportação

O foco deste painel é responder objetivamente: **"Meus dados estão prontos para submissão?"**. Nenhuma métrica genérica — apenas indicadores acionáveis que o pesquisador precisa verificar antes de enviar dados ao GBIF/SiBBr.

#### [MODIFY] [mod_preview.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/mod_preview.R)

**UI**: Adicionar `uiOutput(ns("readiness_panel"))` entre o subtítulo e a tabela.

**Server**: Novo render calculando métricas do `mapped_data_r()` completo (não do preview de 100 linhas):

| Stat Box | Métrica | Cálculo | Por que útil? |
|----------|---------|---------|---------------|
| **Registros** | Total de linhas | `nrow(df)` | Conferir se o dataset está completo |
| **Com Coordenadas** | % de linhas com lat+lon preenchidos | `sum(!is.na(lat) & !is.na(lon)) / nrow(df) * 100` | Dados sem coordenadas não aparecem em mapas |
| **Com Data** | % de linhas com eventDate preenchido | `sum(!is.na(eventDate) & nzchar(eventDate)) / nrow(df) * 100` | Temporal coverage é critério de qualidade GBIF |
| **IDs Únicos** | occurrenceID sem duplicatas | `"✓"` se todos únicos, `"X duplicatas"` se houver | Duplicatas impedem ingestão em repositórios |

Abaixo dos stat boxes, **checklist de campos obrigatórios** compacta:

Para cada campo obrigatório DwC (`scientificName`, `eventDate`, `decimalLatitude`, `decimalLongitude`, `basisOfRecord`, `occurrenceID`), mostrar um chip com ícone:
- ✅ verde se a coluna existe E tem ≥1 valor preenchido
- ❌ vermelho se a coluna não existe no dataset mapeado

Isso dá ao pesquisador um "checklist visual de prontidão" sem precisar scrollar a tabela inteira.

Usa o mesmo estilo `.stats-container` + `.stat-box` da Home para consistência visual. A checklist usa chips com estilo `.dwc-term-chip` já existente (mesmo padrão da Home).

#### [MODIFY] [data_dictionary.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/data_dictionary.R)

Novas chaves i18n:
```r
preview_stats_total_rows = list(pt = "Registros", en = "Records")
preview_stats_with_coords = list(pt = "Com Coordenadas", en = "With Coordinates")
preview_stats_with_date = list(pt = "Com Data", en = "With Date")
preview_stats_unique_ids = list(pt = "IDs \u00DAnicos", en = "Unique IDs")
preview_stats_duplicates = list(pt = "%s duplicatas", en = "%s duplicates")
preview_readiness_title = list(pt = "Campos obrigat\u00F3rios", en = "Required fields")
preview_readiness_present = list(pt = "presente", en = "present")
preview_readiness_missing = list(pt = "ausente", en = "missing")
```

---

### Onda 2 — Download Button Fix + Feedback de Export

#### [MODIFY] [mod_preview.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/mod_preview.R)

**Fix do botão de download**: O label do `downloadButton` atual usa `uiOutput` aninhado, que é frágil. Substituir por `renderUI` que gera o `downloadButton` inteiro com label fixo via `tr()`:

```r
output$download_btn_container <- shiny::renderUI({
    shiny::downloadButton(
        outputId = ns("download"),
        label = shiny::tagList(
            shiny::icon("download"),
            " ",
            tr("preview_download", lang_r())
        ),
        class = "btn-success"
    )
})
```

No UI, trocar o `downloadButton` estático por `uiOutput(ns("download_btn_container"))`.

**Feedback no export**: Adicionar `shiny::withProgress()` envolvendo o `process_for_export()` para dar feedback visual durante exports grandes:

```r
output$download <- shiny::downloadHandler(
    filename = function() paste0("dwc_export_", Sys.Date(), ".csv"),
    content = function(file) {
        shiny::req(mapped_data_r())
        shiny::withProgress(
            message = tr("preview_exporting", lang_r()),
            value = 0.3,
            {
                full_data <- process_for_export(mapped_data_r())
                shiny::setProgress(0.8)
                readr::write_csv(full_data, file, na = "")
                shiny::setProgress(1)
            }
        )
        shiny::showNotification(tr("success_download", lang_r()), type = "message")
    }
)
```

#### [MODIFY] [data_dictionary.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/data_dictionary.R)

Nova chave:
```r
preview_exporting = list(pt = "Exportando dados...", en = "Exporting data...")
```

---

### Onda 3 — DataTable UX Improvements

#### [MODIFY] [mod_preview.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/mod_preview.R)

**Column formatting**: Adicionar `columnDefs` no DT para:
- Truncar valores longos (>80 chars) com `...` e tooltip completo
- Marcar colunas 100% vazias com header destacado (tom cinza/opaco)

**DT options aprimorados**:
```r
DT::datatable(
    preview_data(),
    options = list(
        pageLength = 25,
        scrollX = TRUE,
        autoWidth = FALSE,
        columnDefs = list(
            list(
                targets = "_all",
                render = DT::JS(
                    "function(data, type, row, meta) {",
                    "  if (type === 'display' && data !== null && data.length > 80) {",
                    "    return '<span title=\"' + data + '\">' + data.substr(0, 80) + '...</span>';",
                    "  }",
                    "  return data;",
                    "}"
                )
            )
        ),
        language = list(
            search = tr("preview_datatable_search", lang_r()),
            lengthMenu = tr("preview_datatable_length_menu", lang_r()),
            info = tr("preview_datatable_info", lang_r()),
            emptyTable = tr("preview_datatable_empty", lang_r()),
            zeroRecords = tr("preview_datatable_zero_records", lang_r()),
            paginate = list(
                first = tr("preview_datatable_first", lang_r()),
                last = tr("preview_datatable_last", lang_r()),
                `next` = tr("preview_datatable_next", lang_r()),
                previous = tr("preview_datatable_prev", lang_r())
            )
        )
    ),
    class = "display compact stripe",
    rownames = FALSE
)
```

---

### Onda 4 — Empty State Aprimorado

#### [MODIFY] [mod_preview.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/mod_preview.R)

Substituir o empty state simples por um card visual com ícone grande e orientação:

```r
shiny::div(
    class = "preview-empty-state",
    shiny::icon("table", class = "fa-3x"),
    shiny::h4(tr("preview_no_data_title", lang_r())),
    shiny::p(tr("preview_no_data", lang_r()))
)
```

#### [MODIFY] [data_dictionary.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/data_dictionary.R)

Nova chave:
```r
preview_no_data_title = list(
    pt = "Nenhum dado mapeado",
    en = "No mapped data"
)
```

#### [MODIFY] [custom.css](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/inst/app/www/custom.css)

Adicionar seção dedicada ao Preview:
```css
/* =============================================================================
   PREVIEW TAB
   ============================================================================= */

/* Stats panel reuses .stats-container + .stat-box from Homepage */

/* Empty state */
.preview-empty-state {
  text-align: center;
  padding: var(--space-12) var(--space-6);
  color: var(--accent);
  opacity: 0.7;
}

.preview-empty-state i {
  color: var(--border-strong);
  margin-bottom: var(--space-4);
}

.preview-empty-state h4 {
  color: var(--text-primary);
  margin-bottom: var(--space-2);
}

.preview-empty-state p {
  font-size: var(--text-sm);
}

/* Column indicating 100% empty */
.preview-col-empty {
  opacity: 0.4;
  font-style: italic;
}

/* Truncated cell tooltip */
.dataTable td span[title] {
  cursor: help;
  border-bottom: 1px dotted var(--border-default);
}
```

---

### Onda 5 — i18n Completeness

#### [MODIFY] [data_dictionary.R](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/R/data_dictionary.R)

Adicionar todas as chaves DT faltantes:
```r
preview_datatable_empty = list(
    pt = "Nenhum registro na tabela",
    en = "No records available"
)
preview_datatable_zero_records = list(
    pt = "Nenhum registro encontrado",
    en = "No matching records found"
)
preview_datatable_first = list(pt = "Primeira", en = "First")
preview_datatable_last = list(pt = "\u00DAltima", en = "Last")
preview_datatable_next = list(pt = "Pr\u00F3xima", en = "Next")
preview_datatable_prev = list(pt = "Anterior", en = "Previous")
```

---

### Onda 6 — Documentação

#### [MODIFY] [CHANGELOG.md](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/CHANGELOG.md)

Nova entrada em `[Unreleased]` ou nova versão com seções `Adicionado`, `Alterado`, `Corrigido`.

#### [MODIFY] [DECISIONS.md](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/docs/DECISIONS.md)

Novo ADR-019 documentando as decisões de UI do Preview tab (stats panel, empty state, truncation).

#### [MODIFY] [LESSONS.md](file:///c:/Users/Admin/OneDrive/Finch%20-%20Claude/finch/docs/LESSONS.md)

Novas lições sobre:
- `downloadButton` com label dinâmico via `renderUI` container
- `DT::datatable` language object completeness para i18n
- Column quality indicators no preview

---

## Verification Plan

### Automated Tests

```bash
cd c:\Users\Admin\OneDrive\Finch - Claude\finch
Rscript -e "devtools::test()"
```

O baseline atual (812 testes) deve permanecer 100% verde. As ondas propostas não alteram lógica de negócios em `utils_*.R`, então não devem quebrar testes existentes.

### Manual Verification

> [!TIP]
> A verificação visual é essencial para esta task, já que as mudanças são primariamente de UI/UX.

1. **Iniciar o app**:
   - Abrir RStudio no projeto `finch`
   - Executar `devtools::load_all(); run_app()`

2. **Carregar CSV de teste** na aba Home (de preferência um dataset com 1000+ linhas para testar performance do stats panel)

3. **Fazer mapeamento parcial** (mapear apenas 3-4 campos DwC) e navegar para aba **Pré-visualização**

4. **Verificar Stats Panel**: Confirmar que exibe 4 stat boxes com valores coerentes (registros, campos, completude, colunas vazias)

5. **Verificar DataTable**:
   - Paginação bilíngue (mudar idioma e verificar "Próxima/Next", "Anterior/Previous")
   - Buscar funciona com label correto
   - Células com texto longo mostram truncamento com `...` e tooltip ao hover

6. **Verificar Download**:
   - Clicar "Baixar CSV Completo"
   - Verificar que barra de progresso aparece durante export
   - Verificar que notificação verde "Download iniciado!" aparece ao final
   - Abrir CSV e confirmar dados completos (não truncados a 100 linhas)

7. **Verificar Empty State**:
   - Navegar para Preview **sem** ter feito mapeamento
   - Confirmar que mostra ícone centralizado, título e mensagem orientando o usuário

8. **Verificar troca de idioma** (PT ↔ EN) em todas as strings novas
