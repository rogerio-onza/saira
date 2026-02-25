# PLANO_IMPLEMENTACAO_ONDAS_FINCH.md

## 1. Resumo Executivo
Este plano organiza a refatoracao em ondas independentes para voce executar em chats separados, com criterios de aceite claros e baixo risco de regressao.
A ordem e obrigatoria para evitar quebrar app/deploy no meio.

Data-base do diagnostico: 2026-02-13.

## 2. Objetivo Final
1. Eliminar riscos reais de quebra em ambiente de pacote/deploy.
2. Melhorar i18n e consistencia de UI.
3. Ganhar performance no processamento de datas em datasets grandes.
4. Aumentar modularidade do `mod_mapping`.
5. Aumentar cobertura de testes nas `utils_*` criticas.

## 3. Estado Atual Confirmado
1. `devtools::test()` passa com 98 testes.
2. `devtools::check(document = FALSE, manual = FALSE)` falha com 1 ERROR.
3. Problemas de pacote/deploy hoje:
- Dependencia nao declarada: `jsonlite` usada em `R/mod_mapping.R`.
- Test helper quebrando no tarball: `tests/testthat/helper-source-utils.R` busca `R/*.R` via caminho local.
- Uso massivo de `source()` em `R/*.R` (26 ocorrencias).
4. Benchmark de datas (micro-benchmark 100k):
- `fix_dates_to_iso()` atual: ~8.8s.
- `parse_dates_to_iso()` atual: ~12.3s.
- Prototipo vetorizado: ~0.82s.
5. Interpretacao do benchmark:
- Isso mede funcao isolada, nao o app inteiro.
- O ganho esperado e principalmente no passo de normalizacao de datas do fluxo de export/processamento.

## 4. Regras de Execucao por Onda
1. Nao iniciar onda seguinte sem fechar os gates da onda atual.
2. Toda onda deve terminar com:
- `devtools::test()`.
- Testes especificos da onda.
3. Ondas com risco estrutural devem rodar tambem:
- `devtools::check(document = FALSE, manual = FALSE)`.
4. Sem mudanca de comportamento funcional sem teste explicito cobrindo a mudanca.
5. Preserve assinatura publica quando possivel.
6. Em caso de duvida, prefira compatibilidade retroativa.

## 5. Mudancas Publicas/Interfaces (Planejadas)
1. `load_dwc_terms_rds(force = FALSE)` em `R/utils_dwc.R`.
- Compativel com chamadas atuais sem parametro.
2. `parse_dates_to_iso(...)` mantem assinatura atual.
- Sem mudanca de contrato de retorno.
3. `mod_mapping_server(...)` mantem assinatura e retorno.
- Refactor so interno (onda 4).

## 6. Onda 0 (Preparacao e Baseline)
Objetivo: congelar baseline e criar referencia para regresses.

Escopo:
- Nenhuma mudanca funcional.
- So coleta de baseline tecnico.

Passos:
1. Rodar `devtools::test()`.
2. Rodar `devtools::check(document = FALSE, manual = FALSE)`.
3. Rodar benchmark local de datas com 100k linhas para registrar tempo inicial.
4. Registrar saida em um arquivo de log de engenharia.

Gates:
1. Baseline coletado e salvo.
2. Lista de falhas atual confirmada.

Prompt de chat recomendado:
`Executar Onda 0 do plano: coletar baseline (test, check, benchmark datas 100k) e me devolver relatorio objetivo.`

---

## 7. Onda 1 (Estabilidade de Pacote/Deploy) - PRIORIDADE 1
Objetivo: remover causas reais de quebra em check/deploy.

Arquivos-alvo:
- `R/app_ui.R`
- `R/app_server.R`
- `R/mod_upload.R`
- `R/mod_mapping.R`
- `R/mod_preview.R`
- `R/mod_validate_names.R`
- `R/mod_validate_coords.R`
- `R/mod_wiki.R`
- `R/mod_help.R`
- `R/utils_i18n.R`
- `DESCRIPTION`
- `tests/testthat/helper-source-utils.R`
- `tests/testthat/test-utils-mapping.R`

Passos:
1. Remover `source(here::here(...))` de todos os arquivos em `R/`.
2. Ajustar `tr()` em `R/utils_i18n.R` para nao usar `source()`.
3. Garantir que `tr()` resolva `i18n_dict` via namespace de pacote de forma estavel.
4. Adicionar `jsonlite` no `Imports` do `DESCRIPTION`.
5. Trocar `head(...)` por `utils::head(...)` em `R/mod_preview.R`.
6. Corrigir `tests/testthat/helper-source-utils.R`.
7. Substituir carga por path absoluto de `R/*.R` por estrategia compativel com check/tarball.
8. Ajustar `tests/testthat/test-utils-mapping.R` para carregar `dwc_synonyms_v1.rds` por `system.file(...)` com fallback de dev.
9. Reexecutar testes e check.

Riscos conhecidos:
1. Quebra de testes que dependem de objetos antes injetados por `source()`.
2. Ordem de carga de funcoes no ambiente de teste.
3. Uso de dicionario i18n em contexto nao interativo.

Mitigacoes:
1. Refatorar helper de teste primeiro.
2. Rodar `devtools::test()` apos cada bloco de ajuste.
3. So seguir para check completo quando testes unitarios estabilizarem.

Gates:
1. `devtools::test()` verde.
2. `devtools::check(document = FALSE, manual = FALSE)` sem ERROR de testes/dependencias.
3. Warning de `jsonlite` ausente eliminado.

Prompt de chat recomendado:
`Implementar Onda 1 do plano: estabilidade de pacote/deploy, remover source() em R/, corrigir helper de testes e DESCRIPTION (jsonlite), rodar test+check e reportar diffs e riscos.`

---

## 8. Onda 2 (I18n Consistente)
Objetivo: remover hardcodes criticos e padronizar strings com `tr()`.

Arquivos-alvo:
- `R/app_server.R`
- `R/app_ui.R`
- `R/mod_validate_names.R`
- `R/mod_validate_coords.R`
- `R/mod_wiki.R`
- `R/mod_mapping.R`
- `R/mod_preview.R`
- `R/data_dictionary.R`

Passos:
1. Criar chaves faltantes no dicionario para:
- Titulo do menu de validacao.
- Titulo do upload/home.
- Mensagens de warnings de validacao.
- Mensagens de "todos validos".
- Placeholders e labels do wiki.
- Textos de `lengthMenu` e `info` no preview.
2. Em `R/app_server.R`, substituir `"Validacao"` por `tr("nav_validate", lang_r())`.
3. Em `R/app_ui.R`, substituir `" Inicio"` por output i18n equivalente.
4. Em modulos de validacao, substituir `if (lang_r() == "pt") ... else ...` por `tr()`.
5. Em `R/mod_wiki.R`, tornar placeholder e choices sensiveis a idioma.
6. Em `R/mod_preview.R`, externalizar language strings para dicionario.

Riscos conhecidos:
1. Chave faltante no dicionario gerar placeholder `[key]`.
2. Regressao visual por mudanca de `uiOutput` em navegacao.

Mitigacoes:
1. Teste de sanidade de chaves PT/EN no final da onda.
2. Teste manual de alternancia de idioma em todas as abas.

Gates:
1. Zero hardcodes remanescentes nos pontos auditados.
2. Alternancia PT/EN refletindo strings corretamente.
3. Testes automatizados verdes.

Prompt de chat recomendado:
`Implementar Onda 2 do plano: normalizar i18n nos pontos auditados (app_server/app_ui/validate/wiki/preview/mapping), atualizar data_dictionary e validar alternancia PT-EN.`

---

## 9. Onda 3 (Performance de Datas)
Objetivo: reduzir custo de normalizacao de datas sem mudar semantica funcional.

Arquivos-alvo:
- `R/utils_io.R`
- `R/utils_export.R`
- `tests/testthat/test-utils-io.R` (novo)
- `tests/testthat/test-utils-export.R` (novo)

Passos:
1. Refatorar `parse_dates_to_iso()` para processamento vetorizado por formato.
2. Manter regras atuais de formatos aceitos.
3. Preservar retorno esperado para casos invalidos/vazios.
4. Em `fix_dates_to_iso()`, delegar parsing para `parse_dates_to_iso()`.
5. Garantir compatibilidade de comportamento com fluxo de `process_for_export()`.
6. Criar testes cobrindo:
- ISO ja valido.
- DD/MM/YYYY.
- DD-MM-YYYY.
- DD/MM/YY.
- DD.MM.YYYY.
- valores invalidos.
- `NA` e string vazia.
7. Reexecutar benchmark 100k e comparar com baseline.

Riscos conhecidos:
1. Mudanca semantica sutil em valor invalido (preservar original vs `NA`).
2. Diferenca entre parsing por coluna e parsing por vetor.

Mitigacoes:
1. Testes de regressao com snapshots de entrada/saida.
2. Criterio explicito para cada classe de entrada.

Gates:
1. Testes de datas verdes.
2. Ganho de performance mensuravel no benchmark 100k.
3. Sem regressao no `process_for_export()`.

Prompt de chat recomendado:
`Implementar Onda 3 do plano: vetorizar parsing de datas (utils_io/utils_export), manter semantica atual, criar testes de regressao e benchmark comparativo.`

---

## 10. Onda 4 (Modularizacao de mod_mapping)
Objetivo: reduzir acoplamento e mover logica pura para `utils_mapping.R`.

Arquivos-alvo:
- `R/mod_mapping.R`
- `R/utils_mapping.R`
- `tests/testthat/test-mod-mapping-server.R`
- `tests/testthat/test-utils-mapping.R`

Passos:
1. Identificar funcoes puras dentro de `mod_mapping_server`.
2. Extrair funcoes de transformacao para `R/utils_mapping.R`.
3. Criar funcao pura central para montagem de `df_final` (hoje dentro de `processed_data`).
4. Manter no modulo:
- wiring reativo.
- atualizacao de inputs.
- renderizacao.
5. Preservar contratos:
- `mod_mapping_server()` retorna `reactive(data.frame)`.
- badges e metadados continuam com mesmo comportamento.
6. Ampliar testes unitarios para logica extraida.
7. Rodar teste de modulo com `shiny::testServer`.

Riscos conhecidos:
1. Regressao de estado reativo (`rv$map_values`, `rv$map_meta`).
2. Mudanca de ordem/selecao de colunas no output final.
3. Regressao no `eventDate` composto.

Mitigacoes:
1. Extrair por blocos pequenos, com commit/test por bloco.
2. Cobrir casos criticos ja existentes nos testes de mapping.
3. Adicionar testes novos para contrato de `processed_data`.

Gates:
1. Testes de mapping verdes.
2. Saida de `processed_data` compativel com baseline funcional.
3. Sem regresses de badges/auto-map/reset.

Prompt de chat recomendado:
`Implementar Onda 4 do plano: extrair logica pura de mod_mapping para utils_mapping mantendo contrato de saida e estado reativo, com testes de regressao.`

---

## 11. Onda 5 (Cache de DwC Terms)
Objetivo: eliminar I/O repetido e deixar caminho pronto para escala.

Arquivos-alvo:
- `R/utils_dwc.R`
- `tests/testthat/test-utils-dwc.R` (novo)

Passos:
1. Implementar cache interno em `load_dwc_terms_rds(force = FALSE)`.
2. Garantir que `get_dwc_terms()`, `get_required_dwc_terms()` e `get_dwc_terms_list()` reutilizem cache.
3. Incluir invalidacao por `force = TRUE`.
4. Criar testes:
- primeira chamada carrega.
- segunda chamada reutiliza.
- `force = TRUE` recarrega.
- conteudo permanece consistente.

Riscos conhecidos:
1. Cache sujo em sessao de teste.
2. Acoplamento com ordem de execucao de testes.

Mitigacoes:
1. Funcao de reset de cache para ambiente de teste.
2. `teardown` limpando estado global de cache.

Gates:
1. Testes de utils_dwc verdes.
2. Comportamento funcional inalterado para consumidores.

Prompt de chat recomendado:
`Implementar Onda 5 do plano: adicionar cache de dwc_terms com invalidacao explicita, incluindo testes de estado e consistencia.`

---

## 12. Onda 6 (Cobertura de Testes Faltante)
Objetivo: reduzir risco de regressao fora do modulo de mapping.

Arquivos-alvo (novos):
- `tests/testthat/test-utils-io.R`
- `tests/testthat/test-utils-dwc.R`
- `tests/testthat/test-utils-export.R`
- `tests/testthat/test-utils-i18n.R`

Escopo de cobertura minimo:
1. `utils_io.R`:
- encoding.
- delimiter.
- parse de datas.
2. `utils_dwc.R`:
- `validate_coords`.
- `validate_occurrence_id`.
- loaders de termos.
3. `utils_export.R`:
- pipeline `process_for_export`.
- datas.
- coordenadas.
- occurrenceID.
- license.
4. `utils_i18n.R`:
- `tr()` para chaves validas.
- fallback de lingua.
- comportamento para chave inexistente.
- integridade PT/EN das chaves principais.

Gates:
1. Novos testes estaveis.
2. Regresses detectaveis em areas hoje sem cobertura.
3. `devtools::test()` verde ao final.

Prompt de chat recomendado:
`Implementar Onda 6 do plano: criar suite de testes faltante para utils_io/utils_dwc/utils_export/utils_i18n com foco em regressao funcional.`

---

## 13. Onda 7 (Opcional) - Conteudo de Help fora de codigo
Objetivo: reduzir hardcode volumoso HTML no `mod_help`.

Arquivos-alvo:
- `R/mod_help.R`
- `inst/app/...` (conteudo por idioma)

Passos:
1. Mover conteudo PT/EN para arquivos externos.
2. Carregar conteudo por idioma no modulo.
3. Manter render identico ao atual.

Gates:
1. Conteudo visual preservado.
2. Troca de idioma funcional.

Prompt de chat recomendado:
`Implementar Onda 7 opcional do plano: externalizar conteudo do mod_help por idioma preservando renderizacao atual.`

---

## 14. Checklist de Aceite Final do Projeto
1. `devtools::test()` verde.
2. `devtools::check(document = FALSE, manual = FALSE)` sem ERROR.
3. Dependencias em `DESCRIPTION` alinhadas com uso real.
4. Sem `source()` em `R/*.R`.
5. i18n consistente nos pontos auditados.
6. Melhoria de performance de datas demonstrada por benchmark.
7. `mod_mapping` mais modular sem mudanca de contrato publico.

## 15. Assuncoes e Defaults
1. Ordem das ondas e mandatoria.
2. Compatibilidade funcional e prioridade sobre refactor "bonito".
3. O benchmark de datas e indicador de componente, nao SLA do app completo.
4. Onda 7 e opcional por custo alto e baixo risco de quebra.
5. Cada onda deve ser executada em chat separado com prompt dedicado (modelos acima).
