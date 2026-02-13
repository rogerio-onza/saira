# Decises de Arquitetura

Registro de decises tcnicas significativas do Finch.
Formato: ADR leve (Architecture Decision Record).

---

## ADR-001: Estrutura de pacote R em vez de `global.R`

- **Data**: 2026-02-08
- **Contexto**: Shiny apps convencionais usam `global.R` + `ui.R` + `server.R`. ?? medida que o Finch cresce em mdulos, precisamos de namespace limpo e testabilidade.
- **Deciso**: Usar estrutura de pacote R com `DESCRIPTION`, `R/`, e entrada via `pkgload::load_all()`.
- **Consequncias**: Namespace automtico, sem `source()` manual, dependncias declaradas, funes testveis com `testthat`.

---

## ADR-002: Preview limitado a 100 linhas, export com dados completos

- **Data**: 2026-02-08
- **Contexto**: Datasets com 99k+ linhas travam `DT::datatable` no navegador.
- **Deciso**: `head(df, 100)` para preview, `process_for_export(df)` com dados completos no download.
- **Consequncias**: UI responsiva mantendo fidelidade total no arquivo exportado.

---

## ADR-003: Separador `;` (entrada) e ` | ` (sada DwC)

- **Data**: 2026-02-11
- **Contexto**: Planilhas brasileiras usam `;` como separador de tokens dentro de clulas. O padro DwC usa ` | ` para campos multivalorados.
- **Deciso**: Split por `;`, join com ` | `. Vrgula nunca  tratada como delimitador de tokens.
- **Alternativas**: Usar `,` como delimitador adicional ??" rejeitado porque interfere com valores de coordenadas decimais (ex: `-23,55`).
- **Consequncias**: Consistente com dados brasileiros. Documentado na tela de upload como recomendao.

---

## ADR-004: `scientificName` como seleo nica

- **Data**: 2026-02-12
- **Contexto**: O `selectInput` genrico permitia mltiplas colunas, gerando `Nome1 | Nome2` ??" invlido como nome taxonmico.
- **Deciso**: `multiple = (term != "scientificName")`. Se houver seleo antiga com mltiplos valores, manter apenas o primeiro.
- **Consequncias**: Derivao automtica de `genus`, `specificEpithet` e `taxonRank` funciona corretamente com valor escalar.

---

## ADR-005: Campos especiais com inputs customizados

- **Data**: 2026-02-11
- **Contexto**: Quatro campos do Record-level (`datasetName`, `modified`, `license`, `language`) no se beneficiam do mapeamento genrico dropdown ??' coluna.
- **Deciso**: Inputs customizados dentro do mesmo `renderUI`:
  - `datasetName`: Dropdown + `textInput` (texto tem prioridade)
  - `modified`: Checkbox "data de hoje" + `dateInput` (sempre visvel)
  - `license`: Checkboxes CC com seleo nica forada
  - `language`: Checkboxes inline (`pt`, `en`, `es`)
- **Consequncias**: UX mais intuitiva, mas necessita `isolate()` para preservar valores entre re-renders.

---

## ADR-006: Motor Rostrum como opt-in via toggle

- **Data**: 2026-02-12
- **Contexto**: O auto-mapping com scoring (name + value)  experimental e pode produzir mapeamentos incorretos.
- **Deciso**: Toggle `bslib::input_switch` desligado por padro. Rtulo "Rostrum (beta)" explicita o estado experimental.
- **Consequncias**: Motor legado continua acessvel. Usurios avanados podem ativar Rostrum conscientemente.

---

## ADR-007: Derivao taxonmica no-destrutiva

- **Data**: 2026-02-12
- **Contexto**: Ao mapear `scientificName`, o sistema pode derivar `genus`, `specificEpithet` e `taxonRank`.
- **Deciso**: Apenas completar campos vazios/NA. Nunca sobrescrever valores j mapeados pelo usurio.
- **Consequncias**: Segurana de dados preservada. Usurio mantm controle total sobre campos preenchidos manualmente.

---

## ADR-008: Licenas abreviadas no preview e export

- **Data**: 2026-02-12
- **Contexto**: Licenas so armazenadas como URLs longas (ex: `https://creativecommons.org/publicdomain/zero/1.0/legalcode`). No preview e no CSV, essas URLs ocupam espao visual excessivo.
- **Deciso**: Normalizar URLs conhecidas para labels curtas (`CC0`, `CC-BY`, `CC-BY-NC`). Valores fora do mapeamento permanecem inalterados.
- **Variantes tratadas**: com/sem `http(s)://`, com/sem `/legalcode`, com/sem `/` final.
- **Consequncias**: Preview legvel e CSV mais limpo, sem perda de informao.

---

## ADR-009: Loading bloqueante com feedback visual client-side

- **Data**: 2026-02-12
- **Contexto**: `withProgress()` do Shiny no bloqueia interao durante processamento. Em Shiny sncrono, loops bloqueantes no atualizam a UI.
- **Deciso**: Modal com `easyClose = FALSE`, barra de progresso em HTML esttico, atualizao via JavaScript client-side com timer.
- **Alternativas**: `shiny::withProgress()` ??" rejeitado por no bloquear UI. `future/promises` ??" complexidade excessiva para o escopo atual.
- **Consequncias**: Feedback visual contnuo mesmo durante processamento pesado. Timer JS limpo no `on.exit()`.
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