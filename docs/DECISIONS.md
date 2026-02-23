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

---

## ADR-014: Cache em processo para `dwc_terms` e `dwc_synonyms_v1` com invalidação explicita

- **Data**: 2026-02-14
- **Contexto**: Os loaders de arquivos estaticos (`dwc_terms.rds` e `dwc_synonyms_v1.rds`) eram executados repetidamente no fluxo reativo, causando I/O e sanitizacao redundantes.
- **Decisao**:
  - Implementar cache por processo para `load_dwc_terms_rds(force = FALSE)` e `load_dwc_synonyms_v1(path = NULL, force = FALSE)`.
  - Em `force = TRUE`, invalidar e recarregar explicitamente do disco.
  - Quando `load_dwc_synonyms_v1(path = ...)` recebe caminho explicito, carregar/sanitizar diretamente sem depender do cache global.
  - Remover fallbacks legados de `data/` e manter apenas caminhos de `inst/extdata`.
  - Adicionar hooks internos de teste para reset e introspeccao de estado (`reset_*_cache()`, `*_cache_state()`), sem ampliar API publica.
- **Alternativas**:
  - Manter carga sempre on-demand sem cache - rejeitado por I/O repetido desnecessario.
  - Expor reset de cache como API publica - rejeitado para evitar surface area publica sem necessidade de usuario final.
  - Cache apenas para `dwc_terms` - rejeitado por inconsistência arquitetural com o objetivo da onda.
- **Consequencias**:
  - Menor custo de I/O em ciclos reativos e auto-map.
  - Comportamento de cache observavel e testavel sem acoplamento por ordem de execucao.
  - Estrutura de dados estaticos alinhada ao padrao `inst/extdata`.

---

## ADR-015: Onda 6 executada como expansao de suites existentes de utils

- **Data**: 2026-02-14
- **Contexto**: O plano original da Onda 6 previa "criar suite de testes faltante" para `utils_io`, `utils_dwc`, `utils_export` e `utils_i18n`, mas as quatro suites ja existiam no repositorio e o baseline estava verde.
- **Decisao**:
  - Tratar Onda 6 como expansao de cobertura de regressao, nao como recriacao de suites.
  - Priorizar lacunas funcionais objetivas: I/O (encoding/delimiter/read), validacao DwC (coords/occurrenceID), helpers de export (license/coords/ids) e fallback de i18n.
  - Preservar assinaturas publicas e restringir mudancas a testes + documentacao de engenharia.
- **Alternativas**:
  - Reescrever suites do zero - rejeitado por apagar historico util e aumentar risco sem ganho tecnico.
  - Encerrar sem novos testes - rejeitado por manter lacunas de regressao em funcoes publicas relevantes.
- **Consequencias**:
- Cobertura funcional mais ampla sem alterar comportamento de producao.
- Maior capacidade de detectar regressao pontual em utilitarios puros.
- Menor custo de manutencao por evoluir suites ja estabilizadas.

---

## ADR-016: `basisOfRecord` com valor unico por linha via assistente dedicado

- **Data**: 2026-02-14
- **Contexto**: O mapeamento generico do Finch permite concatenacao de multiplos valores (` | `), mas `basisOfRecord` usa vocabulario controlado e deve refletir apenas uma categoria por registro.
- **Decisao**:
  - Tratar `basisOfRecord` como fluxo especial com coluna fonte unica no card de mapeamento.
  - Usar assistente modal para mapear cada valor bruto da celula inteira para um dos 8 termos oficiais GBIF/TDWG ou "Nao mapear".
  - Aplicar mapeamento row-wise em `build_processed_mapping_df(..., basis_of_record_map = NULL)` antes da logica generica de concatenacao.
  - Valores nao reconhecidos ficam vazios no output final.
- **Alternativas**:
  - Reusar mapeamento generico com split por `;` - rejeitado porque pode gerar mais de uma categoria por linha.
  - Forcar fallback automatico para `Occurrence` - rejeitado por risco de classificar incorretamente dados nao mapeados.
- **Consequencias**:
  - `basisOfRecord` passa a ter contrato explicito de valor unico por linha.
  - UX melhora com progresso, preview e auto-sugestao de termos canonicos.
  - Mantem compatibilidade com o restante do pipeline, sem alterar API publica exportada.

---

## ADR-017: Sincronizacao por snapshot no assistente de `basisOfRecord` para evitar cascata reativa

- **Data**: 2026-02-15
- **Contexto**: A implementacao inicial do assistente de `basisOfRecord` usava `observe` continuo lendo todos os `input$basis_of_record_target_*` renderizados na pagina atual. Em datasets grandes, isso aumentou latencia de interacao no modal e reatividade desnecessaria.
- **Decisao**:
  - Remover observer continuo de sincronizacao `input -> draft_map`.
  - Introduzir sincronizacao por snapshot da pagina atual apenas em eventos explicitos (`Anterior`, `Proxima`, `Salvar`).
  - Manter `processed_data` dependente apenas de `rv$basis_of_record_map` (estado confirmado no `Salvar`), preservando aplicacao row-wise do ADR-016 fora do ciclo de edicao do modal.
  - Reduzir custo de preview do assistente: mapear somente as 5 linhas exibidas e calcular contagem de nao-mapeados por lookup vetorizado.
  - Trocar selects da tabela do assistente para `selectize = FALSE` para reduzir custo de inicializacao de widget.
- **Alternativas**:
  - Manter observer continuo com `isolate` parcial - rejeitado por manter alto acoplamento reativo entre UI da tabela e estado draft.
  - Recalcular preview completo em todas as linhas a cada mudanca de select - rejeitado por custo O(n) desnecessario durante edicao interativa.
- **Consequencias**:
  - Menor latencia ao abrir modal e ao trocar valores nos dropdowns do assistente.
  - Footer do modal permanece acessivel com scroll interno dedicado.
  - Fluxo de mapeamento permanece aderente ao ADR-016: valor unico por linha aplicado no processamento final, sem concatenacao.

---

## ADR-018: Vetorizacao de helpers de `basisOfRecord` para datasets grandes

- **Data**: 2026-02-15
- **Contexto**: Apos aplicar snapshot sync (ADR-017) e demais correcoes de wiring reativo, o modal do assistente continuava lento ao abrir em datasets com 96k+ linhas. A causa residual era que `normalize_basis_of_record_key`, `sanitize_basis_of_record_term` e `sanitize_basis_of_record_map` operavam element-wise via `vapply`/`for`, gerando 96k+ chamadas R por invocacao.
- **Decisao**:
  - Criar versoes vetorizadas: `normalize_basis_of_record_keys()` (usa `trimws` + `tolower` nativos) e `sanitize_basis_of_record_terms()` (usa `%in%` vetorizado com `get_basis_of_record_terms()` chamado uma unica vez).
  - Reescrever `sanitize_basis_of_record_map()` para usar as versoes vetorizadas em vez de `for` loop.
  - Atualizar `extract_basis_of_record_unique_entries()` substituindo `vapply` + `match` por `!duplicated()` vetorizado.
  - Atualizar `map_basis_of_record_values()` para chamar versoes vetorizadas.
  - Atualizar call sites em `mod_mapping.R`: `get_effective_basis_of_record_map()` e preview de nao-mapeados.
  - Manter versoes escalares para contextos de 1 elemento (ex.: `sync_current_page_to_draft`).
- **Alternativas**:
  - Usar `Rcpp` para normalizar em C++ - rejeitado por complexidade desnecessaria; operacoes base R ja sao nativas C.
  - Cachear resultado de `extract_unique_entries` - rejeitado porque a vetorizacao torna a operacao suficientemente rapida sem estado extra.
- **Consequencias**:
  - Abertura do modal passa de segundos para centesimos de segundo em datasets de 96k+ linhas.
  - Testes existentes (812) passam sem alteracao, confirmando compatibilidade funcional.

---

## ADR-019: Preview orientado a prontidao de export com indicadores de qualidade

- **Data**: 2026-02-15
- **Status**: Parcialmente superado pelo ADR-021 no que tange prontidao em tempo de preview.
- **Contexto**: A aba Preview estava funcional, mas minimalista: sem painel de prontidao, sem feedback de progresso no download, sem indicadores visuais de qualidade por coluna e com cobertura de testes insuficiente para o modulo.
- **Decisao**:
  - Introduzir camada pura `utils_preview` para separar calculo de metricas/regras da renderizacao Shiny.
  - Adicionar painel de prontidao com metricas acionaveis (`Registros`, `% com coordenadas`, `% com data`, `IDs unicos`) e checklist de campos obrigatorios.
  - Tratar `IDs unicos` como OK quando `occurrenceID` estiver ausente/vazio, pois o pipeline de export gera UUID automaticamente.
  - Destacar no DataTable colunas 100% vazias considerando o dataset mapeado completo (nao apenas as 100 linhas do preview).
  - Melhorar legibilidade da tabela com truncamento de texto longo e tooltip com valor completo.
  - Substituir label fragil do download por `downloadButton` dinamico completo em `renderUI` e adicionar `withProgress` no export.
  - Melhorar empty state da Preview para card visual orientativo.
- **Alternativas**:
  - Manter calculos no modulo Shiny - rejeitado por acoplamento e menor testabilidade.
  - Calcular qualidade de colunas apenas nas 100 linhas - rejeitado por risco de falso diagnostico para export completo.
  - Tratar `occurrenceID` ausente como falha no painel - rejeitado por entrar em conflito com comportamento oficial do pipeline de export.
- **Consequencias**:
  - Preview passa a suportar decisao de "pronto para exportar" com sinais objetivos e bilinguismo completo.
  - Logica de preview fica testavel fora de Shiny com cobertura de regressao dedicada.
  - UX de download e empty state fica consistente com o restante da aplicacao.

---

## ADR-020: Desacoplar DataTable de readiness para preservar preview rapido

- **Data**: 2026-02-15
- **Status**: Parcialmente superado pelo ADR-021 no que tange execucao de prontidao no runtime da aba Preview.
- **Contexto**: A implementacao do painel de prontidao acoplou `output$datatable` a `preview_readiness()`. Em datasets grandes, a tabela de 100 linhas aguardava o scan completo do dataset, violando o ADR-002 (preview rapido com `head(df, 100)`).
- **Decisao**:
  - Remover dependencia de `output$datatable` em `preview_readiness()`.
  - Calcular destaque de colunas vazias apenas sobre `preview_data()` (100 linhas).
  - Manter `output$readiness_panel` independente, calculado sobre o dataset completo.
  - Remover `empty_columns` de `compute_preview_readiness()` para evitar varredura O(n x m) de todas as colunas.
  - Definir prioridade de render maior para `datatable` e menor para `readiness_panel`.
- **Alternativas**:
  - Mover readiness para acao explicita (ex.: botao "Verificar prontidao") - rejeitado neste ciclo para manter UX atual sem adicionar novo controle.
- **Consequencias**:
  - Preview volta a abrir com tabela imediata baseada em 100 linhas.
  - Painel de prontidao nao bloqueia mais o caminho critico da aba.
  - Regra do ADR-002 e restaurada sem perder indicadores de qualidade.

---

## ADR-021: Pipeline duplo de mapeamento (preview leve e export completo sob demanda)

- **Data**: 2026-02-15
- **Contexto**: Mesmo apos desacoplar o `datatable` de `preview_readiness()`, a aba Preview ainda podia ficar lenta porque consumia `mapped_data` completo vindo de `mod_mapping`. Isso fazia o pipeline pesado de mapeamento completo ser recalculado em cada ajuste de campo, antes da renderizacao do preview.
- **Decisao**:
  - Separar o mapeamento em dois fluxos reativos dentro de `mod_mapping`:
    - `processed_data`: dataset completo (uso em download e validacoes).
    - `preview_processed_data`: dataset leve calculado apenas sobre `head(raw_data, 100)`.
  - Expor `preview_processed_data` como atributo interno (`preview_data`) do retorno principal de `mod_mapping_server`, preservando compatibilidade da assinatura publica.
  - Atualizar `app_server` para passar `preview_data` ao `mod_preview_server` e manter `processed_data` completo para download e modulos de validacao.
  - Atualizar `mod_preview_server` para aceitar fonte de download separada (`download_data_r`), mantendo tabela baseada no canal leve.
  - Remover `readiness_panel` do runtime da aba Preview para manter UX simples e eliminar computacao pesada fora de acoes explicitas.
- **Alternativas**:
  - Manter painel de prontidao completo no Preview e apenas ajustar prioridade reativa - rejeitado por manter custo pesado durante navegacao e remapeamento.
  - Recalcular mapeamento completo a cada mudanca e tentar mascarar latencia via loading - rejeitado por nao resolver causa raiz e por piorar responsividade.
- **Consequencias**:
  - Preview passa a ser estritamente rapido, com custo limitado ao subconjunto de 100 linhas.
  - Processamento completo fica concentrado em acoes explicitas (download e validacoes), alinhado ao ADR-002.
  - UX do Preview permanece simples (titulo, subtitulo, botao de download, tabela), sem regressao visual.
  - ADR-019 e ADR-020 permanecem como historico, mas ficam parcialmente superados no que diz respeito a prontidao em tempo de preview.

---

## ADR-022: Checklist de campos obrigatorios em modo leve na aba Preview

- **Data**: 2026-02-15
- **Contexto**: A UX da aba Preview precisava recuperar sinal visual de prontidao sem reintroduzir o custo pesado que motivou o ADR-021. Tambem havia regressao visual no botao de download (icone duplicado) e no seletor "Mostrar _MENU_ registros" do DataTable.
- **Decisao**:
  - Reintroduzir apenas o checklist de campos obrigatorios como `renderUI` independente, usando `compute_preview_readiness()` sobre `preview_data()` (subconjunto de 100 linhas).
  - Manter `output$datatable` desacoplado do checklist para preservar caminho critico rapido.
  - Reutilizar as classes CSS existentes `.preview-readiness-chip-ok` e `.preview-readiness-chip-missing` para chips de status.
  - Corrigir botao de download para usar label textual + argumento `icon` explicito no `downloadButton`, evitando duplicacao.
  - Ajustar CSS especifico de `dataTables_length select` com `padding-right` e `background-position` para evitar sobreposicao da seta no valor selecionado.
- **Alternativas**:
  - Reativar painel completo de prontidao com metricas sobre dataset total - rejeitado por potencial de regressao de performance no fluxo de preview.
  - Calcular checklist no dataset completo com canal separado - rejeitado neste ciclo para manter custo previsivel e UI responsiva.
- **Consequencias**:
  - Preview recupera checklist visual util sem comprometer responsividade.
  - Fluxo de download/validacao continua usando dataset completo em canal dedicado.
  - Correcoes visuais eliminam dois pontos de confusao recorrentes da interface.

---

## ADR-023: Download com confirmacao + modal de progresso sem chunking

- **Data**: 2026-02-15
- **Contexto**: O download completo em DwC precisa de UX mais clara sobre tempo de processamento. Cancelamento real exigiria chunking e poderia degradar o pipeline vetorizado atual.
- **Decisao**:
  - Manter `downloadHandler` e `process_for_export()` intactos (vetorizado).
  - Adicionar etapa de confirmacao antes do download, com aviso de que a acao nao pode ser interrompida.
  - Exibir modal de progresso visual reutilizando o estilo do auto-map (barra + frases), com progresso estimado via JS ate o fim do processamento.
  - Validar ausencia de colunas obrigatorias antes de iniciar o download (sem bloquear `occurrenceID`, que pode ser auto-gerado).
- **Alternativas**:
  - Implementar chunking para cancelamento real - rejeitado por risco de degradar desempenho e aumentar complexidade.
  - Manter `withProgress()` simples - rejeitado por UX insuficiente e inconsistência com o padrao visual do app.
- **Consequencias**:
  - UX mais clara sem mexer no pipeline vetorizado de export.
  - Download continua fiel ao contrato atual e sem regressao de performance.

---

## ADR-024: Validacao taxonomica com deduplicacao e cascata de provedores

- **Data**: 2026-02-15
- **Contexto**: A validacao taxonomica consulta bases locais via taxadb e pode ser custosa em datasets grandes. O ADR-002 limita preview, mas a validacao precisa operar sobre o dataset completo.
- **Decisao**:
  - Deduplicar nomes antes de consultar (`unique(scientificName)`) e depois propagar resultados por join.
  - Usar `taxadb::filter_name()` como fonte primaria de validacao.
  - Cascata com prioridade fixa: o primeiro provedor que retorna resultado define o veredito (aceito, sinonimo ou ambiguo).
  - ADR-002 nao se aplica a validacao taxonomica (nao usar `head(df, 100)`), apenas ao preview.
- **Alternativas**:
  - Limitar validacao a 100 linhas - rejeitado por perda de cobertura.
  - Combinar resultados de varios provedores ao mesmo tempo - rejeitado por conflitar teorias taxonomicas e aumentar ambiguidade.
- **Consequencias**:
  - Tempo de validacao reduzido por deduplicacao.
  - Resultados mais consistentes e previsiveis com cascata.
  - Preview permanece leve e independente da validacao.

---

## ADR-025: UX bloqueante na validacao taxonomica + fallback por provedor

- **Data**: 2026-02-15
- **Contexto**: A validacao de nomes podia ficar silenciosa por segundos/minutos em datasets grandes, sem indicar andamento de consulta nos bancos do `taxadb`. Alem disso, falha em um provedor podia interromper toda a cascata, mesmo com outros provedores disponiveis.
- **Decisao**:
  - Migrar seletor de provedores para `checkboxGroupInput`, com ordem fixa `GBIF > ITIS > COL > NCBI` e default apenas `GBIF`.
  - Adotar modal bloqueante no padrao Rostrum para validacao taxonomica, com barra e fases estimadas client-side (`0-15` preparo, `15-85` consulta por provedor, `85-95` consolidacao, `95-100` finalizacao).
  - Tornar `run_taxadb_cascade()` resiliente: tratar erro por provedor via `tryCatch`, registrar falhas em `attr(..., "provider_failures")` e continuar a cascata com os provedores restantes.
  - Expor no modulo resumo dos provedores consultados e aviso de provedores com falha.
  - Tornar explicito na UI que o relatorio e consolidado por nomes cientificos unicos.
- **Alternativas**:
  - Usar apenas `showNotification()` sem modal - rejeitado por feedback insuficiente em operacoes longas.
  - Implementar progresso real servidor-side de download/consulta - rejeitado neste ciclo por custo alto em Shiny sincrono sem migracao para async.
  - Interromper toda a validacao ao primeiro erro de provedor - rejeitado por reduzir resiliencia.
- **Consequencias**:
  - UX previsivel durante validacoes longas, com estado visivel do processamento.
  - Maior robustez operacional quando um provedor estiver indisponivel.
  - Contrato funcional preservado (relatorio continua consolidado por nomes unicos).

---

## ADR-026: Gate leve de prontidao para habilitar `Validar nomes` sem materializar `mapped_data`

- **Data**: 2026-02-16
- **Contexto**: O botao `Validar nomes` dependia de `quick_inputs() -> mapped_data_r()`. Em datasets grandes, ao mapear `scientificName` e voltar para a aba de validacao, o botao demorava para habilitar porque `mapped_data_r()` reconstruia `processed_data` completo (incluindo derivacoes taxonomicas), embora nenhuma validacao tivesse sido solicitada.
- **Decisao**:
  - Criar em `mod_mapping` um reactive leve `validation_gate_r` com contrato estavel:
    - `status = "no_data" | "missing_scientific" | "ok"`
    - `has_data` (boolean)
    - `scientific_col` (nome da coluna mapeada ou vazio)
  - Restringir `validation_gate_r` a `raw_data_r()` + estado de mapeamento de `scientificName` (`rv$map_values` com fallback para `input$map_scientificName`), sem chamar `processed_data` nem `build_processed_mapping_df`.
  - Expor o gate como atributo interno do retorno de `mod_mapping_server`: `attr(processed_data, "validation_gate")`.
  - No `app_server`, propagar esse gate para `mod_validate_names_server(..., validation_gate_r = validation_gate)`.
  - Em `mod_validate_names`, fazer `quick_inputs()` priorizar `validation_gate_r`; usar `mapped_data_r()` apenas como fallback legado quando o gate nao for fornecido.
  - Manter processamento pesado (`prepared_inputs()`, normalizacao e fluxo taxadb) exclusivamente no clique em `input$validate`.
  - Manter a regra de UX: botao continua desabilitado enquanto `status != "ok"`.
- **Alternativas**:
  - Manter checagem via `mapped_data_r()` em `quick_inputs()` - rejeitado por acoplamento com pipeline pesado e latencia perceptivel.
  - Mover habilitacao para polling JS no cliente - rejeitado por duplicar regra de negocio fora do server e aumentar risco de divergencia.
  - Habilitar sempre o botao e bloquear apenas no clique - rejeitado por piorar feedback preventivo da interface.
- **Consequencias**:
  - Habilitacao do botao passa a responder quase instantaneamente apos mapear `scientificName`, inclusive ao voltar de outra aba.
  - Elimina processamento pesado de mapeamento no caminho de renderizacao/estado da aba de validacao.
  - Preserva compatibilidade retroativa de `mod_validate_names_server` via parametro opcional e fallback.
  - Reforca separacao arquitetural entre estado leve de UI e processamento completo sob demanda.

---

## ADR-027: Inicio em duas fases na validacao de nomes para feedback imediato no clique

- **Data**: 2026-02-16
- **Contexto**: Mesmo com o gate leve do ADR-026, o clique em `Validar nomes` ainda podia aparentar "sem resposta" quando a etapa pesada inicial (normalizacao/deduplicacao e montagem de estado da execucao) rodava antes do primeiro repaint da interface.
- **Decisao**:
  - Introduzir estado intermediario `starting` no modulo de validacao de nomes.
  - No clique em `input$validate`, executar apenas validacoes rapidas, marcar `starting = TRUE` e agendar o inicio pesado para o proximo ciclo com `session$onFlushed(..., once = TRUE)`.
  - Mover a etapa pesada para um observer separado (`observeEvent(rv$start_requested, ...)`), mantendo a regra de que processamento taxonomico pesado ocorre somente apos clique explicito.
  - Durante `starting`, atualizar a UI como ocupada (botao com spinner, cards desabilitados e painel de progresso com estado "running").
  - Ao entrar em execucao efetiva, transicionar para `running`; em erro de preparacao, retornar para estado estavel com notificacao.
- **Alternativas**:
  - Manter tudo no mesmo `observeEvent(input$validate, ...)` - rejeitado por bloquear feedback visual em datasets grandes.
  - Resolver apenas com notificacao simples sem separar fases - rejeitado por nao garantir repaint antes do trecho pesado.
  - Migrar imediatamente para async (`future/promises`) - rejeitado neste ciclo por custo de mudanca arquitetural mais alto que o necessario para o problema de UX.
- **Consequencias**:
  - Usuario recebe feedback imediato apos clicar em `Validar nomes`, sem percepcao de "botao morto".
- Preserva semantica funcional do fluxo (processamento pesado continua condicionado ao clique).
- Separa claramente etapa de "arranque de UI" da etapa de processamento, facilitando manutencao e extensoes futuras (ex.: modal bloqueante completo).

---

## ADR-028: Homepage compacta com obrigatorios alinhados ao Preview e categorias sempre visiveis

- **Data**: 2026-02-19
- **Contexto**: A homepage estava alta demais no desktop, exigindo scroll cedo no lado direito. Alem disso, os campos obrigatorios exibidos na Home podiam divergir do contrato de prontidao usado na aba Preview. A tentativa com tabs clicaveis para categorias reduziu altura, mas aumentou atrito de leitura.
- **Decisao**:
  - Compactar os hints de upload em um bloco unico (`upload-hints-compact`) para reduzir altura no lado esquerdo.
  - Reorganizar "Como funciona" em layout horizontal de 4 etapas para aproveitar melhor largura no lado direito.
  - Alinhar a lista de obrigatorios da Home ao mesmo conjunto do Preview: `scientificName`, `eventDate`, `decimalLatitude`, `decimalLongitude`, `basisOfRecord`, `occurrenceID`.
  - Exibir categorias de obrigatorios diretamente, sempre visiveis, em grupos compactos (`Record-level`, `Occurrence`, `Taxon`, `Location`), sem interacao por tabs.
  - Aplicar cache-busting no CSS (`www/custom.css?v=<timestamp>`) para reduzir risco de regressao visual por cache stale durante iteracoes de UI.
- **Alternativas**:
  - Manter layout vertical original de steps + blocos separados de alerta - rejeitado por ocupar altura excessiva.
  - Usar tabs clicaveis para obrigatorios - rejeitado por esconder informacao essencial e piorar scannability para onboarding.
  - Forcar overrides com `!important` no CSS - rejeitado por politica de estilo e manutencao.
- **Consequencias**:
  - Homepage mais legivel sem esconder informacao critica de DwC.
  - Menor risco de inconsistencias funcionais entre Home e Preview para campos obrigatorios.
  - Iteracoes de CSS ficam mais previsiveis em ambiente local por invalidacao de cache de asset.

---

## ADR-029: Foco pos-validacao em itens acionaveis com filtro server-side no stream

- **Data**: 2026-02-19
- **Contexto**: A aba de validacao de nomes melhorou em robustez/performance nas ondas ADR-024..027, mas no pos-validacao o stream ainda abria com muitos itens `accepted`, reduzindo escaneabilidade para os casos que exigem acao (`not_found`, `ambiguous`, `synonym`, `ignored`). No pre-validacao, a coluna direita exibia estado vazio com baixo valor informativo.
- **Decisao**:
  - Reorganizar layout da aba `validate_names` para manter a coluna esquerda focada em configuracao (provedores + opcoes) e mover a secao de acao para a coluna direita.
  - No estado pre-validacao, exibir hint orientativo na coluna direita em vez de stream/progresso vazios.
  - Implementar filtro do stream no server com pills e contadores por status (`all`, `problems`, `not_found`, `ambiguous`, `synonym`, `ignored`), sem introduzir `shinyjs`.
  - Definir filtro default para `problems` ao concluir execucao, preservando `all` como opcao de retorno.
  - Manter tabela de resultados focada em itens nao aceitos, com badges traduzidos, italico em `scientificName`, highlight por status e linguagem completa de DataTable.
  - Preservar contratos dos ADR-026 e ADR-027: gate leve de prontidao e fluxo `starting -> running` sem materializar pipeline pesado fora do clique.
- **Alternativas**:
  - Filtragem via `shinyjs::runjs` no DOM - rejeitado por duplicar estado entre cliente/server e aumentar risco de divergencia.
  - Manter stream em `all` por padrao - rejeitado por reduzir foco operacional apos a conclusao.
  - Incluir `accepted` tambem na tabela de resultados - rejeitado neste ciclo para evitar ruído e preservar foco em acao.
- **Consequencias**:
  - Pos-validacao mais orientado a decisao, com menor carga cognitiva para triagem.
  - Sem regressao dos caminhos de performance estabilizados nas ondas anteriores.
  - Superficie de i18n e testes ampliada para cobrir o novo comportamento de UX.

---

## ADR-030: Padrao visual unico para DataTables em todos os modulos

- **Data**: 2026-02-19
- **Contexto**: O estilo mais refinado de tabela (header azul, controles compactos e paginacao consistente) estava restrito a aba Preview, enquanto validacao de nomes, validacao de coordenadas e Wiki ainda usavam variacoes locais.
- **Decisao**:
  - Extrair o estilo de tabela para uma classe compartilhada: `.finch-table-shell`.
  - Aplicar o wrapper `.finch-table-shell` em todas as tabelas `DT::datatable` do app (`preview`, `validate_names`, `validate_coords`, `wiki`).
  - Padronizar configuracao de paginacao para `pageLength = 10` com `lengthMenu = 10/25/50/100`.
  - Completar localizacao de DataTables na validacao de coordenadas (search/length/info/empty/zero/paginate) para alinhar com os demais modulos bilingues.
- **Alternativas**:
  - Manter estilos separados por modulo - rejeitado por gerar divergencia visual e manutencao duplicada.
  - Sobrescrever globalmente `.dataTables_wrapper` sem wrapper de escopo - rejeitado por risco de efeitos colaterais em tabelas com comportamento especial.
- **Consequencias**:
  - Consistencia visual entre todas as tabelas e controles de navegacao.
  - Menor custo de manutencao futura para ajustes de UX de DataTable.
  - Diretriz tecnica explicita para novas tabelas no projeto.

---

## ADR-031: Restaurar upload dropzone de superficie inteira com copy central e fallback cross-browser

- **Data**: 2026-02-21
- **Contexto**: A homepage sofreu regressao apos reversoes de UI: o upload perdeu o comportamento esperado de dropzone grande e voltou a exibir conflitos visuais com a caixa nativa do `fileInput`. Alem disso, em parte dos navegadores o drag-and-drop nao iniciava de forma consistente por deteccao rigida de `dataTransfer.types`.
- **Decisao**:
  - Carregar `www/upload-dropzone.js` via `app_ui` com versionamento no `src` para evitar cache stale em iteracoes de UI.
  - Manter `fileInput` como backend de upload, mas remover o wrapper visual nativo (`.input-group`) durante o bind JS; o input real e reanexado no container da dropzone para preservar eventos `change` do Shiny.
  - Tornar a deteccao de arquivos no drag-and-drop resiliente (`types.contains`, `types.indexOf`, iteracao com `item()`), evitando dependencia exclusiva de `Array.prototype.includes`.
  - Restaurar visual de dropzone de superficie inteira com area clicavel completa, watermark CSV opaco ao fundo e copy centralizada.
  - Mover o texto de tamanho maximo para dentro da dropzone junto da instrucao de acao, mantendo tipografia alinhada ao design system (`IBM Plex Sans` para instrucao e `IBM Plex Mono` para metadado).
- **Alternativas**:
  - Manter `fileInput` nativo com botao/campo conectados e apenas estilizar borda externa - rejeitado por nao recuperar a UX esperada de "box de arraste" e por manter ruido visual.
  - Esconder a caixa nativa apenas via CSS - rejeitado por fragilidade entre temas/markup e por nao resolver completamente sobreposicoes.
  - Deixar o texto de tamanho maximo fora da area de drop - rejeitado por reduzir clareza contextual no ponto de acao.
- **Consequencias**:
  - Upload volta ao padrao visual esperado pelo produto com feedback claro de arrastar/soltar.
  - Menor risco de regressao cross-browser no evento de drop.
  - Menor acoplamento entre UX custom e markup interno do Bootstrap/Shiny no componente de upload.

---

## ADR-032: Compatibilidade de contrato no gate da validacao de coordenadas com fallback seguro

- **Data**: 2026-02-21
- **Contexto**: `app_server` repassa `attr(mapped_data, "validation_gate")` vindo de `mod_mapping`, cujo contrato atual e orientado a nomes (`status/has_data/scientific_col`). `mod_validate_coords` passou a tentar consumir esse atributo como se fosse contrato de coordenadas (`coords_status/lat_col/lon_col`), causando estado incorreto de prontidao e bloqueio indevido do botao em parte dos cenarios.
- **Decisao**:
  - Tratar o gate por atributo como opcional e orientado a capacidade: somente usar quando o contrato de coordenadas estiver presente (`coords_status` ou `lat_col`/`lon_col`).
  - Quando o contrato esperado nao existir, aplicar fallback explicito para deteccao de prontidao via `mapped_data_r()` (`decimalLatitude`/`decimalLongitude`).
  - Completar no CSS as classes ja referenciadas por `mod_validate_coords` (cards, pills, badges e legenda) para evitar divergencia entre estrutura renderizada e estilo aplicado.
- **Alternativas**:
  - Exigir que `mod_mapping` passe imediatamente um segundo gate especifico de coordenadas - rejeitado neste ciclo por ampliar superficie de contrato publico sem necessidade imediata.
  - Ignorar totalmente `attr(..., "validation_gate")` em coordenadas - rejeitado por descartar compatibilidade futura com gates leves especificos.
  - Habilitar sempre o botao e validar apenas no clique - rejeitado por piorar feedback preventivo da UI.
- **Consequencias**:
  - Elimina falso negativo de prontidao na aba de coordenadas quando o atributo recebido nao corresponde ao contrato esperado.
  - Preserva compatibilidade progressiva para adoção futura de gate leve especifico de coordenadas.
  - Reforca a pratica de validacao de contrato entre modulos para atributos internos compartilhados.

---

## ADR-033: Gate leve dedicado e layout em paineis para validacao de coordenadas

- **Data**: 2026-02-21
- **Contexto**: Mesmo com o fallback do ADR-032, a aba de coordenadas ainda dependia de `mapped_data_r()` para prontidao em cenarios sem contrato completo de gate. Alem disso, o layout concentrava stats/mapa/tabela em um bloco monolitico, dificultando manutencao e posicionamento consistente da coluna de contexto.
- **Decisao**:
  - Introduzir `validation_gate_coords` no `mod_mapping` como canal leve dedicado (`coords_status`, `has_data`, `lat_col`, `lon_col`), sem materializar `processed_data`.
  - Propagar o gate dedicado no `app_server` para `mod_validate_coords_server(..., validation_gate_r = ...)`.
  - Refatorar `mod_validate_coords` para UI em paineis independentes (`stats_panel`, `filter_pills`, `map_panel`, `table_panel`) no grid `col-lg-3/9`.
  - Manter `validate_coords` como wrapper legado, mas delegando a validacao para `validate_coords_df` e preservando assinatura historica.
- **Alternativas**:
  - Permanecer apenas com fallback em `mapped_data_r()` - rejeitado por ainda acoplar prontidao da UI ao caminho pesado.
  - Manter `results_panel` unico - rejeitado por dificultar evolucao do layout lateral sticky e reaproveitamento de blocos.
- **Consequencias**:
- Habilitacao da validacao de coordenadas responde de forma previsivel com custo leve.
- Estrutura visual da aba de coordenadas fica modular e alinhada ao padrao dos modulos recentes.
- Compatibilidade retroativa de chamadas antigas de `validate_coords` e `mod_validate_coords_server` e preservada.

---

## ADR-034: Motor canonico de coordenadas com CoordinateCleaner, gate com country e diagnostico deterministico

- **Data**: 2026-02-21
- **Contexto**: O motor legado de coordenadas era limitado para deteccao geoespacial e nao cobria checks de referencia espacial (mar, pais, capitais, centroids, instituicoes). Tambem havia ambiguidade na UI sobre quando permitir execucao, especialmente sem `country` mapeado.
- **Decisao**:
  - Adotar `CoordinateCleaner` como engine principal da aba de coordenadas via `validate_coords_cc_df(...)`.
  - Manter `validate_coords_df()` como legado para compatibilidade, mas remover seu uso como caminho primario da aba.
  - Exigir gate de entrada com `lat/lon/country` mapeados antes de iniciar validacao.
  - Evoluir o contrato de gate para estados granulares:
    - `no_data`
    - `ok`
    - `missing_lat`
    - `missing_lon`
    - `missing_country`
    - `missing_multiple`
  - Resolver `country` para ISO3 internamente no pipeline com cadeia de fallback (`iso3c -> iso2c -> country.name`) e mapa minimo de aliases frequentes.
  - Definir `seas_scale = 110` como resolucao oficial do check de mar.
  - Definir dois perfis de execucao:
    - `complete` (todos os checks principais)
    - `fast` (subset orientado a throughput)
  - Preservar heuristicas legadas fora do escopo nativo do CoordinateCleaner:
    - `swapped`
    - `identical_all`
  - Definir diagnostico final deterministico por prioridade, com uma classe final por linha e familias canonicamente expostas para UI:
    - `ok`, `validity`, `country`, `sea`, `zero_equal`, `reference`
  - Garantir contrato nao-destrutivo: nenhuma linha e removida, apenas flag/diagnostico.
  - Declarar dependencias espaciais em `Imports` (`CoordinateCleaner`, `countrycode`, `sf`, `rnaturalearth`, `rnaturalearthdata`) para reduzir variabilidade de ambiente.
- **Alternativas**:
  - Manter motor legado como principal e usar `CoordinateCleaner` apenas opcionalmente - rejeitado por cobertura geoespacial inferior.
  - Tratar dependencias espaciais em `Suggests` - rejeitado por aumentar risco de runtime inconsistente no fluxo principal da aba.
  - Permitir validacao sem `country` - rejeitado por comprometer checks de consistencia por pais.
- **Consequencias**:
  - Maior robustez dos diagnosticos geoespaciais e melhor alinhamento com praticas de qualidade de dados de biodiversidade.
  - Custo de instalacao maior por dependencias espaciais pesadas, compensado por previsibilidade operacional.
  - Contrato de dados da aba de coordenadas fica explicito e testavel de ponta a ponta.

---

## ADR-035: Full-width local da aba de coordenadas com divisao 2/10 + 6/6 e legenda por familia

- **Data**: 2026-02-21
- **Contexto**: A aba de coordenadas apresentava sobras laterais e distribuicao espacial subotima para leitura de mapa/tabela. O requisito de produto pedia melhor aproveitamento horizontal, com coluna de controle compacta na esquerda e resultados ocupando a largura util.
- **Decisao**:
  - Remover limite de largura fixa da pagina de coordenadas (`max-width` inline).
  - Adotar grid principal `col-lg-2` (controle + stats, sticky) e `col-lg-10` (resultado).
  - Dentro do resultado, manter divisao `50/50` (`col-lg-6` mapa, `col-lg-6` tabela), conforme requisito funcional.
  - Aplicar override de padding lateral local da aba via seletor contextual (`:has(.validate-coords-page)`), sem afetar outras tabs.
  - Reorganizar UI em paineis independentes (`action_card`, `stats_panel`, `filter_pills`, `map_panel`, `table_panel`) para reduzir acoplamento.
  - Migrar filtros para familias de diagnostico e alinhar legenda do mapa ao mesmo contrato.
  - Manter nota explicativa de cluster para evitar associacao incorreta entre cor de cluster e tipo de issue.
- **Alternativas**:
  - Ajustar apenas larguras de coluna sem mexer em max-width/padding da aba - rejeitado por manter sobras laterais.
  - Usar proporcao 7/5 para mapa/tabela - rejeitado neste ciclo por conflito com requisito explicito de 50/50.
  - Sobrescrever layout global de todas as tabs - rejeitado por risco de regressao visual fora do modulo.
- **Consequencias**:
  - Melhor uso horizontal da tela e leitura mais equilibrada entre mapa e tabela.
  - Isolamento de estilo reduz risco de regressao transversal em outras areas da aplicacao.
  - Contrato visual da aba de coordenadas fica coerente com o contrato de dados por familia de diagnostico.

---

## ADR-036: Resolucao de pais em cascata com aliases externalizados em `.rds` e fuzzy conservador

- **Data**: 2026-02-22
- **Contexto**: A primeira versao do `country -> ISO3` no pipeline de coordenadas usava uma cadeia curta (`iso3c -> iso2c -> country.name`) e um mapa minimo hard-coded. Em bases reais, isso mantinha volume alto de `country_unresolved` para variacoes de idioma, abreviacoes e erros leves de digitacao.
- **Decisao**:
  - Externalizar aliases customizados para `inst/extdata/country_aliases.rds` e remover o hard-code interno como fonte primaria.
  - Criar script reprodutivel `data-raw/generate_country_aliases.R` para regenerar o `.rds` versionado.
  - Reescrever `coords_country_to_iso3()` em 5 camadas deterministicas:
    - `iso3c` estrito
    - `iso2c` estrito
    - nomes CLDR multilíngues (`countrycode::codelist` + `custom_dict`)
    - aliases do `.rds`
    - fuzzy matching conservador com guardrails
  - Aplicar estrategia de performance por deduplicacao (`unique -> resolve -> match de volta`) e cache de referencia:
    - cache de aliases carregados (`coords_load_aliases()`)
    - cache da referencia fuzzy multilíngue (`coords_build_fuzzy_reference()`)
  - Manter `coords_alias_map()` como wrapper de compatibilidade para evitar quebra de chamadas legadas.
  - Resolver path do `.rds` com fallback robusto entre ambiente de desenvolvimento e pacote instalado (`resolve_country_aliases_path()`).
- **Alternativas**:
  - Manter dicionario hard-coded dentro da funcao - rejeitado por baixa escalabilidade e alto custo de manutencao.
  - Usar `.csv` como fonte principal de aliases - rejeitado por custo de parse, fragilidade de encoding e divergencia do padrao de artefatos RDS do projeto.
  - Aplicar fuzzy agressivo sem restricoes - rejeitado por risco de falso positivo em siglas curtas e nomes proximos.
- **Consequencias**:
  - Queda de falsos `country_unresolved` em dados heterogeneos sem alterar o contrato nao-destrutivo do pipeline.
  - Maior previsibilidade na manutencao de aliases (dados versionados fora do codigo).
  - Custos de CPU controlados por deduplicacao e cache, com cobertura de testes dedicada para regressao funcional e performance.

---

## ADR-037: Foco do diagnostico em `sea/swapped/reference` e remocao de `cc_coun` do fluxo principal

- **Data**: 2026-02-22
- **Contexto**: Em dados reais (inclusive planilhas de publicacao cientifica), o teste `cc_coun` vinha gerando volume alto de `country_mismatch` sem sinal operacional claro, especialmente em zonas costeiras/fronteiras/territorios especiais. Isso passou a competir com os sinais mais acionaveis para o produto (`sea`, `swapped`, `reference`).
- **Decisao**:
  - Remover `cc_coun` do pipeline de diagnostico principal da aba `validate_coords`.
  - Remover a familia `country` dos filtros/pills/legenda e do fluxo de contagem de diagnosticos.
  - Manter o gate de entrada com `lat/lon/country` (o campo `country` continua obrigatorio para o contrato do modulo).
  - Manter `seas_scale = 110` fixo no motor.
  - Tornar `reference` autoexplicativo na UI com nota textual dedicada na legenda.
  - Reverter o experimento de fundo vetorial no Leaflet para tiles padrao (`CartoDB.Positron`) por robustez visual imediata em runtime.
- **Alternativas**:
  - Manter `cc_coun` como parte obrigatoria do diagnostico final - rejeitado por ruido elevado na triagem.
  - Remover totalmente qualquer dependencia de `country` da aba - rejeitado para preservar contrato de mapeamento e compatibilidade do fluxo.
  - Manter fundo vetorial `rnaturalearth` no mapa da UI - rejeitado neste ciclo apos regressao visual de exibicao em runtime.
- **Consequencias**:
  - Stream de problemas fica mais aderente ao objetivo operacional da aba (mar, inversao e hotspots de referencia).
  - Reducao de falso alerta na categoria de pais inconsistente.
  - Menor atrito de interpretacao no mapa, com legenda mais clara para `reference`.

---

## ADR-038: Modal de loading resiliente em `validate_coords` e basemap selecionavel no Leaflet

- **Data**: 2026-02-22
- **Contexto**: O modal de loading da validacao de coordenadas passou a falhar com `attempt to apply non-function` ao tentar renderizar `<lottie-player>` via `shiny::tags$` em uma custom tag com hifen. A falha ocorria antes da transicao para `run_requested`, interrompendo a execucao e criando percepcao de lentidao/travamento. Em paralelo, havia requisito de produto para alternar basemap entre `OpenStreetMap` e `Esri.WorldImagery`.
- **Decisao**:
  - Renderizar o web component Lottie com HTML explicito (`shiny::HTML("<lottie-player ...>")`) em vez de `shiny::tags$` para custom tag.
  - Manter `src` do asset com prefixo `www/` (`www/lottie/...`) porque o app serve assets via `addResourcePath("www", ...)`.
  - Blindar o arranque da validacao em `observeEvent(rv$start_requested, ...)` com `tryCatch`:
    - falha de modal nao bloqueia pipeline;
    - `rv$run_requested <- TRUE` sempre executa;
    - aviso leve informa fallback sem animacao.
  - Ajustar tamanho do Lottie no modal para metade (melhor proporcao visual).
  - Trocar basemap padrao para `OpenStreetMap` e adicionar `Esri.WorldImagery` como opcao selecionavel via `addLayersControl`.
  - Definir `OpenStreetMap` como camada inicial visivel; `Esri.WorldImagery` inicia oculto.
- **Alternativas**:
  - Trocar `src` para `lottie/...` sem `www/` - rejeitado por incompatibilidade com o contrato atual de assets do app.
  - Manter modal sem `tryCatch` - rejeitado por permitir que erro visual bloqueie validacao de backend.
  - Expor seletor de basemap fora do Leaflet (UI externa) - rejeitado neste ciclo por aumento de complexidade sem ganho funcional imediato.
- **Consequencias**:
  - Elimina o erro fatal de modal e restaura fluxo de validacao.
  - Falhas de UI no loading deixam de afetar a execucao funcional.
  - Usuario passa a controlar contexto cartografico (rua vs satelite) sem perder padrao default.
  - Suite `test-mod-validate-coords-server` volta a verde e ganha cobertura de regressao para falha de modal.

---

## ADR-039: Enquadramento dinamico do mapa de coordenadas por pontos filtrados

- **Data**: 2026-02-22
- **Contexto**: A aba `validate_coords` ainda inicializava o mapa com `fitBounds` fixo (bounding box da America do Sul), o que gerava foco geografico inconsistente apos validacao/filtro, principalmente para datasets de outras regioes.
- **Decisao**:
  - Remover o `fitBounds` fixo da inicializacao do `renderLeaflet`.
  - Inicializar o mapa com visao neutra (`setView(0, 0, zoom = 2)`), sem supor regiao.
  - No observer de atualizacao (`leafletProxy`), apos `addCircleMarkers`, calcular limites reais do subconjunto exibido (`lat_num`/`lon_num`) e aplicar `fitBounds`.
  - Tratar caso degenerado (todos os pontos no mesmo par lat/lon) com `setView(..., zoom = 8)` para evitar comportamento ruim de `fitBounds` com bbox zero.
  - Aplicar o ajuste por filtro ativo (pills), de forma que cada familia mostre seu proprio enquadramento.
- **Alternativas**:
  - Manter bbox fixa regional - rejeitado por viés geografico e UX inconsistente.
  - Calcular bounds apenas no dataset completo (ignorando filtro ativo) - rejeitado por reduzir utilidade dos pills.
  - Ajustar bounds antes de adicionar marcadores - rejeitado por pior rastreabilidade do estado final renderizado no proxy.
- **Consequencias**:
  - Mapa passa a abrir e reposicionar de acordo com os dados realmente exibidos.
  - Reduz a necessidade de pan/zoom manual apos cada validacao ou troca de filtro.
  - Mantem comportamento robusto para cenarios de ponto unico e para subsets pequenos.

---

## ADR-040: Guardrails visuais obrigatorios para caixas, navbar e seta de dropdown

- **Data**: 2026-02-23
- **Contexto**: A migração para o design v4 introduziu regressões de UX já tratadas anteriormente: caixas com borda grossa unilateral, desalinhamento do seletor de idioma no header, espaçamento insuficiente entre itens de navegação e corrupção visual do indicador de dropdown (`â–¾`).
- **Decisao**:
  - Proibir borda grossa em apenas um lado para caixas de informação/status (`alert`, `notification` e componentes equivalentes).
  - Adotar borda fina completa (quatro lados) com fundo semântico como padrão oficial.
  - Fixar contrato de navbar com alinhamento vertical consistente entre links e seletor de idioma, incluindo espaçamento horizontal mínimo entre itens.
  - Para setas de dropdown em pseudo-elemento CSS, usar escape seguro de encoding (`content: '\25BE'`) ou SVG; não usar glifo Unicode literal.
- **Alternativas**:
  - Manter destaque por barra lateral grossa nas caixas - rejeitado por inconsistência visual e recorrência de regressão.
  - Manter caractere literal de seta no CSS - rejeitado por risco conhecido de corrupção de encoding em build/deploy.
  - Tratar alinhamento do header apenas por ajuste local pontual - rejeitado por não estabelecer contrato estável para regressões futuras.
- **Consequencias**:
  - Padrão visual das caixas fica consistente em todo o app.
  - Header mantém alinhamento previsível entre navegação e idioma em diferentes viewports.
  - Indicadores de dropdown deixam de depender de encoding do arquivo CSS.

---

## ADR-041: Progresso de upload fora da dropzone, largura integral e sem "chip-container"

- **Data**: 2026-02-23
- **Contexto**: A UX do upload apresentou regressao recorrente: a barra nativa de progresso do `fileInput` aparecia dentro da dropzone (ou visualmente acoplada a ela), com largura inconsistente em relacao aos chips informativos e, em uma iteracao, encapsulada por uma caixa extra parecida com chip.
- **Decisao**:
  - Separar estruturalmente a area de upload em dois blocos:
    - `upload-dropzone`: apenas superficie de arrastar/soltar e copy visual.
    - `upload-native-input`: container do `fileInput` nativo e do progresso.
  - Manter o `input[type=file]` funcional para o binding do Shiny e para o clique da dropzone, removendo apenas o shell visual nativo (`.input-group`) em runtime via `upload-dropzone.js`.
  - Atualizar o binding JS para localizar o `fileInput` tanto dentro da dropzone quanto no container irmao (`.upload-native-input`), preservando compatibilidade com o novo DOM.
  - Instituir guardrail de CSS para impedir progresso dentro da dropzone:
    - `.upload-dropzone .progress`, `.upload-dropzone .shiny-file-input-progress`, `.upload-dropzone [id$="_progress"]` => `display: none !important`.
  - Estilizar o progresso oficial apenas em `.upload-native-input`, com altura padronizada em `40px` e largura integral.
  - Forcar largura integral com alta especificidade (`width`, `min-width`, `max-width` + `!important`) para neutralizar estilo inline que o Shiny injeta em `#<id>_progress`.
  - Remover o "container-chip" em volta da barra (sem borda/fundo no container da progress), deixando o visual somente na `.progress-bar` interna.
  - Reduzir o espacamento entre barra e chips para `0px`, conforme ajuste final solicitado.
- **Alternativas**:
  - Manter progresso dentro da dropzone com posicionamento absoluto: rejeitado por conflito com requisito de produto e por ambiguidade visual.
  - Reimplementar progresso 100% custom (sem barra nativa do Shiny): rejeitado neste ciclo por custo de manutencao e risco de divergir do lifecycle nativo.
  - Aceitar largura automatica da progress sem override: rejeitado, pois estilo inline do Shiny manteve barra curta em cenarios reais.
- **Consequencias**:
  - A barra deixa de competir visualmente com a dropzone e passa a ocupar area propria, previsivel.
  - O componente fica consistente com chips adjacentes em dimensao e alinhamento.
  - Reduz risco de regressao por acoplamento DOM/CSS, com guardrails explicitos.
  - O uso de `!important` fica documentado como excecao tecnica controlada para override de estilo inline.

---

## ADR-042: Redesign da Wiki com toolbar externa e tabela estilizada por callbacks

- **Data**: 2026-02-23
- **Contexto**: A aba `wiki` ainda usava composicao simples de titulo/subtitulo + busca/filtros separados e tabela com estilizacao parcial, ficando abaixo do contrato visual do design-v4 para componentes informativos. Tambem era necessario preservar o padrao arquitetural do app: `DT::datatable` client-side dentro de `.finch-table-shell`, i18n completo e baixo risco de regressao em outros modulos.
- **Decisao**:
  - Reestruturar o topo da Wiki para um card unico (`header_card`) com:
    - eyebrow,
    - titulo com palavra destacada,
    - subtitulo com icone + link,
    - estatisticas dinamicas da base (`termos`, `obrigatorios`, `classes`).
  - Substituir controles fragmentados por uma toolbar unica (`toolbar_card`) contendo:
    - busca externa custom,
    - seletor de quantidade (`Mostrar ... registros`),
    - pills de classe com estado ativo e cores por categoria.
  - Sincronizar toolbar e DataTable via API no callback JS:
    - `table.search(...)`,
    - `table.column(1).search(...)`,
    - `table.page.len(...)`.
  - Aplicar redesign da tabela sem alterar assinatura publica do modulo:
    - `rowCallback` para badges/links/codigo/estado obrigatorio;
    - `headerCallback` para layout de `th` e icone de sort;
    - `dom = "t<'wiki-table-footer'ip>"` para posicionar `info` e paginacao em barra de rodape sem alterar o componente interno de pagina.
  - Escopar todo CSS novo da Wiki em `.wiki-module`/`.wiki-table` para evitar side effects em `preview`, `validate_names` e `validate_coords`.
  - Definir link generico oficial deste ciclo para Wiki: `https://sibbr.gov.br`.
- **Alternativas**:
  - Manter renderizacao padrao do DataTables com `columnDefs/render` minimo - rejeitado por nao atingir o contrato visual completo solicitado.
  - Criar tabela HTML manual fora do DataTables - rejeitado por perder paginacao/ordenação nativa e aumentar custo de manutencao.
  - Aplicar estilos globais de tabela sem escopo local - rejeitado por risco de regressao cross-modulo (contrario ao ADR-030).
- **Consequencias**:
  - Wiki passa a ter linguagem visual equivalente aos componentes premium do app, com melhor escaneabilidade.
  - Fluxo de busca/filtro/quantidade fica consistente e responsivo via API do DataTables.
  - Superficie de i18n aumenta (novas chaves), exigindo manutencao conjunta de testes.
  - Risco de regressao reduzido por escopo CSS local e preservacao de contratos existentes de modulo.

---

## ADR-043: Hotfix de binding da toolbar da Wiki e paginação deterministica

- **Data**: 2026-02-23
- **Contexto**: Apos o ADR-042, foram observadas regressoes na Wiki: busca externa sem atualizar em tempo real, chips de classe sem refletir estado/filtro e seletor `Mostrar` sem aplicar `15` linhas de forma confiavel.
- **Decisao**:
  - Reforcar o callback JS da Wiki com eventos delegados em `document` e namespace por instancia de modulo.
  - Sincronizar filtro por classe via API do DataTables (`column().search`) mantendo estado visual dos chips no mesmo fluxo.
  - Tornar o ajuste de quantidade deterministico com `page.len(len)` e reposicionamento para a primeira pagina (`page('first').draw('page')`).
  - Ajustar acabamento visual do shell da tabela para cantos arredondados continuos (topo e rodape).
- **Alternativas**:
  - Manter binding direto em elementos renderizados por `renderUI` - rejeitado por fragilidade quando o DOM e recriado.
  - Forcar redraw completo sem reposicionamento de pagina - rejeitado por comportamento ambiguo ao trocar `10 -> 15`.
- **Consequencias**:
  - Busca, chips e seletor `Mostrar` voltam a operar de forma previsivel em runtime.
  - Reduz regressao intermitente associada a recriacao de DOM em controles externos.
  - Contrato visual da Wiki permanece consistente com o redesign do ADR-042.
