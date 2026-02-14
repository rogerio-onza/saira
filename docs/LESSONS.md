# Licoes Aprendidas

Conhecimento reutilizavel extraido do desenvolvimento do Finch.
Indexado por **tema** -- consulte antes de implementar algo similar.

---

## R Package Structure

- **Linhas vazias no DESCRIPTION** quebram `pkgload::load_all()`. Todo campo deve seguir imediatamente o anterior.
- **Todo pacote usado com `::`** precisa estar no `Imports` do DESCRIPTION. Exemplo: `here`, `jsonlite`.
- **`pkgload::load_all()`** carrega todos os arquivos de `R/` automaticamente -- nao precisa de `source()` em cada modulo.
- **Diretorio de trabalho**: `pkgload::load_all()` precisa ser chamado a partir do diretorio que contem `DESCRIPTION`.

## Shiny / Reactive Patterns

- **`renderUI` recria inputs** a cada invalidacao. Usar `isolate(input$...)` para preservar valores do usuario entre re-renders.
- **Checkboxes de selecao unica**: `checkboxGroupInput` + `observeEvent` no server para forcar single-select. Mantem a estetica de checkbox quadrado.
- **Loops bloqueantes** em Shiny sincrono nao atualizam UI durante execucao. Progresso real requer HTML estatico + atualizacao JS client-side.
- **`shiny::toJSON`** pode nao estar disponivel em todas as versoes. Preferir `jsonlite::toJSON(...)` com dependencia declarada.
- **`uiOutput` em `placeholder`** de `fileInput` nao funciona. Usar `update*` no server.

## CSS / Bootstrap / bslib

- **`fileInput` gera `input-group`** do Bootstrap. Nao forcar flex externo -- estilizar o `input-group` diretamente.
- **Variaveis CSS referenciadas no codigo devem existir no `:root`**. Gradientes com variaveis indefinidas resultam em UI invisivel (ex: texto branco em fundo transparente).
- **Cores de botao** precisam de `!important` para sobrescrever temas `bslib`.
- **`border-radius` em inputs conectados**: primeiro elemento `X 0 0 X`, segundo `0 X X 0`.
- **`backdrop-filter: blur()`** em modais cria efeito "debaixo d'agua" indesejado. Usar escurecimento simples (`rgba(0,0,0,0.45)`).
- **Scroll container**: usar `scrollbar-gutter: stable` para evitar sobreposicao da barra de rolagem sobre conteudo.

## i18n / Internacionalizacao

- **Todo texto visivel** deve passar por `tr(key, lang_r())`. Strings inline do tipo `if (lang == "pt") "X" else "Y"` violam o sistema i18n.
- **Encoding UTF-8** deve ser verificado ao editar `data_dictionary.R`. Caracteres acentuados podem corromper se o editor salvar em Latin-1.
- **Placeholder de `selectInput`** nao aceita `uiOutput` -- usar `update*Input()` no server.

## DwC / Dados de Biodiversidade

- **Separador de entrada**: `;` (padrao brasileiro). Virgula NAO eh delimitador de tokens.
- **Separador de saida DwC**: ` | ` (pipe com espacos).
- **`scientificName`** eh campo de selecao unica -- nao aceitar multiplas colunas.
- **Derivacao taxonomica**: a partir de `scientificName`, eh possivel derivar `genus`, `specificEpithet` e `taxonRank`. Regra: apenas completar campos vazios/NA, nunca sobrescrever.
- **`eventDate` com 4 colunas**: parser especial (startMonth, startYear, endMonth, endYear) -> `YYYY-MM/YYYY-MM`. Em falha, manter valor bruto sem bloquear.
- **Licencas Creative Commons** tem multiplas formas de URL. Normalizar removendo `http(s)://`, `/legalcode`, e `/` final antes de comparar.
- **NA no CSV exportado**: usar `readr::write_csv(na = "")` para produzir celulas vazias.

## Performance

- **`sapply()` element-wise** eh lento com 99k+ linhas. Vetorizar parsing de datas testando cada formato em lote.
- **`as.Date(..., format=...)` sem mascara previa** pode aceitar entradas parcialmente e gerar anos incorretos (ex: `0023`). Usar regex estrita por formato antes de parsear.
- **Ano com 2 digitos (`DD/MM/YY`)** precisa de regra de seculo explicita. No Finch: cutoff dinamico (`YY <= ano atual (2d) -> 20YY`, senao `19YY`).
- **RDS estatico** (como `dwc_terms.rds`) nao deve ser relido do disco a cada mudanca reativa. Cachear na primeira leitura.

## Testes

- **`testthat.R`** na raiz de `tests/` eh o runner padrao do pacote.
- **Testes de regressao**: ao corrigir bug de badges/estado reativo, adicionar teste que alterna filtros e verifica estabilidade.
- **Funcoes puras em `utils_*.R`** devem ser testaveis sem carregar Shiny. Extrair logica dos modulos para utilities.

## Package Check / Deploy

- Em pacote R, evitar `source()` dentro de arquivos em `R/`; carregar funcoes via namespace previne divergencia entre ambiente dev e tarball.
- Em testes executados por `R CMD check`, nao depender de caminho local para `R/*.R`; preferir `getFromNamespace()` para funcoes internas.
- Para arquivos de teste (ex.: RDS), preferir `system.file(..., package = "finch")` com fallback de desenvolvimento quando necessario.
- Ao adicionar chamadas `pkg::fun()`, garantir dependencia declarada em `Imports` para evitar warning de dependencia nao declarada.
