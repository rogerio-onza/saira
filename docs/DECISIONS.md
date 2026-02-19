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
