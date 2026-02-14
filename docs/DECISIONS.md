# Decisoes de Arquitetura

Registro de decisoes tecnicas significativas do Finch.
Formato: ADR leve (Architecture Decision Record).

---

## ADR-001: Estrutura de pacote R em vez de `global.R`

- **Data**: 2026-02-08
- **Contexto**: Shiny apps convencionais usam `global.R` + `ui.R` + `server.R`. A medida que o Finch cresce em modulos, precisamos de namespace limpo e testabilidade.
- **Decisao**: Usar estrutura de pacote R com `DESCRIPTION`, `R/`, e entrada via `pkgload::load_all()`.
- **Consequencias**: Namespace automatico, sem `source()` manual, dependencias declaradas, funcoes testaveis com `testthat`.

---

## ADR-002: Preview limitado a 100 linhas, export com dados completos

- **Data**: 2026-02-08
- **Contexto**: Datasets com 99k+ linhas travam `DT::datatable` no navegador.
- **Decisao**: `head(df, 100)` para preview, `process_for_export(df)` com dados completos no download.
- **Consequencias**: UI responsiva mantendo fidelidade total no arquivo exportado.

---

## ADR-003: Separador `;` (entrada) e ` | ` (saida DwC)

- **Data**: 2026-02-11
- **Contexto**: Planilhas brasileiras usam `;` como separador de tokens dentro de celulas. O padrao DwC usa ` | ` para campos multivalorados.
- **Decisao**: Split por `;`, join com ` | `. Virgula nunca eh tratada como delimitador de tokens.
- **Alternativas**: Usar `,` como delimitador adicional -- rejeitado porque interfere com valores de coordenadas decimais (ex: `-23,55`).
- **Consequencias**: Consistente com dados brasileiros. Documentado na tela de upload como recomendacao.

---

## ADR-004: `scientificName` como selecao unica

- **Data**: 2026-02-12
- **Contexto**: O `selectInput` generico permitia multiplas colunas, gerando `Nome1 | Nome2` -- invalido como nome taxonomico.
- **Decisao**: `multiple = (term != "scientificName")`. Se houver selecao antiga com multiplos valores, manter apenas o primeiro.
- **Consequencias**: Derivacao automatica de `genus`, `specificEpithet` e `taxonRank` funciona corretamente com valor escalar.

---

## ADR-005: Campos especiais com inputs customizados

- **Data**: 2026-02-11
- **Contexto**: Quatro campos do Record-level (`datasetName`, `modified`, `license`, `language`) nao se beneficiam do mapeamento generico dropdown -> coluna.
- **Decisao**: Inputs customizados dentro do mesmo `renderUI`:
  - `datasetName`: Dropdown + `textInput` (texto tem prioridade)
  - `modified`: Checkbox "data de hoje" + `dateInput` (sempre visivel)
  - `license`: Checkboxes CC com selecao unica forcada
  - `language`: Checkboxes inline (`pt`, `en`, `es`)
- **Consequencias**: UX mais intuitiva, mas necessita `isolate()` para preservar valores entre re-renders.

---

## ADR-006: Motor Rostrum como opt-in via toggle

- **Data**: 2026-02-12
- **Contexto**: O auto-mapping com scoring (name + value) eh experimental e pode produzir mapeamentos incorretos.
- **Decisao**: Toggle `bslib::input_switch` desligado por padrao. Rotulo "Rostrum (beta)" explicita o estado experimental.
- **Consequencias**: Motor legado continua acessivel. Usuarios avancados podem ativar Rostrum conscientemente.

---

## ADR-007: Derivacao taxonomica nao-destrutiva

- **Data**: 2026-02-12
- **Contexto**: Ao mapear `scientificName`, o sistema pode derivar `genus`, `specificEpithet` e `taxonRank`.
- **Decisao**: Apenas completar campos vazios/NA. Nunca sobrescrever valores ja mapeados pelo usuario.
- **Consequencias**: Seguranca de dados preservada. Usuario mantem controle total sobre campos preenchidos manualmente.

---

## ADR-008: Licencas abreviadas no preview e export

- **Data**: 2026-02-12
- **Contexto**: Licencas sao armazenadas como URLs longas (ex: `https://creativecommons.org/publicdomain/zero/1.0/legalcode`). No preview e no CSV, essas URLs ocupam espaco visual excessivo.
- **Decisao**: Normalizar URLs conhecidas para labels curtas (`CC0`, `CC-BY`, `CC-BY-NC`). Valores fora do mapeamento permanecem inalterados.
- **Variantes tratadas**: com/sem `http(s)://`, com/sem `/legalcode`, com/sem `/` final.
- **Consequencias**: Preview legivel e CSV mais limpo, sem perda de informacao.

---

## ADR-009: Loading bloqueante com feedback visual client-side

- **Data**: 2026-02-12
- **Contexto**: `withProgress()` do Shiny nao bloqueia interacao durante processamento. Em Shiny sincrono, loops bloqueantes nao atualizam a UI.
- **Decisao**: Modal com `easyClose = FALSE`, barra de progresso em HTML estatico, atualizacao via JavaScript client-side com timer.
- **Alternativas**: `shiny::withProgress()` -- rejeitado por nao bloquear UI. `future/promises` -- complexidade excessiva para o escopo atual.
- **Consequencias**: Feedback visual continuo mesmo durante processamento pesado. Timer JS limpo no `on.exit()`.

---

## ADR-010: Package-safe loading sem `source()` em `R/` e testes tarball-safe

- **Data**: 2026-02-13
- **Contexto**: O `devtools::check(document = FALSE, manual = FALSE)` falhava no tarball porque helper de teste carregava `R/*.R` por caminho local, e havia uso de `source(here::here(...))` dentro de arquivos em `R/`.
- **Decisao**:
  - Remover `source()` de todos os arquivos em `R/` e confiar no namespace do pacote.
  - Resolver `i18n_dict` em `tr()` via ambiente/namespace (`asNamespace("finch")`) em vez de leitura por `source()`.
  - Em testes, substituir carregamento por path local de `R/*.R` por `getFromNamespace()` e usar `system.file(..., package = "finch")` para arquivos de dados com fallback de desenvolvimento.
  - Declarar explicitamente `jsonlite` em `Imports` e usar `utils::head(...)` em preview para evitar warning de global function.
- **Alternativas**:
  - Manter `source()` condicional por ambiente de desenvolvimento - rejeitado por fragilidade em `R CMD check` e comportamento divergente entre dev e tarball.
  - Copiar funcoes para dentro dos testes - rejeitado por duplicar logica e aumentar custo de manutencao.
- **Consequencias**:
  - `check` deixa de falhar por erro estrutural de testes/deploy.
  - Fluxo de carga fica consistente entre desenvolvimento, instalacao e check.
  - Testes ficam menos acoplados ao layout local do projeto.

---

## ADR-011: Qualificacao explicita de isolate e limpeza de Imports nao usados

- **Data**: 2026-02-13
- **Contexto**: Apos Onda 1, o `R CMD check` ainda reportava NOTES por `Imports` nao usados (`dplyr`, `lubridate`, `shinyFeedback`) e por `isolate` sem namespace explicito em `mod_mapping`.
- **Decisao**:
  - Remover de `DESCRIPTION` pacotes em `Imports` sem uso real no codigo.
  - Qualificar chamadas reativas como `shiny::isolate(...)` para evitar ambiguidades no check.
- **Alternativas**:
  - Manter pacotes "reservados" em `Imports` para uso futuro - rejeitado por gerar ruido no check e mascarar dependencias reais.
  - Usar `importFrom(shiny, isolate)` em NAMESPACE - rejeitado neste ciclo por preferencia de namespace explicito no ponto de uso.
- **Consequencias**:
  - `checking dependencies in R code ... OK`.
  - `checking R code for possible problems ... OK` (sem NOTE de `isolate`).
  - Mantem-se apenas o warning conhecido de non-ASCII (fora do escopo desta onda).

---

## ADR-012: Vetorizacao de parsing de datas com cutoff dinamico para `DD/MM/YY`

- **Data**: 2026-02-14
- **Contexto**: O baseline da Onda 0 mostrou custo alto no parsing de datas em 100k linhas (`parse_dates_to_iso()` e `fix_dates_to_iso()`). Tambem havia comportamento ambiguo para ano com 2 digitos (`DD/MM/YY`) e risco de parse parcial sem mascara estrita.
- **Decisao**:
  - Vetorizar `parse_dates_to_iso()` por formato com mascaras regex estritas.
  - Em `DD/MM/YY`, aplicar cutoff dinamico por ano atual: `YY <= ano_atual_2d -> 20YY`, senao `19YY`.
  - Refatorar `fix_dates_to_iso()` para delegar parsing ao parser vetorizado.
  - Preservar semantica de export: em valor invalido nao vazio, manter valor bruto; em `NA`/`""`, manter `NA`.
- **Alternativas**:
  - Manter loop element-wise com `sapply()` e `for` - rejeitado por custo alto em datasets grandes.
  - Usar cutoff fixo (ex: 70) - rejeitado por ser menos aderente ao contexto temporal atual definido para o projeto.
  - Tratar `YY` sempre como invalido - rejeitado por piorar compatibilidade com dados legados ja usados no fluxo.
- **Consequencias**:
  - Ganho mensuravel de performance em benchmark 100k (Onda 3).
  - Comportamento de seculo para `YY` documentado e testado, sem ambiguidade implícita.
  - Fluxo de export mantem compatibilidade funcional para invalidos nao vazios.

---

## ADR-013: Centralizar montagem de `processed_data` em utilitario puro de mapping

- **Data**: 2026-02-14
- **Contexto**: `mod_mapping` concentrava logica de transformacao de dados dentro de `processed_data` reactive, dificultando testes unitarios fora de Shiny e aumentando acoplamento com estado de interface.
- **Decisao**:
  - Extrair para `R/utils_mapping.R` a funcao pura `build_processed_mapping_df(...)` com retorno composto (`data` + `eventdate_failure_count`).
  - Extrair helpers puros de estado/selecao (`has_selected_value`, `sanitize_map_selection`, `default_meta`, `empty_map_values`, `empty_map_meta`, `build_manual_meta`).
  - Manter em `mod_mapping` apenas wiring reativo, atualizacao de inputs, renderizacao e sincronizacao de `rv$eventdate_parse_failures`.
- **Alternativas**:
  - Manter toda a montagem no reactive do modulo - rejeitado por baixa testabilidade e alto acoplamento.
  - Extrair tambem logica de badges/UI na mesma onda - rejeitado neste ciclo para reduzir risco funcional.
- **Consequencias**:
  - A montagem final de dados passa a ser testavel por `testthat` sem `testServer`.
  - Contrato publico do modulo permanece inalterado (`mod_mapping_server()` retorna `reactive(data.frame)`).
  - Regressao de estado reativo continua coberta por testes de modulo.
