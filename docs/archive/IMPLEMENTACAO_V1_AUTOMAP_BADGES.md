# Implementacao V1 - Auto-Map + Badges (Backend Primeiro)

Data: 2026-02-12  
Projeto: Saira  
Escopo: V1 sem inferencia automatica de datas/horarios (exceto match exato)

## 1. Objetivo da versao

Esta versao implementa o motor V1 de auto-mapeamento com badges de confianca, preservando a estabilidade da aba de mapeamento.

Estrategia adotada:

- Backend primeiro
- Toggle visivel para todos os usuarios
- Toggle desligado por padrao
- Com toggle desligado: comportamento legado + sem badges

## 2. Mudancas principais por arquivo

### 2.1 `R/utils_mapping.R`

Adicao do motor V1 completo:

- `sanitize_synonyms_table()`
- `load_dwc_synonyms_v1(path = NULL)`
- `tokenize_for_matching()`
- `score_token_overlap()`
- `score_text_similarity()`
- `compute_name_score(col_name, term, synonyms_tbl)`
- `sample_values_for_scoring(values, name_score)`
- `validate_numeric_range()`
- `validate_scientific_name_pattern()`
- `validate_individual_count()`
- `compute_value_score(values, term, name_score)`
- `classify_automap_status(final_score, compatible_type = TRUE)`
- `resolve_reason_code(...)`
- `run_automap_v1(df, dwc_terms_df, synonyms_tbl)`

Regras implementadas:

- Score final: `0.5 * name_score + 0.5 * value_score`
- Thresholds:
  - `AUTO >= 0.90`
  - `SUGERIDO 0.75 - 0.89`
  - `MANUAL < 0.75`
- Termos temporais sem inferencia automatica:
  - `eventDate`, `year`, `month`, `day`, `modified`, `dateIdentified`
  - Excecao: match exato normalizado
- Guardrails:
  - Coluna 100% vazia => score 0
  - Incompatibilidade de tipo bloqueia AUTO
- Valor neutro sem validador especifico: `value_score = 0.80`
- Resolucao de conflitos:
  - maior `final_score`
  - empate: maior `value_score`
  - persistindo: coluna mais especifica (mais tokens)

Observacao importante:

- Foi ajustado `run_automap_v1()` para manter schema consistente em todas as linhas, evitando erro de `rbind` por numero de colunas diferente.

### 2.2 `R/mod_mapping.R`

Refatoracao anti-regressao na aba Mapping:

- Nova fonte unica de estado:
  - `rv$map_values` (selecao por termo)
  - `rv$map_meta` (status badge, score, motivo, origem)
- Controle de atualizacao programatica:
  - `rv$is_programmatic_update`
  - `rv$programmatic_terms`
- IDs de inputs `map_<term>` preservados
- `processed_data` agora consome estado em `rv$map_values`
- `occurrenceID` estabilizado com `rv$occurrence_ids` por lote

Novo comportamento do botao `Auto-mapear`:

- Toggle OFF (`enable_automap_v1 = FALSE`):
  - executa motor legado (match exato)
  - limpa metadados de badge
  - sem badges na UI
- Toggle ON (`enable_automap_v1 = TRUE`):
  - executa `run_automap_v1(...)`
  - aplica `AUTO` e `SUGERIDO`
  - `MANUAL` permanece sem selecao
  - armazena metadados para badges/tooltips

Override manual:

- Quando V1 esta ligado e o usuario altera selecao:
  - status vira `EDITADO` (ou `MANUAL` quando limpar)
  - motivo `manual_adjust` (ou `manual_cleared`)

Reset:

- Limpa `rv$map_values` e `rv$map_meta`
- Mantem fluxo dos campos customizados conforme comportamento existente
- Nao quebra select inputs

### 2.3 `R/data_dictionary.R`

Novas chaves i18n (PT/EN):

- Toggle V1:
  - `toggle_automap_v1_label`
  - `toggle_automap_v1_help`
- Notificacoes:
  - `notif_auto_mapping_v1`
  - `notif_auto_mapping_v1_error`
- Badges:
  - `badge_auto`
  - `badge_suggested`
  - `badge_edited`
  - `badge_manual`
- Motivos de badge:
  - `badge_reason_exact_match`
  - `badge_reason_known_synonym`
  - `badge_reason_content_validated`
  - `badge_reason_manual_adjust`
  - `badge_reason_manual_cleared`
  - `badge_reason_type_incompatible`
  - `badge_reason_temporal_manual_only`
  - `badge_reason_conflict_lost`
  - `badge_reason_empty_column`
  - `badge_reason_low_name_confidence`
  - `badge_reason_no_confident_match`
  - `badge_reason_low_confidence`

### 2.4 `inst/app/www/custom.css`

Novos estilos para suporte visual:

- `.mapping-beta-help` (texto auxiliar do toggle)
- `.field-header-row` (layout titulo + badge)
- `.field-status-badge` (badge com tooltip)

### 2.5 `R/utils_dwc.R`

Hardening de carga de termos DwC:

- `load_dwc_terms_rds()` agora busca em multiplos caminhos fallback:
  - `system.file(...)`
  - `here::here(...)`
  - caminho relativo local
- Objetivo: robustez em app/testes locais

### 2.6 Novo dado: `data/dwc_synonyms_v1.rds`

Criado artefato RDS com schema:

- `term` (chr)
- `synonym` (chr)
- `name_score` (dbl 0.90 - 0.98)
- `lang` (pt|en|any)
- `active` (lgl)

Contem sinonimos iniciais para termos-chave (ex.: `scientificName`, coordenadas, `individualCount`, etc.).

## 3. Mudancas na UI de Mapping

Adicoes:

- Toggle no sidebar: `enable_automap_v1` (default `FALSE`)
- Ajuda curta do toggle via i18n
- Badge por card quando V1 ligado:
  - `AUTO` (success)
  - `SUGERIDO` (warning)
  - `EDITADO` (info)
  - `MANUAL` (light/muted)
- Tooltip com:
  - motivo principal
  - score final quando disponivel

Compatibilidade preservada:

- IDs dos selects `map_<term>` nao foram alterados
- Contrato de retorno do modulo mantido:
  - `mod_mapping_server(...)` retorna `reactive(data.frame)`

## 4. Testes implementados

### 4.1 Infra de teste

Novo arquivo:

- `tests/testthat/helper-source-utils.R`

Funcao:

- Carrega fontes locais (`utils`, `i18n`, `mod_mapping`) para testes de funcoes nao exportadas.

### 4.2 Unitarios do motor

Arquivo atualizado:

- `tests/testthat/test-utils-mapping.R`

Cobre:

- match exato normalizado
- match por sinonimo
- score de coordenadas validas/invalidas
- score de `scientificName` valido/ruido
- score de `individualCount`
- exclusao temporal (exceto match exato)
- resolucao de conflitos
- thresholds de classificacao
- schema de retorno do `run_automap_v1`

### 4.3 Testes de modulo (server)

Novo arquivo:

- `tests/testthat/test-mod-mapping-server.R`

Cobre:

- toggle OFF: legado + sem badge metadata
- toggle ON: aplica V1 + metadados
- override manual vira `EDITADO`
- reset limpa estado sem quebrar
- estado persiste com alteracao de filtros
- contrato de `processed_data` preservado

## 5. Validacao executada

Validacao de sintaxe (parse) executada com sucesso para:

- `R/utils_mapping.R`
- `R/mod_mapping.R`
- `R/data_dictionary.R`
- `R/utils_dwc.R`
- `tests/testthat/test-utils-mapping.R`
- `tests/testthat/test-mod-mapping-server.R`

Suite de testes executada:

- `Rscript -e "testthat::test_dir('tests/testthat', reporter='summary')"`
- Resultado final: `DONE` (sem falhas)

## 6. Garantias de compatibilidade

Preservado nesta versao:

- fluxo Upload -> Mapping -> Preview -> Validate -> Export
- regras especiais existentes (`eventDate` manual/parsing atual, `scientificName` selecao unica, campos customizados)
- sem inferencia automatica temporal no V1 (exceto match exato)
- sem alteracao de contrato publico do modulo de mapeamento

## 7. Limitacoes intencionais (fora de escopo V1)

- Sem inferencia avancada de datas/horarios
- Sem composicao Stage 2
- Sem aprendizado local de aliases por usuario
- Sem governanca multiusuario

## 8. Resumo executivo

Esta entrega implementa o V1 de auto-map com seguranca operacional:

- novo motor pronto e funcional
- acionamento controlado por toggle (default OFF)
- badges e explicabilidade quando V1 ON
- estado reativo endurecido para evitar regressao de botao/select
- cobertura de testes ampliada (unit + server)
- validacao automatizada concluida sem falhas
