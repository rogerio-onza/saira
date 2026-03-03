# Plano de Auditoria e Melhoria — Saira (CRAN Readiness)

## Contexto

O Saira é um pacote R de padronização de dados de biodiversidade para Darwin Core, com motor de mapeamento automático (Rostrum), banco SQLite de aprendizado e UI bilíngue (PT/EN). O objetivo desta auditoria é preparar o código para submissão ao CRAN, garantindo alta qualidade, performance, legibilidade e manutenibilidade. Os achados cobrem bugs reais, violações de padrões CRAN, redundâncias, documentação desatualizada, SQL sem índices e CSS com problemas de design system. As ondas abaixo estão ordenadas por urgência (bloqueadores primeiro) e coesão temática.

---

## Ondas de Implementação

### Onda 0 — Bloqueadores CRAN (pré-requisitos obrigatórios)

**Problema**: Estes itens causam rejeição automática pelo CRAN. Devem ser corrigidos antes de qualquer outra coisa.

**Arquivos principais**: `DESCRIPTION`, `app.R`, `R/run_app.R`, `.Rbuildignore`, `tests/testthat/test-e2e-flows.R`

#### 0.1 — Campo `Remotes:` proibido no CRAN
- `DESCRIPTION` linha 36: `Remotes: ropensci/rnaturalearthhires` — CRAN rejeita submissões com `Remotes:`. Remover esta linha.
- `rnaturalearthhires` mover de `Imports` → `Suggests` (já existe fallback para `scale = 50` em `utils_coords.R`).
- Confirmar que o fallback em `utils_coords.R` está ativo e testado.

#### 0.2 — Metadata obrigatória ausente
- `DESCRIPTION`: substituir `email = "rogerio@example.com"` por e-mail real do mantenedor.
- `DESCRIPTION`: adicionar campos `URL:` e `BugReports:` (GitHub ou similar).
- `DESCRIPTION`: remover `LazyData: true` (deprecated no R 4.0+, sem dados em `data/` que precisem de lazy loading após migração para `inst/extdata`).

#### 0.3 — `pkgload::load_all()` em `app.R`
- `app.R` usa `pkgload::load_all()` para desenvolvimento. Em produção instalado do CRAN, isso falha ou não faz sentido.
- Tornar condicional: envolver em `if (requireNamespace("pkgload", quietly = TRUE) && !isNamespaceLoaded("saira")) { pkgload::load_all(quiet = TRUE) }`.
- Garantir que `app.R` como entry-point seja transparente para usuário final vs. desenvolvedor.

#### 0.4 — `.claude/` não excluído do build
- `.Rbuildignore`: adicionar `^\.claude$` para evitar que arquivos de configuração do Claude Code sejam incluídos no tarball CRAN.

#### 0.5 — Bug real de teste E2E (assertion desativada)
- `tests/testthat/test-e2e-flows.R`: `expect_true(nchar(upload_html) > 0L || TRUE)` — o `|| TRUE` torna o assert sempre verdadeiro (bug silencioso). Remover `|| TRUE`.

---

### Onda 1 — Bugs e Violações de Código R

**Problema**: Padrões proibidos ou perigosos no código R que violam boas práticas CRAN e podem causar comportamento inesperado.

**Arquivos principais**: `R/utils_coords.R`, `R/utils_mapping.R`, `R/utils_taxadb.R`, `R/utils_rostrum_db.R`

#### 1.1 — Eliminar `<<-` de código de pacote
CRAN desencoraja `<<-` fora de closures com escopo explícito e bem definido. Locais identificados:

- `R/utils_coords.R` (dentro de `apply_layer()` aninhada): substituir por retorno explícito acumulado fora do loop.
- `R/utils_mapping.R` (2 locais em closures de scoring): refatorar para usar variável local com `local()` ou retorno por referência via environment explícito.
- `R/utils_taxadb.R` (3 locais em `tryCatch` error handlers): usar variável de resultado no escopo correto, inicializada antes do `tryCatch`.

**Padrão substituto recomendado**:
```r
# Em vez de <<- dentro de tryCatch
result <- NULL
tryCatch({
  result <- compute()
}, error = function(e) {
  result <<- fallback_value  # RUIM
})

# Melhor: variável no escopo correto
result <- tryCatch(compute(), error = function(e) fallback_value)
```

#### 1.2 — Acesso privado a namespace de pacote externo
- `R/utils_coords.R`: `get(fun_name, envir = asNamespace("CoordinateCleaner"), inherits = FALSE)` acessa funções privadas do CoordinateCleaner por nome dinâmico. CRAN pode rejeitar isso.
- Substituir pela API pública: `CoordinateCleaner::cc_val()`, `CoordinateCleaner::cc_sea()`, etc. com `match.arg()` para validar o nome da função antes da chamada.

#### 1.3 — Edge cases sem guarda de `NULL`/`NA`
- `R/utils_coords.R` linha ~63: `path <- candidates[file.exists(candidates)][1]` — se nenhum arquivo existir, `path` é `NA`. Adicionar `if (is.na(path)) stop("arquivo não encontrado")`.
- `R/utils_rostrum_db.R` linha ~141: `version <- query$version[[1]]` — se query retorna 0 linhas, `[[1]]` falha. Adicionar `if (nrow(query) == 0) return(NULL)` antes.
- `R/utils_rostrum_db.R` linha ~517: `alias_id <- DBI::dbGetQuery(...)$id[[1]]` — mesmo problema. Guardar resultado da query antes de indexar.

---

### Onda 2 — Performance e Banco de Dados

**Problema**: Oportunidades de melhoria de velocidade sem quebrar contratos existentes.

**Arquivos principais**: `data-raw/rostrum_schema.sql`, `R/utils_rostrum_db.R`, `R/utils_mapping.R`

#### 2.1 — Índices SQL ausentes
- `rostrum_schema.sql`: `rostrum_synonyms` — ausência de índice em `synonym` (coluna de lookup). Adicionar `CREATE INDEX idx_synonyms_value ON rostrum_synonyms(synonym);`.
- `rostrum_schema.sql`: `rostrum_aliases` — adicionar índice composto para consultas de aliases ativos: `CREATE INDEX idx_alias_active ON rostrum_aliases(deprecated, reviewed);`.
- `rostrum_schema.sql`: `rostrum_alias_events` — adicionar índice em `created_at` para auditoria cronológica.

#### 2.2 — Constraint de validade em `confidence`
- `rostrum_schema.sql`: coluna `confidence REAL` sem `CHECK`. Adicionar `CHECK (confidence >= 0.0 AND confidence <= 1.0)` para impedir dados inválidos no banco.

#### 2.3 — Migração de schema com índices novos
- `R/utils_rostrum_db.R`: a migração existente aplica alterações incrementais por versão. Adicionar uma versão de migração que cria os índices faltantes sem recriar tabelas.

---

### Onda 3 — Namespace e Roxygen

**Problema**: CRAN exige que todo uso de função externa esteja declarado via `@importFrom`. O NAMESPACE atual não tem nenhum `importFrom()`.

**Arquivos principais**: Todos os `R/utils_*.R`, `R/mod_*.R`, `NAMESPACE`

#### 3.1 — Adicionar `@importFrom` nos roxygen de cada arquivo
Prioridade de funções mais usadas:
- `jsonlite`: `fromJSON`, `toJSON`
- `DBI`: `dbConnect`, `dbDisconnect`, `dbExecute`, `dbGetQuery`, `dbWithTransaction`
- `RSQLite`: `SQLite`
- `shiny`: funções de módulo (`moduleServer`, `NS`, `reactive`, `reactiveVal`, `observeEvent`, `req`, etc.)
- `digest`: `digest2int`
- `withr`: funções usadas em testes/cleanup
- `readr`: `read_csv`, `write_csv`
- `stringr`: `str_detect`, `str_trim`, `str_split`

**Estratégia**: Adicionar bloco roxygen mínimo em cada arquivo utilitário com `@importFrom` coletivos, e usar `usethis::use_import_from()` ou equivalente para gerar `NAMESPACE` correto via `devtools::document()`.

#### 3.2 — Exportar e documentar funções do Rostrum
- **Decisão do usuário**: as funções do Rostrum serão exportadas publicamente.
- Adicionar `@export` + roxygen completo (`@title`, `@description`, `@param`, `@return`, `@examples`) para:
  - `run_rostrum_engine()` — `R/utils_rostrum_engine.R`
  - `rostrum_options()`, `validate_candidate_df()`, `validate_decision_df()`, `adapt_synonyms_v1_to_v2()` — `R/utils_rostrum_contracts.R`
  - `rostrum_connect()`, `rostrum_seed_synonyms_if_empty()`, `rostrum_load_synonyms_from_db()` — `R/utils_rostrum_db.R`
  - `rostrum_record_alias_confirmation()`, `rostrum_record_alias_override()`, `undo_session_aliases()` — `R/utils_rostrum_db.R`
  - `rostrum_export_template_json()`, `rostrum_import_template_json()`, `rostrum_list_template_catalog()` — `R/utils_rostrum_templates.R`
- Para funções puramente internas (helpers de score, stage steps): adicionar `@keywords internal` + `@noRd`.
- Refatorar todos os testes que usam `getFromNamespace("fn", "saira")` para chamar `saira::fn()` diretamente (após `pkgload::load_all()`). Isso elimina o acoplamento frágil ao namespace privado.

---

### Onda 4 — Limpeza de i18n e CSS

**Problema**: Código morto em i18n e CSS prejudica manutenção e pode confundir contribuidores futuros.

**Arquivos principais**: `inst/extdata/i18n.json`, `inst/app/www/css/14-mapping.css`, CSS em geral

#### 4.1 — Duplicatas com sufixo `.1` no i18n.json
- `i18n.json`: 8+ chaves duplicadas com sufixo `.1` (ex: `"validate_coords_all_valid.1"`). São cópias exatas das chaves sem sufixo. Remover todas as ocorrências com `.1`.
- Adicionar teste de regressão que detecta chaves duplicadas por nome base no JSON.

#### 4.2 — Remover chaves de espanhol não utilizadas
- **Decisão do usuário**: remover agora, sem placeholder.
- `i18n.json`: remover a chave `"lang_es"` e qualquer valor `"es": "..."` em chaves que tenham apenas PT/EN/ES.
- Verificar e remover de `R/utils_i18n.R` / `R/data_dictionary.R` qualquer validação que mencione `"es"` como idioma suportado.
- Adicionar teste de regressão que garante exatamente os idiomas `["pt", "en"]` em todas as chaves (nada a mais, nada a menos).
- Criar ADR documentando a remoção e abrindo espaço para retomada futura controlada.

#### 4.3 — Cores hardcoded no CSS (fora dos tokens)
- `inst/app/www/css/14-mapping.css`: `#e67e22` (badge-ambiguous) e `#8e44ad` (badge-template) não usam variáveis CSS do `00-tokens.css`.
- Adicionar os tokens em `00-tokens.css` e referenciar via `var(--color-badge-ambiguous)` etc.

#### 4.4 — Seletores CSS duplicados
- Múltiplos arquivos CSS definem `.badge`, `.btn-*`, `.card` com overrides parciais.
- Consolidar: cada seletor deve ter uma definição canônica. Overrides contextuais devem usar prefixo de módulo (`.mapping-module .badge`, etc.).

---

### Onda 5 — Documentação Técnica (docs/)

**Problema**: A documentação técnica está significativamente desatualizada em relação ao código atual (que passou por Ondas 0-7 do Rostrum). Isso prejudica contribuidores e usuários do pacote.

**Arquivos principais**: `docs/claude.md`, `docs/architecture.md`, `docs/DECISIONS.md`, `docs/ENCODING_RULES.md`, `docs/LESSONS.md`

#### 5.1 — `docs/claude.md` desatualizado
Múltiplos problemas críticos:
- Seção 2 (File Structure): não lista `utils_coords.R`, `utils_preview.R`, `utils_taxadb.R`, `utils_common.R`, `utils_rostrum_*.R`, `data_dictionary.R`. Lista `data_dictionary.R` como `data/dwc_terms.rds` (que agora é `inst/extdata/`).
- Seção 5 (Stack): menciona `shinyFeedback` que foi removido como dependência.
- Seção 8: menciona `global.R` como alternativa, mas o projeto usa exclusivamente estrutura de pacote.
- Seção 9: regra "Use `here::here()`" — pacote `here` ainda está em `Imports` mas pode ser removido se não for mais necessário.
- Ações: reescrever seção 2 com estrutura atual completa, remover referências a `shinyFeedback`, atualizar regra de `here::here()`.

#### 5.2 — `docs/architecture.md` profundamente desatualizado
- Versão 2.0 de 07/02/2026 — não reflete nenhuma mudança das Ondas 3-7.
- Exemplo de DESCRIPTION no documento tem dependências incorretas (lista `dplyr`, `lubridate`, `shinyFeedback` que foram removidas; não lista `DBI`, `RSQLite`, `digest`, `withr`).
- CSS: descreve arquivo único `custom.css` — agora são 17 módulos.
- Não documenta: motor Rostrum (stages 1-3), aprendizado SQLite, templates V3, paralelização opcional.
- Ação: atualizar seção de dependências, adicionar seção "Motor Rostrum" descrevendo pipeline de 3 stages + SQLite.

#### 5.3 — `docs/DECISIONS.md` com ADRs faltando
- Ondas 3-7 implementaram decisões arquiteturais significativas sem ADRs formais.
- Criar ADRs para:
  - Composição de `scientificName` e `eventDate` (Stage 2)
  - Resolução multicriterio de conflitos (Stage 3)
  - Modelo de aliases SQLite com escopo pessoal/instituição/público
  - Templates V3 com versioning JSON
  - Remoção de `run_automap_v1()` (breaking change documentada)
  - Paralelização opcional via `future`/`furrr`

#### 5.4 — `docs/ENCODING_RULES.md` — adicionar regra sobre `<<-`
- Adicionar regra 10: "Avoid `<<-` in package code. Use explicit environment management or structured return values instead."

#### 5.5 — `docs/LESSONS.md` — adicionar lições CRAN
- Adicionar seção "## CRAN Submission" com lições aprendidas nesta auditoria:
  - `Remotes:` não permitido; usar `Suggests` + fallback gracioso
  - `<<-` em tryCatch handlers: padrão correto
  - `get(fn, envir = asNamespace("pkg"))` — acessar API pública explicitamente
  - `@importFrom` obrigatório para todas as dependências

---

### Onda 6 — Limpeza Final e Polimento CRAN

**Problema**: Itens de baixa criticidade que devem ser resolvidos antes da submissão para evitar `NOTE`s e `WARNING`s do `R CMD CHECK`.

**Arquivos principais**: `R/run_app.R`, `README.md`, `tests/testthat/helper-source-utils.R`, `DESCRIPTION`

#### 6.1 — `launch.browser` hardcoded
- `R/run_app.R`: `launch.browser = TRUE` — substituir por `getOption("shiny.launch.browser", interactive())` para compatibilidade com ambientes headless (Docker, CI/CD, servidor).

#### 6.2 — `here` como dependência necessária
- Verificar se `here::here()` ainda é usado no código atual (suspeita: foi substituído por `system.file()`).
- Se não há uso real: remover de `Imports`. Isso reduz o grafo de dependências.

#### 6.3 — README.md para usuário de pacote instalado
- Seção de instalação mostra `shiny::runApp()` que não funciona para pacote instalado.
- Reescrever com instruções corretas:
  ```r
  # Instalação
  install.packages("saira")  # quando publicado no CRAN
  # Uso
  library(saira)
  run_app()
  ```
- Adicionar seção de instalação de dependências opcionais (`rnaturalearthhires` para precisão costeira).

#### 6.4 — Simplificar `helper-source-utils.R`
- O helper usa múltiplos caminhos candidatos com fallback. Padronizar usando `system.file()` quando o pacote estiver carregado, com fallback para `testthat::test_path()` apenas em dev.
- Reduzir acoplamento a caminhos absolutos de desenvolvimento.

#### 6.5 — Verificação final com `R CMD CHECK`
- Executar `devtools::check()` após todas as ondas e corrigir todos os `ERROR`, `WARNING` e `NOTE` restantes.
- Executar `rhub::check_for_cran()` para validação nos ambientes oficiais.

---

## Arquivos Críticos Modificados por Onda

| Onda | Arquivos Principais |
|------|---------------------|
| 0 | `DESCRIPTION`, `app.R`, `R/run_app.R`, `.Rbuildignore`, `tests/testthat/test-e2e-flows.R` |
| 1 | `R/utils_coords.R`, `R/utils_mapping.R`, `R/utils_taxadb.R`, `R/utils_rostrum_db.R` |
| 2 | `data-raw/rostrum_schema.sql`, `R/utils_rostrum_db.R` |
| 3 | Todos `R/utils_*.R` e `R/mod_*.R`, `NAMESPACE` |
| 4 | `inst/extdata/i18n.json`, `inst/app/www/css/*.css` |
| 5 | `docs/claude.md`, `docs/architecture.md`, `docs/DECISIONS.md`, `docs/ENCODING_RULES.md`, `docs/LESSONS.md` |
| 6 | `R/run_app.R`, `README.md`, `tests/testthat/helper-source-utils.R`, `DESCRIPTION` |

---

## Verificação

Após cada onda executar:
```r
# Após Onda 0:
devtools::check(cran = TRUE)  # Verificar sem ERRORs bloqueadores

# Após Ondas 1-3:
devtools::test()  # Todos os testes devem passar (PASS X, FAIL 0)

# Após Onda 3:
devtools::document()  # Regenerar NAMESPACE com importFrom corretos

# Após Onda 4:
Rscript data-raw/build_css.R  # Rebuild do CSS concatenado se aplicável
# Verificar manualmente que badges template/ambiguous renderizam corretamente

# Após Onda 6 (final):
devtools::check(cran = TRUE)
# Meta: 0 ERROR, 0 WARNING, 0 NOTE (exceto nota sobre tamanho de pacote se aplicável)
```
