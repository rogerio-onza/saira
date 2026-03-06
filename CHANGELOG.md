# Changelog

Todas as mudancas notaveis do Saira sao documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

---

---

## [0.2.1] - 2026-03-06

### Adicionado
- `tests/testthat/test-utils-rostrum-engine.R`: 10 testes de integracao do orquestrador `run_rostrum_engine()`, cobrindo contrato de retorno, mapeamento por sinonimos, degradacao gracosa com colunas nao reconhecidas, overrides manuais, e tratamento de erros (BP-02).
- `tests/testthat/test-utils-common.R`: 38 novos testes unitarios cobrindo `create_rds_cache()`, `is_blank_value()`, `normalize_for_matching()` e `tokenize_for_matching()` — funcoes core usadas por todo o codebase que estavam sem cobertura de teste (BP-01).
- `.onLoad()` em `R/saira-package.R`: pre-aquecimento de `load_dwc_terms_rds()` e `coords_load_aliases()` no startup do pacote, eliminando spikes de latencia no primeiro uso do engine de mapeamento e validacao de coordenadas (P-05).
- `shiny.error` handler global em `run_app.R` que sobe erros nao tratados como `warning()` para o sistema de log do servidor, tornando falhas silenciosas visiveis (B-03).

### Alterado
- `R/app_server.R`: diagnosticos de slot ausente do `mod_mapping` convertidos de `message()` para `warning()` para respeitar `skill.md` ("strictly necessary" para console output) e garantir visibilidade em logs de producao sem poluir stdout (C-01).
- `R/utils_rostrum_db.R`, `R/utils_coords.R`, `R/mod_mapping.R`, `R/utils_brproviders.R`: 8 chamadas `message()` de diagnostico de erro convertidas para `warning()` pelos mesmos motivos (C-03 a C-06).
- `R/utils_taxadb.R`: acumulacao de falhas de provider em `run_taxadb_cascade()` refatorada de `rbind()` em loop para list accumulation + `do.call(rbind, ...)` ao final — elimina copias desnecessarias do data.frame em cada iteracao (P-01).
- `DESCRIPTION`: `rnaturalearthhires` movido de `Imports` para `Suggests`, pois e dependencia opcional com fallback explicito em `utils_coords.R:453-454`; `sf`, `rnaturalearth` e `rnaturalearthdata` permanecem em `Imports` por serem validados como requeridos em runtime (A-01).

### Alterado (Prioridade C)
- `R/utils_taxadb.R`: logica duplicada de resolucao de `query_name` extraida de `fetch_taxadb_matches()` e `query_taxadb_batch()` para o helper privado `resolve_query_name_col()`, eliminando ~25 linhas copiadas e centralizando o ponto de manutencao (4.4).
- `R/mod_validate_coords.R`: `filtered_result_r` recebeu `|> shiny::bindCache(coord_validation_r(), active_filter())` para cachear resultados de filtragem entre ciclos reativos — evita re-processar o data.frame quando o usuario alterna entre filtros ja visitados (2.2).
- `R/mod_validate_names.R`: `effective_report` recebeu `|> shiny::bindCache(validation_result(), rv$manual_reviews, input$remove_authors, input$ignore_qualifiers)` para cachear o report enriquecido enquanto nenhuma das dependencias mudar (2.2).
- `R/utils_common.R`: `normalize_for_matching()` e `tokenize_for_matching()` receberam blocos `@param`/`@return` roxygen2 completos (4.5).
- `data-raw/build_css.R`: cabecalho expandido com instrucoes de quando executar o script e como usa-lo, prevenindo estilos desatualizados no bundle `custom.css` (3.5).
- `inst/app/www/css/02-navbar.css`: todos os 5 `!important` do navbar receberam comentarios inline explicando qual regra Bootstrap/bslib/Flatly estao sobrescrevendo (D-03).
- `inst/app/www/css/13-upload.css`: todos os 5 `!important` da barra de progresso receberam comentarios inline explicando o comportamento Shiny que forcam (D-03).
- `DESCRIPTION`: versao bumped de `0.1.0` para `0.2.1`, sincronizando com o historico real do CHANGELOG (0.2.0 = rework Rostrum, 0.2.1 = auditoria de qualidade).

### Nao implementado (bloqueio tecnico documentado)
- `2.3 DT proxy`: padrao `dataTableProxy + replaceData()` e inviavel em `mod_validate_names` e `mod_validate_coords` porque os badges HTML das celulas sao gerados via `tr(diag_label_key(x), lang_r())` inline — qualquer troca de idioma invalida o conteudo das celulas, nao apenas os cabecalhos. Isso exigiria re-render completo de qualquer forma, eliminando o beneficio do proxy. Mantido como item de arquitetura futura caso as traducoes migrem para CSS/JavaScript.

### Corrigido
- `inst/app/www/css/03-buttons.css`: `.btn-success` alterado de `color: var(--bg-card)` (branco, contraste 3.08:1 — falha WCAG AA) para `color: var(--text-primary)` (contraste 4.43:1 — passa WCAG AA). `design.md` documentava o valor como 4.7:1, o que estava incorreto; o documento sera atualizado (D-01).
- `inst/app/www/css/00-tokens.css`: `--coord-swapped` alterado de `#8b5cf6` (contraste 3.81:1, falha WCAG AA) para `#6d28d9` (contraste 6.4:1, passa WCAG AA com folga). Cor nao pertence a paleta do passaro, ajuste sem impacto na identidade visual (D-02).
- `R/utils_export.R`: `apply_name_review_payload()` adicionou `warning()` ao retorno silencioso quando `df` nao e um data.frame, prevenindo que bugs do caller passem despercebidos (B-01).


- `data-raw/generate_rostrum_synonyms.R`: gerador reproduzivel do bundle de sinonimos DwC com tabela curada PT+EN inline. Cobre 27 novos termos sem cobertura (`type`, `disposition`, `preparations`, `occurrenceRemarks`, `kingdom`, `phylum`, `class`, `order`, `family`, `genus`, `specificEpithet`, `infraspecificEpithet`, `taxonRank`, `scientificNameAuthorship`, `verbatimIdentification`, `identificationQualifier`, `vernacularName`, `identifiedBy`, `country`, `stateProvince`, `county`, `locality`, `locationRemarks`, `verbatimLatitude`, `verbatimLongitude`, `fieldNotes`, `habitat`) e reforca 6 termos rasos (`eventDate`, `recordedBy`, `basisOfRecord`, `catalogNumber`, `collectionCode`, `institutionCode`). Bundle regenerado: 29 → 147 entradas, 19 → 46 termos unicos. Correcao: `"species"` (en, 0.93) e `"especie"` (pt, 0.93) movidos para `scientificName` (estavam ausentes/equivocados); `specificEpithet` perde o alias `"especie"` (semanticamente errado para dados brasileiros) (ADR-073).
- `rostrum_sync_synonyms()` (interno) em `utils_rostrum_db.R`: sincronizacao continua do bundle `source = "v1_rds"` para `rostrum_synonyms` com hash-gate por processo. INSERT novos, UPDATE confidence alterada, SET `active = 0` para removidos. Nunca toca em `rostrum_aliases` nem em outras fontes (ADR-073).
- 7 novos casos de teste em `tests/testthat/test-utils-rostrum-db.R` cobrindo todos os cenarios de sincronizacao: banco vazio, idempotencia via hash-gate, novos sinonimos, deativacao de removidos, isolamento de outras fontes, preservacao de `rostrum_aliases`, e integracao com o engine.
- Texto estatico de fallback para os 8 titulos de abas de navegacao (`nav_home`, `nav_mapping`, `nav_preview`, `nav_validate`, `nav_validate_names`, `nav_validate_coords`, `nav_wiki`, `nav_help`): titulos agora aparecem imediatamente no carregamento inicial sem flash de branco, mantendo o switch de idioma pt/en via CSS `:has(.nav-title-dynamic:not(:empty)) .nav-title-static { display: none }` (ADR-075).
- `<link rel="preconnect">` para `fonts.googleapis.com`, `fonts.gstatic.com` e `cdnjs.cloudflare.com` no `<head>` do `app_ui()`, reduzindo latencia de DNS+TCP+TLS para recursos de fonte CDN (ADR-076).
- `.onLoad()` em `R/saira-package.R` que pre-aquece o cache do dicionario i18n ao carregar o pacote, eliminando a leitura de disco de 74 KB no caminho critico do build da UI (ADR-076).

### Alterado
- `run_rostrum_engine()`: substitui chamada `rostrum_seed_synonyms_if_empty(conn)` por `rostrum_sync_synonyms(conn)` no fluxo de carregamento de sinonimos. O banco converge automaticamente com o bundle atual em toda sessao nova; `rostrum_seed_synonyms_if_empty` permanece disponivel como API publica (ADR-073).

### Corrigido
- `data-raw/generate_rostrum_synonyms.R` / `inst/extdata/dwc_synonyms_v1.rds`: dois aliases semanticamente errados no bundle de sinonimos corrigidos (ADR-077):
  - `"especie"` (pt) estava em `specificEpithet` (0.90); em dados brasileiros, colunas "especie" contem o binomial completo, nao apenas o epiteto; movido para `scientificName` (0.93).
  - `"species"` (en) estava ausente do bundle; sem hit de sinonimo, o lookup caia em token-overlap com score 0.55 (zero tokens em comum entre `["species"]` e `["scientific", "name"]`); adicionado a `scientificName` (0.93).
- Titulos das abas de navegacao ficavam em branco por ~200-500ms no primeiro carregamento, pois dependiam exclusivamente de `uiOutput` + `renderUI` sem conteudo inicial.

- Validacao taxonomica BR com fallback de confirmacao no `GBIF`:
  - `florabr`/`faunabr` agora encerram automaticamente apenas nomes `accepted`;
  - resultados BR `synonym`, `ambiguous` e `not_found` seguem para tentativa de confirmacao no `GBIF`;
  - consolidacao final preserva o resultado mais informativo por `query_name`, evitando downgrade para `not_found` quando o BR ja trouxe um achado melhor;
  - testes de `utils_taxadb` ampliados para cobrir a nova regra de cascata e consolidacao.
- Onda 3 do motor Rostrum (Stage 2 + Stage 3.5):
  - composicao de `scientificName` a partir de `genus + specificEpithet` (com suporte opcional a `infraspecificEpithet` e `scientificNameAuthorship`);
  - guard de circularidade por lineage `composed_from` para impedir retroalimentacao entre regras;
  - composicao de `eventDate` em ISO estrito (`YYYY`, `YYYY-MM`, `YYYY-MM-DD`) com validacao de calendario/leap year;
  - fallback pos-conflito para `verbatim*` (`decimalLatitude`, `decimalLongitude`, `eventDate`) sem sobrescrever alvo ja mapeado.
- Nova suite `tests/testthat/test-utils-rostrum-stage2.R` cobrindo:
  - composicao/scientificName (presenca, skip por mapeamento existente, skip por override manual, guard de circularidade);
  - composicao/eventDate (completo, parcial, invalido e leap year);
  - fallback Stage 3.5 para `verbatim*`.
- Onda 4 do motor Rostrum (Stage 3 completo):
  - resolvedor multicriterio deterministico por candidato (score, validacao, tipo, completude, especificidade e tokenizacao), com desempate final alfabetico;
  - ambiguidade legitima com comparacao float-safe (`gap < ambiguity_gap - sqrt(eps)`);
  - mapeamento de perdedor para termo relacionado `verbatim*` com guard de score minimo e alvo livre.
- Nova suite `tests/testthat/test-utils-rostrum-stage3.R` cobrindo conflitos, ambiguidade, determinismo e fallback de perdedores.
- Onda 5 do motor Rostrum (aprendizado local em SQLite):
  - API de aliases com upsert transacional (`BEGIN IMMEDIATE`), eventos auditaveis e lookup por precedencia (`personal > institution > public`);
  - funcoes de captura de aprendizado (`rostrum_record_alias_confirmation`, `rostrum_record_alias_override`);
  - rollback em lote por sessao com `undo_session_aliases(conn, run_id)`.
- Nova suite `tests/testthat/test-utils-rostrum-aliases.R` cobrindo persistencia, deprecacao, precedencia e update sem duplicacao.
- Onda 6 do motor Rostrum (Templates V3 — JSON + SQLite):
  - validador de payload JSON com checagem de campos obrigatorios, tipos, itens duplicados e janela de versao (`utils::compareVersion()`);
  - `app_min_version` futura rejeita o template; `app_max_version` passada emite warning mas carrega;
  - export (`rostrum_export_template_json`) e import (`rostrum_import_template_json`) com persistencia SQLite transacional;
  - aplicacao de template com override de score para 1.0 e status `TEMPLATE`, inserida no pipeline APOS Stage 1 e ANTES de Stage 2;
  - deteccao e log de conflitos entre template e sugestao heuristica;
  - catalogo local com filtros por `institution_id` e `use_case` (`rostrum_list_template_catalog`);
  - badge `.badge-template` em roxo `#8e44ad` no CSS; chave i18n `rostrum_badge_template` e `rostrum_reason_template_override` (PT/EN);
  - migracao de schema v1 -> v2 adicionando coluna `use_case` com backward compatibility.
- Nova suite `tests/testthat/test-utils-rostrum-templates.R` cobrindo validacao, versao, export/import, prioridade e catalogo.
- Onda 7 do motor Rostrum (V4+ hardening, performance e rollout):
  - modo debug via `options(saira.rostrum.debug = TRUE)` com logging por `message()` em pontos criticos do pipeline;
  - campos de timing `stage1_ms`, `stage2_ms`, `stage3_ms` no retorno de `run_rostrum_engine()` e na tabela `rostrum_runs`;
  - paralelizacao opcional de Stage 1 com `future`/`furrr` via feature flag `stage1_parallel = FALSE` (desligado por padrao); determinismo validado entre modos `sequential` e `multisession`;
  - remocao do legado: `run_automap_v1()` e toggle `enable_automap_v1` removidos; testes atualizados;
  - `adapt_synonyms_v1_to_v2()` mantida por mais uma release como safety net.
- Nova suite `tests/testthat/test-performance-regression.R` com thresholds: Stage 1 < 7.5s, Stage 2 < 2s, Stage 3 < 0.5s, pipeline completo < 8s (gateada por `RUN_PERF=true`).
- Completacao da PR-1.2 (migracao de sinonimos para SQLite):
  - `rostrum_seed_synonyms_if_empty(conn, v1_path)`: popula `rostrum_synonyms` no SQLite a partir do RDS legado na primeira execucao (idempotente, transacional);
  - `rostrum_load_synonyms_from_db(conn)`: le sinonimos ativos do SQLite retornando formato V1-compativel (`name_score`, `lang`) para uso direto em `sanitize_synonyms_table()`;
  - `run_rostrum_engine()` agora tenta SQLite primeiro quando `conn` disponivel, com fallback para V1 RDS se tabela vazia;
  - 4 novos testes em `test-utils-rostrum-db.R`: seed com 2 linhas, idempotencia, formato V1-compativel de saida, retorno NULL em tabela vazia.
- Cache persistente dos provedores BR com governanca de versao:
  - `brprovider_ensure_data()` com bootstrap sincrono no primeiro download e update assincrono em background quando cache local ja existe;
  - metadata por provider em `<provider>.meta.json` com `local_version`, `remote_version_last_seen`, `last_checked_at`, `last_updated_at`, `status`, `last_error` e `retry_after_at`;
  - lock por provider (`<provider>.update.lock`) para evitar concorrencia em multiplos cliques/sessoes;
  - escrita atomica de cache com `<provider>.rds.tmp` + swap para `<provider>.rds` + backup `<provider>.rds.bak`.
- Descoberta de versao remota via pagina oficial do IPT (`ipt.jbrj.gov.br`) com comparacao segmentada de versoes numericas.
- Observabilidade de status para UI:
  - funcoes `brprovider_cache_status()`/`brprovider_cache_statuses()`;
  - badges por provider (`up_to_date`, `update_in_progress`, `update_failed`, `never_downloaded`);
  - notificacao quando update em background conclui.
- Novas suites/casos de teste:
  - `tests/testthat/test-utils-brproviders.R` (versao, lock, bootstrap, fallback, rollback e polling de update);
  - `tests/testthat/test-utils-taxadb.R` (integracao de `brprovider_ensure_data()` no state machine);
  - `tests/testthat/test-mod-validate-names-server.R` (badges de status no painel de configuracao).

### Corrigido
- `R/utils_brproviders.R`: badge "Update failed" persistia no painel de provedores mesmo apos validacao bem-sucedida com cache local disponivel — `brprovider_cache_status()` ja revertia `never_downloaded → up_to_date` quando `has_data = TRUE`, mas faltava o bloco equivalente para `update_failed → up_to_date`; adicionado bloco simetrico apos a regra existente.
- `R/mod_validate_names.R`: textos dos badges de status de provedor (`Up to date`, `Updating...`, `Update failed`, `Not downloaded`) e notificacoes de conclusao de update em background estavam hardcoded em ingles, ignorando o idioma selecionado; migrados para `tr()` com 6 novas chaves i18n (`validate_names_provider_status_*` e `validate_names_provider_notify_*`).
- `R/utils_brproviders.R`: download do faunabr/florabr nao ocorria quando `verbose = FALSE` — `get_faunabr()` e `get_florabr()` condicionam o bloco de `httr::GET` a `verbose = TRUE` internamente; `brprovider_download_data()` agora sempre passa `verbose = TRUE` para os dois pacotes, desacoplando verbosidade do saira da verbosidade do provider.
- `R/utils_brproviders.R`: artifact check do faunabr verificava `taxon.txt` (arquivo intermediario extraido do zip) em vez de `CompleteBrazilianFauna.gz` (saida final de `get_faunabr()` lida por `load_faunabr()`); corrigido para refletir o artefato real.
- `R/utils_brproviders.R`: chamada a `faunabr::get_faunabr()` envolvida em `withCallingHandlers()` que converte warnings de extracao de zip (`error 1 in extracting from zip`, `cannot open`) em `stop()` com mensagem descritiva e instrucao de rede.
- `R/utils_taxadb.R`: warning de deprecacao do dbplyr (`check_from argument of tbl_sql() is deprecated as of dbplyr 2.5.0`) suprimido com `withCallingHandlers()` nas duas chamadas a `taxadb::filter_name()` — issue upstream no taxadb/dbplyr, nao bloqueante, mas ruidoso no console.
- `R/mod_mapping.R`: conexao SQLite (`rostrum_connect()`) nao era criada no modulo — aliases e templates do banco nunca eram aplicados; `conn` agora e inicializado no `mod_mapping_server()` e repassado ao `run_rostrum_engine()`.
- `R/mod_mapping.R`: overrides manuais de mapeamento nao eram registrados como aliases; observer de mudanca manual agora chama `rostrum_record_alias_override()`.
- `R/mod_mapping.R`: confirmacao de escolha AMBIGUO nao gravava alias de aprendizado; observer `confirm_ambiguity_choice` agora chama `rostrum_record_alias_confirmation()` ou `rostrum_record_alias_override()` conforme a escolha.
- `R/utils_taxadb.R`: gate de inicializacao de provedor BR foi trocado para `brprovider_ensure_data()`; quando update remoto falha mas cache local existe, a validacao segue com o melhor cache disponivel sem interromper o usuario.
- `R/utils_brproviders.R`: status de metadata passa a preservar `update_failed` mesmo sem cache local, permitindo feedback correto no UI apos falha de bootstrap.

### Alterado
- `R/utils_rostrum_engine.R`: Stage 2 deixou de ser passthrough e passou a gerar saida composta com `explain_json`/`composed_from_json`.
- `R/utils_rostrum_engine.R`: degradacao do orquestrador ajustada para fallback correto (`Stage 2` falha -> resultado final preserva `Stage 1`).
- `R/utils_mapping.R`: `build_eventdate_interval()` vetorizada (remocao de loop row-by-row), mantendo contrato funcional do parser legado de intervalo.
- `R/utils_rostrum_engine.R`: `run_rostrum_engine(..., conn=...)` passou a aplicar overrides de alias antes dos stages 2/3, preservando comportamento legado sem conexao SQLite.
- `R/mod_mapping.R`: mapeamento de `reason_code` atualizado para novos codigos de fallback `verbatim*` em badges/tooltip.

### Corrigido
- `app_ui()`: `tags$head(...)` movido para fora de `bslib::page_navbar()` via `tagList`, eliminando warning de itens de navegacao invalidos em R CMD check.
- Non-ASCII em `R/app_ui.R`, `R/app_server.R`, `R/mod_upload.R` e `R/utils_export.R` substituidos por escapes `\uXXXX` (portabilidade).
- `man/mod_preview_server.Rd` e `man/validate_coords_cc_df.Rd` regenerados via `devtools::document()` para eliminar codoc mismatch.
- E2E (`test-e2e-flows.R`): `app_dir` substituido por `shiny::shinyApp()`; gate `RUN_E2E=true` adicionado para isolar suite em etapa dedicada.
- `R/utils_rostrum_engine.R`: correcoes em tie-break e fallback de Stage 3 para evitar race de ambiguidade e garantir comportamento deterministico em repeticoes.

---

## [0.2.0] - 2026-02-28

### Adicionado
- **CSS modular**: `custom.css` quebrado em 17 modulos por dominio (`inst/app/www/css/`), com script de build deterministico (`data-raw/build_css.R`) e guardrails de header e completude.
- **i18n externalizado**: dicionario migrado de lista inline R (1810 linhas) para `inst/extdata/i18n.json` (601 chaves), com loader+cache em `data_dictionary.R` e BOM removal inline.
- **Testes de cobertura**: `test-mod-wiki-server.R` (5 testes), `test-mod-help-server.R` (8 testes), `test-mod-upload-server.R` expandido de 1 para 7 testes.
- **E2E com shinytest2**: suite `test-e2e-flows.R` com 4 fluxos (upload+mapeamento, wiki, help+busca, troca de idioma).
- **Release gate**: `scripts/release_gate.R` com 5 etapas (unit, CSS, i18n, E2E, R CMD check).
- **CI**: `.github/workflows/test.yml` com GitHub Actions.
- `R/utils_common.R` com `is_blank_value()` extraido de `utils_mapping.R` (DRY).

### Alterado
- **Contrato `mod_mapping_server`**: retorno migrado de `reactive` com `attr()` para `list()` explicita com 4 slots (`processed_data_r`, `preview_data_r`, `validation_gate_r`, `validation_gate_coords_r`).
- `app_server.R` atualizado para consumir `list()` com fallback defensivo.
- `mod_mapping.R` refatorado: assistente `basisOfRecord` extraido para `mod_mapping_basis_assistant.R`, blocos de UI/automap para `mod_mapping_cards.R` e `mod_mapping_loading.R`. Contagem de linhas de 1834 para ~1150.
- `data_dictionary.R` reescrito de 1810 para 61 linhas (JSON loader).
- Closure `custom_language_choices` removida; logica inlined em `mod_mapping_cards.R`.

### Corrigido
- `custom_language_choices` nao encontrada em runtime apos extracao para `mod_mapping_cards.R`.
- `strip_bom()` nao disponivel em tempo de source por ordem alfabetica de carregamento; BOM removal inlined em `data_dictionary.R`.

### Documentacao
- `docs/DECISIONS.md`: ADR-054 (contrato list), ADR-055 (CSS modular), ADR-056 (i18n JSON).
- `docs/LESSONS.md`: licoes sobre load order, CSS build, i18n cache.
- `docs/ENCODING_RULES.md`: regra 9 para `i18n.json`.

### Testes
- Suite total: **2659 PASS, 0 FAIL** (baseline era 2604, +55 testes novos).

---

## [0.1.31] - 2026-02-28

### Alterado
- `R/app_server.R`: reatividade de idioma com debounce de 150ms e bypass de startup via `reactiveVal` flag.
- `R/utils_coords.R`: fuzzy matching de paises vetorizado (batch `adist`) com `tryCatch` de resiliencia. `normalize_country_token` com `iconv(from = "UTF-8")` explicito.

### Testes
- `test-coords-country-to-iso3.R`: 5 novos testes — snapshot de regressao, adversarial, ambiguidade, batch heterogeneo 50+, e budget com tokens diversos nao-reconhecidos.

### Documentacao
- `docs/DECISIONS.md`: novo ADR-053 sobre debounce 150ms e fuzzy batch.

---

## [0.1.30] - 2026-02-27

### Alterado
- Resolucao do teste de mar (`cc_sea`) migrada de `scale = 110` (1:110M, ~10km) para `scale = 10` (1:10M, ~1km), usando dados de alta resolucao do pacote `rnaturalearthhires`.
- Fallback automatico para `scale = 50` quando `rnaturalearthhires` nao esta instalado.
- Clustering de marcadores do Leaflet (`markerClusterOptions`) removido na aba `validate_coords` — pontos agora renderizam individualmente nas posicoes reais.
- Raio dos marcadores adaptado ao tamanho do dataset: 6px (<=2000 pontos) ou 4px (>2000 pontos) para performance.
- Chip de alerta (`alert-warning`) adicionado na legenda do mapa informando que pontos costeiros podem ser flagados incorretamente pelo teste de mar.
- Nota de cluster removida (clustering eliminado).

### Adicionado
- `rnaturalearthhires` adicionado em `Suggests` no `DESCRIPTION` com `Additional_repositories: https://ropensci.r-universe.dev`.
- Nova chave i18n `validate_coords_sea_precision_note` (PT/EN) para o chip de alerta de precisao do mar.

### Documentacao
- `docs/DECISIONS.md`: novo ADR-052 formalizando migracao de `seas_scale` e remocao de clustering.
- `docs/LESSONS.md`: novas licoes sobre convencao Natural Earth, `rnaturalearthhires` e clustering vs pontos individuais.

## [0.1.29] - 2026-02-27

### Corrigido
- Modal de revisao manual na aba `validate_names` nao abria e bloqueava a tela:
  - `hidden.bs.modal` no `lifecycle_script` estava registrado em elemento filho (`div#review_modal_root`) em vez do ancestor `.modal`; eventos DOM borbulham para cima e nunca alcancavam o listener, impedindo a limpeza de `body.vn-review-open` e deixando o backdrop ativo permanentemente.
  - `resolve_review_target()` retornava `NULL` silenciosamente quando `rv$stream_df` ficava stale entre render e clique, sem feedback ao usuario.

### Alterado
- `resolve_review_target()` agora tenta `rv$stream_df` primeiro e faz fallback para `validation_result()` quando o stream nao contem o nome clicado.
- `observeEvent(input$open_review_target)` agora exibe notificacao de aviso e executa limpeza defensiva do backdrop (`vnCleanupBackdrop`) quando o alvo nao pode ser resolvido.
- Handler JS `vnCleanupBackdrop` registrado na UI do modulo para remover `body.vn-review-open`, backdrops e estado `modal-open` residuais.
- Nova chave i18n `validate_names_review_target_not_found` adicionada em `data_dictionary.R`.

## [0.1.28] - 2026-02-27

### Adicionado
- Fluxo de revisao manual inline na aba `validate_names` para nomes problematicos (`Nao encontrado`, `Ambiguo`, `Sinonimo`):
  - botao `✎ Revisar` por card problematico;
  - modal unico reutilizavel com dois modos (`confirmacao rapida` e `edicao`);
  - estado vazio comemorativo com CTA `Exportar` (navega para aba Preview).
- Novo payload reativo de revisao manual anexado ao retorno de `mod_validate_names_server` via atributo `review_export_payload`.
- Nova camada pura de export em `R/utils_export.R`:
  - `apply_name_review_payload()` adiciona colunas `validacao_manual` e `motivo_revisao` para todas as linhas;
  - aplica confirmacoes/correcoes manuais por `query_name` normalizado, incluindo substituicao de `scientificName` em todas as ocorrencias.

### Alterado
- `mod_preview_server()` recebeu parametro opcional `name_review_payload_r = NULL` e passou a aplicar revisoes manuais antes de `process_for_export()`.
- `app_server()` agora conecta `mod_validate_names_server()` ao `mod_preview_server()` via payload de revisao manual.
- `build_validation_report()` em `R/utils_taxadb.R` passou a manter `query_name` e `input_name` no relatorio final para suportar rastreabilidade das revisoes.
- Tabela de relatorio em `validate_names` passou a:
  - ordenar revisoes no topo por `reviewed_at` desc;
  - exibir badge `Rev. Manual` para correcoes;
  - mostrar linha secundaria em italico com o nome substituido.

### Corrigido
- Contadores/filtros de problematicos em `validate_names` agora consideram apenas os status canonicos (`not_found`, `ambiguous`, `synonym`) e descontam nomes ja revisados.
- Estado e contagem de `Nao resolvidos` atualizam de forma reativa apos cada decisao de revisao.

### Testes
- `test-mod-validate-names-server.R` ampliado para cobrir fluxo de revisao manual (confirm/correct), ordenacao efetiva e empty state final.
- `test-utils-export.R` ampliado para cobrir defaults, confirmacao sem edicao, correcoes com/fallback de motivo e propagacao para ocorrencias repetidas.
- `test-mod-preview-server.R` ampliado para validar compatibilidade com o novo parametro opcional de payload.
- `test-utils-i18n.R` atualizado com novas chaves `validate_names_review_*`.
- `test-css-guardrails.R` atualizado com guardrail de `prefers-reduced-motion` e seletor/token do namespace `.vn-review-*`.

## [0.1.27] - 2026-02-26

### Alterado
- Aba `validate_names` ajustada para full-width local, no mesmo padrao espacial da aba `validate_coords`, sem alterar o contrato tri-coluna:
  - removido limite de largura hardcoded do shell em `mod_validate_names_ui()`;
  - adicionados contratos CSS locais para `.validate-names-page` (`width: 100%`, `max-width: none`) e para o `tab-pane` contextual (`padding-left/right: 0`).
- Layout tri-coluna preservado sem mudanca de contrato:
  - painel de configuracao continua fixo em `240px`;
  - painel de relatorio continua fixo em `340px`;
  - token de altura por viewport (`--validate-names-header-offset`) mantido.
- Tabela de relatorio da validacao de nomes refinada para reduzir compressao visual das 3 colunas:
  - distribuicao explicita por coluna no `DT::datatable` (`scientificName` priorizada, `status` compacta, `taxonomicStatus` intermediaria);
  - nova renderizacao de `taxonomicStatus` com quebra controlada;
  - ajustes de celula e largura para reduzir truncamento agressivo de `scientificName`.

### Testes
- `tests/testthat/test-css-guardrails.R` ampliado para validar o novo contrato full-width de `validate_names`:
  - presenca de `.validate-names-page` com `max-width: none`;
  - presenca de `.tab-content > .tab-pane:has(.validate-names-page)` com `padding-left/right: 0`.
- Guardrails existentes de tri-coluna (`240px`/`340px` + altura por viewport) mantidos.

### Documentacao
- `docs/DECISIONS.md`: novo ADR-050 formalizando o ajuste seguro de largura para `validate_names` com tri-coluna preservada.
- `docs/LESSONS.md`: novas licoes sobre estrategia de descompressao com shell full-width e distribuicao explicita de colunas em painel fixo.

## [0.1.26] - 2026-02-24

### Alterado
- Rename global do projeto para `saira` em identificadores tecnicos e branding:
  - `DESCRIPTION::Package` para `saira`
  - referencias de namespace (`package =`, `asNamespace`, `getFromNamespace`, `library`, `test_check`) atualizadas
  - textos de UI/documentacao/README atualizados para `Saira`
  - classe compartilhada de tabela padronizada para `.saira-table-shell`
- Assets renomeados para o novo prefixo:
  - `inst/app/www/images/saira.svg`
  - `inst/app/www/images/saira_alone.svg`
  - `inst/app/www/images/saira_alone.png`
  - `inst/app/www/lottie/lottieflow-loading-07-saira.json`
- Onda 1 implementada:
  - criados `.editorconfig` e `.gitattributes` com contrato de UTF-8/LF
  - `DESCRIPTION` com correcoes de encoding (`\\uXXXX`) e versoes minimas para `sf`, `rnaturalearth`, `rnaturalearthdata`
  - headers `# Author:` padronizados em ASCII para `Rogerio Nunes Oliveira`
  - novo `docs/ENCODING_RULES.md`
  - `.Rbuildignore` atualizado para ignorar artefatos de infraestrutura (`.editorconfig`, `.gitattributes`, `.Rprofile`, `renv`, `renv.lock`)
- Onda 2 implementada:
  - `R/utils_io.R` recebeu `strip_bom()`
  - `detect_delimiter()` agora le em UTF-8, remove BOM e trata primeira linha vazia com fallback `,`
  - removido `options(encoding = "UTF-8")` de `app.R` e `R/run_app.R`
- Onda 3 implementada:
  - `R/mod_upload.R` agora protege `get_dwc_terms()` com `tryCatch` e fallback seguro em caso de falha de RDS
  - `R/app_server.R` passou a logar fallbacks reativos e encerra sessao com log de cleanup (`[Saira] ...`)
  - validacao de `force` consolidada em `validate_force_flag()` canonica (`utils_coords` e `utils_mapping` delegam para ela)
  - `renv` inicializado com `renv.lock` versionado

### Adicionado
- Nova suite de teste `tests/testthat/test-mod-upload-server.R` cobrindo startup resiliente de `mod_upload_server()` quando `get_dwc_terms()` falha.
- Novos testes de I/O para BOM/delimitador:
  - `strip_bom()` remove BOM corretamente
  - `detect_delimiter()` com BOM e arquivo vazio
- Novos testes de validacao de `force`:
  - `load_dwc_synonyms_v1(force = ...)`
  - `coords_load_aliases(force = ...)`

### Documentacao
- `docs/DECISIONS.md`: novos ADRs para rename global `Saira` e hardening de encoding/BOM/defesas.
- `docs/LESSONS.md`: novas licoes sobre rename de pacote sem compat legada, BOM em delimitador e fallback defensivo de startup.

## [0.1.25] - 2026-02-24

### Alterado
- Aba `validate_names` refatorada para shell tri-coluna:
  - coluna esquerda fixa (`240px`) para configuracao (provedores, toggles e acao);
  - coluna central flexivel para stream de nomes processados;
  - coluna direita fixa (`340px`) para relatorio tabular.
- `R/mod_validate_names.R` reorganizado para novos outputs:
  - `config_panel`
  - `stream_panel`
  - `report_panel`
  - `report_table`
- Seletor de provedores migrado para cards empilhados com estado ativo e destaque de prioridade 1.
- Painel de acao consolidado com:
  - botao principal `▶ Validar Nomes`,
  - mini-stats (provedores/opcoes),
  - barra de progresso com metadados de fase/lote/provedor.
- Stream central ganhou layout dedicado com pills de filtro visiveis (`Todos`, `So problematicos`, `Nao encontrados`, `Ambiguos`, `Sinonimos`) e itens coloridos por status.
- Relatorio da direita passou a usar toolbar externa (busca + `Mostrar N`) sincronizada via callback JS com `DT::datatable`.
- `inst/app/www/custom.css` expandido com namespace local `.vn-*` para evitar side effects cross-modulo e com novos utilitarios de badge (`badge-success`, `badge-warning`, `badge-error`, `badge-info`, `badge-muted`).
- Novas chaves i18n adicionadas para os textos da UI v3 de validacao de nomes (acao, progresso, stream e relatorio).

### Corrigido
- Contraste semantico da tabela de relatorio por status alinhado ao `design.md`:
  - sinonimo (`info-bg`),
  - ambiguo (`warning-bg`),
  - nao encontrado (`error-bg`),
  - aceito/ignorado (`#ffffff`).

### Testes
- `tests/testthat/test-mod-validate-names-server.R` ampliado com cobertura de classificacao dos buckets de relatorio (`valid`, `invalid`, `unresolved`, `total`).
- `tests/testthat/test-utils-i18n.R` atualizado para exigir e resolver as novas chaves `validate_names_*` da UI v3.
- `tests/testthat/test-css-guardrails.R` ampliado com guardrails do layout tri-coluna (`token de altura`, `larguras fixas 240/340`).

### Documentacao
- `docs/DECISIONS.md`: novo ADR sobre o contrato tri-coluna da aba `validate_names` e sincronizacao de controles externos com `DT`.
- `docs/LESSONS.md`: novas licoes sobre shell tri-coluna com altura de viewport e binding delegado para toolbar externa de DataTable.

## [0.1.24] - 2026-02-24

### Alterado
- Migracao tipografica global para `design-v5`: `Cormorant Garamond` (serif) + `Space Mono` (mono), preservando paleta, layout e interacoes do v4.
- `R/app_ui.R` atualizado para:
  - usar `font_collection` v5 no `bs_theme` (`base_font`/`heading_font` serif e `code_font` mono);
  - carregar explicitamente a URL oficial do Google Fonts do v5 no `head`.
- `inst/app/www/custom.css` atualizado com fundacao tipografica v5:
  - remocao do `@import` antigo de IBM Plex;
  - novos tokens `--font-serif`, `--font-mono` e alias `--font-sans -> --font-serif`;
  - body/headings/labels/code/buttons alinhados ao novo contrato tipografico.
- Hardcodes tipograficos de IBM foram removidos dos modulos locais (`wiki`, `help`, `upload`, `mapping`, `preview`, `validate_names`, `validate_coords`) em favor de tokens CSS.
- Guardrail de legibilidade para diagnosticos compactos de coordenadas adicionado com ajuste de `letter-spacing` e `tabular nums`, sem alterar geometria/layout dos componentes.
- `docs/design.md` atualizado para o conteudo de `design_v5.md` como referencia oficial do design system.

### Testes
- `tests/testthat/test-css-guardrails.R` expandido para bloquear regressao de hardcoded `font-family` IBM e validar tokens tipograficos v5.
- Nova suite `tests/testthat/test-app-ui-fonts.R` adicionada para validar:
  - injecao do Google Fonts v5 no `app_ui`;
  - ausencia de referencias antigas IBM no `bs_theme`;
  - manutencao de `custom.css` com cache-busting.

### Documentacao
- `docs/DECISIONS.md`: novo ADR sobre estrategia de migracao tipografica v5 com aliases de compatibilidade e guardrails anti-regressao.
- `docs/LESSONS.md`: novas licoes sobre evitar hardcode de familia tipografica em CSS e validar legibilidade de mono em tamanhos pequenos.

---

## [0.1.23] - 2026-02-24

### Corrigido
- Aba `help`: alinhamento definitivo da lupa no campo de busca com ancoragem no wrapper relativo `.help-search-input-wrap`, mantendo o icone dentro da caixa em todos os breakpoints.
- Posicionamento da lupa estabilizado com caixa fixa (`14x14`), `left: 13px`, `top: 50%` e `transform: translateY(-50%)`, combinado com `padding-left: 42px` no input para evitar colisao com o texto.
- Interferencia de espacamento do Shiny/Bootstrap removida no card de busca (`.shiny-input-container` e `.control-label` com `margin-bottom: 0`), garantindo baseline consistente entre icone e placeholder.

---

## [0.1.22] - 2026-02-23

### Alterado
- Redesign completo da aba `help` com novo layout em duas colunas (`conteudo + sidebar sticky`) e wrapper expandido para `max-width: 1400px`.
- `R/mod_help.R` refatorado para:
  - substituir acordeao `bslib::accordion` por acordeao custom com toggles semanticos (`aria-expanded`) e estrutura visual dedicada;
  - adotar 4 secoes finais da ajuda (`Darwin Core`, `FAQ`, `Formatos aceitos`, `Separador de multiplos valores`);
  - mover busca para card isolado e header para card editorial;
  - adicionar sidebar com cards de `Autor`, `Reportar bug`, `Links uteis` e `Construido com`.
- Novo asset client-side `inst/app/www/help-accordion.js` com event delegation para abrir/fechar itens do acordeao mantendo compatibilidade com re-render da UI.
- `R/app_ui.R` atualizado para carregar `www/help-accordion.js` com cache-busting no mesmo padrao dos demais assets.
- `inst/app/www/custom.css` recebeu novo bloco escopado da Help (`.help-module`) com estilos completos de layout, acordeao, FAQ grid, demo de separador e cards de sidebar.

### i18n
- `R/data_dictionary.R` expandido com novas chaves PT/EN da Help:
  - header e busca (`help_header_*`, `help_search_placeholder`, `help_empty_state`);
  - secoes e conteudo (`help_section_*`, `help_dwc_*`, `help_faq_*`, `help_formats_*`, `help_separator_*`);
  - sidebar (`help_author_*`, `help_bug_*`, `help_links_*`, `help_stack_*`);
  - acessibilidade (`a11y_help_bug_link`, `a11y_help_external_link`).

### Testes
- Suites de i18n atualizadas para exigir e resolver as novas chaves da Help:
  - `tests/testthat/test-utils-i18n.R`
  - `tests/testthat/test-i18n-a11y-keys.R`

### Documentacao
- `docs/DECISIONS.md`: novo ADR formalizando o redesign da Help com acordeao custom e sidebar sticky.
- `docs/LESSONS.md`: novas licoes sobre escopo CSS local da Help e comportamento resiliente de acordeao com event delegation.

---

## [0.1.21] - 2026-02-23

### Corrigido
- Aba `wiki`: callback da toolbar externa do DataTable refeito com eventos delegados e namespace por modulo, restaurando sincronizacao de busca em tempo real e filtro por chips de classe.
- Aba `wiki`: seletor `Mostrar` corrigido para aplicar `pageLength` corretamente (incluindo `15`) e reposicionar para a primeira pagina ao trocar a quantidade.
- Aba `wiki`: shell da tabela ajustado para arredondamento continuo nos cantos superiores e inferiores.

---

## [0.1.20] - 2026-02-23

### Alterado
- Redesign completo da aba `wiki` com novo header card, toolbar unificada (busca + seletor de quantidade + filtros por classe) e layout de tabela alinhado ao design system v4.
- `R/mod_wiki.R` reestruturado para:
  - substituir `title/subtitle` simples por card de cabecalho com metricas dinamicas (`50 termos`, `12 obrigatorios`, `6 classes`);
  - usar controles externos de busca/filtro/page-length sincronizados com a API do DataTables;
  - renderizar `Termo`, `Classe`, `Definicao`, `Exemplo` e `Obrigatorio` via callbacks de linha/cabecalho para aplicar badges e estilos sem alterar a assinatura publica do modulo.
- `inst/app/www/custom.css` recebeu bloco escopado da Wiki (`.wiki-module`) cobrindo:
  - header card e stat pills;
  - toolbar card e pills por classe com estados ativos tematicos;
  - thead custom com icone de sort, zebra/hover em `tbody`, badges de classe/obrigatoriedade e footer wrapper da paginacao.
- Contrato de link da Wiki atualizado para URL generica oficial do ciclo: `https://sibbr.gov.br` (subtitulo e links de termo).

### i18n
- Novas chaves adicionadas em `R/data_dictionary.R` para textos do novo header/toolbar da Wiki:
  - `wiki_header_eyebrow`, `wiki_header_link_label`
  - `wiki_stats_terms_label`, `wiki_stats_required_label`, `wiki_stats_classes_label`
  - `wiki_show_label`, `wiki_records_label`
  - `a11y_wiki_page_length_label`
- Textos existentes da Wiki refinados:
  - `wiki_subtitle` atualizado para copy de documentacao oficial;
  - `wiki_search_placeholder` expandido para busca por termo/definicao/exemplo;
  - `wiki_class_all` encurtado para `Todas` / `All`.

### Testes
- Suites de i18n atualizadas para cobrir as novas chaves da Wiki:
  - `tests/testthat/test-utils-i18n.R`
  - `tests/testthat/test-i18n-a11y-keys.R`

### Documentacao
- `docs/DECISIONS.md`: novo ADR formalizando contrato visual/funcional da Wiki com controles externos e escopo CSS local.
- `docs/LESSONS.md`: nova licao sobre uso de toolbar externa em DataTables com footer wrapper sem alterar a paginacao interna.

---

## [0.1.19] - 2026-02-23

### Corrigido
- Regressao visual do header apos rollout do design-v4:
  - mais espacamento entre itens de navegacao;
  - padding ajustado dos links para evitar "box colado" no texto;
  - alinhamento vertical do seletor de idioma com os demais itens do navbar.
- Ajuste fino do seletor de idioma no header (desktop/tablet):
  - largura do `selectInput` ampliada para `150px`, alinhada ao padding interno;
  - `padding-right` e `background-position` do select ajustados para evitar colisao da seta com o texto;
  - fallback mobile mantido compacto via breakpoint `@media (max-width: 767.98px)`.
- Correcao de aplicacao de estilos no header em markup real do `page_navbar`:
  - overrides de espacamento/padding atualizados para `ul.navbar-nav > li > a` (alem de `.nav-link`);
  - seletor de idioma no navbar alterado para `selectize = FALSE`, eliminando sobreposicao da seta sobre o texto.
- Aba `validate_coords`: card de configuracao volta a renderizar antes do upload:
  - gates leves de validacao (`validation_gate` e `validation_gate_coords`) passaram a tratar `shiny.silent.error` de `req(input$file)` como estado `no_data`;
  - botao de validar permanece bloqueado ate cumprir as regras existentes de prontidao (`status == ok`).
- Regressao do indicador de dropdown na aba de mapeamento:
  - substituido glifo suscetivel a encoding por escape CSS seguro (`content: '\25BE'`), eliminando exibicao `â–¾`.
- Removido ultimo caso remanescente de borda lateral grossa unilateral em box estilizado, reforcando padrao de borda fina completa.

### Documentacao
- `docs/architecture.md`: adicionada secao de guardrails visuais obrigatorios para caixas, navbar e indicadores de dropdown.
- `docs/DECISIONS.md`: novo `ADR-040` formalizando contrato visual anti-regressao.
- `docs/LESSONS.md`: reforcadas licoes de CSS sobre bordas unilaterais, encoding de seta de dropdown e alinhamento de navbar.

---

## [0.1.18] - 2026-02-22

### Alterado
- Rework completo do design system para o `design-v4`, com migração da paleta principal do app para a nova identidade (`primary/accent/success/warning/error/info`) e manutenção do fundo base `#f4f3ee`.
- `bs_theme` do `app_ui` alinhado ao v4 mantendo `bootswatch = "flatly"` para reduzir risco de regressão funcional.
- `inst/app/www/custom.css` atualizado com tokens v4, novos tokens semânticos de formulário/navbar, sombras/focus rings e compatibilização dos componentes existentes (`buttons`, `alerts`, `badges`, `stream pills`, `status badges`, `coord badges`).
- Cores de diagnóstico de coordenadas alinhadas ao v4 em `R/utils_coords.R` para manter consistência entre tabela, badges e mapa.
- Estado vazio da aba de mapeamento passou de estilos inline hardcoded para classes CSS (`mapping-empty-state`, `mapping-empty-icon`).

### Corrigido
- Falhas pré-existentes da suíte `test-css-guardrails`:
  - removido uso de tokens CSS indefinidos;
  - removido excesso de `!important` (limite hard guardrail);
  - removido `opacity: 0.45` da paginação desabilitada do DataTables.
- Falhas pré-existentes da suíte `test-i18n-a11y-keys` com adição das 9 chaves ausentes no dicionário.

### Acessibilidade
- Inputs sem label visível receberam labels acessíveis:
  - seletor de idioma no navbar;
  - upload de arquivo;
  - busca da ajuda;
  - busca e filtro de classe da Wiki;
  - selects de destino no assistente `basisOfRecord`.
- Sidebar de mapeamento ganhou rótulos semânticos para seções de ações e filtros.

### Documentação
- `docs/design.md` sobrescrito pelo conteúdo de `design-v4.md`, consolidando oficialmente o novo design do app.

### Testes
- `devtools::test()` verde (`PASS 1900`, `FAIL 0`).

---

## [0.1.17] - 2026-02-22

### Alterado
- Reposicionamento do mapa de `validate_coords` passou a usar enquadramento dinamico pelos pontos exibidos no filtro ativo:
  - removido `fitBounds` fixo da America do Sul na inicializacao;
  - inicializacao padrao com `setView(0, 0, zoom = 2)`;
  - apos plotar marcadores, `leafletProxy` calcula limites reais (`min/max` de `lat_num/lon_num`) e aplica `fitBounds`.
- Tratamento de ponto unico adicionado no mapa de coordenadas:
  - quando todos os pontos visiveis colapsam no mesmo par lat/lon, o app usa `setView(..., zoom = 8)` em vez de `fitBounds` degenerado.

### Corrigido
- Evitado viés regional no mapa apos validacao (antes o foco inicial sempre voltava para bounding box fixo).
- Melhorado o foco visual apos troca de pills/filtros, mantendo o mapa centralizado no subconjunto realmente exibido.

---

## [0.1.16] - 2026-02-22

### Alterado
- Modal de loading da aba `validate_coords` passou a renderizar o web component de animacao com HTML explicito (`<lottie-player ...>`) em vez de `shiny::tags$` para tag customizada.
- Fluxo de arranque da validacao em `observeEvent(rv$start_requested)` ficou resiliente a falhas visuais de modal:
  - `showModal()` protegido por `tryCatch`;
  - `rv$run_requested <- TRUE` preservado mesmo com erro de UI;
  - aviso de fallback adicionado (`validate_coords_modal_fallback`).
- Tamanho do icone/animação de loading reduzido para metade no modal de coordenadas (`.coords-loading-lottie`: `90x70`).
- Basemap do mapa de coordenadas atualizado para oferecer escolha entre:
  - `providers$OpenStreetMap` (padrao)
  - `providers$Esri.WorldImagery` (opcional via controle de camadas)

### Corrigido
- Erro fatal no clique de validacao de coordenadas: `attempt to apply non-function` ao abrir modal com `lottie-player`.
- Regressao de UX onde a validacao aparentava "demorar" por abortar antes do processamento real quando o modal falhava.

### Testes
- `devtools::test(filter='mod-validate-coords-server')` verde (`PASS 16`, `FAIL 0`), incluindo novo teste de regressao para falha em `showModal()`.

---

## [0.1.15] - 2026-02-22

### Alterado
- Removido `cc_coun` (country mismatch) do pipeline de diagnóstico da aba `validate_coords`.

---

## [0.1.14] - 2026-02-22

### Adicionado
- Artefato de aliases de pais externalizado em `inst/extdata/country_aliases.rds` (seed inicial com aliases frequentes), substituindo a dependencia de dicionario hard-coded em codigo
- Script reprodutivel `data-raw/generate_country_aliases.R` para gerar e atualizar `country_aliases.rds`
- Novas funcoes internas em `R/utils_coords.R` para suporte ao novo fluxo:
  - `resolve_country_aliases_path()` para resolver caminho do `.rds` em ambiente de desenvolvimento e pacote instalado
  - `coords_sanitize_aliases_table()` para validar/sanitizar estrutura `alias`/`iso3c`
  - `coords_load_aliases()` com cache em sessao para leitura unica do `.rds`
  - `coords_build_fuzzy_reference()` com cache da referencia multilíngue usada no fallback fuzzy
- Nova suite dedicada de testes `tests/testthat/test-coords-country-to-iso3.R` cobrindo camadas de resolucao, casos negativos e budget de performance

### Alterado
- `coords_country_to_iso3()` foi reescrita em cascata de 5 camadas:
  - `iso3c` estrito
  - `iso2c` estrito
  - CLDR multilíngue via `countrycode::codelist` + `custom_dict`
  - aliases customizados via `.rds`
  - fuzzy matching conservador
- Conversao de pais agora deduplica valores unicos, resolve em lote e re-expande para o vetor original, preservando cardinalidade e ordem
- `coords_alias_map()` foi mantida por compatibilidade retroativa, mas passou a ser wrapper do `.rds` (sem hard-code interno)
- `validate_coords_cc_df()` passou a herdar automaticamente o novo comportamento de resolucao de pais via `coords_country_to_iso3()`
- `.Rbuildignore` atualizado para ignorar `data-raw/` no build do pacote

### Corrigido
- Reducao relevante de `country_unresolved` para entradas heterogeneas (PT/EN/ES, siglas, abreviacoes e erros de digitacao leves)
- Endurecimento do fuzzy para reduzir falso positivo: comprimento minimo, distancia maxima relativa, exigencia de melhor match unico e margem para segundo melhor candidato

### Testes
- `devtools::test(filter = "coords-country-to-iso3|utils-coords")` verde
- `devtools::test(filter = "mod-validate-coords-server|mod-mapping-server")` verde

---

## [0.1.13] - 2026-02-21

### Adicionado
- Novo motor canonico de coordenadas em `R/utils_coords.R` com `validate_coords_cc_df(df, lat_col, lon_col, country_col, profile, seas_scale)` usando `CoordinateCleaner` como engine principal
- Conversao `country -> ISO3` com cadeia de resolucao (`iso3c -> iso2c -> country.name`) e mapa minimo de aliases para reduzir falhas de mapeamento
- Diagnostico final deterministico por linha (`diagnostic` + `diagnostic_family`) sem exclusao de registros, com preservacao de cardinalidade (`nrow(out) == nrow(in)`)
- Perfis de execucao no motor de coordenadas:
  - `complete`: `capitals`, `centroids`, `countries`, `equal`, `gbif`, `institutions`, `seas`, `zeros`
  - `fast`: `countries`, `equal`, `seas`, `zeros`
- Pos-processamento legado apos `CoordinateCleaner` preservado para:
  - `swapped` (possivel inversao lat/lon)
  - `identical_all` (todas as coordenadas completas identicas)
- Novo contrato de gate leve de coordenadas em `mod_mapping` com suporte a `country`:
  - `coords_status`, `has_data`, `lat_col`, `lon_col`, `country_col`, `has_lat`, `has_lon`, `has_country`
  - estados granulares: `no_data`, `ok`, `missing_lat`, `missing_lon`, `missing_country`, `missing_multiple`
- Nova suite de testes de modulo para coordenadas: `tests/testthat/test-mod-validate-coords-server.R`

### Alterado
- Aba `validate_coords` migrada para layout full-width real:
  - remocao de `max-width` fixo no container
  - grid principal `col-lg-2` (esquerda) + `col-lg-10` (direita)
  - area de resultados em `50/50` (`col-lg-6` mapa + `col-lg-6` tabela)
- Fluxo de execucao da validacao refeito para usar exclusivamente `validate_coords_cc_df(...)` no clique de validar
- Gate da UI de coordenadas passou a bloquear execucao ate haver mapeamento de `lat/lon/country`
- Card de acao da validacao ganhou seletor de perfil (`Complete`/`Fast`)
- Pills da aba de coordenadas migradas para familias de diagnostico:
  - `all`, `problems`, `validity`, `country`, `sea`, `zero_equal`, `reference`
- Tabela de diagnostico expandida para 6 colunas:
  - `Linha`, `Diagnostico`, `Latitude`, `Longitude`, `Country`, `ISO3`
- Legenda do mapa alinhada ao novo contrato por familias de diagnostico, mantendo nota de cluster para evitar interpretacao incorreta de cor
- `DESCRIPTION` atualizado para incluir dependencias espaciais em `Imports`:
  - `CoordinateCleaner`, `countrycode`, `sf`, `rnaturalearth`, `rnaturalearthdata`
- `NAMESPACE` atualizado para exportar `validate_coords_cc_df`

### Corrigido
- Fluxo reativo interno da validacao de coordenadas ajustado para executar corretamente no primeiro disparo e em ambiente de teste (`testServer`)
- Observer de warning de conversao de coordenadas endurecido para tratar atributos ausentes em cenarios mockados
- Testes de filtro da aba de coordenadas ajustados ao comportamento oficial da UI (filtro padrao pos-validacao em `problems`)

### Testes
- Atualizada cobertura de `tests/testthat/test-utils-coords.R` para pipeline CC completo:
  - parse decimal com virgula
  - `country` resolvido e nao resolvido
  - `validity_missing` e `validity_bounds`
  - mapeamento de flags CC para familias/diagnostico
  - prioridade de diagnostico
  - `swapped` e `identical_all`
  - garantia de cardinalidade
- Atualizada cobertura de gate em `tests/testthat/test-mod-mapping-server.R` com `country_col` e estados granulares
- Nova cobertura de integracao da aba em `tests/testthat/test-mod-validate-coords-server.R`:
  - bloqueio sem `country`
  - execucao com `lat/lon/country`
  - troca de perfil
  - filtros por familia afetando stream de dados

---

## [0.1.12] - 2026-02-21

### Adicionado
- Gate leve dedicado para coordenadas no `mod_mapping` (`validation_gate_coords`) com contrato `coords_status/lat_col/lon_col`
- Wiring no `app_server` para repassar gate de coordenadas ao `mod_validate_coords`
- Layout da aba `validate_coords` reorganizado em painéis separados (`stats_panel`, `filter_pills`, `map_panel`, `table_panel`) com grid `col-lg-3/9`
- Estilos de sidebar sticky e classes semânticas para estatísticas de coordenadas (`stat-box-ok/error/warn/muted`)

### Alterado
- `validate_coords` (wrapper legado) passou a delegar para `validate_coords_df`, mantendo assinatura e adicionando `issue_type/error_key` no retorno
- Aba de coordenadas passou a usar gate explícito por parâmetro opcional em `mod_validate_coords_server(..., validation_gate_r = NULL)`
- `DESCRIPTION` atualizado com `leaflet (>= 2.1.0)` em `Imports`

### Corrigido
- Dependência ausente de `leaflet` que poderia quebrar `R CMD check`
- Habilitação da validação de coordenadas desacoplada do caminho pesado de `mapped_data` quando gate leve está disponível
- Sinal visual de "Válidas" na aba de coordenadas alinhado para classe semântica (`stat-box-ok`) em vez de cor inline inconsistente

---

## [0.1.11] - 2026-02-21

### Adicionado
- Drag-and-drop robusto de upload na homepage com `upload-dropzone.js` carregado no `app_ui` com cache-busting
- Copy central dentro do dropzone com duas linhas i18n (`upload_dropzone_hint` e `upload_max_size`)
- Classes CSS dedicadas ao dropzone de superficie inteira (`upload-dropzone-copy`, `upload-dropzone-max-size`) e estados (`is-dragover`, `has-file`)
- Classes CSS ausentes da aba `validate_coords` para suportar cards, pills, badges de issue e legenda do mapa (`validate-coords-card`, `coords-gate-*`, `coords-filter-pills`, `coord-issue-badge-*`, `coords-map-legend-*`)

### Alterado
- Homepage Upload restaurada para o padrao de dropzone grande com area clicavel inteira, hint centralizado e watermark CSV opaco de fundo
- Bloco "Tamanho maximo de arquivo" movido da lista de hints para dentro do dropzone, junto com a instrucao de arrastar/soltar
- Texto do hint de upload atualizado para instrucao unica de acao ("arraste/solte ou clique")
- `mod_validate_coords` passou a validar contrato do gate recebido por atributo antes de usar (`coords_status/lat_col/lon_col`); quando o contrato nao existe, aplica fallback seguro em `mapped_data_r()`

### Corrigido
- Regressao de drag-and-drop em navegadores com `dataTransfer.types` sem suporte uniforme a `includes`; deteccao de arquivos agora cobre `contains/indexOf/item`
- Regressao visual da homepage onde a caixa nativa do `fileInput` reaparecia junto do dropzone custom; wrapper visual nativo agora e removido no bind e o input real e reanexado ao container
- Regressao funcional na aba `validate_coords` em cenarios onde `validation_gate` de nomes era reaproveitado indevidamente e bloqueava o botao de validacao
- Regressao visual na aba `validate_coords` por classes referenciadas no modulo sem definicao no stylesheet

---

## [0.1.10] - 2026-02-19

### Adicionado
- Classe CSS compartilhada `.saira-table-shell` para padrao visual de DataTables no app inteiro
- Novas chaves i18n de DataTable na validacao de coordenadas (search/length/info/empty/zero/paginacao)
- Diretriz tecnica documentada para uso de `.saira-table-shell` em novas tabelas (`docs/LESSONS.md`) e decisao arquitetural formal (`ADR-030`)

### Alterado
- Estilo da tabela de preview aplicado de forma consistente nas tabelas de `validate_names`, `validate_coords` e `wiki` (header, busca, length menu e paginação)
- Wrappers de tabela unificados para usar `.saira-table-shell` em todos os modulos com `DT::datatable`
- `lengthMenu` padronizado para `10/25/50/100` nas tabelas de validacao de nomes, validacao de coordenadas e wiki
- Tabela da Wiki passa a abrir com 10 linhas por pagina para alinhar com o padrao visual e de navegacao do app

### Corrigido
- Inconsistencia de dimensao/estilo no dropdown "Mostrar _MENU_ registros" fora da aba Preview
- Divergencia visual dos botoes de paginacao (Anterior/Proxima) entre tabelas do app

---

## [0.1.9] - 2026-02-19

### Adicionado
- Pills horizontais de filtro na Wiki DwC com classes traduzidas e estado ativo visual, incluindo `Identification` para manter cobertura completa das classes
- Renderizacao visual da coluna `Obrigatorio` na Wiki com badges (`obrigatorio`/`opcional`)
- Novas chaves i18n da Wiki para badges e linguagem completa do DataTable (length/info/empty/zero/paginacao)

### Alterado
- Busca da Wiki unificada no campo customizado superior, com integracao via DataTables API (`table.search(...).draw()`)
- Filtro de classe da Wiki migrado para DataTables API em coluna (`table.column(1).search(...).draw()`), sincronizado com o dropdown de compatibilidade oculto
- `DT::datatable` da Wiki atualizado para `language` completo em PT/EN

### Corrigido
- Redundancia de filtros de busca na Wiki (filtro padrao do DataTables ocultado no escopo da tabela Wiki)
- Escaneabilidade da tabela Wiki melhorada com hover de linha dedicado e badges de obrigatoriedade

---

## [0.1.8] - 2026-02-19

### Adicionado
- Filtro server-side no stream da validacao de nomes com pills e contadores por status (`all`, `problems`, `not_found`, `ambiguous`, `synonym`, `ignored`)
- Novo estado de UX pre-validacao na coluna direita com hint orientativo para iniciar a validacao
- Novas chaves i18n da validacao de nomes para:
  - hint pre-validacao
  - filtros do stream
  - labels de colunas da tabela
  - badges de status
  - linguagem completa do DataTable
- Novos testes de regressao:
  - `test-mod-validate-names-server`: cobertura da logica de filtro/count no stream e default de filtro pos-conclusao
  - `test-utils-i18n`: cobertura das novas chaves da aba de validacao de nomes

### Alterado
- Layout da aba `validate_names` reorganizado para mover a secao de acao para a coluna direita e manter a coluna esquerda focada em provedores + opcoes
- Cards de provedores compactados (`min-height` menor + padding reduzido) para melhorar fit vertical no desktop
- Opcoes de validacao reorganizadas em grid de 2 colunas em viewport desktop
- Tabela de resultados da validacao (itens nao aceitos) atualizada com:
  - badges traduzidos e coloridos para `validation_status`
  - `scientificName` em italico no modo display
  - `rowCallback` para aplicar classes de highlight por status
  - linguagem completa PT/EN no DataTable
- Filtro padrao do stream apos conclusao da validacao definido para `problems` (itens acionaveis)

### Corrigido
- Desperdicio de espaco no estado inicial da aba de validacao (stream vazio sem informacao acionavel)
- Escaneabilidade baixa no pos-validacao devido a excesso de itens `accepted` no stream por default
- Leitura da tabela de resultados dificultada por status cru sem badge visual e sem localizacao completa

---

## [0.1.7] - 2026-02-19

### Alterado
- Homepage (aba `upload`) compactada para reduzir altura total e melhorar fit em viewport desktop:
  - Bloco unico de hints de upload (`upload-hints-compact`) substitui os blocos separados de especificacoes, privacidade e recomendacao
  - Fluxo "Como funciona" migrado para disposicao horizontal com 4 cards compactos e separadores visuais entre etapas
- Campos obrigatorios DwC da homepage alinhados com a mesma referencia funcional usada na aba Preview (`scientificName`, `eventDate`, `decimalLatitude`, `decimalLongitude`, `basisOfRecord`, `occurrenceID`)
- Lista de obrigatorios na homepage reestruturada para exibicao direta por categoria (sem clique em tabs), com grupos sempre visiveis: `Record-level`, `Occurrence`, `Taxon`, `Location`
- Inclusao de versionamento de URL para `www/custom.css` em `app_ui` para reduzir risco de cache stale apos mudancas visuais

### Corrigido
- Inconsistencia entre os campos obrigatorios exibidos na homepage e os criterios de prontidao da aba Preview
- Regressao de UX na homepage onde a exploracao por tabs ocultava termos obrigatorios e aumentava atrito de leitura
- Possivel persistencia de CSS antigo no navegador apos deploy local devido a cache do asset estatico

---

## [0.1.6] - 2026-02-16

### Adicionado
- Novo gate leve de prontidao da validacao de nomes exposto por `mod_mapping_server` como atributo interno `validation_gate` no reactive retornado (`status`, `has_data`, `scientific_col`)
- Novo parametro opcional `validation_gate_r` em `mod_validate_names_server` para receber o sinal leve de prontidao sem depender do dataset mapeado completo
- Novos testes de regressao:
  - `test-mod-mapping-server`: cobertura do contrato e transicoes de `validation_gate` (`no_data -> missing_scientific -> ok`)
  - `test-mod-validate-names-server`: cobertura do caminho leve garantindo que `quick_inputs()`/`can_run_validation()` nao chamam `mapped_data_r()` quando `validation_gate_r` esta presente

### Alterado
- Wiring do `app_server` para propagar `validation_gate` do modulo de mapeamento para o modulo de validacao de nomes
- `quick_inputs()` em `mod_validate_names` agora prioriza `validation_gate_r` e usa `mapped_data_r()` apenas como fallback de compatibilidade
- Documentacao de interface de `mod_validate_names_server` atualizada para refletir o novo parametro opcional
- Fluxo do clique em `Validar nomes` reestruturado em duas fases (`starting` -> `running`) para permitir repaint imediato da UI antes da etapa pesada

### Corrigido
- Latencia para habilitar o botao `Validar nomes` apos mapear `scientificName` e retornar para a aba de validacao
- Recalculo pesado desnecessario antes do clique em `Validar nomes` no caminho de prontidao da UI
- Regressao de UX onde a aba de validacao parecia "travada" apenas para decidir estado de habilitacao do botao
- Falta de feedback visual no clique em `Validar nomes`: agora o usuario recebe retorno imediato (spinner/estado em andamento) mesmo quando a preparacao pesada demora

---

## [0.1.5] - 2026-02-15

### Adicionado
- Aba de validacao de nomes com modal bloqueante no padrao Rostrum durante a execucao da validacao taxonomica, incluindo barra de progresso estimada por fases
- Resumo persistente na validacao de nomes indicando provedores consultados, provedores com falha e aviso explicito de consolidacao por nomes cientificos unicos
- Nova suite `tests/testthat/test-mod-validate-names-server.R` cobrindo controles de provedores e fluxo resiliente a falha parcial

### Alterado
- Seletor de provedores da validacao taxonomica migrado de `selectizeInput` para `checkboxGroupInput`, com ordem fixa `GBIF > ITIS > COL > NCBI` e default em `GBIF`
- Mensagem de total da validacao taxonomica atualizada para refletir consolidacao por nomes unicos

### Corrigido
- `run_taxadb_cascade()` agora trata erros por provedor individualmente, registra falhas em atributo `provider_failures` e continua a cascata com os demais provedores
- Fluxo do botao `Validar Nomes` passou a exibir feedback consistente mesmo sem dados mapeados (`req` silencioso removido), abrindo modal de carregamento antes das etapas pesadas e retornando aviso explicito quando `mapped_data` estiver vazio/ausente

---

## [0.1.3] - 2026-02-15

### Adicionado
- Checklist leve de campos obrigatorios na aba Preview com chips coloridos (`.preview-readiness-chip-ok` / `.preview-readiness-chip-missing`) para `scientificName`, `eventDate`, `decimalLatitude`, `decimalLongitude`, `basisOfRecord` e `occurrenceID`

### Alterado
- Preview da tabela alinhada ao `design.md`: paginação redesenhada (botões compactos, estado ativo consistente), caixa de busca/length menu com dimensões menores e container visual dedicado
- DataTable da Preview passa a abrir com `10` registros por página (`pageLength = 10`, `lengthMenu = 10/25/50/100`)
- Checklist de campos obrigatórios evoluiu de chips para cards de status (sem chips), com painel branco e cards internos bege
- Cards de obrigatórios agora usam apenas ícones de estado ampliados (sem texto `presente/ausente`): ausente com ícone vazado vermelho, presente com ícone preenchido verde
- Botão de download da Preview recebeu hover elegante com elevação leve, sombra de acento e foco visível
- Header da tabela da Preview ajustado para azul sólido do design system e paginação com tema azul (remoção do verde herdado no controle de páginas)
- Fluxo de download da Preview passa a usar confirmação antes do export e modal de progresso visual no padrão Rostrum, mantendo `process_for_export()` intacto

### Corrigido
- Botao "Baixar CSV Completo" na Preview sem duplicacao de icone (`downloadButton` agora com label textual + `icon` explicito)
- Seletor de quantidade em "Mostrar _MENU_ registros" no DataTable da Preview com padding/alinhamento ajustados para evitar sobreposicao da seta sobre o valor
- Testes de `mod_preview_server` atualizados para cobrir checklist de prontidao e regressao de icone duplicado no botao de download
- Modal de validacao do download da Preview agora apresenta os campos obrigatorios faltantes em card branco sobre fundo bege

---

## [0.1.4] - 2026-02-15

### Adicionado
- Nova camada `R/utils_taxadb.R` com normalizacao, deduplicacao, cascata e construcao de relatorio taxonomico via `taxadb::filter_name()`
- Aba de validacao de nomes com seletor de provedores, opcoes de limpeza de nomes, estatisticas por status e download de relatorio
- Novos testes `tests/testthat/test-utils-taxadb.R` cobrindo normalizacao, cascata e merge de resultados
- ADR-024 registrando deduplicacao e cascata de provedores na validacao taxonomica

### Alterado
- `DESCRIPTION` inclui `taxadb` em `Imports`
- `docs/architecture.md` e `docs/skill.md` atualizados para `filter_name()` e provedores suportados
- Tabela de validacao com classes visuais por status e localizacao completa do DataTable

### Corrigido
- Cascade taxonomica agora alinha colunas antes do `rbind`, evitando erro quando resultados variam entre provedores

---

## [0.1.2] - 2026-02-15

### Adicionado
- Nova camada utilitaria `R/utils_preview.R` com funcoes puras para preparar preview e calcular prontidao (`prepare_preview_data`, `compute_preview_readiness`)
- Painel de prontidao na aba Preview com 4 metricas (registros, coordenadas, data, IDs unicos) e checklist visual de campos obrigatorios
- Novas chaves i18n da Preview para painel, progresso de export e linguagem completa do DataTable (empty/zero/paginacao)
- Novos testes `tests/testthat/test-utils-preview.R` e `tests/testthat/test-mod-preview-server.R` cobrindo logica pura e contrato do modulo

### Alterado
- `mod_preview` refatorado para usar funcoes puras de preview, `downloadButton` dinamico via `renderUI` e `withProgress` no export
- Empty state da Preview evoluido para card visual com icone/titulo/mensagem
- DataTable da Preview aprimorado com truncamento de celulas longas + tooltip, `autoWidth = FALSE` e destaque para colunas 100% vazias no dataset completo
- Politica de `occurrenceID` no painel: IDs unicos considerado OK quando ausente/vazio por fallback de geracao automatica no export
- CSS dedicado da Preview adicionado em `inst/app/www/custom.css` (painel/chips/empty state/colunas vazias/tooltip/responsivo)
- Pipeline de mapeamento separado em dois canais: `processed_data` (completo) e `preview_data` (leve sobre `head(raw_data, 100)`), com wiring no `app_server` para usar preview leve na tabela e dados completos no download/validacoes

### Corrigido
- Fragilidade do label de download na Preview (remocao de `uiOutput` aninhado dentro de `downloadButton`)
- Teste preexistente de `basisOfRecord` em `tests/testthat/test-utils-dwc.R` ajustado para comparacao robusta a acentuacao
- Recalculo pesado no fluxo de Preview: tabela deixou de depender do dataset completo mapeado e passou a usar canal leve dedicado, mantendo processamento completo apenas em acoes explicitas (download/validacao)
- Aba Preview simplificada no runtime (titulo, subtitulo, botao de download, tabela), sem execucao de painel de prontidao durante navegacao

---

## [0.1.1] - 2026-02-14

### Alterado
#### Onda 3 - performance de datas
- `parse_dates_to_iso()` refatorada para parsing vetorizado por formato com mascaras estritas
- Regra `DD/MM/YY` com cutoff dinamico por ano atual (`YY <= ano atual (2 digitos) -> 20YY`, senao `19YY`)
- `fix_dates_to_iso()` passa a delegar parsing para `parse_dates_to_iso()` nas colunas `eventDate`, `dateIdentified` e `modified`

#### Onda 6 - expansao de cobertura de regressao em utils criticas
- Suites existentes (`utils_io`, `utils_dwc`, `utils_export`, `utils_i18n`) foram ampliadas em vez de recriadas
- Cobertura agora inclui cenarios diretos para leitura/delimitador/encoding, validacao de coordenadas e occurrenceID, normalizacao de licencas, limpeza de coordenadas, geracao/preservacao de occurrenceID e fallbacks de i18n
- Sem mudanca de assinatura publica nas funcoes testadas

#### Onda 4 - modularizacao de mod_mapping
- `processed_data` do `mod_mapping` foi centralizado na funcao pura `build_processed_mapping_df()` em `R/utils_mapping.R`
- Helpers puros de estado/mapeamento foram extraidos para `R/utils_mapping.R` (`has_selected_value`, `sanitize_map_selection`, `default_meta`, `empty_map_values`, `empty_map_meta`, `build_manual_meta`)
- `mod_mapping_server()` manteve assinatura e retorno (`reactive(data.frame)`), preservando wiring reativo e comportamento de UI

#### Onda 5 - cache de artefatos DwC estaticos
- `load_dwc_terms_rds()` agora suporta `force = FALSE/TRUE` com cache em processo e invalidação explicita
- `load_dwc_synonyms_v1()` agora suporta `force = FALSE/TRUE` com cache em processo quando `path = NULL`
- Fallbacks legados `data/` removidos para `dwc_terms.rds` e `dwc_synonyms_v1.rds`; carga padronizada em `inst/extdata`
- Helpers internos de estado/reset de cache adicionados para isolamento de testes (`*_cache_state()`, `reset_*_cache()`)

#### basisOfRecord Mapping Assistant (V1 completa)
- Novo assistente dedicado no card `basisOfRecord` com modal de mapeamento por valor bruto da celula
- Vocabulario oficial com 8 termos GBIF/TDWG incorporado em `R/utils_dwc.R` com labels e descricoes PT/EN
- `basisOfRecord` agora usa coluna fonte unica e processamento final com um valor por linha (ou vazio), sem concatenacao
- Auto-sugestao por match exato case-insensitive para termos canonicos (ex: `humanobservation` -> `HumanObservation`)
- Modal com opcao `Nao mapear`, progresso `X/Y`, paginacao compacta e preview ao vivo de 5 linhas
- `build_processed_mapping_df()` estendido com `basis_of_record_map` para aplicar mapeamento row-wise antes do fluxo generico

### Corrigido
- Semantica de export preservada para invalidos nao vazios: valor bruto mantido em `fix_dates_to_iso()`
- `NA` e string vazia continuam resultando em `NA` nas colunas de data do export
- Warning de portabilidade por non-ASCII em `R/data_dictionary.R`, `R/mod_help.R` e `R/utils_i18n.R` eliminado via escapes Unicode (`\\uXXXX`) mantendo comportamento funcional
- Assistente de `basisOfRecord`: removido observer continuo dos selects da tabela (sincronizacao agora por snapshot em `Anterior/Proxima/Salvar`) para evitar cascata reativa
- Preview do assistente de `basisOfRecord` otimizado para mapear apenas 5 linhas exibidas e calcular nao-mapeados via lookup vetorizado
- Modal do assistente de `basisOfRecord` ajustado para manter footer visivel na viewport, com scroll interno no body e tabela interna mais compacta
- Modal do assistente de `basisOfRecord` harmonizado com a aba de mapeamento: superficie branca (`bg-card`), dropdowns com estilo dos campos de mapeamento, cabecalhos em azul solido e bordas da tabela no mesmo padrao dos campos de mapeamento
- Paginacao do assistente de `basisOfRecord` simplificada: contador textual `Pagina X de Y` removido entre os botoes `Anterior` e `Proxima`
- Tabelas do assistente de `basisOfRecord` (mapeamento e preview) ajustadas com fundo branco nas celulas, cabechalhos azuis consistentes e `scrollbar-gutter` estavel para evitar sobreposicao da barra de rolagem
- Dropdowns da tabela do assistente de `basisOfRecord` migrados para `selectize = FALSE` para reduzir custo de inicializacao no modal
- Tabela do assistente de `basisOfRecord`: header sticky reforcado com isolamento de camada/pintura para impedir que valores rolem por tras do cabecalho
- Funcoes `normalize_basis_of_record_key`, `sanitize_basis_of_record_term` e `sanitize_basis_of_record_map` vetorizadas (`normalize_basis_of_record_keys`, `sanitize_basis_of_record_terms`) para eliminar `vapply`/`for` element-wise em 96k+ linhas; call sites atualizados em `extract_basis_of_record_unique_entries`, `map_basis_of_record_values`, `get_effective_basis_of_record_map` e preview do assistente

### Adicionado
- Novos testes de regressao: `tests/testthat/test-utils-io.R` e `tests/testthat/test-utils-export.R`
- Script de benchmark 100k: `tests/bench/benchmark_dates_onda3.R`
- Relatorio comparativo da Onda 3: `docs/archive/benchmark_onda3_2026-02-14.md`
- Novos testes de regressao da Onda 4 em `tests/testthat/test-utils-mapping.R` e `tests/testthat/test-mod-mapping-server.R`
- Nova suite `tests/testthat/test-utils-dwc.R` cobrindo cache/invalidacao/consistencia de `dwc_terms`
- Novos cenarios de cache de sinonimos em `tests/testthat/test-utils-mapping.R`
- Novos cenarios de Onda 6 em `tests/testthat/test-utils-io.R`, `tests/testthat/test-utils-dwc.R`, `tests/testthat/test-utils-export.R` e `tests/testthat/test-utils-i18n.R`

---

## [0.1.0] - 2026-02-13

### Adicionado
- **Auto-mapping Rostrum (beta)**: Motor proprietario de mapeamento automatico com scoring por nome + conteudo
- **Badges de confianca**: Indicadores visuais (`AUTO`, `SUGERIDO`, `MANUAL`, `EDITADO`) nos campos mapeados
- **Synonyms table**: Suporte a sinonimos via `dwc_synonyms_v1.rds` para matching fuzzy
- **Loading bloqueante**: Modal com progresso, frases rotativas e icones contextuais durante auto-map
- **Toggle Rostrum**: Switch `bslib::input_switch` para ativar/desativar motor V1
- **Abreviacao de licencas**: CC URLs -> labels curtas (`CC0`, `CC-BY`, `CC-BY-NC`) no preview e export
- **Testes automatizados**: `test-utils-mapping.R` (58 testes) e `test-mod-mapping-server.R` (16 testes)

### Corrigido
#### Onda 2 - i18n consistente
- `app_server` usa `tr("nav_validate", lang_r())` e a tab inicial usa `tr("nav_home", lang_r())`
- `mod_validate_names` e `mod_validate_coords` removem condicionais `if (lang == "pt")` para warnings/sucesso
- `mod_wiki` com placeholder, filtro de classe e headers da tabela traduzidos via `tr()`
- `mod_preview` com textos do DataTable (`search`, `lengthMenu`, `info`) externalizados no dicionario
- `mod_mapping` com placeholders e labels de categorias/idioma ligados ao dicionario
- Novo teste `tests/testthat/test-utils-i18n.R` validando chaves e resolucao PT/EN da Onda 2

#### Ajustes complementares da release
- Badges sumindo apos desmarcar/remarcar categorias (leitura isolada -> reativa)
- `scientificName` aceitava multiplas colunas (agora selecao unica)
- `NA` literal no CSV exportado -> celulas vazias com `readr::write_csv(na = "")`
- Filtro de categorias: selecao vazia mostrava todos os cards (agora mostra nenhum)
- Categoria fantasma `Organism` removida do filtro

#### Onda 1 - estabilidade de pacote/deploy
- `shiny::toJSON` -> `jsonlite::toJSON` (compatibilidade)
- Estabilidade de pacote/deploy: remocao de `source()` em `R/*.R`
- Test helper compativel com tarball de check (sem path local para `R/*.R`)
- `DESCRIPTION`: `jsonlite` adicionado em `Imports`
- `mod_preview`: `head(...)` substituido por `utils::head(...)`
- `utils_i18n::tr()`: resolucao de `i18n_dict` via ambiente/namespace sem `source()`

---

## [0.0.5] - 2026-02-12

### Adicionado
- **Campos especiais no mapeamento**: `datasetName` (dropdown + texto), `modified` (checkbox + calendario), `license` (checkboxes CC), `language` (checkboxes `pt`/`en`/`es`)
- **Concatenacao DwC padronizada**: `;` como separador de entrada, ` | ` como saida
- **Parser de eventDate**: 4 colunas -> `YYYY-MM/YYYY-MM` com fallback para valor bruto
- **Indicador visual de mapeamento**: Borda verde em cards mapeados, sem barra laranja
- Funcoes puras: `normalize_semicolon_tokens`, `collapse_mapped_values`, `build_eventdate_interval`, `detect_eventdate_roles`, `parse_month_to_number`
- Funcoes de derivacao: `extract_scientific_name_components`, `fill_missing_character_values`, `replace_na_with_blank`

### Corrigido
- Cabecalhos de categoria invisiveis: variaveis CSS `--primary-dark`, `--text-muted`, `--border` nao definidas
- Category header redesenhado (gradiente azul escuro com alto contraste)
- Bug de re-render resetando selecoes em campos customizados (fix com `isolate(input$...)`)
- Selecao unica forcada para `license` e `language` via observeEvent server-side

---

## [0.0.4] - 2026-02-09

### Alterado
- Escala tipografica final: `--text-xs: 0.75rem` ate `--text-2xl: 1.75rem`
- Navbar title maior que card headers (`--text-2xl` vs `--text-lg`)
- Card header padding aumentado
- DwC fields em layout horizontal (flex) em vez de grid 4 colunas
- Campos DwC obrigatorios com boxes compactos e padding adequado

### Corrigido
- Encoding corrompido em `data_dictionary.R` (caracteres acentuados restaurados)

---

## [0.0.3] - 2026-02-09

### Adicionado
- Dashboard de Qualidade de Dados apos upload (colunas vazias, tipos detectados)
- Notificacao de sucesso em verde (`#2d6a4f`)
- Alertas e notificacoes em negrito

### Alterado
- Nav "Upload" -> "Inicio" com icone `fa-home`
- Font base aumentada para `1rem`
- Stats boxes em largura completa (`flex: 1 1 0`)
- Input group de upload com botao/campo conectados (sem gap)

### Removido
- Rodape com logos de financiamento (Observatorio, Zhouse, Humanize)

---

## [0.0.2] - 2026-02-08

### Adicionado
- Logo hexagonal no navbar (72px)
- FontAwesome 6.5.1 CDN (classic solid)
- Layout de duas colunas na home: Dados (5) + Bem-vindo (7)
- Workflow visual com 4 passos (Upload -> Mapeamento -> Validacao -> Exportar)
- Privacy alert: "Todos os dados processados localmente"
- 50+ strings i18n no `data_dictionary.R`
- ~200 linhas de CSS para novos componentes

### Corrigido
- Botao de upload: texto ilegivel (amarelo sobre amarelo) -> cores explicitas com `!important`
- Cards de estatisticas compactados -> padding restaurado
- Limite de upload: 500 MB (antes sem limite definido)
- Botao de upload: icon-only (40x40px) com height sincronizada

---

## [0.0.1] - 2026-02-08

### Corrigido
- `DESCRIPTION`: linhas vazias entre secoes removidas
- `DESCRIPTION`: dependencia `here` adicionada ao Imports
- `app_ui.R`: `nav_spacer()` -> `bslib::nav_spacer()` (namespace)
- `utils_dwc.R`: contagem de vetores incompativel (`rep("Taxon", 15)` -> `14`)
