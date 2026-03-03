# Plano Mestre Rostrum Engine V1→V4+ (Ondas + PRs, com SQLite desde V1)

## Resumo
Este plano implementa o `rostrum_engine.md` de forma completa (V1→V4+), mantendo política conservadora de risco, rollout opt-in até V3, e migração controlada com breaking changes planejadas.
A execução será em ondas com PRs pequenos e testáveis, alinhada a `claude.md`, `architecture.md`, `skill.md`, `design.md`, `DECISIONS.md`, `LESSONS.md` e `CHANGELOG.md`.

> **Atualizado com auditoria técnica (2026-03-01)**: 4 issues críticos, 6 altos, 8 médios e 4 baixos identificados no plano original. Todas as correções estão integradas nas ondas abaixo sem alterar a estrutura de PRs.

## Decisões Fechadas (já definidas)
- Escopo: V1→V4+ completo.
- Política de risco: conservadora (prioriza precisão e revisão humana).
- Formato: ondas + PRs.
- Compatibilidade: breaking changes controladas.
- Persistência: SQLite desde V1.
- Rollout: toggle `Rostrum (beta)` continua opt-in até V3.

## Baseline Atual (estado real do repositório)
- Motor atual V1 está em `R/utils_mapping.R`, com `run_automap_v1()` e thresholds `AUTO>=0.90`, `SUGERIDO>=0.75`.
- Mapping module usa contrato list (ADR-054) em `R/mod_mapping.R`.
- Dicionário i18n está em JSON em `inst/extdata/i18n.json`.
- CSS é modular e gerado (ADR-055), com estilo de mapping em `inst/app/www/css/14-mapping.css`.
- Testes mapping baseline: `PASS 234` (sem falhas).
- Benchmark rápido local: `run_automap_v1` em 20k linhas x 50 colunas ≈ `36.36s` (gargalo claro para roadmap de performance).

## Auditoria Técnica — Issues Encontrados

### CRÍTICOS (bloqueia implementação se não corrigido)

**C1. `score_ratio_to_confidence()` nunca produz valores abaixo de 0.50**
- Arquivo: `R/utils_mapping.R` ~line 471-473.
- Fórmula atual: `pmin(1, pmax(0.5, 0.5 + 0.5 * valid_ratio))`.
- Efeito: `value_score` mínimo = 0.50. Com `name_score = 1.0`, `final_score = 0.75` (SUGERIDO), mesmo com conteúdo 100% inválido.
- A spec diz "veto hard se `value_score < 0.3`" mas isso **nunca dispara** com a fórmula atual.
- **Fix (PR-2.2)**: Mudar fórmula para range completo `[0, 1]` + veto explícito pré-classificação.

**C2. Token substring detection ausente em `score_token_overlap()`**
- Arquivo: `R/utils_mapping.R` ~line 359-375.
- `intersect(col_tokens, term_tokens)` só detecta tokens idênticos.
- "record" vs "recordedBy" → tokens `["record"]` vs `["recorded","by"]` → overlap = 0.
- A spec define bônus +0.1 (token exato) e penalidade -0.1 (substring) como mecanismo central de desambiguação.
- **Fix (PR-2.1)**: Reescrever com comparação par-a-par incluindo detecção de substring.

**C3. Sem error boundary entre stages do pipeline**
- Falha no Stage 2 descarta todos os resultados do Stage 1.
- `mod_mapping.R` lines 793-862 usa `tryCatch` flat — sem recuperação parcial.
- **Fix (PR-2.4)**: Cada stage retorna `list(success, data, warnings, errors, timing_ms)`. Orquestrador aceita resultado parcial.

**C4. Race condition em SQLite multi-usuário (Shiny Server)**
- Plano original diz `busy_timeout` mas isso não resolve race lógica (read-compute-write com estado stale).
- **Fix (PR-1.1 + PR-5.2)**: `BEGIN IMMEDIATE` para alias writes; documentar que `SAIRA_DATA_DIR` compartilhado requer advisory lock.

### ALTOS (causa bugs sutis ou regressões)

**H1. Regra "token overlap requer `value_score >= 0.8`" não aplicada**
- `R/utils_mapping.R` ~line 722-724 computa `final_score` sem gate condicional.
- **Fix (PR-2.2)**: Gate explícito: `if (name_reason == "token_overlap" && name_score <= 0.70 && value_score < 0.80) skip candidate`.

**H2. Normalização redundante: O(T*C) chamadas desnecessárias**
- `normalize_for_matching()` chamada dentro do loop aninhado para cada par (termo, coluna).
- 200 termos × 50 colunas = 10.000 chamadas; colunas re-normalizadas 200×, termos 50×.
- `sanitize_synonyms_table()` idem — chamada 10.000× dentro de `compute_name_score()`.
- **Fix (PR-2.1)**: Pré-computar fora do loop. Antecipar de Onda 7 para Onda 2.

**H3. Migração de sinônimos V1→V2 com mismatch de schema**
- V1: `name_score` em `[0.90, 0.98]`, coluna `lang`, valor `"any"`.
- V2 SQLite: `confidence` em `[0.0, 1.0]`, coluna `language`, sem `"any"`.
- **Fix (PR-1.2)**: Função explícita `adapt_synonyms_v1_to_v2()` com mapeamento: `lang="any"` → `language="mul"` (ISO 639-2).

**H4. Sem testes unitários para funções core de scoring**
- `score_ratio_to_confidence()`, `validate_numeric_range()`, `sample_values_for_scoring()` — zero testes.
- `sample_values_for_scoring()` usa `sample()` sem seed fixo → resultados não-determinísticos.
- **Fix (PR-0.1)**: Adicionar testes + seed determinístico por coluna.

**H5. Sem golden file tests (regression anchors)**
- Nenhum snapshot que fixe scores esperados para inputs conhecidos.
- **Fix (PR-0.1)**: Criar `tests/testthat/fixtures/scoring_golden_cases.rds` com 30 pares input/output do V1 atual.

**H6. UI de resolução AMBÍGUO não especificada**
- Plano original diz "badge AMBÍGUO" mas não define o workflow de resolução.
- **Fix (PR-2.4)**: `modalDialog` com radio buttons para cada candidato, amostra de valores, botão "Confirmar".

### MÉDIOS

- **M1.** `build_eventdate_interval()` row-by-row (for loop em 20k rows) — contribui para baseline de 36s. **Fix (PR-3.2)**: Vetorizar.
- **M2.** Floating-point em detecção de ambiguidade (`abs(a-b) < 0.1`) — sem epsilon safety. **Fix (PR-4.2)**: `abs(a - b) < (0.1 - .Machine$double.eps^0.5)`.
- **M3.** `PRAGMA foreign_keys = ON` não mencionado — FK não enforced. **Fix (PR-1.1)**: Setar na conexão.
- **M4.** Template `app_min/max_version` sem validação. **Fix (PR-6.1)**: `utils::compareVersion()` contra versão corrente.
- **M5.** Sem i18n keys para novos reason codes (~20 keys faltando). **Fix (PR-2.4)**: Lista completa PT+EN.
- **M6.** Sem debug mode para logging verbose. **Fix (PR-7.1)**: `options(saira.rostrum.debug = TRUE)`.
- **M7.** Penalidades semânticas stackáveis sem cap. **Fix (PR-2.3)**: Cap total em -0.5.
- **M8.** `normalize_for_matching()` necessário em dois módulos. **Fix (PR-0.1)**: Extrair para `R/utils_common.R`.

### BAIXOS

- **L1.** Sampling head-biased vs spec (estratificado). **Fix (PR-2.2)**.
- **L2.** Badge TEMPLATE sem cor no design system. **Fix (PR-6.2)**: `#8E44AD` (roxo).
- **L3.** Sem E2E test para toggle ON/OFF. **Fix (PR-2.4)**.
- **L4.** Sem audit trail para overrides manuais. **Fix (PR-5.1)**.

## Objetivo Técnico Final
Entregar um motor Rostrum em 3 estágios com explicabilidade total:
1. Stage 1: scoring híbrido conservador (nome + conteúdo + penalidades + veto).
2. Stage 2: composição de termos (scientificName/eventDate/verbatim*), sem circularidade.
3. Stage 3: resolução de conflitos com ambiguidade explícita e fallback para termos relacionados.
4. Persistência local em SQLite para aliases, templates, auditoria e telemetria operacional.
5. UI com badges e explicações detalhadas, consistente com design system.
6. Pipeline de testes/benchmarks que impeça regressões de precisão, UX e performance.

## Padrões Transversais (aplicam a todas as ondas)

### T1. Error Boundary Pattern
Cada stage retorna:
```r
list(success = TRUE/FALSE, data = df, warnings = chr(), errors = chr(), timing_ms = numeric(1))
```
Orquestrador degrada gracefully: Stage 1 falha → retorna vazio; Stage 2 falha → retorna Stage 1; Stage 3 falha → retorna Stage 1+2.

### T2. Determinismo de Sampling
Toda amostragem usa seed derivado do conteúdo da coluna:
```r
seed <- digest::digest2int(paste0(values[1:min(10, length(values))], collapse = "|"))
withr::with_seed(seed, { sample(...) })
```

### T3. Migration Safety
Toda migração SQLite em transação `BEGIN IMMEDIATE` com rollback automático em erro:
```r
rostrum_migrate <- function(conn, target_version) {
  current <- DBI::dbGetQuery(conn, "SELECT MAX(version) FROM schema_version")[[1]]
  if (is.na(current)) current <- 0L
  if (current >= target_version) return(invisible(TRUE))
  DBI::dbExecute(conn, "BEGIN IMMEDIATE")
  tryCatch({
    for (v in (current + 1):target_version) {
      migration_fn <- get(paste0("migrate_v", v))
      migration_fn(conn)
      DBI::dbExecute(conn, sprintf(
        "INSERT INTO schema_version(version, applied_at) VALUES(%d, '%s')",
        v, format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")))
    }
    DBI::dbExecute(conn, "COMMIT")
  }, error = function(e) {
    DBI::dbExecute(conn, "ROLLBACK")
    stop("Migration to v", target_version, " failed: ", e$message)
  })
}
```

### T4. Performance Baseline
Benchmark automatizado em `tests/bench/` com threshold de regressão (1.5× baseline). CI falha se exceder.

## Mudanças Importantes de API/Interface/Tipos

### APIs internas novas (core Rostrum)
- `run_rostrum_engine(df, dwc_terms_df, options, context, conn=NULL) -> list` (retorna `rostrum_result` com error boundary T1).
- `rostrum_stage1_candidates(...) -> rostrum_result` (com `$success`, `$data`, `$warnings`, `$errors`, `$timing_ms`).
- `rostrum_stage2_compositions(...) -> rostrum_result`.
- `rostrum_stage3_resolve(...) -> rostrum_result`.
- `rostrum_apply_decisions(...) -> list(map_values, map_meta, audit_payload)`.

### Contrato de dados do motor (novo)
- `candidate_df`: `term`, `column_name`, `name_score`, `value_score`, `penalty_score`, `veto_code`, `final_score`, `decision_band`, `reason_code`, `explain_json`.
- `decision_df`: `term`, `selected_col`, `status`, `score`, `score_gap`, `ambiguity_flag`, `source` (`auto|alias|template|manual`), `provenance_id`.
- `composition_df`: `term`, `inputs_json`, `output_preview`, `status`, `reason_code`.
- **Novo**: `validate_candidate_df()` e `validate_decision_df()` — funções de validação de schema para cada contrato.

### Evolução controlada do contrato de módulo
- `R/mod_mapping.R` manterá slots atuais (`processed_data_r`, `preview_data_r`, `validation_gate_r`, `validation_gate_coords_r`) por 1 release de transição.
- Novos slots adicionados: `rostrum_decisions_r`, `rostrum_explain_r`, `rostrum_run_stats_r`.
- Após transição: remover dependência do caminho legado `run_automap_v1()`.

### Persistência SQLite (nova superfície técnica)
- Novo backend em `R/utils_rostrum_db.R` com migrações versionadas.
- DB path default: `tools::R_user_dir("saira", "data")/rostrum.sqlite` (fallback `~/.saira/rostrum.sqlite`).
- Config via env vars: `SAIRA_DATA_DIR`, `SAIRA_USER`, `SAIRA_INSTITUTION`.
- **Novo**: `rostrum_connect()` wrapper que seta `PRAGMA foreign_keys = ON`, `journal_mode = WAL`, `busy_timeout = 5000` em toda conexão.

## Modelo de Dados SQLite (decision-complete)

### Tabelas
- `schema_version(version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)`.
- `rostrum_synonyms(term TEXT, synonym TEXT, language TEXT, context TEXT, confidence REAL, validation_regex TEXT, notes TEXT, active INTEGER, source TEXT, updated_at TEXT, PRIMARY KEY(term,synonym,language,context,source))`.
- `rostrum_aliases(alias_id INTEGER PRIMARY KEY, scope TEXT, user_id TEXT, institution_id TEXT, col_name_norm TEXT, dwc_term TEXT, confidence REAL, reviewed INTEGER, deprecated INTEGER, created_at TEXT, created_by TEXT, updated_at TEXT)`.
- `rostrum_alias_events(event_id INTEGER PRIMARY KEY, alias_id INTEGER REFERENCES rostrum_aliases(alias_id), action TEXT, run_id TEXT, payload_json TEXT, created_at TEXT, created_by TEXT)`.
- `rostrum_templates(template_id TEXT PRIMARY KEY, name TEXT, scope TEXT, owner_id TEXT, institution_id TEXT, schema_version TEXT, app_min_version TEXT, app_max_version TEXT, is_active INTEGER, description TEXT, created_at TEXT, updated_at TEXT)`.
- `rostrum_template_items(template_id TEXT, dwc_term TEXT, source_columns_json TEXT, transform_kind TEXT, transform_params_json TEXT, priority INTEGER, required INTEGER, PRIMARY KEY(template_id,dwc_term))`.
- `rostrum_runs(run_id TEXT PRIMARY KEY, session_id TEXT, app_version TEXT, engine_version TEXT, rows_n INTEGER, cols_n INTEGER, elapsed_ms INTEGER, stage1_ms INTEGER, stage2_ms INTEGER, stage3_ms INTEGER, auto_n INTEGER, suggested_n INTEGER, ambiguous_n INTEGER, manual_n INTEGER, options_json TEXT, metrics_json TEXT, created_at TEXT)`.
- **Nova**: `rostrum_run_details(run_id TEXT, term TEXT, column_name TEXT, name_score REAL, value_score REAL, penalty_score REAL, final_score REAL, veto_code TEXT, decision_band TEXT, explain_json TEXT, PRIMARY KEY(run_id, term, column_name), FOREIGN KEY(run_id) REFERENCES rostrum_runs(run_id))`.

### Índices obrigatórios
- `idx_alias_lookup` em (`scope`,`user_id`,`institution_id`,`col_name_norm`,`dwc_term`,`deprecated`).
- `idx_synonyms_term_lang` em (`term`,`language`,`active`).
- `idx_runs_created_at` em (`created_at`).
- **Novo**: `idx_alias_events_run_id` em (`run_id`) — para batch undo.

### Regras de precedência
- `template > alias_personal > alias_institution > alias_public > synonym_base > heurística nome`.
- Revisão manual sempre prevalece sobre qualquer sugestão automática.

## Ondas e PRs (implementação)

## Onda 0 — Congelamento de contrato e baseline (pré-implementação)

### PR-0.1: Baseline técnico
- **Entrega original**: Scripts de benchmark e snapshot de precisão com datasets sintéticos/reais.
- **[+H4]** Adicionar testes unitários para `score_ratio_to_confidence()`, `validate_numeric_range()`, `sample_values_for_scoring()`.
- **[+H5]** Criar golden file `tests/testthat/fixtures/scoring_golden_cases.rds` com 30 pares input/output do V1 atual.
- **[+M8]** Extrair `normalize_for_matching()` e `tokenize_for_matching()` para `R/utils_common.R`.
- **[+T4]** Criar `tests/bench/benchmark_rostrum_stage1.R` e salvar baseline.
- Arquivos: `R/utils_common.R`, `tests/testthat/test-utils-scoring-boundaries.R` (novo), `tests/bench/`, `tests/testthat/fixtures/`.
- Aceite: baseline versionado para tempo, cobertura, falso positivo; funções core de scoring com testes unitários; golden file criado.

**Novos testes (`test-utils-scoring-boundaries.R`):**
- `score_ratio_to_confidence(0)` == 0.5 (documenta floor intencional do V1).
- `score_ratio_to_confidence(1)` == 1.0.
- `score_ratio_to_confidence(NaN)` não crasha.
- `validate_numeric_range` com valores nos limites exatos (-90, 90, -180, 180).
- `validate_numeric_range` com vetor vazio.
- `sample_values_for_scoring`: mesma entrada produz mesma saída (com seed fixo).
- Golden file: 30 casos do V1 reproduzidos exatamente.

### PR-0.2: ADRs de arranque
- **Entrega original**: Novos ADRs para SQLite V1, breaking controlado, novo contrato Rostrum.
- **[+C3]** ADR para error boundary pattern (T1).
- **[+T2]** ADR para determinismo de sampling.
- **[+T3]** ADR para migration safety pattern.
- **[+H3]** ADR para evolução do schema de sinônimos (`name_score` → `confidence`, `lang` → `language`).
- Arquivos: `docs/DECISIONS.md`, `docs/LESSONS.md`.
- Aceite: decisões explícitas e rastreáveis antes de código funcional.

## Onda 1 — Fundação V1 (SQLite + Core Contracts)

### PR-1.1: Backend SQLite + migração
- **Entrega original**: `utils_rostrum_db.R`, `data-raw/rostrum_schema.sql`, migração automática.
- **[+C4]** `rostrum_connect()` wrapper que seta `PRAGMA foreign_keys = ON`, `journal_mode = WAL`, `busy_timeout = 5000`.
- **[+M3]** FK explícita entre `rostrum_alias_events.alias_id` → `rostrum_aliases(alias_id)`.
- **[+T3]** `rostrum_migrate()` com `BEGIN IMMEDIATE` + rollback em erro.
- **[+Observabilidade]** Adicionar tabela `rostrum_run_details` para logging de decisões por coluna (debug pós-hoc).
- Mudanças: adicionar `DBI`, `RSQLite`, `digest`, `withr` em `DESCRIPTION`.
- Aceite: criação/migração idempotente, WAL ativo, `busy_timeout` configurado, FK enforced.

**Novos testes (`test-utils-rostrum-db.R`):**
- Migração cria todas as tabelas idempotentemente.
- Migração mid-failure faz rollback limpo.
- Conexão seta WAL mode e `foreign_keys = ON`.
- `schema_version` incrementa corretamente.

### PR-1.2: Migração de sinônimos para v2
- **Entrega original**: Loader compatível (`v1 rds` → tabela SQLite), schema ampliado.
- **[+H3]** Função explícita `adapt_synonyms_v1_to_v2()` com mapeamento:
  - `lang="any"` → `language="mul"` (ISO 639-2 para multilingual).
  - `name_score` → `confidence` (preserva range original `[0.90, 0.98]`).
  - Defaults para `context="unknown"`, `validation_regex=NA`, `notes="Migrated from v1 RDS"`.
- Aceite: motor aceita dados antigos e novos durante transição; adaptador testado.

**Novos testes:**
- `adapt_synonyms_v1_to_v2` preserva todas as rows e mapeia `"any"` → `"mul"`.
- Sinonimos migrados mantêm `confidence` no range original.

### PR-1.3: Tipos e opções do motor
- **Entrega original**: Objeto `rostrum_options()` com defaults conservadores; structs de saída.
- **[+Contrato]** `validate_candidate_df()` e `validate_decision_df()` com checagem de colunas, tipos e ranges.
- Aceite: contrato fixado em testes de schema.

**Novos testes:**
- `validate_candidate_df` rejeita df com colunas faltando.
- `validate_decision_df` rejeita df com tipos errados.

## Onda 2 — Stage 1 completo (V1 funcional conservador)

### PR-2.1: Name score hierárquico final
- **Entrega original**: exact/synonym/token(full/partial)/Levenshtein; bônus token exato e penalidade substring.
- **[+C2 — CRÍTICO]** Reescrever `score_token_overlap()` com detecção par-a-par de substring:
  - Mínimo 3 caracteres para considerar substring match.
  - Bônus +0.1 para token exato, penalidade -0.1 para substring.
  - Exemplo: "record" vs recordNumber (exato, +0.1) > "record" vs recordedBy (substring de "recorded", -0.1).
- **[+H2]** Pré-computar `normalized_columns` e `normalized_terms` fora do loop aninhado; passar sinônimos pré-sanitizados a `compute_name_score()`.
- Arquivo principal: `R/utils_mapping.R` (função `score_token_overlap` ~line 359).
- Aceite: casos de `record` vs `recordedBy` cobertos por teste; performance do loop melhorada.

### PR-2.2: Value score estratificado real
- **Entrega original**: Amostragem estratificada (até 1000 valores), validadores por termo prioritário, veto hard/soft.
- **[+C1 — CRÍTICO]** Corrigir `score_ratio_to_confidence()` para range completo `[0, 1]`:
  - Remover floor 0.5 da fórmula.
  - Adicionar veto explícito: `if (valid_ratio < 0.30) return(list(score = 0, reason = "veto_low_validation"))`.
- **[+H1]** Gate condicional para token overlap: `if (name_reason == "token_overlap" && name_score <= 0.70 && value_score < 0.80) skip candidate`.
- **[+L1]** Mudar sampling para estratificado uniforme: `indices <- round(seq(1, n, length.out = target_n))`.
- **[+T2]** Seed determinístico por coluna para `sample()`.
- **[+H5]** Atualizar golden file após mudança de fórmula (novo baseline V2).
- Arquivo principal: `R/utils_mapping.R` (funções ~lines 431, 471, 528).
- Aceite: regra "token overlap exige `value>=0.8`" obrigatória em teste; veto dispara para `value_score < 0.3`.

### PR-2.3: Penalidades semânticas + veto
- **Entrega original**: Penalidades contextuais (`temp/depth/count/generic`) e códigos de veto explícitos.
- **[+M7]** Cap total de penalidades em -0.5 para evitar stacking excessivo.
  - Exemplo: "temp_count_campo1" acumularia -0.3 + -0.2 + -0.1 = -0.6, mas capped em -0.5.
- Arquivo principal: `R/utils_mapping.R` (função nova `apply_semantic_penalties`).
- Aceite: `value_score < 0.3` zera candidato; coluna vazia não é aplicada; penalties capped.

### PR-2.4: Integração no módulo Mapping
- **Entrega original**: Badge `AMBÍGUO`, popover de explicabilidade, i18n completo.
- **[+C3 — CRÍTICO]** Error boundary: `run_rostrum_engine()` com recuperação parcial por stage (T1).
- **[+H6]** UI de resolução AMBÍGUO: `modalDialog` com radio buttons para cada candidato, amostra de valores, botão "Confirmar".
- **[+M5]** Lista completa de i18n keys novos (~20 keys PT+EN) para reason codes:
  - `rostrum_reason_exact_match`, `rostrum_reason_known_synonym`, `rostrum_reason_token_overlap`, `rostrum_reason_text_similarity`, `rostrum_reason_veto_hard`, `rostrum_reason_veto_soft`, `rostrum_reason_semantic_penalty`, `rostrum_reason_ambiguity_detected`, `rostrum_reason_conflict_won`, `rostrum_reason_conflict_lost`, `rostrum_badge_auto`, `rostrum_badge_suggested`, `rostrum_badge_ambiguous`, `rostrum_badge_manual`, `rostrum_badge_alias`, `rostrum_badge_template`, `rostrum_explain_name_score`, `rostrum_explain_value_score`, `rostrum_explain_penalty`, `rostrum_explain_alternatives`.
- **[+L2]** Badge TEMPLATE: cor `#8E44AD` (roxo), CSS class `.badge-template`.
- Arquivos: `R/mod_mapping.R`, `inst/extdata/i18n.json`, `inst/app/www/css/14-mapping.css`.
- Aceite: toggle segue opt-in; comportamento legado preservado com toggle OFF; error boundary funcional.

**Novos testes (todos os PRs da Onda 2, em `test-utils-rostrum-stage1.R`):**
- "record" vs recordNumber scores > "record" vs recordedBy (substring penalty).
- Token overlap com `value_score < 0.8` rejeitado.
- Token overlap com `value_score >= 0.8` aceito.
- Penalidade semântica "temp_air" + latitude reduz abaixo de 0.75.
- Penalidades stackadas capped em -0.5.
- Veto dispara para `value_score < 0.3` (com fórmula corrigida).
- Veto dispara para coluna 100% vazia.
- Veto dispara para tipo incompatível.
- Golden file: 30 casos atualizados com nova fórmula (novo baseline).
- Property test: `final_score` sempre em `[0, 1]` para 100 inputs aleatórios.
- Error boundary: Stage 2 falha → Stage 1 results preservados.

## Onda 3 — Stage 2 (composição sem circularidade)

### PR-3.1: scientificName bidirecional seguro
- **Entrega original**: Composição `genus + specificEpithet (+infra+authorship)` quando `scientificName` ausente; derivação inversa só preenche vazios.
- **[+Circularidade]** Guard explícito: manter registro `composed_from` que impede termo composto de ser input de outra composição.
- **[+Override]** Check de override manual antes de compor: `if (is.na(manual_overrides[["scientificName"]]))`.
- Aceite: sem sobrescrever valor manual; sem loop entre regras; guard de circularidade testado.

### PR-3.2: eventDate composto ISO estrito
- **Entrega original**: Composição `year/month/day` com validação de calendário (inclui bissexto), suporta parcial.
- **[+M1]** Vetorizar `build_eventdate_interval()` — substituir for-loop por operações vetorizadas com `vapply`.
- **[+Leap year]** Teste explícito: 2024-02-29 válido, 2023-02-29 inválido.
- Aceite: entradas ambíguas rejeitadas para AUTO; fallback manual preservado; performance < 2s para 20k rows.

### PR-3.3: verbatim* de baixa prioridade
- **Entrega original**: `verbatimLatitude`, `verbatimLongitude`, `verbatimEventDate`, `verbatimCoordinates`.
- **[+Timing]** Executar após Stage 3 conflict resolution como "Stage 3.5" (não durante Stage 3).
- **[+Tabela]** Fallback targets hardcoded: `decimalLatitude → verbatimLatitude`, `decimalLongitude → verbatimLongitude`, `eventDate → verbatimEventDate`.
- Aceite: não "rouba" mapeamento principal; só aplica quando regra permitir.

**Novos testes (`test-utils-rostrum-stage2.R`):**
- scientificName composição de genus + specificEpithet.
- scientificName composição skipada quando já presente.
- scientificName composição skipada quando manualmente mapeado.
- Circularidade: genus derivado de scientificName não retro-alimenta composição.
- eventDate YYYY-MM-DD de year+month+day.
- eventDate parcial: YYYY de year only.
- eventDate inválido: month=13 rejeitado; day=31 para month=2 rejeitado.
- Leap year: 2024-02-29 aceito, 2023-02-29 rejeitado.

## Onda 4 — Stage 3 (conflitos, ambiguidade e perdedores)

### PR-4.1: Resolvedor de conflito multicritério
- **Entrega original**: Desempate por tipo, completude, value score, especificidade e token exato.
- **[+Determinismo]** Tiebreak final com fallback alfabético por nome do termo:
  ```r
  tie_order <- order(-final_score, -value_score, -specificity, term)
  ```
- Aceite: conflito determinístico e reproduzível (mesma entrada sempre mesmo resultado).

### PR-4.2: Ambiguidade legítima
- **Entrega original**: Quando `diff < 0.1`, status `AMBIGUO` e ação manual obrigatória.
- **[+M2]** Comparação epsilon-safe: `abs(a - b) < (0.1 - .Machine$double.eps^0.5)`.
- Aceite: nenhuma escolha automática em empate técnico; comparação float-safe.

### PR-4.3: Mapeamento de perdedor para termo relacionado
- **Entrega original**: Loser mapping para `verbatim*` com `score>=0.75`.
- **[+Guard]** Loser só mapeia se `score >= 0.75` **E** verbatim* não já ocupado.
- Aceite: preserva informação original sem duplicar semântica.

**Novos testes (`test-utils-rostrum-stage3.R`):**
- Dois candidatos com score diff < 0.1 marcados AMBÍGUO.
- Dois candidatos com score diff >= 0.1: higher wins.
- Determinismo: mesma entrada sempre mesmo resultado (rodar 100×).
- Loser mapeado para verbatim* quando elegível.
- Loser NÃO mapeado quando `score < 0.75`.
- Loser NÃO mapeado quando verbatim* já ocupado.
- Conflito prefere numérico sobre texto para coordenadas.
- Conflito prefere maior completude.

## Onda 5 — Aprendizado local com SQLite (aliases)

### PR-5.1: Captura de aprendizado
- **Entrega original**: Confirmação de sugestão grava alias com confiança original; correção manual grava alias com `1.0`.
- **[+Batch undo]** Função `undo_session_aliases(conn, run_id)` para rollback de sessão.
- **[+L4]** Registrar overrides manuais (quando usuário troca AUTO por outra coluna) como evento auditável.
- Aceite: cada ação gera evento auditável em `rostrum_alias_events`; batch undo funcional.

### PR-5.2: Precedência por escopo
- **Entrega original**: Suporte técnico para `personal|institution|public`; ativação inicial em `personal`.
- **[+C4]** `BEGIN IMMEDIATE` para todas as writes de alias.
- **[+Índice]** `idx_alias_events_run_id` em (`run_id`) para performance de batch undo.
- Aceite: `personal` sempre vence outros escopos; writes transacionais.

### PR-5.3: Depreciação e revisão
- **Entrega original**: Fluxo de desativar alias errado sem apagar histórico.
- Aceite: alias deprecated não influencia próximas execuções.

**Novos testes (`test-utils-rostrum-aliases.R`):**
- Alias criado na confirmação persiste entre sessões.
- Alias com `deprecated=1` não influencia scoring.
- Batch undo depreca todos os aliases de um `run_id`.
- Precedência: personal > institution > public.
- Alias duplicado (mesmo `col_name_norm` + `dwc_term` + scope) faz update, não insert.

## Onda 6 — Templates V3 (JSON + SQLite)

### PR-6.1: Schema JSON de template
- **Entrega original**: Validador de schema/versão e normalizador de payload.
- **[+M4]** Validação de `app_min/max_version` contra versão corrente via `utils::compareVersion()`.
- Aceite: template inválido falha com erro explicável; template com versão futura rejeitado.

### PR-6.2: Export/Import de templates
- **Entrega original**: Salvar estado de mapping atual, carregar em dataset novo, persistir no SQLite.
- **[+L2]** Badge TEMPLATE: cor `#8E44AD` (roxo), CSS class `.badge-template { background-color: #8E44AD; }`.
- Aceite: template aplicado mostra badge `TEMPLATE`.

### PR-6.3: Prioridade de template
- **Entrega original**: Template carregado tem prioridade sobre sugestão heurística.
- Aceite: conflitos com template geram log e explicação explícita.

**Novos testes (`test-utils-rostrum-templates.R`):**
- Template JSON válido passa validação.
- Template com campos obrigatórios faltando falha com erro descritivo.
- Template com `app_min_version` futura rejeitado.
- Template com `app_max_version` passada emite warning mas carrega.
- Export captura estado completo de mapping.
- Import aplica mapeamentos com badge TEMPLATE.
- Template tem prioridade sobre scoring heurístico.

## Onda 7 — V4+ hardening, performance e rollout

### PR-7.1: Otimização de performance Stage 1
- **Entrega original**: Perfil de coluna cacheado; poda de pares; vetorização adicional.
- **[+M6]** `options(saira.rostrum.debug = TRUE)` para logging verbose com `message()`.
- **[+Observabilidade]** `stage1_ms`, `stage2_ms`, `stage3_ms` em `rostrum_runs` (já incluso no schema acima).
- Aceite: reduzir tempo baseline em pelo menos 50%.

### PR-7.2: Paralelização opcional
- **Entrega original**: Feature flag para paralelizar scoring por coluna (`future/furrr`).
- **[+T2]** Teste de determinismo: `sequential` vs `multisession` produz `decision_df` idêntico.
- Aceite: sem alteração de resultado determinístico.

### PR-7.3: Remoção controlada do legado
- **Entrega original**: Descontinuação de caminho `run_automap_v1` após release de transição.
- **[+Checklist]** Remoção explícita:
  1. Remover `run_automap_v1()`.
  2. Remover toggle `enable_automap_v1` e UI associada.
  3. Atualizar todos os testes que referenciam nomes V1.
  4. Remover `dwc_synonyms_v1.rds` após migração comprovada.
  5. Manter `adapt_synonyms_v1_to_v2()` por mais 1 release como safety net.
- Aceite: migration notes no changelog; testes passando sem wrappers legados.

### PR-7.4: Repositório local de templates (pré-hub)
- **Entrega original**: Catálogo local com filtros por instituição/uso.
- Aceite: pronto para futura extensão de "Template Hub".

**Novos testes (`test-performance-regression.R`):**
- Stage 1: 50 cols × 20k rows < 7.5s (50% do target de 15s).
- Stage 2: < 2s para scientificName + eventDate em 20k rows.
- Stage 3: < 0.5s para conflict resolution em 50 termos.
- Full pipeline: < 8s total.

## Estratégia de Testes (obrigatória)

### Novas suites
- `test-utils-scoring-boundaries.R` (Onda 0 — funções core de scoring).
- `test-utils-rostrum-db.R` (Onda 1 — SQLite, migração, conexão).
- `test-utils-rostrum-stage1.R` (Onda 2 — scoring completo, veto, penalties).
- `test-utils-rostrum-stage2.R` (Onda 3 — composição, circularidade).
- `test-utils-rostrum-stage3.R` (Onda 4 — conflitos, ambiguidade, losers).
- `test-utils-rostrum-aliases.R` (Onda 5 — aliases, precedência, batch undo).
- `test-utils-rostrum-templates.R` (Onda 6 — JSON schema, import/export).
- `test-mod-mapping-rostrum-v2.R` (Onda 2+ — integração módulo).
- `test-e2e-rostrum-flows.R` (Onda 2+ — E2E com shinytest2).
- `test-performance-regression.R` (Onda 7 — benchmarks de regressão).

### Cenários críticos de aceitação
1. Match exato, sinônimo, token overlap e Levenshtein com pesos corretos.
2. **[C2]** Token substring: "record" vs recordNumber > "record" vs recordedBy.
3. Regra especial: token overlap não passa com `value_score < 0.8`.
4. **[C1]** Veto hard em tipo incompatível, coluna vazia e `value_score < 0.3` (fórmula corrigida).
5. Stage 2 não executa antes de Stage 1 completo.
6. Composição de scientificName sem sobrescrita manual.
7. EventDate composto respeita ISO e datas válidas (inclui leap year).
8. Stage 3 marca `AMBÍGUO` quando `gap < 0.1` (epsilon-safe).
9. Perdedor mapeado para `verbatim*` apenas quando elegível e target livre.
10. Alias pessoal aprendido altera sugestão em novo upload.
11. Alias deprecated não volta a ser aplicado.
12. **[+]** Batch undo de aliases por sessão funciona.
13. Template inválido é rejeitado com erro de schema.
14. Template válido aplica mapeamento prioritário com badge `TEMPLATE`.
15. Toggle OFF mantém comportamento legado.
16. Toggle ON executa pipeline Rostrum com explicabilidade completa.
17. **[+C3]** Falha no Stage 2 preserva resultados do Stage 1.
18. **[+T2]** Scoring é determinístico (mesma entrada → mesma saída, sem variação de seed).
19. Release gate continua verde (`devtools::test`, CSS guardrails, i18n, E2E, check).

## Metas de qualidade e performance
- Precisão de AUTO: >=95% em validação manual de datasets de referência.
- Cobertura de AUTO: >=60%.
- Sugestões úteis: >=25%.
- Falso positivo em AUTO: <=5%.
- Tempo alvo (desktop padrão): 50 colunas e 20k linhas <=15s no V2, <=8s no V4.
- Observação: baseline atual medido está em ~36s no cenário sintético equivalente.

## Rollout e versionamento (breaking controlado)
- Release A (`0.3.x`): Onda 0 + Onda 1 + Onda 2 (V1 conservador com SQLite).
- Release B (`0.4.x`): Onda 3 + Onda 4 (V2 composição + conflitos).
- Release C (`0.5.x`): Onda 5 + Onda 6 (V3 aliases + templates).
- Release D (`0.6.x`): Onda 7 (V4+ hardening/perf e remoção de legado).
- Toggle Rostrum permanece OFF por padrão até fim de `0.5.x`.

## Dependências novas em DESCRIPTION
- `DBI` (>= 1.0.0) — Onda 1.
- `RSQLite` (>= 2.2.0) — Onda 1.
- `digest` (>= 0.6.0) — Onda 0 (seed determinístico).
- `withr` (>= 2.5.0) — Onda 0 (`with_seed`).

## Atualizações de documentação por onda
- `docs/rostrum_engine.md`: manter como especificação viva do pipeline.
- `docs/DECISIONS.md`: 1 ADR por PR arquitetural relevante.
- `docs/LESSONS.md`: registrar lições de performance, reatividade e persistência.
- `CHANGELOG.md`: atualizar em cada PR com Keep a Changelog.
- `docs/architecture.md`: atualizar contratos de módulo e dados.
- `docs/design.md`: refletir novos badges e estados visuais (incluir TEMPLATE roxo).

## Assumptions e Defaults explícitos
- Padrão de desenvolvimento segue `claude.md/architecture.md/skill.md`: lógica em `utils_*`, módulo como ponte, i18n obrigatório, sem `library()` em `R/*.R`.
- Toda persistência do Rostrum é local/offline (sem APIs externas).
- SQL migrations são idempotentes e versionadas com `BEGIN IMMEDIATE` + rollback.
- UI continua bilíngue PT/EN, com expansão opcional para ES no dicionário de sinônimos.
- `custom.css` continua gerado; mudanças de estilo entram nos módulos em `inst/app/www/css/*` e passam pelo build determinístico.
- `SAIRA_DATA_DIR` compartilhado entre processos Shiny Server requer advisory lock externo (documentado, não implementado na V1).
