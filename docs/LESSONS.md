# Lições Aprendidas

Conhecimento reutilizável extraído do desenvolvimento do Finch.
Indexado por **tema** — consulte antes de implementar algo similar.

---

## R Package Structure

- **Linhas vazias no DESCRIPTION** quebram `pkgload::load_all()`. Todo campo deve seguir imediatamente o anterior.
- **Todo pacote usado com `::`** precisa estar no `Imports` do DESCRIPTION. Exemplo: `here`, `jsonlite`.
- **`pkgload::load_all()`** carrega todos os arquivos de `R/` automaticamente — não precisa de `source()` em cada módulo.
- **Diretório de trabalho**: `pkgload::load_all()` precisa ser chamado a partir do diretório que contém `DESCRIPTION`.

## Shiny / Reactive Patterns

- **`renderUI` recria inputs** a cada invalidação. Usar `isolate(input$...)` para preservar valores do usuário entre re-renders.
- **Checkboxes de seleção única**: `checkboxGroupInput` + `observeEvent` no server para forçar single-select. Mantém a estética de checkbox quadrado.
- **Loops bloqueantes** em Shiny síncrono não atualizam UI durante execução. Progresso real requer HTML estático + atualização JS client-side.
- **`shiny::toJSON`** pode não estar disponível em todas as versões. Preferir `jsonlite::toJSON(...)` com dependência declarada.
- **`uiOutput` em `placeholder`** de `fileInput` não funciona. Usar `update*` no server.

## CSS / Bootstrap / bslib

- **`fileInput` gera `input-group`** do Bootstrap. Não forçar flex externo — estilizar o `input-group` diretamente.
- **Variáveis CSS referenciadas no código devem existir no `:root`**. Gradientes com variáveis indefinidas resultam em UI invisível (ex: texto branco em fundo transparente).
- **Cores de botão** precisam de `!important` para sobrescrever temas `bslib`.
- **`border-radius` em inputs conectados**: primeiro elemento `X 0 0 X`, segundo `0 X X 0`.
- **`backdrop-filter: blur()`** em modais cria efeito "debaixo d'água" indesejado. Usar escurecimento simples (`rgba(0,0,0,0.45)`).
- **Scroll container**: usar `scrollbar-gutter: stable` para evitar sobreposição da barra de rolagem sobre conteúdo.

## i18n / Internacionalização

- **Todo texto visível** deve passar por `tr(key, lang_r())`. Strings inline do tipo `if (lang == "pt") "X" else "Y"` violam o sistema i18n.
- **Encoding UTF-8** deve ser verificado ao editar `data_dictionary.R`. Caracteres como `ó`, `ã`, `ç` podem corromper se o editor salvar em Latin-1.
- **Placeholder de `selectInput`** não aceita `uiOutput` — usar `update*Input()` no server.

## DwC / Dados de Biodiversidade

- **Separador de entrada**: `;` (padrão brasileiro). Vírgula NÃO é delimitador de tokens.
- **Separador de saída DwC**: ` | ` (pipe com espaços).
- **`scientificName`** é campo de seleção única — não aceitar múltiplas colunas.
- **Derivação taxonômica**: a partir de `scientificName`, é possível derivar `genus`, `specificEpithet` e `taxonRank`. Regra: apenas completar campos vazios/NA, nunca sobrescrever.
- **`eventDate` com 4 colunas**: parser especial (startMonth, startYear, endMonth, endYear) → `YYYY-MM/YYYY-MM`. Em falha, manter valor bruto sem bloquear.
- **Licenças Creative Commons** têm múltiplas formas de URL. Normalizar removendo `http(s)://`, `/legalcode`, e `/` final antes de comparar.
- **NA no CSV exportado**: usar `readr::write_csv(na = "")` para produzir células vazias.

## Performance

- **`sapply()` element-wise** é lento com 99k+ linhas. Vetorizar parsing de datas testando cada formato em lote.
- **RDS estático** (como `dwc_terms.rds`) não deve ser relido do disco a cada mudança reativa. Cachear na primeira leitura.

## Testes

- **`testthat.R`** na raiz de `tests/` é o runner padrão do pacote.
- **Testes de regressão**: ao corrigir bug de badges/estado reativo, adicionar teste que alterna filtros e verifica estabilidade.
- **Funções puras em `utils_*.R`** devem ser testáveis sem carregar Shiny. Extrair lógica dos módulos para utilities.

## Package Check / Deploy

- Em pacote R, evitar `source()` dentro de arquivos em `R/`; carregar funções via namespace previne divergência entre ambiente dev e tarball.
- Em testes executados por `R CMD check`, não depender de caminho local para `R/*.R`; preferir `getFromNamespace()` para funções internas.
- Para arquivos de teste (ex.: RDS), preferir `system.file(..., package = "finch")` com fallback de desenvolvimento quando necessário.
- Ao adicionar chamadas `pkg::fun()`, garantir dependência declarada em `Imports` para evitar warning de dependência não declarada.