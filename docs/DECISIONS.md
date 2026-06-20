# Decisoes de Arquitetura

Registro de decisoes tecnicas significativas do Saira.
Formato: ADR leve (Architecture Decision Record).

---

## ADR-001: Estrutura de pacote R em vez de `global.R`

- **Data**: 2026-02-08
- **Contexto**: Shiny apps convencionais usam `global.R` + `ui.R` + `server.R`. A medida que o Saira cresce em modulos, precisamos de namespace limpo e testabilidade.
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
  - Resolver `i18n_dict` em `tr()` via ambiente/namespace (`asNamespace("saira")`) em vez de leitura por `source()`.
  - Em testes, substituir carregamento por path local de `R/*.R` por `getFromNamespace()` e usar `system.file(..., package = "saira")` para arquivos de dados com fallback de desenvolvimento.
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
- **Contexto**: O mapeamento generico do Saira permite concatenacao de multiplos valores (` | `), mas `basisOfRecord` usa vocabulario controlado e deve refletir apenas uma categoria por registro.
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
  - Extrair o estilo de tabela para uma classe compartilhada: `.saira-table-shell`.
  - Aplicar o wrapper `.saira-table-shell` em todas as tabelas `DT::datatable` do app (`preview`, `validate_names`, `validate_coords`, `wiki`).
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
- **Contexto**: A aba `wiki` ainda usava composicao simples de titulo/subtitulo + busca/filtros separados e tabela com estilizacao parcial, ficando abaixo do contrato visual do design-v4 para componentes informativos. Tambem era necessario preservar o padrao arquitetural do app: `DT::datatable` client-side dentro de `.saira-table-shell`, i18n completo e baixo risco de regressao em outros modulos.
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

---

## ADR-044: Redesign da Help com acordeao custom, sidebar sticky e escopo CSS local

- **Data**: 2026-02-23
- **Contexto**: A aba `help` usava layout simples em coluna unica com `bslib::accordion`, sem estrutura editorial, sem sidebar informativa e com baixo alinhamento ao design v4 aplicado nas abas mais recentes.
- **Decisao**:
  - Migrar a aba para grid de duas colunas (`1fr + 320px`) com wrapper local (`max-width: 1400px`) e quebra responsiva para coluna unica em telas menores.
  - Substituir o cabecalho solto por card de header e mover o campo de busca para card dedicado.
  - Trocar `bslib::accordion` por markup custom (header/body por item) com estados `is-open`, `aria-expanded`, `aria-hidden` e animacao de `max-height`.
  - Definir 4 secoes canonicas da Help:
    - `Darwin Core`
    - `FAQ`
    - `Formatos aceitos`
    - `Separador de multiplos valores`
  - Adicionar script dedicado `www/help-accordion.js` com event delegation no `document` para manter funcionamento apos re-render de `renderUI`.
  - Introduzir sidebar sticky com quatro cards:
    - Autor (metadados atuais do pacote, versao e contatos)
    - Reportar bug (link para GitHub Issues)
    - Links uteis (TDWG/DwC, SiBBr, GBIF, ALA)
    - Construido com (stack base + chips de IA)
  - Escopar todo o CSS novo em `.help-module`/`.help-*` para evitar regressao visual em Wiki/Preview/Validacoes.
- **Alternativas**:
  - Manter `bslib::accordion` e aplicar apenas skin visual - rejeitado por limitar controle de estrutura, animacao e estados de acessibilidade.
  - Reaproveitar classes globais de cards/tabela sem escopo local - rejeitado por aumentar risco de side effects cross-modulo.
  - Implementar sidebar sem comportamento sticky - rejeitado por reduzir utilidade de cards de referencia em telas desktop.
- **Consequencias**:
  - A aba `help` passa a ter paridade visual com o design system v4 e melhor escaneabilidade de conteudo.
  - A camada de i18n cresce com novas chaves de conteudo e acessibilidade, exigindo sincronizacao dos testes no mesmo ciclo.
  - O JS do acordeao fica desacoplado da instancia de modulo e resiliente a rebuild de DOM por `renderUI`.

---

## ADR-045: Alinhamento definitivo da lupa no campo de busca da Help

- **Data**: 2026-02-24
- **Contexto**: O icone de busca da aba `help` apresentava deslocamento horizontal/vertical em runtime e, em alguns cenarios, parecia fora da caixa. A causa foi a combinacao de estilos herdados de `textInput` (Shiny/Bootstrap) com posicionamento absoluto sem contrato geometrico rigido.
- **Decisao**:
  - Fixar contrato estrutural do campo de busca:
    - wrapper imediato `.help-search-input-wrap` com `position: relative`;
    - icone `.help-search-icon` com `position: absolute`, `left: 13px`, `top: 50%`, `transform: translateY(-50%)`, `width/height: 14px`, `line-height: 1`, `display: inline-flex`, `align-items: center`, `justify-content: center`;
    - input com `height: 42px` e `padding-left: 42px` para reservar area do icone.
  - Neutralizar espacamento herdado do stack Shiny/Bootstrap no card de busca:
    - `.help-search-card .shiny-input-container { margin-bottom: 0; }`
    - `.help-search-card .control-label { margin-bottom: 0; }`
- **Alternativas**:
  - Usar `input-group` Bootstrap com prepend de icone - rejeitado por conflitar com o contrato visual custom da Help.
  - Ajustar por tentativa (`margin-top`/`top` fixo) sem caixa fixa do icone - rejeitado por baixa estabilidade entre navegadores e breakpoints.
- **Consequencias**:
  - Alinhamento da lupa passa a ser deterministico e resiliente a variacao de fonte/line-height.
  - Campo de busca fica estavel em PT/EN, desktop e mobile, sem regressao de colisao com placeholder.

---

## ADR-046: Migracao tipografica global para design v5 com tokens e alias de compatibilidade

- **Data**: 2026-02-24
- **Contexto**: O design-v5 introduziu mudanca de tipografia (Cormorant Garamond + Space Mono) mantendo a paleta/camadas visuais do v4. O CSS acumulava hardcodes de `IBM Plex` em blocos locais (`help`, `wiki`, validacoes, preview), o que elevava risco de regressao e inconsistencias ao trocar familias globais.
- **Decisao**:
  - Adotar `Cormorant Garamond` como base serif e `Space Mono` como mono oficial.
  - Carregar Google Fonts v5 explicitamente no `head` de `app_ui`.
  - Em `bs_theme`, usar `font_collection(...)` (sem `font_google` por familia antiga) para alinhar fallback local e evitar acoplamento com import implicito.
  - Remover `@import` legado de IBM no `custom.css` e centralizar tipografia por tokens:
    - `--font-serif: 'Cormorant Garamond', Georgia, serif;`
    - `--font-mono: 'Space Mono', 'IBM Plex Mono', monospace;`
    - `--font-sans: var(--font-serif);` (alias temporario de compatibilidade nesta onda)
  - Eliminar hardcodes de `font-family: "IBM Plex ..."` em componentes locais e substituir por tokens.
  - Preservar guardrails visuais existentes (ADR-040/041/045), sem mexer em geometria, spacing ou wiring dos componentes.
  - Incluir guardrail de legibilidade para diagnosticos compactos de coordenadas (< `0.85rem`) com ajuste tipografico leve (`letter-spacing` + `tabular nums`) sem alterar layout.
- **Alternativas**:
  - Migrar apenas tokens globais e manter hardcodes locais - rejeitado por manter incoerencia visual e custo recorrente de manutencao.
  - Substituir todas as ocorrencias por serif/mono sem alias de compatibilidade - rejeitado por maior risco de regressao transversal nesta onda.
  - Manter `font_google("IBM Plex ...")` no tema e trocar apenas CSS - rejeitado por divergencia entre tema runtime e design system oficial.
- **Consequencias**:
  - Tipografia do app passa a seguir contrato unico e rastreavel por tokens.
  - Reduz regressao futura em refactors de modulo, pois evita familia hardcoded dispersa.
  - Mantem compatibilidade progressiva durante a transicao por alias `--font-sans`.

---

## ADR-047: Layout tri-coluna para `validate_names` com painel de configuracao fixo e relatorio com toolbar externa

- **Data**: 2026-02-24
- **Contexto**: A aba `validate_names` usava composicao `col-lg-6/col-lg-6` com cards fragmentados (`providers`, `options`, `action`, `summary`, `stats`, `results`, `stream`) e alto custo de scroll para alternar entre configuracao, monitoramento e leitura de tabela. O contrato visual alvo exigia: coluna esquerda fixa de configuracao, coluna central de stream em tempo real e coluna direita fixa de relatorio.
- **Decisao**:
  - Refatorar `mod_validate_names_ui()` para shell horizontal unico (`config_panel`, `stream_panel`, `report_panel`), mantendo assinatura publica do modulo e retorno reativo inalterados.
  - Consolidar configuracao em `config_panel`:
    - provedores em cards empilhados com destaque de prioridade 1;
    - toggles de normalizacao;
    - CTA `Validar Nomes`, mini-stats e progresso textual/visual.
  - Manter stream incremental no centro com pills ativas por status e itens semanticos.
  - Migrar tabela para `report_panel` com `DT::datatable` + toolbar externa (busca e `Mostrar N`) sincronizada via callback JS delegado.
  - Isolar estilizacao em namespace local `.vn-*` dentro de `custom.css`, evitando regressao transversal em `validate_coords`, `wiki` e `help`.
- **Alternativas**:
  - Manter grid `6/6` e apenas "skin" visual - rejeitado por nao resolver acoplamento funcional entre configuracao/stream/tabela.
  - Substituir `DT` por tabela HTML manual - rejeitado por perda de ordenacao/paginacao nativas e aumento de custo de manutencao.
  - Reusar classes antigas `validate-names-*` sem namespace novo - rejeitado por risco de colisao CSS com regras legadas.
- **Consequencias**:
  - Fluxo operacional da aba fica mais previsivel: configurar (esquerda), monitorar (centro), auditar (direita).
  - Contrato de API do modulo permanece estavel (sem impacto em `app_server`).
  - Superficie de i18n cresce (novas chaves `validate_names_*`), exigindo atualizacao conjunta de testes.
  - Guardrails visuais passam a exigir larguras fixas dos paines laterais e altura de workspace por viewport tokenizada.

---

## ADR-048: Rename global do pacote e branding para `saira`

- **Data**: 2026-02-24
- **Contexto**: O nome do produto e do pacote precisava migrar do nome anterior para `saira` em toda a base, sem manter camada de compatibilidade legada.
- **Decisao**:
  - Adotar `saira` como identificador tecnico unico do pacote (`DESCRIPTION::Package`, namespace em codigo/testes e comandos de uso).
  - Adotar `Saira` como branding unico em UI, i18n, README e documentacao.
  - Renomear classes e assets com prefixo antigo para `saira-*` (incluindo arquivos de imagem/lottie).
  - Aplicar rename tambem em documentacao historica/versionada dentro do repositorio para eliminar referencias residuais.
- **Alternativas**:
  - Manter aliases de transicao (nome anterior + `saira`) - rejeitado por aumentar custo de manutencao e superficie de erro.
  - Renomear apenas branding visual mantendo pacote no nome anterior - rejeitado por incoerencia tecnica e operacional.
- **Consequencias**:
  - Mudanca e breaking para quem importava o pacote pelo nome anterior diretamente.
  - Menor ambiguidade futura por existir apenas um nome tecnico e de produto.
  - Necessidade de atualizar todos os testes/utilitarios que consultam namespace por string literal.

---

## ADR-049: Hardening de encoding/BOM e startup defensivo nas ondas 1-3

- **Data**: 2026-02-24
- **Contexto**: Havia mistura de encoding/line endings, uso de `options(encoding = "UTF-8")`, detecao de delimitador sem tratamento de BOM e pontos de startup suscetiveis a falha dura.
- **Decisao**:
  - Instituir contrato de arquivo via `.editorconfig` + `.gitattributes` e guia operacional `docs/ENCODING_RULES.md`.
  - Corrigir `DESCRIPTION` com escapes Unicode e padronizar headers de autor em ASCII.
  - Implementar `strip_bom()` e fortalecer `detect_delimiter()` para UTF-8, BOM e primeira linha vazia.
  - Remover `options(encoding = "UTF-8")` de `app.R` e `run_app.R`.
  - Tornar `mod_upload` resiliente a falha em `get_dwc_terms()` com `tryCatch` + fallback tipado.
  - Tornar `app_server` observavel em fallbacks reativos e registrar encerramento de sessao.
  - Consolidar validacao de `force` em `validate_force_flag()` canonica.
  - Inicializar `renv` e versionar `renv.lock`.
- **Alternativas**:
  - Tratar apenas sintoma pontual de encoding - rejeitado por nao enderecar causa raiz.
  - Manter validacoes `force` duplicadas por modulo - rejeitado por risco de drift.
- **Consequencias**:
  - Menor risco de regressao por encoding e BOM em CSV.
  - Startup mais robusto quando artefatos estaticos falham.
  - Melhor observabilidade operacional via logs explicitos.

---

## ADR-050: Ajuste seguro de largura para `validate_names` com tri-coluna preservada

- **Data**: 2026-02-26
- **Contexto**: A aba `validate_names` manteve o contrato tri-coluna do ADR-047, mas o shell com limite de largura fixo e a distribuicao automatica da tabela no painel direito deixavam as 3 colunas do relatorio visualmente espremidas em desktop.
- **Decisao**:
  - Remover limite de largura hardcoded do shell UI de `mod_validate_names_ui()`.
  - Adotar contrato full-width local para `validate_names` no mesmo padrao espacial da aba `validate_coords`:
    - `.validate-names-page { width: 100%; max-width: none; ... }`
    - `.tab-content > .tab-pane:has(.validate-names-page) { padding-left/right: 0; }`
  - Preservar guardrails do ADR-047 sem alteracoes:
    - `--validate-names-header-offset`
    - `.vn-config-panel` com `width: 240px`
    - `.vn-report-panel` com `width: 340px`
  - Tornar a tabela do relatorio mais legivel sem redesign estrutural:
    - largura explicita por coluna (`scientificName` priorizada, `status` compacta, `taxonomicStatus` intermediaria);
    - ajuste de celula para reduzir truncamento agressivo em nome cientifico e permitir quebra controlada em `taxonomicStatus`.
- **Alternativas**:
  - Aumentar largura fixa do painel direito (>340px) - rejeitado por quebrar guardrails visuais vigentes.
  - Migrar para redesign amplo no padrao de coordenadas (left + right) - rejeitado por extrapolar escopo do ajuste seguro.
  - Manter distribuicao automatica de colunas da DataTable - rejeitado por manter baixa legibilidade no painel de 340px.
- **Consequencias**:
  - A aba de nomes passa a aproveitar melhor a largura util da pagina, alinhando comportamento espacial com `validate_coords`.
  - O contrato tri-coluna permanece estavel para CSS/tests e para o restante do app.
- Nao ha mudanca de API publica em R; alteracao restrita a UI/CSS e guardrails.

---

## ADR-051: Revisao manual de nomes problematicos integrada ao export

- **Data**: 2026-02-27
- **Contexto**: A validacao automatica de nomes pode retornar casos nao resolvidos (`not_found`, `ambiguous`, `synonym`) que exigem decisao humana. Reprocessar planilha inteira para cada ajuste manual gera atrito de UX e aumenta risco de inconsistencia entre a aba de validacao e o CSV final.
- **Decisao**:
  - Introduzir revisao manual inline em `validate_names` via modal unico de dois modos (confirmar/editar), sempre iniciado em confirmacao rapida.
  - Tratar revisao como estado reativo central por `query_name`, valendo para todas as ocorrencias do mesmo nome consultado.
  - Considerar "problematicos nao resolvidos" apenas para os tres status canonicos: `not_found`, `ambiguous`, `synonym`.
  - Propagar decisoes para export por payload reativo anexado ao retorno do modulo (`review_export_payload`) sem quebrar o contrato existente de retorno principal (`reactive(data.frame)`).
  - Aplicar payload no fluxo de download da Preview antes do pipeline de export, adicionando sempre as colunas `validacao_manual` e `motivo_revisao`.
- **Alternativas**:
  - Exigir correcao na planilha original + novo upload - rejeitado por UX fraca e ciclo operacional lento.
  - Persistir revisoes em storage externo - rejeitado neste ciclo por custo de infraestrutura e escopo.
  - Implementar modais separados para cada tipo de problema - rejeitado por duplicacao de logica e maior risco de drift visual/funcional.
- **Consequencias**:
  - Fluxo de resolucao de nomes passa a ser end-to-end dentro da UI, sem reload.
  - Export final fica auditavel com metadados explicitos de intervencao manual.
  - Acoplamento entre `validate_names` e `preview` passa a ocorrer por atributo reativo opcional (compativel com fallback nulo).

---

## ADR-052: Alta resolucao de costa para cc_sea e remocao de clustering do Leaflet

- **Data**: 2026-02-27
- **Contexto**: `validate_coords_cc_df` usava `seas_scale = 110` (1:110M, ~10km de imprecisao costeira), causando falsos positivos de "mar" para pontos terrestres proximos da costa. O `markerClusterOptions()` do Leaflet agrupava pontos em circulos numerados quando >=500 pontos, impedindo verificacao visual da posicao real dos pontos flagados.
- **Decisao**:
  - Migrar `seas_scale` default de `110` para `10` (1:10M, ~1km de precisao), usando dados de alta resolucao do pacote `rnaturalearthhires`.
  - Implementar fallback automatico para `scale = 50` quando `rnaturalearthhires` nao esta instalado, via `requireNamespace(..., quietly = TRUE)`.
  - Adicionar `rnaturalearthhires` em `Suggests` no `DESCRIPTION` com `Additional_repositories` apontando para `https://ropensci.r-universe.dev`.
  - Remover `markerClusterOptions()` do Leaflet, renderizando todos os pontos individualmente com raio adaptativo (4px para >2000 pontos, 6px caso contrario).
  - Adicionar chip de alerta visivel (`alert alert-warning`) na legenda do mapa informando que pontos costeiros podem ser flagados incorretamente.
- **Alternativas**:
  - Manter `scale = 110` com disclaimer textual - rejeitado por nao resolver a causa raiz dos falsos positivos.
  - Usar `buffland` (costa com buffer de 1 grau/~111km) - rejeitado por ser excessivamente permissivo, escondendo flags legitimas de mar.
  - Usar `scale = 50` como default fixo - descartado em favor de `scale = 10` com fallback para `50`, aproveitando a maior precisao quando o pacote esta disponivel.
- **Consequencias**:
  - Diagnostico de "mar" fica significativamente mais preciso para pontos costeiros.
  - Pontos no mapa aparecem sempre nas posicoes reais, permitindo verificacao visual direta.
  - `rnaturalearthhires` precisa ser instalado separadamente pois nao esta no CRAN.
  - Performance do mapa pode ser ligeiramente menor para datasets muito grandes (>5000 pontos) sem clustering, mitigado por `preferCanvas` e raio reduzido.

---

## ADR-053: Debounce de idioma e fuzzy matching vetorizado (Onda 4 — Performance Reativa)

- **Data**: 2026-02-28
- **Status**: Aceito
- **Contexto**: A troca de idioma disparava ~385 re-renderizacoes simultaneas sem amortizacao. O fuzzy matching de paises na Layer 5 de `coords_country_to_iso3()` usava loop por item com `adist()` individual, O(n x m) com overhead de chamada de funcao por token.
- **Decisao**:
  - Debounce de 150ms em `lang_r` com bypass na primeira renderizacao via `reactiveVal` flag (`lang_initialized`). Primeira renderizacao imediata para evitar atraso de startup.
  - Substituir loop individual por batch matricial com `adist(all_tokens, ref$alias)`. Sem chunking (memoria trivial para matrizes observadas no uso real).
  - Envolver bloco batch em `tryCatch` para resiliencia a encoding corrompido — se `adist` falhar, loga e pula em vez de crashar todo o batch.
  - `normalize_country_token`: `iconv(from = "UTF-8")` explicito em vez de `from = ""` (dependente de locale do OS).
  - Todas as regras de desambiguacao preservadas: `best_dist`, `max_dist = max(1, floor(nchar/4))`, melhor unico, margem para segundo melhor.
- **Alternativas**:
  - Debounce cego sem bypass de startup — rejeitado por causar delay visivel na primeira renderizacao.
  - Chunking com `chunk_size = 2000` — omitido por complexidade desnecessaria; pode ser adicionado se benchmark futuro justificar.
  - `vapply` para normalizar tokens — rejeitado por `normalize_country_token` ja ser vetorizado internamente.
- **Criterios de aceite**:
  - Todos os testes existentes + novos passam.
  - Saida de `coords_country_to_iso3` identica para dataset de referencia (teste de snapshot).
  - Ganho minimo de 30% no cenario "nao-reconhecidos em massa" vs baseline.
- **Consequencias**:
  - Performance de UI melhora em troca de idioma.
  - Throughput de fuzzy matching melhora em datasets com muitos paises nao-reconhecidos.
  - Resiliencia a encoding corrompido em fuzzy batch.

---

## ADR-054: Contrato de retorno `list()` para `mod_mapping_server` (Onda 5)

- **Data**: 2026-02-28
- **Status**: Aceito
- **Contexto**: `mod_mapping_server()` retornava `reactive(data.frame)` com canais auxiliares injetados via `attr()` (`preview_data`, `validation_gate`, `validation_gate_coords`). Esse padrao dificultava a descoberta de API, nao era auto-documentado e dependia de convencao implicita entre produtor e consumidor.
- **Decisao**:
  - Substituir `attr()` por retorno explicito como `list()` nomeada com 4 slots:
    - `processed_data_r`: reactive com data.frame DwC completo
    - `preview_data_r`: reactive com data.frame das primeiras 100 linhas (IDs dummy)
    - `validation_gate_r`: reactive com status de mapeamento para `scientificName`
    - `validation_gate_coords_r`: reactive com status de mapeamento para `decimalLatitude`/`decimalLongitude`/`country`
  - `app_server.R` consome via `$` (ex: `mapping_result$processed_data_r`) com fallback defensivo para cada slot.
  - `attr()` em `mod_validate_names_server` (`review_export_payload`) permanece inalterado nesta onda como divida tecnica explicita.
  - Futuros canais adicionais: basta adicionar novo slot na lista sem breaking change.
- **Alternativas**:
  - Manter `attr()` e documentar convencao - rejeitado por baixa visibilidade e risco de regressao silenciosa.
  - Retornar `R6` ou `environment` tipado - rejeitado por complexidade desnecessaria neste estagio.
- **Consequencias**:
  - API de `mod_mapping_server` passa a ser auto-documentada e verificavel com `expect_named()`.
  - Consumidores sao atualizados no mesmo ciclo: `app_server.R`, `test-mod-mapping-server.R`.
  - Testes aumentaram de 2604 para 2605 (+1 assertion de estrutura).
  - Divida tecnica: `attr("review_export_payload")` em `validate_names` sera migrado em onda futura.

---

## ADR-055: CSS Modular com Build Deterministico (Onda 5)

- **Data**: 2026-02-28
- **Status**: Aceito
- **Contexto**: `custom.css` monolitico com 6243 linhas dificultava manutencao, code review e isolamento de estilos por modulo. Alteracoes em um dominio (ex.: upload) arriscavam regressao em outro (ex.: wiki).
- **Decisao**:
  - Dividir `custom.css` em 17 modulos ordenados por dominio (`inst/app/www/css/00-tokens.css` a `16-help.css`).
  - Manter `custom.css` como artefato gerado por `data-raw/build_css.R` com header `/* GENERATED FILE */`.
  - Guardrails automatizados: teste verifica header de artefato gerado e completude (todo modulo em `css/` deve estar no bundle).
  - Ordem dos modulos respeita cascata CSS original (tokens -> base -> componentes -> modulos -> overrides).
- **Alternativas**:
  - CSS-in-JS ou sass/less — rejeitado por complexidade desnecessaria em app Shiny.
  - Multiplos `<link>` tags sem bundle — rejeitado por aumento de requests HTTP e risco de ordem incorreta.
- **Consequencias**:
  - Editar estilo de um modulo nao afeta outros arquivos.
  - `data-raw/build_css.R` deve ser executado apos editar qualquer modulo CSS.
  - Visual identico ao monolitico original (verificado por contagem de linhas: 6234 modulos + 1 header = 6235 bundle).

---

## ADR-056: Dicionario i18n Externalizado em JSON (Onda 5)

- **Data**: 2026-02-28
- **Status**: Aceito
- **Contexto**: `data_dictionary.R` continha 1810 linhas de lista R inline com todas as traducoes. Dificil de editar, propenso a erros de encoding, e impossivel de consumir por ferramentas externas.
- **Decisao**:
  - Externalizar dicionario para `inst/extdata/i18n.json` (601 chaves, formato `{ "key": { "pt": "...", "en": "..." } }`).
  - `data_dictionary.R` reescrito como loader com cache in-process (padrao ADR-014).
  - BOM removal inline (`sub("^\uFEFF", "", raw)`) em vez de `strip_bom()` para evitar dependencia de load order.
  - JSON gerado por `data-raw/export_i18n.R` (one-shot, nao parte do build regular).
  - Contrato preservado: `i18n_dict` disponivel no namespace do pacote, consumido por `tr()` via `resolve_i18n_dict()`.
- **Alternativas**:
  - YAML — rejeitado por dependencia adicional e parsing mais lento.
  - CSV/TSV — rejeitado por dificuldade com caracteres especiais e multiline.
  - Manter inline R — rejeitado por todos os problemas listados no contexto.
- **Consequencias**:
  - `data_dictionary.R` reduzido de 1810 para 61 linhas.
  - Traducoes editaveis em qualquer editor JSON.
  - Requer `jsonlite` em Imports (ja era dependencia do pacote).
  - Cache in-process evita releitura do disco a cada chamada a `tr()`.

---

## ADR-057: E2E isolado por env var `RUN_E2E=true`

- **Data**: 2026-03-01
- **Contexto**: E2E com `shinytest2` e custoso (Chromium + startup do app) e instavel em R CMD check por dependencia de `app_dir`. Tambem rodava durante `devtools::test()` quando `shinytest2` estava instalado.
- **Decisao**:
  - Adicionar gate `RUN_E2E=true` em `tests/testthat/test-e2e-flows.R`.
  - Trocar `AppDriver$new(app_dir = ...)` por `AppDriver$new(app = shiny::shinyApp(app_ui(), app_server))`.
  - Ativar o gate em `scripts/release_gate.R` via `Sys.setenv("RUN_E2E" = "true")` antes da etapa E2E e `Sys.unsetenv("RUN_E2E")` em seguida.
- **Alternativas rejeitadas**:
  - `withr::with_envvar` (exige pacote nao declarado).
  - Mover E2E para diretorio separado (piora ergonomia de filtro com `devtools::test()`).
- **Consequencias**:
  - E2E roda uma unica vez via `Rscript scripts/release_gate.R`.
  - `devtools::test()` passa a pular E2E com mensagem informativa por padrao.
  - Menor variabilidade de caminho de app em ambientes de check e CI.

---

## ADR-058: Error boundary por stage no pipeline Rostrum

- **Data**: 2026-03-01
- **Status**: Aceito
- **Contexto**: O pipeline Rostrum evolui para 3 stages. Falha em um stage nao pode descartar resultados validos dos anteriores.
- **Decisao**:
  - Adotar contrato de retorno por stage:
    - `list(success, data, warnings, errors, timing_ms)`.
  - O orquestrador deve degradar com recuperacao parcial:
    - Stage 1 falha -> retorna vazio.
    - Stage 2 falha -> preserva Stage 1.
    - Stage 3 falha -> preserva Stage 1 + Stage 2.
- **Alternativas**:
  - `tryCatch` unico no pipeline inteiro - rejeitado por perder granularidade e observabilidade.
- **Consequencias**:
  - Falhas deixam de causar perda total de resultado.
  - Contrato do motor fica testavel por stage.

---

## ADR-059: Sampling deterministico no scoring

- **Data**: 2026-03-01
- **Status**: Aceito
- **Contexto**: `sample()` sem seed fixo gera flutuacao de score entre execucoes com a mesma entrada.
- **Decisao**:
  - Derivar seed por conteudo da coluna com `digest::digest2int(...)`.
  - Executar amostragem dentro de `withr::with_seed(seed, ...)`.
- **Alternativas**:
  - Seed global fixa por sessao - rejeitado por acoplamento entre colunas e risco de efeito colateral.
  - Remover aleatoriedade sem amostragem - rejeitado por custo em colunas muito grandes.
- **Consequencias**:
  - Mesma entrada gera mesma amostragem e mesmo score.
  - Golden tests de scoring ficam estaveis.

---

## ADR-060: Migracoes SQLite transacionais com `BEGIN IMMEDIATE`

- **Data**: 2026-03-01
- **Status**: Aceito
- **Contexto**: Em ambiente multi-usuario (ex.: Shiny Server), migracoes sem lock de escrita podem sofrer race condition e estado parcial.
- **Decisao**:
  - Toda migracao roda em transacao explicita com `BEGIN IMMEDIATE`.
  - Em falha, `ROLLBACK` obrigatorio.
  - `schema_version` controla versoes aplicadas de forma idempotente.
- **Alternativas**:
  - Migracao sem transacao - rejeitado por risco de schema parcial.
  - `busy_timeout` isolado sem lock explicito - rejeitado por nao resolver corrida logica.
- **Consequencias**:
  - Mid-failure nao deixa rastros de schema incompleto.
  - Evolucao de schema fica auditavel e reproduzivel.

---

## ADR-061: Evolucao controlada de sinonimos V1 para V2

- **Data**: 2026-03-01
- **Status**: Aceito
- **Contexto**: V1 usa schema `term/synonym/name_score/lang/active`; V2 SQLite usa `confidence/language/context/...` e nao aceita `lang = any`.
- **Decisao**:
  - Introduzir adaptador explicito `adapt_synonyms_v1_to_v2()`.
  - Mapeamentos obrigatorios:
    - `lang = any` -> `language = mul`.
    - `name_score` -> `confidence` (preserva range original).
    - Defaults:
      - `context = "unknown"`,
      - `validation_regex = NA`,
      - `notes = "Migrated from v1 RDS"`.
- **Alternativas**:
  - Migracao implicita inline no loader - rejeitado por baixa rastreabilidade.
  - Rejeitar payload V1 - rejeitado por quebrar retrocompatibilidade na transicao.
- **Consequencias**:
  - Caminho de migracao fica explicito e testavel.
  - V1 e V2 coexistem durante a janela de transicao.

---

## ADR-062: Onda 3 do Rostrum com composicao segura e fallback pos-conflito

- **Data**: 2026-03-02
- **Status**: Aceito
- **Contexto**: O Stage 2 do Rostrum estava como no-op e nao entregava composicao de termos. O plano exigia composicao de `scientificName` e `eventDate` com guard de circularidade e preservacao de override manual. Tambem era necessario aplicar fallback `verbatim*` apenas apos resolucao de conflito.
- **Decisao**:
  - Implementar composicao de `scientificName` no Stage 2 usando `genus + specificEpithet` (com suporte opcional a `infraspecificEpithet` e `scientificNameAuthorship`) apenas quando:
    - `scientificName` nao estiver mapeado no Stage 1;
    - nao houver override manual para `scientificName`.
  - Implementar guard explicito de circularidade com trilha `composed_from`: um termo composto nao pode virar insumo de composicao que dependa dele direta ou indiretamente.
  - Implementar composicao de `eventDate` no Stage 2 com ISO estrito e validacao de calendario:
    - formatos suportados: `YYYY`, `YYYY-MM`, `YYYY-MM-DD`;
    - datas invalidas (mes/dia fora de faixa, combinacoes invalidas, leap year invalido) sao rejeitadas no caminho automatico.
  - Mover fallback para `verbatim*` para depois do Stage 3 (Stage 3.5), com regra conservadora:
    - `decimalLatitude -> verbatimLatitude`;
    - `decimalLongitude -> verbatimLongitude`;
    - `eventDate -> verbatimEventDate`;
    - apenas com score elegivel e sem sobrescrever alvo ja ocupado.
  - Vetorizar `build_eventdate_interval()` em `utils_mapping` para reduzir custo de loop row-by-row em bases grandes.
- **Alternativas**:
  - Manter Stage 2 como passthrough - rejeitado por nao cumprir contrato da Onda 3.
  - Permitir composicao mesmo com override manual - rejeitado por risco de sobrescrever decisao humana.
  - Aplicar fallback `verbatim*` durante Stage 3 - rejeitado por interferir na resolucao principal de conflitos.
- **Consequencias**:
  - Stage 2 passa a contribuir com sugestoes compositas explicaveis, mantendo politica conservadora.
  - Circularidade entre regras de composicao deixa de ser possivel por contrato.
  - `eventDate` composto fica mais previsivel e aderente a ISO, incluindo leap year.
  - Fallback `verbatim*` preserva informacao sem roubar mapeamento principal.

---

## ADR-063: Schema canonico de composition_df como augmentacao do stage data

- **Data**: 2026-03-02
- **Status**: Aceito
- **Contexto**: O plano original definia `composition_df` como contrato separado com colunas `term, inputs_json, output_preview, status, reason_code`. A implementacao da Onda 3 optou por augmentar o stage data existente com a coluna `composed_from_json` (JSON array dos termos fonte), armazenando o preview dentro de `explain_json` ja existente. Essa abordagem divergiu do plano e precisava de decisao explicita.
- **Decisao**:
  - O schema canonico de composicao e o stage data augmentado, com as colunas obrigatorias: `term`, `selected_col`, `status`, `reason`, `applied`, `composed_from_json`.
  - Nao ha `composition_df` como artefato separado; a composicao e inline com os resultados de Stage 1/2.
  - `validate_composition_df()` valida esse schema augmentado (nao o schema do plano original).
  - `composed_from_json` eh `NA_character_` para termos nao-compostos (retrocompativel com Stage 1).
  - Composicao parcial (`composed_eventdate_partial`) com `applied = TRUE` e design intencional: quando apenas o `year` esta disponivel, o mapeamento eh direto (relabeling da coluna), sem valor sintetico, portanto auto-aplicavel.
  - Composicao total (`composed_scientific_name`, `composed_eventdate_ymd`) produz valor sintetico sem coluna fonte direta, portanto `applied = FALSE` (requer confirmacao do usuario).
- **Alternativas**:
  - `composition_df` separado conforme plano original -- rejeitado porque duplicaria dados ja no stage data e criaria sincronizacao de estado entre duas estruturas.
- **Consequencias**:
  - `validate_composition_df()` em `R/utils_rostrum_contracts.R` valida o schema real.
  - Testes de contrato cobrem tipos, status enum e colunas obrigatorias.
  - O plano original e atualizado nesta nota como decisao consciente.

---

## ADR-064: Stage 3 com resolvedor multicriterio deterministico

- **Data**: 2026-03-02
- **Status**: Aceito
- **Contexto**: O Stage 3 estava como placeholder (apenas fallback para `verbatim*`), sem resolver conflitos reais entre candidatos e sem garantia de determinismo em empates tecnicos.
- **Decisao**:
  - Implementar rank multicriterio por candidato no Stage 3 com a ordem:
    - `final_score` desc,
    - `value_score` desc,
    - aderencia de tipo (`numeric` vs `text`) desc,
    - completude desc,
    - especificidade desc,
    - `exact_hits` desc,
    - `substring_hits` asc,
    - desempate alfabetico final.
  - Aplicar ambiguidade legitima com comparacao float-safe:
    - `abs(top1 - top2) < (ambiguity_gap - sqrt(eps))`.
  - Resolver conflitos cross-term com o mesmo criterio e desempate final por nome do termo para reproduzibilidade.
  - Introduzir fallback de perdedor para termo relacionado `verbatim*` apenas com guard:
    - `score >= suggest_threshold`,
    - alvo ainda livre.
- **Alternativas**:
  - Manter `run_automap_v1()` como unico resolvedor de conflito - rejeitado por limitar o Stage 3 a passthrough.
  - Resolver conflitos por ordem de iteracao do data.frame - rejeitado por nao-determinismo.
- **Consequencias**:
  - Stage 3 passa a ser funcional e testavel de ponta a ponta.
  - Conflitos passam a ter rastreabilidade explicita (`conflict_won`, `conflict_lost`, `ambiguity_detected`).
  - Fallback de perdedores preserva informacao sem sobrescrever mapeamento existente.

---

## ADR-065: Aprendizado local de aliases com precedencia por escopo e auditoria

- **Data**: 2026-03-02
- **Status**: Aceito
- **Contexto**: O schema SQLite de aliases existia, mas faltava camada funcional para escrita transacional, lookup com precedencia e trilha auditavel de eventos por sessao.
- **Decisao**:
  - Implementar API de aliases em `R/utils_rostrum_db.R`:
    - `rostrum_upsert_alias()`,
    - `rostrum_record_alias_confirmation()`,
    - `rostrum_record_alias_override()`,
    - `rostrum_lookup_alias()`/`rostrum_lookup_alias_for_term()`,
    - `rostrum_deprecate_alias()`,
    - `undo_session_aliases()`.
  - Todas as writes de aliases usam transacao explicita com `BEGIN IMMEDIATE`.
  - Lookup aplica precedencia de escopo:
    - `personal > institution > public`,
    - sempre ignorando `deprecated = 1`.
  - Cada mudanca escreve evento em `rostrum_alias_events` com `run_id` para auditoria e batch undo.
  - `run_rostrum_engine(..., conn=...)` aplica overrides de alias no Stage 1 antes de Stage 2/3.
- **Alternativas**:
  - Persistir aliases fora do SQLite (CSV local) - rejeitado por perder transacao e indice de consulta.
  - Aplicar alias apenas na UI (`mod_mapping`) - rejeitado por acoplamento e baixa testabilidade.
- **Consequencias**:
  - Aprendizado local passa a ser persistente entre sessoes.
  - Alias deprecado deixa de afetar novas execucoes sem perda de historico.
  - Rollback por sessao fica operacional via `undo_session_aliases(conn, run_id)`.

---

## ADR-066: Templates V3 com schema JSON versionado e prioridade sobre heuristica

- **Data**: 2026-03-02
- **Status**: Aceito
- **Contexto**: Templates de mapeamento precisavam de um contrato serializado que suportasse versionamento, escopo de instituicao, validacao offline e override de heuristica de Stage 1-3.
- **Decisao**:
  - Templates armazenados como JSON com `schema_version`, `app_min_version` e `app_max_version`.
  - Validacao via `rostrum_validate_template_payload()` rejeita payloads com `app_min_version` acima da versao do app atual.
  - `app_max_version` abaixo da versao atual gera `warning` sem bloquear importacao.
  - Importacao via `rostrum_import_template_json()` persiste em `rostrum_templates` + `rostrum_template_items` no SQLite.
  - Catalogo consultavel via `rostrum_list_template_catalog()` com filtro por `scope`, `institution_id` e `use_case`.
  - Engine aplica template como override de mais alta prioridade (antes de Stage 2/3) quando `context$template_id` estiver preenchido.
  - Status resultante de itens aplicados via template: `"TEMPLATE"` com reason `"template_priority_override"`.
  - Conflito detectado (heuristica sugeria coluna diferente) e logado como `"conflict override"` em `res$warnings`.
- **Alternativas**:
  - Templates como RDS binario - rejeitado por portabilidade e falta de versionamento semantico.
  - Templates apenas na UI sem persistencia - rejeitado por perda de conhecimento entre sessoes.
- **Consequencias**:
  - Templates reutilizaveis entre usuarios de mesma instituicao via import/export de JSON.
  - Versionamento explicito previne aplicacao de template obsoleto (> `app_max_version`).
  - Catalogo filtrado permite UI de selecao de template sem carregar todos os itens.

---

## ADR-067: Hardening do Rostrum Engine com debug mode, timing e paralelizacao opcional

- **Data**: 2026-03-02
- **Status**: Aceito
- **Contexto**: O motor Rostrum precisava de instrumentacao para diagnostico em producao, paralelizacao segura para datasets grandes e remocao do legacy `run_automap_v1`.
- **Decisao**:
  - `rostrum_options(debug = TRUE)` emite logs de timing por stage em `message()`.
  - Timing por stage registrado em `$timing_ms` de cada resultado de stage.
  - Paralelizacao de Stage 1 via `future`/`furrr` quando `options$stage1_parallel = TRUE`, com fallback gracioso se pacotes nao estiverem instalados.
  - `run_automap_v1()` e o toggle `enable_automap_v1` foram removidos definitivamente.
  - `adapt_synonyms_v1_to_v2()` mantido como adaptador de compatibilidade para migracao de RDS legados.
  - Suite de performance regressiva com limiares explicitos: Stage 1 < 7.5s, Stage 2 < 2s, Stage 3 < 0.5s, pipeline completo < 8s para 20k x 50 colunas.
- **Alternativas**:
  - Manter `run_automap_v1` com flag de deprecacao - rejeitado por risco de uso acidental e custo de manutencao dupla.
  - Paralelizacao obrigatoria - rejeitado por dependencia de `future`/`furrr` em `Imports`.
- **Consequencias**:
  - Diagnostico de performance em producao via `debug = TRUE` sem overhead em modo normal.
  - Paralelizacao disponivel como opt-in sem aumentar grafo de dependencias obrigatorias.
  - Breaking change documentada: `run_automap_v1` nao existe mais.

---

## ADR-068: Remocao do `lang_es` e chaves `.1` do i18n.json

- **Data**: 2026-03-03
- **Status**: Aceito
- **Contexto**: O `i18n.json` continha 10 chaves com sufixo `.1` (duplicatas exatas) e a chave `lang_es` para espanhol, idioma que nao esta implementado no app.
- **Decisao**:
  - Remover as 10 chaves `validate_coords_*.1` — copias identicas das versoes sem sufixo.
  - Remover `lang_es` — espanhol nao tem suporte ativo e a chave nao e usada no codigo.
  - Idiomas suportados sao exatamente `["pt", "en"]`.
  - Espanhol pode ser reintroduzido futuramente como onda separada com todas as traducoes completas e validacao de cobertura.
- **Consequencias**:
  - JSON limpo, sem duplicatas.
  - Testes de regressao podem validar exatamente 2 idiomas por chave.
  - Adicao futura de espanhol requer ADR explicito e cobertura completa de traducoes.

---

## ADR-070: verbose = TRUE hardcoded nas chamadas a get_faunabr / get_florabr

- **Data**: 2026-03-05
- **Status**: Aceito
- **Contexto**: `brprovider_download_data()` repassa seu parametro `verbose` diretamente para `faunabr::get_faunabr()` e `florabr::get_florabr()`. Ambos os pacotes condicionam o bloco de download (`httr::GET`) a `if (verbose)`, deixando o `utils::unzip()` executar incondicionalmente logo apos. Com `verbose = FALSE` (padrao na chamada de `utils_taxadb.R`), o zip nunca e baixado, o unzip falha com "error 1 in extracting from zip file" e o pipeline aborta com "cannot open the connection". O servidor remoto e o arquivo zip estavam integros (validado em 05/03/2026, v=1.48).
- **Decisao**: Forcar `verbose = TRUE` nas chamadas internas a `get_faunabr()` e `get_florabr()` dentro de `brprovider_download_data()`. O `verbose` do wrapper continua controlando mensagens do proprio saira; o `verbose` interno dos pacotes controla se o download acontece — sao responsabilidades distintas.
- **Alternativas rejeitadas**:
  - Passar `verbose = verbose` (comportamento original): falha silenciosa quando chamado com `verbose = FALSE`.
  - Reportar apenas upstream e aguardar fix no pacote: risco de regressao indefinido, pois o bug esta no faunabr/florabr e nao ha prazo para correcao.
- **Consequencias**: Download sempre ocorre independentemente da verbosidade do saira. A saida de progress do pacote externo fica visivel no console durante o download unico (comportamento aceitavel, pois e operacao one-shot que salva RDS).

---

## ADR-069: Auditoria CRAN — remocao de `Remotes:`, `<<-` e `getFromNamespace`

- **Data**: 2026-03-03
- **Status**: Aceito
- **Contexto**: Antes de submissao ao CRAN, auditoria identificou bloqueadores: `Remotes:` no DESCRIPTION, `<<-` em handlers de error, acesso privado a namespace externo e `getFromNamespace` em testes.
- **Decisao**:
  - Remover `Remotes: ropensci/rnaturalearthhires`. Pacote mantido em `Imports` por necessidade funcional; `Additional_repositories` preservado.
  - Substituir `<<-` em tryCatch handlers pelo padrao `tryCatch(fn(), error = function(e) e)` + `inherits(result, "error")`.
  - Substituir `get(fn, envir = asNamespace("CoordinateCleaner"))` por `switch()` explicito com `CoordinateCleaner::cc_*`.
  - Substituir `getFromNamespace("fn", "saira")` em testes por `saira:::fn` (internos) ou chamada direta (exportados).
  - `pkgload::load_all()` em `app.R` tornado condicional com `requireNamespace` + `!isNamespaceLoaded`.
  - Centralizar `@importFrom` em `R/saira-package.R` e adicionar `@export` + roxygen completo as funcoes publicas do Rostrum.
- **Consequencias**:
  - `devtools::check(cran = TRUE)` passa sem ERRORs nos bloqueadores identificados.
  - API publica do Rostrum documentada e acessivel via `saira::fn`.
  - Testes mais claros: acesso intencional a internos via `:::` e acesso a publicos diretamente.

---

## ADR-071: Cache persistente `.rds` por provider BR com update automatico em background

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: O fluxo antigo de provedores BR era sensivel a falhas temporarias de rede/servidor e nao separava claramente bootstrap inicial de refresh de versao. Para o usuario final, isso gerava latencia desnecessaria e risco de interrupcao de validacao em cenarios onde um cache local valido ja existia.
- **Decisao**:
  - Consolidar o contrato de cache em disco por provider com:
    - artefato principal `<provider>.rds`;
    - metadata `<provider>.meta.json` (`local_version`, `remote_version_last_seen`, `last_checked_at`, `last_updated_at`, `status`, `last_error`, `retry_after_at`);
    - lock `<provider>.update.lock` para evitar download concorrente.
  - Introduzir `brprovider_ensure_data(provider_id)`:
    - sem cache: bootstrap sincrono obrigatorio;
    - com cache: retorno imediato e disparo opcional de update em background quando TTL expirar.
  - Executar atualizacao em worker assincrono (`future`) e finalizar por polling (`brprovider_poll_updates()`), sem bloquear o ciclo de validacao.
  - Garantir escrita atomica de cache (`.tmp` + validacao + rename) com backup (`.rds.bak`) e preservacao do cache anterior em falhas.
  - Integrar status de runtime ao UI (`up_to_date`, `update_in_progress`, `update_failed`, `never_downloaded`) com badges/notificacoes nao bloqueantes.
- **Alternativas rejeitadas**:
  - Download sincrono sempre no inicio de cada validacao: rejeitado por piorar UX e aumentar dependencia de rede.
  - Atualizacao apenas manual por versao pinada: rejeitado por elevar custo operacional e risco de desatualizacao prolongada.
  - Cache sem metadata de status/versao: rejeitado por baixa observabilidade e dificuldade de diagnostico.
- **Consequencias**:
  - Validacao prioriza continuidade com cache local mesmo em cenarios offline/intermitentes.
  - Atualizacoes de versao passam a ser oportunistas e desacopladas da acao principal do usuario.
  - A superficie de estado aumenta (metadata/lock/jobs), exigindo testes especificos de concorrencia, rollback e retry/backoff.

---

## ADR-073: `update_failed` com cache disponivel deve ser revertido para `up_to_date`

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: `brprovider_cache_status()` ja possuia logica para reverter `never_downloaded → up_to_date` quando `has_data = TRUE`. Porem nao havia bloco equivalente para `update_failed → up_to_date`. Como resultado, uma falha de atualização em background (rede/timeout) deixava o badge de status do provider travado em "Update failed" indefinidamente, mesmo com o cache local integro e a validacao retornando resultados corretamente.
- **Decisao**:
  - Adicionar em `brprovider_cache_status()` o bloco `if (has_data && status == "update_failed") { status <- "up_to_date" }` logo apos a regra existente para `never_downloaded`.
  - Manter `last_error` intacto para diagnostico; apenas o campo `status` operacional e revertido.
  - O status `update_failed` continua valido e persistente quando `!has_data` (falha de bootstrap sem cache).
- **Alternativas rejeitadas**:
  - Manter o `update_failed` e adicionar uma quarta variante visual ("cache ok, update falhou"): rejeitada por adicionar estado que o usuario nao consegue diferenciar operacionalmente de "up_to_date" na pratica.
  - Limpar tambem `last_error` ao reverter: rejeitada para preservar rastreabilidade de falhas intermediarias.
- **Consequencias**:
  - Badge exibe "Atualizado" (ou equivalente no idioma) apos qualquer validacao bem-sucedida, independente de falhas anteriores de refresh.
  - Comportamento simetrico com a regra `never_downloaded → up_to_date` ja existente.
  - Teste "poll_updates marks update_failed and preserves cache" atualizado para refletir nova semantica.

## ADR-074: Textos de badge de provider e notificacoes de background devem usar tr()

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: `provider_runtime_badge()` em `mod_validate_names.R` e as notificacoes `showNotification` de conclusao de update em background usavam strings hardcoded em ingles ("Up to date", "Updating...", "Update failed", "Not downloaded", "data updated", "background update failed"), violando o contrato i18n do sistema (`LESSONS.md`: "Todo texto visivel deve passar por tr()").
- **Decisao**:
  - Migrar os quatro labels de badge para chaves `validate_names_provider_status_{up_to_date|updating|update_failed|not_downloaded}` no `i18n.json`.
  - Migrar as duas frases de notificacao para chaves `validate_names_provider_notify_{updated|update_failed}` com formato `sprintf` para interpolar `label_chr` e `suffix`.
  - `provider_runtime_badge()` acessa `lang_r()` via closure do escopo de `mod_validate_names_server`.
- **Alternativas rejeitadas**:
  - Manter ingles com comentario de TODO: rejeitada porque viola regra existente ja codificada em LESSONS e em testes de cobertura de i18n.
- **Consequencias**:
  - 6 novas chaves adicionadas ao `i18n.json` com versoes PT/EN.
  - Suite `test-utils-i18n.R` atualizada para exigir e resolver as novas chaves.
  - Notificacoes de background tambem localizadas.

## ADR-072: Provedores BR so encerram nomes `accepted`; demais casos seguem para confirmacao no GBIF

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: A cascata taxonomica original (ADR-024) parava no primeiro provedor que retornava qualquer veredito (`accepted`, `synonym` ou `ambiguous`). Com a introducao de `florabr`/`faunabr` como camada prioritaria para taxa brasileiros, isso passou a interromper cedo demais a automacao: nomes `synonym` ou `ambiguous` no BR apareciam como problematicos na UI, mas nao eram mais enviados ao `GBIF` para tentativa de confirmacao.
- **Decisao**:
  - Manter `florabr`/`faunabr` como primeira camada da cascata.
  - Tratar apenas `accepted` vindo de provedor BR como short-circuit final.
  - Fazer `synonym`, `ambiguous` e `not_found` vindos do BR seguirem para o `GBIF`.
  - Na consolidacao final, preservar por `query_name` o resultado mais informativo disponivel:
    - um veredito posterior do `GBIF` pode substituir um resultado BR menos conclusivo;
    - um `not_found` tardio do fallback nao deve apagar um `synonym`/`ambiguous` anterior do BR.
- **Alternativas rejeitadas**:
  - Manter a regra antiga do "primeiro veredito vence" tambem para provedores BR: rejeitada por desperdiçar a etapa de confirmacao no `GBIF` exatamente nos casos mais problematicos.
  - Fazer o `GBIF` sempre sobrescrever o BR, inclusive com `not_found`: rejeitada por perder informacao util ja encontrada nas bases BR.
- **Consequencias**:
  - O fluxo fica alinhado a regra de negocio "BR primeiro, `GBIF` como confirmacao quando o BR nao aceita o nome".
  - A UI continua mostrando o melhor achado disponivel por nome, sem regressao para `not_found` apos o fallback.
  - A ADR-024 passa a valer com esta excecao explicita para a camada BR + fallback `GBIF`.

---

## ADR-075: Texto estatico de fallback em titulos de nav para eliminar flash de branco no carregamento

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: Os 8 titulos das abas de navegacao usavam exclusivamente `uiOutput()` + `renderUI()` no servidor. O elemento HTML existia no carregamento inicial, mas ficava vazio ate o servidor Shiny processar os blocos reativos e enviar o conteudo via WebSocket. O usuario via abas sem texto por ~200-500ms antes de qualquer interacao.
- **Decisao**:
  - Cada titulo de aba passa a incluir dois spans filhos dentro de um `.nav-title-container`:
    - `.nav-title-static`: texto traduzido estaticamente via `tr(key, "pt")` no momento do build da UI -- visivel imediatamente, sem round-trip.
    - `.nav-title-dynamic`: o `uiOutput` original, agora com `class = "nav-title-dynamic"`.
  - CSS com `:has(.nav-title-dynamic:not(:empty))` esconde o `.nav-title-static` assim que o servidor popula o span dinamico.
  - O switch de idioma continua funcionando normalmente: o servidor ainda envia atualizacoes via `renderUI`, que sobrescreve o conteudo do span dinamico e aciona a regra CSS.
- **Alternativas rejeitadas**:
  - Remover o ingles e usar texto 100% estatico: resolveria o problema na raiz, mas eliminaria o suporte a idioma sem aprovacao de produto.
  - `session$sendCustomMessage` para atualizar texto via JS: funcional, mas adiciona acoplamento JS desnecessario para um problema resolvel em CSS.
  - `outputOptions(session, ..., suspendWhenHidden = FALSE)`: nao resolve o estado inicial vazio; apenas controla quando o calculo e suspenso.
- **Consequencias**:
  - Titulos de nav aparecem imediatamente no carregamento inicial, sem flash de branco.
  - CSS `:has()` e suportado em todos os browsers modernos (Chrome 105+, Firefox 121+, Safari 15.4+).
  - Sem breaking change no comportamento de switch de idioma.
  - Cada titulo agora chama `tr()` adicionalmente no momento do build da UI (custo minimo, dicionario ja em cache).

---

## ADR-073: Substituicao de seed-if-empty por sync continua de bundle de sinonimos

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: `rostrum_seed_synonyms_if_empty` era idempotente — apos o primeiro seed, nunca mais atualizava o banco com novos sinonimos bundlados. Isso impedia que evolucoes do `dwc_synonyms_v1.rds` chegassem a instancias ja inicializadas sem resetar o SQLite. Com o enriquecimento do bundle (29 → 146 entradas), era necessario um mecanismo que reconciliasse o estado do banco sem afetar aliases aprendidos manualmente.
- **Decisao**:
  - Introduzir `rostrum_sync_synonyms(conn, path = NULL)` (interno, nao exportado) em `utils_rostrum_db.R`.
  - A funcao reconcilia apenas `source = "v1_rds"` dentro de `BEGIN IMMEDIATE`: INSERT novos, UPDATE confidence alterada, SET `active = 0` para removidos. Nunca toca em `rostrum_aliases` nem em outras fontes.
  - Hash-gating por processo: calcula `digest::digest(raw)` do RDS e compara com o ultimo hash sincronizado para o mesmo caminho de DB (cache em `.rostrum_bundle_sync_cache`). Se identico, retorna sem write.
  - `run_rostrum_engine()` substitui a chamada `rostrum_seed_synonyms_if_empty(conn)` por `rostrum_sync_synonyms(conn)`. `rostrum_seed_synonyms_if_empty` permanece disponivel como API publica para uso externo.
- **Alternativas rejeitadas**:
  - Versionar o bundle e rebuild apenas em bump de versao: exigiria campo de versao no RDS e logica de comparacao extra; complexidade nao justificada para um bundle pequeno.
  - Seed manual pelo usuario via UI: quebra UX e exige fluxo de admin desnecessario.
  - Schema change (tabela `rostrum_kv`) para persistir o hash no DB: adicionaria complexidade de migracao desnecessaria; cache em processo (por sessao) e suficiente dado que o bundle e pequeno e o sync e rapido.
- **Consequencias**:
  - Banco converge automaticamente com o bundle atual em toda sessao nova com `conn` valido.
  - Aliases manuais em `rostrum_aliases` nao sao afetados.
  - Hash-gate garante que o overhead por chamada seja negligivel (zero writes quando RDS nao muda).
  - `rostrum_seed_synonyms_if_empty` continua existindo e testada; apenas o engine deixa de chama-la.

---

## ADR-076: Preconnect para CDNs de fontes e preload do dicionario i18n no `.onLoad()`

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: Tres recursos externos bloqueavam o carregamento de fontes (Google Fonts, Font Awesome via CloudFlare, Lottie via unpkg) sem preconnect. Alem disso, o dicionario i18n (74 KB JSON) so era lido do disco na primeira chamada a `tr()` durante o build da UI, adicionando latencia desnecessaria nesse momento critico.
- **Decisao**:
  - Adicionar `<link rel="preconnect">` para `fonts.googleapis.com`, `fonts.gstatic.com` (com `crossorigin`) e `cdnjs.cloudflare.com` antes dos links de stylesheet no `<head>` de `app_ui()`.
  - Adicionar `.onLoad()` em `saira-package.R` que chama `load_i18n_dict()` com `tryCatch` silencioso, aquecendo o cache antes do primeiro `tr()`.
- **Alternativas rejeitadas**:
  - Self-host das fontes: eliminaria a latencia de CDN, mas adiciona complexidade de build e versionamento de assets.
  - `rel="preload"` em vez de `rel="preconnect"`: preload eh mais agressivo e exige `as=` correto por tipo; preconnect eh mais seguro e suficiente para reduzir latencia de negociacao TCP/TLS.
- **Consequencias**:
  - Preconnect reduz latencia de DNS + TCP + TLS para os CDNs em ~100-300ms em conexoes lentas.
  - `.onLoad()` elimina a leitura de disco no caminho critico do build da UI; falha silenciosa preserva compatibilidade com ambientes sem `inst/extdata/i18n.json` (ex.: testes parciais).

---

## ADR-077: Correcao de aliases semanticamente errados no bundle de sinonimos do Rostrum

- **Data**: 2026-03-06
- **Status**: Aceito
- **Contexto**: O lookup de sinonimos do Stage 1 usa correspondencia exata entre `normalize_for_matching(col_name)` e `normalize_for_matching(synonym)`. Se o nome da coluna nao tem hit de sinonimo, o fallback e token-overlap comparando com o nome do termo DwC (nao com os sinonimos). Dois problemas foram identificados no bundle v1:
  1. `"especie"` (pt, specificEpithet, 0.90): em datasets brasileiros, colunas nomeadas "especie" contem o binomial completo (ex: *Panthera onca*), nao apenas o epiteto especifico (*onca*). O mapeamento para `specificEpithet` estava semanticamente errado.
  2. `"species"` (en): ausente do bundle. `normalize_for_matching("SPECIES")` = `"species"` nao casa com nenhum sinonimo existente (o mais proximo era `"species name"` para `scientificName`). O fallback token-overlap produzia score 0.55 (zero tokens em comum entre `["species"]` e `["scientific", "name"]`), abaixo do threshold AUTO.
- **Decisao**:
  - Adicionar `"species"` (en, 0.93) e `"especie"` (pt, 0.93) como sinonimos de `scientificName` em `generate_rostrum_synonyms.R` e regenerar `dwc_synonyms_v1.rds`.
  - Remover `"especie"` de `specificEpithet`.
  - Regra geral documentada: alias que denota o conceito do taxon completo (binomial) nunca deve apontar para o termo do epiteto isolado.
- **Varredura de casos similares**:
  - `"subespecie"` (pt) -> `infraspecificEpithet` (0.91): borderline aceitavel -- datasets de museu tipicamente usam "subespecie" para o epiteto infraespecifico, nao para o binomial completo; monitorar.
  - `"cidade"` (pt) -> `county` (0.90): `county` = municipio no padrao DwC brasileiro; "cidade" e semanticamente mais restrito, mas Brasileiros usam ambos como sinonimos no cotidiano; score minimo (0.90) e value_score filtram falsos positivos; monitorar.
- **Alternativas rejeitadas**:
  - Manter `"especie"` em `specificEpithet` com score baixo (0.70): nao resolve o problema; Stage 3 ainda favoreceria o termo errado quando `specificEpithet` e `scientificName` competem.
  - Bloquear `"especie"`/`"species"` completamente (sem sinonimo em nenhum termo): pior UX; usuarios perdem o hint de mapeamento automatico.
- **Consequencias**:
  - Colunas nomeadas "especie", "ESPECIE", "Especie", "species", "SPECIES" agora recebem score 0.93 para `scientificName` via hit de sinonimo exato.
  - `specificEpithet` perde o alias "especie"; colunas "epiteto especifico", "specific epithet" e "species epithet" continuam mapeando corretamente.
  - `rostrum_sync_synonyms()` propaga a mudanca automaticamente para instancias SQLite existentes na proxima sessao.

---

## ADR-078: Empacotar uma mascara `land 10m` das Americas para `cc_sea(scale = 10)` e degradar apenas fora da cobertura

- **Data**: 2026-03-07
- **Status**: Aceito
- **Contexto**: A ADR-052 elevou `seas_scale` de `110` para `10` para melhorar a deteccao de pontos costeiros. Na pratica, a implementacao inicial ficou fragil em Linux/WSL: `coords_cc_sea_flagged()` aplicava `setTimeLimit(elapsed = 120)`, tentava processar a referencia mais detalhada em toda a rodada e fazia downgrade global para `scale = 50` em qualquer timeout/erro. Alem disso, o caminho principal ainda dependia de `rnaturalearth::ne_download()` ou da instalacao opcional de `rnaturalearthhires`, o que reintroduzia dependencia de rede/GDAL em runtime. Como `rnaturalearthhires` nao pode ir para `Imports` sem inviabilizar uma futura submissao ao CRAN, o pacote precisava de um caminho "out of the box" para usuarios que instalam o app via GitHub e trabalham majoritariamente nas Americas. Durante a primeira tentativa de empacotar a referencia, surgiu uma regressao real: a Guiana Francesa foi classificada como mar porque o recorte do artefato usava cobertura politica (`countries10` / `CONTINENT`) em vez de recorte geografico sobre a camada fisica.
- **Decisao**:
  - Gerar uma vez em `data-raw/generate_ne_land_10m_americas.R` um artefato embutido `inst/extdata/ne_land_10m_americas.rds` derivado do layer fisico `land` `10m` do Natural Earth.
  - O artefato passa a armazenar quatro componentes: `ref` (mascara terrestre dissolvida), `coverage_ref` (geometria de cobertura buffered para roteamento), `coverage_boxes` (bboxes auxiliares) e `meta` (proveniencia).
  - `coords_load_ne_land(scale = 10)` passa a ler exclusivamente esse artefato local; `scale = 50/110` continua usando referencia global local carregada via `rnaturalearth::ne_countries(type = "map_units")`.
  - `coords_cc_sea_flagged()` passa a particionar os pontos: linhas dentro da cobertura embutida usam `10m` local; linhas fora da cobertura usam fallback global `50m`; o downgrade deixa de ser "por rodada" e passa a ser "por ponto fora da cobertura".
  - A referencia `10m` e recortada em runtime ao bbox dos pontos com margem fixa de `2` graus antes da chamada a `cc_sea()`.
  - O timeout deixa de ser implicito; `SAIRA_CC_SEA_TIMEOUT` vira opt-in operacional.
  - A derivacao espacial do artefato deve usar recorte geografico diretamente sobre o layer fisico `land`, nunca recorte politico por `countries`/`continent`.
- **Alternativas rejeitadas**:
  - Mover `rnaturalearthhires` para `Imports`: rejeitada porque criaria dependencia forte fora do CRAN/Bioconductor.
  - Manter `ne_download()` e cache em runtime: rejeitada por fragilidade operacional, dependencia de rede e comportamento instavel entre Windows e WSL.
  - Fazer fallback `10 -> 50` para a rodada inteira ao primeiro timeout: rejeitada porque sacrifica precisao exatamente nas linhas costeiras que motivaram a mudanca para `10m`.
  - Embutir o mundo inteiro em `10m`: rejeitada por aumentar desnecessariamente o tamanho do pacote para o publico atual do app.
  - Recortar a referencia das Americas usando `countries10` / `CONTINENT`: rejeitada apos a regressao da Guiana Francesa, que ficou fora da mascara por estar politicamente associada a Franca.
- **Consequencias**:
  - `cc_sea(scale = 10)` passa a funcionar offline e sem dependencia extra para usuarios do app nas Americas.
  - Datasets mistos agora podem usar dois niveis de resolucao na mesma execucao: `10m` onde o pacote tem cobertura e `50m` fora dela.
  - O artefato embutido vira parte do contrato do pacote e precisa de script de geracao versionado, nota de proveniencia e testes territoriais de regressao.
  - Lentidao normal deixa de ser tratada como falha funcional; timeout so existe quando o operador explicitamente pedir.
  - Territorios ultramarinos e zonas costeiras passam a exigir fixtures especificas de teste; a Guiana Francesa entrou como caso de regressao permanente.

---

## ADR-079: Validacao pos-leitura de UTF-8 com retry de encoding em `read_biodiversity_csv()`

- **Data**: 2026-05-06
- **Status**: Aceito
- **Contexto**: `detect_encoding()` amostra apenas as primeiras 100 linhas do arquivo. Planilhas com conteudo ASCII nas primeiras linhas e bytes Latin-1 em linhas posteriores (ex.: `AMZ_CAMTRAP_AREA.csv` linha 594 — "Pacajá" com byte `0xe1`) sao identificadas como UTF-8. `readr::read_delim()` armazena o byte bruto, produzindo uma string com UTF-8 invalido na coluna MUNICIPALITY. O Stage 1 do motor Rostrum chama operacoes de string nessa coluna, recebe o erro "input string N is invalid UTF-8" e retorna `success = FALSE` com resultado vazio. O usuario ve "0 AUTO, 0 SUGERIDO" sem nenhuma indicacao do problema real.
- **Decisao**: Apos a leitura inicial, validar todas as colunas de caracter via `iconv(col, "UTF-8", "UTF-8")` — a funcao retorna NA para qualquer string com bytes invalidos. Ao detectar NA inesperado, emitir `warning()` com coluna e linha afetadas e re-ler o arquivo com Latin1; em seguida, tentar Windows-1252 se ainda houver invalidos. `readr` converte para UTF-8 ao ler com locale nao-UTF-8, entao nenhum passo de normalizacao adicional e necessario apos retry bem-sucedido. O parametro `encoding` do usuario (quando informado explicitamente) suprime o retry para preservar a intencao original.
- **Alternativa rejeitada**: Aumentar a amostra de `detect_encoding()` para o arquivo inteiro — custo de I/O proibitivo em arquivos grandes; o retry pos-leitura e mais eficiente pois so ocorre quando necessario.
- **Consequencias**:
  - Usuarios que subirem CSVs com encoding misto passam a receber dados corretos em vez de 0 matches.
  - `find_first_invalid_utf8_cell(df)` vira helper interno reutilizavel para diagnostico de encoding.
  - Warning explicito informa coluna e linha afetadas para rastreabilidade.

---

## ADR-080: Guard de falha de Stage 1 no automap antes de sobrescrever `rv$rostrum_decisions`

- **Data**: 2026-05-06
- **Status**: Aceito
- **Contexto**: `run_rostrum_engine()` captura falha de Stage 1 internamente e retorna `success = FALSE` com `data = empty_automap_result_df()` (zero linhas). O handler `auto_map` em `mod_mapping.R` nao verificava `engine_result$success`: sobrescrevia `rv$rostrum_decisions` com o resultado vazio, percorria o loop de zero iteracoes e exibia "0 AUTO, 0 SUGERIDO" como notificacao de sucesso — falso positivo silencioso que apagava qualquer mapeamento manual anterior.
- **Decisao**: Imediatamente apos `run_rostrum_engine()` retornar, verificar `!isTRUE(engine_result$success)`. Se verdadeiro, exibir notificacao de erro com `engine_result$errors[[1]]` (reaproveitando a chave i18n `notif_auto_mapping_v1_error` ja existente) e retornar cedo com `return(NULL)`, preservando `rv$rostrum_decisions` intacto. O guard de Stage 2/3 que ja existia (linhas de `rostrum_warning_stage2_fallback`) nao eh afetado — aqueles sao degrades parciais, nao falha total.
- **Alternativa rejeitada**: Tratar engine_result$data vazio como caso normal e exibir "0 matches" — manteria o comportamento silencioso e nao informaria o usuario sobre a causa real do problema.
- **Consequencias**:
  - Falha de encoding (ou qualquer outra causa de Stage 1) resulta em mensagem de erro clara ao usuario.
  - Estado de mapeamento anterior e preservado; usuario pode corrigir o problema e tentar novamente sem perder trabalho.

---

## ADR-081: Catalogo DwC completo separado do conjunto-base de mapeamento

- **Data**: 2026-05-06
- **Status**: Aceito
- **Contexto**: O app usava 50 termos DwC como conjunto-base fixo tanto no mapeamento quanto na wiki. O padrao TDWG define ~217 termos recomendados nos namespaces `dwc:` e `dcterms:`. Expor todos os 217 no mapeamento de inicio polui a UI; esconder na wiki priva o usuario de descoberta. Era preciso separar "termos que aparecem por padrao no mapeamento" de "catalogo completo disponivel para busca e adicao sob demanda".
- **Decisao**:
  - Manter `inst/extdata/dwc_terms.rds` (50 termos) como conjunto-base do mapeamento — nao alterado.
  - Adicionar `inst/extdata/dwc_full_catalog.rds` (217 termos) gerado por `data-raw/build_dwc_full_catalog.R` via scraping do TDWG (`vocabulary/term_versions.csv` no GitHub).
  - Schema identico (7 colunas: `term`, `class`, `definition_en`, `definition_pt`, `examples`, `required`, `data_type`), zero refatoracao dos consumidores existentes.
  - Deduplicacao por namespace: `dwc:` > `dcterms:` > `dc:` (o par `language` era duplicado).
  - Termos-base aparecem primeiro no catalogo, extras ordenados alfabeticamente.
  - `definition_pt` vazia para os ~167 termos fora dos 50 — wiki exibe fallback para EN.
- **Alternativas rejeitadas**:
  - Adicionar todos os 217 ao `dwc_terms.rds` — quebraria testes existentes e poluiria o mapeamento.
  - Curar manualmente +30 termos — escopo insuficiente; nao cobriria GeologicalContext, MeasurementOrFact etc.
  - GBIF completo com extensoes — ~300 termos, traducao PT inviavel manualmente para V1.
- **Consequencias**:
  - Wiki passa a mostrar 217 termos com filtros de classe derivados dinamicamente.
  - Mapeamento mantém 50 termos por padrao; extras adicionaveis sob demanda (ADR-082).
  - Script regeneravel a cada release do padrao TDWG.

---

## ADR-082: Mapeamento DwC sob demanda via `rv$extra_terms`

- **Data**: 2026-05-06
- **Status**: Aceito
- **Contexto**: Usuarios com datasets nao-convencionais precisam mapear termos fora dos 50 do conjunto-base (ex.: `GeologicalContext`, `MeasurementOrFact`). Adicionar todos os 217 ao mapeamento por padrao seria ruido. O app precisava de um fluxo de "adicionar termo" que fosse aditivo, reversivel por reset e preservasse todos os contratos existentes.
- **Decisao**:
  - `rv$extra_terms <- character(0)` no bloco de `reactiveValues` de `mod_mapping_server`.
  - `dwc_all` reactive passa a chamar `get_active_dwc_terms_list(extra = rv$extra_terms, lang = lang_r())` em vez de `get_dwc_terms_list()` — a lista ativa inclui base + extras.
  - O observer de `all_term_names` e o bloco de inicializacao aditiva de `rv$map_values`/`rv$map_meta` ja existentes cobrem os novos termos sem codigo adicional no init.
  - Botao "Adicionar termo" na sidebar abre modal com `selectizeInput` populado por `get_dwc_full_catalog()` minus termos ativos.
  - `confirm_add_term` insere em `rv$extra_terms`; o re-render reativo de `mapping_ui` e `filter_categories_ui` reflete o novo estado automaticamente.
  - `all_filter_categories` migra de variavel hardcoded (`c("Record-level", ...)`) para reactive derivado de `unique(dwc_all()$category)`.
  - `confirm_reset` inclui `rv$extra_terms <- character(0)` para retornar ao conjunto-base.
  - `auto_map`: passa `get_active_dwc_terms(rv$extra_terms)` para o engine; termos extras recebem status maximo `SUGERIDO` (nunca `AUTO`) por nao estarem no conjunto de calibracao do Rostrum.
  - `rostrum_extra_terms_from_template()` em `utils_rostrum_templates.R` identifica quais termos de um payload precisam ser pre-ativados antes da aplicacao — infra para fluxo futuro de template apply via UI.
- **Alternativas rejeitadas**:
  - `insertUI` para injetar card sem re-render — complexidade de seletor e sincronizacao de estado supera o beneficio; re-render reativo e suficiente em V1.
  - Botao de remocao individual de termo extra — adiado para V2; V1 usa reset como mecanismo de limpeza (tooltip explicativo no card).
  - Persistencia de extras entre sessoes — requer banco de dados de preferencias por usuario, fora do escopo V1.
- **Consequencias**:
  - Usuarios avancados podem adicionar qualquer termo do padrao TDWG sem reiniciar o app.
  - Todos os contratos existentes (`get_dwc_terms()`, `get_dwc_terms_list()`, `processed_data`) permanecem identicos.
  - Auto-map com extras funciona mas com sinalizacao de confianca reduzida (badge SUGERIDO).
  - Template export/import e agnóstico ao conjunto ativo — extras sao serializados naturalmente.
  - Padrao extensivel: qualquer futura causa de falha de Stage 1 beneficia automaticamente do mesmo guard.

---

## ADR-083: Remover coluna de exemplos da wiki e corrigir seletor de pageLength

- **Data**: 2026-05-06
- **Status**: Aceito (com correcao parcial em ADR-085 — vide nota abaixo)
- **Contexto**: Apos adicionar o catalogo DwC completo (217 termos via TDWG, ADR-081), a aba Wiki apresentou tres regressoes: (1) coluna de exemplos gigante — os exemplos literais do TDWG chegam a 768 chars com multiplos valores separados por `;` e markup de backtick, tornando a tabela inutilizavel; (2) barra de rolagem da pagina sumiu — o conteudo da coluna transbordava o container `.wiki-table.saira-table-shell` (que tem `overflow: hidden`); (3) seletor de pageLength nao funcionava — `applyPageLength` usava `draw('page')`, um partial redraw que nao recalcula o estado de paginacao apos mudanca de tamanho de pagina.
- **Decisao**:
  - Remover a coluna `examples` do `terms_table_data()` em `mod_wiki.R` — a wiki exibe 4 colunas (Termo, Classe, Definicao, Obrigatorio). Os dados de exemplos permanecem no `dwc_full_catalog.rds` para uso futuro.
  - Corrigir `applyPageLength`: substituir `table.page('first').draw('page')` por `table.page.len(len).draw(false)`. `draw(false)` faz um full redraw que recalcula o resultado paginado sem resetar a pagina atual; `draw('page')` era um partial redraw que nao atualizava o estado de paginacao apos mudanca de tamanho.
  - Ajustar seletores CSS `nth-child(5)` para `nth-child(4)` (coluna Required, agora na posicao 4) e remover `.wiki-example-code` (dead code).
- **Alternativas rejeitadas**:
  - Truncar exemplos no script de build (primeiro exemplo, sem backticks, max 120 chars) — o usuario preferiu ausencia completa a exemplos parciais que podem confundir.
  - Manter coluna com `max-width` CSS fixo e ellipsis — resolveria o layout mas nao eliminaria o ruido de informacao parcial.
- **Consequencias**:
  - Wiki exibe tabela limpa de 4 colunas; scroll da pagina funciona; seletor de pageLength funciona corretamente.
  - Exemplos ficam acessiveis pelo link do termo (TDWG) em cada linha.
  - Dados de exemplos preservados no RDS — reintroducao futura (com truncagem adequada) nao requer novo download.
- **Correcao (2026-05-07)**: O diagnostico do item (2) — "barra de rolagem da pagina sumiu porque o conteudo transbordava `overflow: hidden`" — estava **errado**. O `overflow: hidden` no shell **clipa** conteudo mas nao **bloqueia** scroll de pagina. A causa-raiz real era `bslib::page_navbar(fillable = TRUE)` confinando o body a `100vh; overflow: hidden` no nivel do layout, e isso afetava qualquer conteudo que extrapolasse a viewport — nao apenas a coluna de exemplos. A remocao da coluna **aliviou o sintoma temporariamente** (com pageLength=10 padrao + 4 colunas, o conteudo voltou a caber em 100vh), mas o problema retornou assim que o usuario aumentou pageLength (25/50/100) ou alternou para a aba Preview com muitas colunas. **Os itens (1) e (3) permanecem corretos**: remover a coluna de exemplos foi a decisao certa por motivos de UX (768 chars eram inuteis), e a correcao de `applyPageLength` para `draw(false)` esta validada. ADR-085 documenta o fix arquitetural correto para o sintoma (2).

---

## ADR-084: Regras CSS one-off vivem no modulo de origem, nunca no bundle

- **Data**: 2026-05-06
- **Status**: Aceito
- **Contexto**: Apos a regeneracao do bundle CSS por `data-raw/build_css.R` (necessaria para o trabalho de ADR-081/082/083), o header e os submenus de validacao passaram a exibir titulos duplicados ("Saira Saira", "Mapeamento Mapeamento", "Coordenadas Coordenadas"). A causa: a regra `.nav-title-container:has(.nav-title-dynamic:not(:empty)) .nav-title-static { display: none }` — adicionada em `97b7cf7` ("Enhance navigation titles with static fallback") — vivia diretamente em `inst/app/www/custom.css`, sem contraparte em nenhum modulo de `inst/app/www/css/`. Como o `build_css.R` reconstroi o bundle a partir dos modulos numerados, qualquer regra adicionada apenas ao bundle final e silenciosamente descartada na proxima regeneracao.
- **Decisao**:
  - Mover a regra para `inst/app/www/css/02-navbar.css` (dominio correto, ao lado da brand) e regenerar o bundle.
  - Adicionar guardrail em `tests/testthat/test-css-guardrails.R` que falha se o seletor `.nav-title-container:has(.nav-title-dynamic:not(:empty)) .nav-title-static` desaparecer do `custom.css`. Protege contra a mesma regressao em futuros rebuilds e contra remocoes acidentais do modulo.
  - Estabelecer regra geral: **toda alteracao em CSS vai no modulo de origem (`inst/app/www/css/NN-*.css`)**; `custom.css` e artefato gerado e nunca deve ser editado a mao. Esta regra ja constava nas LESSONS de Onda 5 ("custom.css comeca com header GENERATED FILE"); o ADR formaliza para casos pos-Onda-5 que ainda escapavam.
- **Alternativas rejeitadas**:
  - Usar JavaScript no client para esconder o fallback quando o uiOutput popular — adiciona dependencia funcional ao JS para corrigir um problema de render order que o CSS resolve em uma linha.
  - Remover o fallback estatico e aceitar o flash de branco no carregamento inicial — viola LESSON i18n "incluir texto estatico como fallback visual" e degrada a UX inicial.
- **Consequencias**:
  - Regra agora sobrevive a rebuilds; mesma garantia se aplica a qualquer regra futura adicionada ao modulo correto.
  - Guardrail captura tanto regressao por rebuild quanto remocao manual da regra do modulo.
  - Padrao reforcado: editar `custom.css` diretamente vira anti-pattern explicito (ja era implicitamente, mas agora com ADR + teste de regressao).

---

## ADR-085: Page-scroll opt-in por aba via `:has()` em vez de `bslib::page_navbar(fillable = TRUE)` global

- **Data**: 2026-05-07
- **Status**: Aceito (substitui parcialmente o item (2) de ADR-083)
- **Contexto**: A v0.2.0 (`b188f4b`) deixou Wiki e Preview com CSS minimo (3-7 linhas em `.wiki-table.saira-table-shell` / `.saira-table-shell`) e DT options apenas com `scrollX = TRUE` — funcionou perfeitamente porque com 50 termos / 6 pills / pageLength=10 todo o conteudo da aba cabia em `100vh`. Apos `fac0f7b` (ADR-081/082/083) expandir o catalogo para 217 termos / 12 pills (toolbar maior + paginacao maior), a tabela e seu footer (info + pagination) passaram a extrapolar a viewport em pageLength=25/50/100, e na aba Preview o sintoma aparece com qualquer dataset que tenha pageLength alto ou muitas colunas. **A causa-raiz e arquitetural, nao de overflow CSS**: `bslib::page_navbar(fillable = TRUE)` (default) coloca `body { height: 100vh; overflow: hidden }` no shell da app — isso e necessario para os layouts viewport-bound de Validate Names/Coords (`calc(100vh - 166px)` no workspace tri-coluna), mas para abas de conteudo que cresce com a interacao do usuario (Wiki paginada, Preview com pageLength variavel), bloqueia o scroll natural do browser e o footer fica inacessivel.

  **Historico de tentativas (over-engineering documentado para nao repetir)**:
  - **Iteracao 1 (errada)**: adicionei `overflow: hidden` no `.saira-table-shell`, regras dedicadas para `.dataTables_wrapper`, `.dataTables_scroll`, `.dataTables_scrollHead`, `.dataTables_scrollBody` (com `overflow-x/y: auto !important` em ambos os shells — 4 `!important` novos), `isolation: isolate` no Wiki shell. Hipotese: a scrollbar interna do DT estava sendo clipada pelo `overflow: hidden` do shell. **Errado**: DT inlina `overflow: auto` no `.dataTables_scrollBody` que, mesmo dentro de um pai com `overflow: hidden`, gera sua propria scrollbar interna (o pai so clipa o que extrapola visualmente, nao bloqueia overflow filho). O fix nao resolveu o sintoma e introduziu 4 novos `!important` (limite do guardrail subiu de 13 para 15 sem necessidade real — violou LESSONS:60 "evitar `!important` como estrategia padrao" e MEMORY guardrail).
  - **Iteracao 2 (errada)**: adicionei `scrollY = "calc(100vh - 540px)"` + `scrollCollapse = TRUE` ao DT options do Preview, `max-height/min-height` em `.preview-table-shell .dataTables_scrollBody`, classe marker `preview-page` + duas regras `:has(.preview-page)` para destravar page-scroll **so** no Preview, e ajustei o offset 380px → 540px tentando reservar espaco ao DT footer. **Errado em parte**: a regra `:has()` era a unica parte certa; tudo o resto era ruido. `scrollY` muda o contrato da tabela para "scroll vertical interno com altura fixa" — quando o usuario seleciona pageLength=10 em uma tela pequena, scrollY ainda recorta as linhas e ele tem que rolar **dentro** da tabela para ver os 10 selecionados. O Preview nunca quis isso; a expectativa do usuario sempre foi "tabela cresce com a pageLength escolhida, pagina rola se o conteudo extrapola".
  - **Iteracao 3 (correta — esta ADR)**: reverter tudo de Iteracoes 1+2 ao baseline v0.2.0. Manter apenas a tecnica `:has()` da Iteracao 2, generalizada para Wiki + Preview em uma unica regra no modulo de overrides centralizado. Zero novos `!important`. Zero alteracoes no DT options.

- **Decisao**:
  - **CSS shells voltam ao baseline v0.2.0**: `.wiki-table.saira-table-shell { padding: 0; border-radius: 16px; overflow: hidden; }` mais o `padding: 0` do wrapper e nada alem disso. `.saira-table-shell { border + radius + bg + shadow + padding }` sem regras de overflow.
  - **DT options do Preview voltam ao baseline v0.2.0**: `pageLength=10, lengthMenu=c(10,25,50,100), scrollX=TRUE, autoWidth=FALSE` — sem `scrollY`, sem `scrollCollapse`. A tabela cresce com a pageLength selecionada (10 → mostra 10 inteiros, 100 → cresce e a pagina rola).
  - **Uma unica regra CSS** em `inst/app/www/css/12-overrides.css` (modulo de overrides centralizado, ja contem `.tab-content { padding }` e `.bslib-page-fill { background }`):
    ```css
    .tab-content > .tab-pane:has(.wiki-module),
    .tab-content > .tab-pane:has(.preview-page) {
      overflow-y: auto;
      height: auto;
      max-height: none;
    }
    ```
    Sem `!important`. A especificidade do seletor `.tab-content > .tab-pane:has(...)` ja vence as regras herdadas de `.bslib-page-fill`. Aplica-se **apenas** as duas abas marcadas, preservando o contrato `100vh - offset` de Validate Names/Coords (LESSONS:90).
  - **Classe marker `preview-page`** adicionada ao container de `mod_preview_ui` ([R/mod_preview.R:16](R/mod_preview.R#L16)). `wiki-module` ja existia em `mod_wiki_ui` desde Onda 5.
  - **Guardrail de `!important` restaurado** de 15 para 13 em `tests/testthat/test-css-guardrails.R`. Bundle volta a 11 `!important` (mesma contagem do baseline).

- **Alternativas rejeitadas**:
  - Passar `fillable = c("upload", "mapping", "validate_names", "validate_coords", "help")` em `bslib::page_navbar` (excluindo Wiki e Preview da lista) — funciona, mas e API R que depende da versao do bslib e introduz acoplamento entre a configuracao do shell de UI e o comportamento de scroll. CSS escopado e mais robusto a futuras versoes do bslib.
  - Adicionar `position: sticky` ao thead da tabela para manter o cabecalho fixo durante page-scroll — usuario pediu o comportamento default ("cabecalho no topo dos registros visiveis"), nao header pinado durante scroll de pagina. Sticky tambem briga com `overflow: hidden` em ancestrais e exige mudanca em multiplos pontos.
  - Manter `scrollY` no Preview e adicionar mais offset para reservar espaco — qualquer valor fixo em `calc(100vh - Xpx)` quebra em telas pequenas (laptop 768p reserva so 228px com offset 540px, nao cabe nem 10 rows). Solucao baseada em pageLength dinamica nao existe nativamente no DT.

- **Consequencias**:
  - Wiki: tabela cresce com pageLength selecionada; pagina rola quando o conteudo extrapola; footer (info + paginacao) sempre acessivel; cabecalho azul no topo dos registros visiveis; scroll horizontal interno do `scrollX = TRUE` intacto.
  - Preview: comportamento identico — tabela cresce com pageLength, pagina rola quando necessario, scroll horizontal interno funciona; usuario seleciona 10 e ve os 10 inteiros sem scroll interno parcial.
  - Validate Names / Validate Coords: layout viewport-bound preservado (regra `:has()` so dispara para `.wiki-module` e `.preview-page`).
  - Bundle: 11 `!important` (zero novos); 14 linhas adicionadas em `12-overrides.css`; 1 caractere alterado em `R/mod_preview.R` (a classe marker).
  - **Anti-pattern documentado**: nao adicionar `!important` para "destravar" scrollbar quando a especificidade de seletor ja resolve. Nao adicionar `scrollY` ao DT como "fix" para falta de page-scroll — sao mecanismos ortogonais e mistura-los muda o contrato visivel da tabela.

## ADR-086: dynamicProperties como composicao JSON estrita TDWG, com chave auto-derivada e override por usuario

- **Data**: 2026-05-08
- **Status**: Aceito
- **Contexto**: O termo DwC `dynamicProperties` recomenda valor JSON estrito por linha (`{"chave1":"valor1","chave2":"valor2"}` — sem espacos, aspas duplas, escape JSON). Antes desta decisao, mapear duas colunas para `dynamicProperties` no Saira caia no fallback generico `collapse_mapped_values()` que produzia `valor1 | valor2` (formato pipe usado para outros termos multi-valorados). O resultado era invalido para repositorios que consomem `dynamicProperties` esperando JSON. Alem disso, o usuario nao tinha como controlar qual nome de chave entrava no JSON — derivado ou customizado. Restrito a 99k+ linhas, qualquer abordagem precisava ser performatica (orcamento `< 0.5s` por 100k x 4 colunas).

- **Decisao**:
  - Tratamento dedicado em `R/utils_mapping.R`:
    - `derive_dynprops_key(column_name)`: vetorizada, usa `iconv ASCII//TRANSLIT` (mesmo padrao de `normalize_for_matching` em [R/utils_common.R:67](R/utils_common.R#L67)) seguido de `gsub("[^a-z0-9]+", "_")` + colapso de underscores duplicados + trim. Fallback `"field"` quando o resultado e vazio. Sem `stringi` (zero novos imports).
    - `json_escape_string(x)`: vetorizada com **fast path** que pula todos os `gsub` quando nenhum elemento contem caracter especial (`grepl("[\\\\\"\x01-\x1f]", ...)`). No caminho lento, escapa por classe (`\\` → `\\\\`, `"` → `\"`, controles BS/TAB/LF/CR/FF + `\\uXXXX` para outros `< 0x20`). UTF-8 multi-byte preservado.
    - `build_dynamic_properties_json(df, cols, keys)`: composicao **vetorizada por coluna**, nao por linha. Pre-formata cada coluna como `paste0("\"", chave, "\":\"", escapado, "\"")` com `""` em celulas vazias, junta colunas com sentinela `\x01`, comprime sentinelas adjacentes, troca por `,`, e envolve em `{...}` somente quando ha conteudo. Linha 100% vazia → `""` (nao `"{}"`).
  - Despacho em `build_processed_mapping_df()`: novo branch `else if (term == "dynamicProperties")` inserido **antes** do branch single-column generico em [R/utils_mapping.R:2048](R/utils_mapping.R#L2048). Garante que single-column dynamicProperties tambem produza JSON (correcao semantica, nao ha caso valido em que valor cru sirva).
  - UX:
    - Card de `dynamicProperties` em [R/mod_mapping_cards.R](R/mod_mapping_cards.R): branch dedicado com `selectInput(multiple = TRUE)` + bloco `.dynprops-keys-block` listando uma `textInput` por coluna selecionada. Placeholder de cada input mostra `auto: <chave_derivada>` (formato `sprintf` via i18n `dynprops_key_placeholder`). Override branco volta para auto.
    - Modal "Adicionar termo" reescrito para usar `<optgroup>` nativo do Shiny (`choices = list(<classe traduzida> = c(<termos alfabeticos>))`) com modal `size = "l"`. Nao adiciona componente customizado — selectize.js renderiza optgroup nativamente em Shiny ≥ 1.7.

- **Resolucao de colisao de chaves**: quando duas colunas normalizam para a mesma chave JSON (ex.: `area-protegida` e `area_protegida` ambos viram `area_protegida`), emitir `warning()` unico no inicio da chamada listando colunas em conflito; **dropar globalmente** as colunas duplicadas (nao por linha). Justificativa: dropar globalmente permite vetorizacao do build de linha (sem laco com `seen` por linha); o caso "primeira coluna vazia, segunda com valor" e raro e o usuario tem o caminho explicito para resolver via override de chave.

- **Performance**: medido `0.21s` para 100k linhas x 4 colunas em maquina de dev (orcamento de teste e `< 0.5s`). Comparativo com abordagens rejeitadas:
  - `vapply` por linha + `paste(c(...), collapse = ",")` skipping vazios: ~3.1s (over budget 6x).
  - `jsonlite::toJSON(auto_unbox = TRUE)` por linha: nao medido — claramente over budget pelas calls per-row.
  - Vetorizacao `do.call(paste, c(parts, sep = sentinel))` + 3 `gsub` no joined: ~0.21s (chosen).

- **Persistencia em templates Rostrum**: `rv$dyn_props_keys` **NAO e persistido** em templates nesta entrega. Templates antigos com `dynamicProperties` continuam funcionando — chaves auto-derivam dos nomes das colunas. Override do usuario fica em sessao. Estensao futura (out of scope): adicionar `transform_kind = "dynamic_properties_json"` + `transform_params = list(keys = ...)` em `R/utils_rostrum_templates.R`.

- **Alternativas rejeitadas**:
  - **Adicionar `stringi` ao DESCRIPTION** para normalizacao Unicode mais robusta — recusado porque `iconv ASCII//TRANSLIT` ja e usado em `utils_common.R` e o pacote tem politica de minimizar deps. Risco de divergencia entre `glibc` e `musl` (Alpine/CI alternativos) mitigado por testes que pinam saidas esperadas em casos comuns PT-BR.
  - **`jsonlite::toJSON` por linha** — mais robusto a edge cases mas ordens de magnitude mais lento por overhead de R-level call e alocacao de listas. Performance era requisito hard.
  - **Manter compat single-column raw** — recusado: emitir valor cru em `dynamicProperties` ja era invalido por TDWG; e correcao nao regressao.
  - **Resolucao row-wise de colisao de chave** (primeira coluna nao-vazia da chave vence em cada linha) — recusado por inviabilizar a vetorizacao. O caso de uso real e raro e tem caminho explicito (override).
  - **Construcao via `lapply(rows, function(...))`** — mesma classe de problema do `vapply` por linha; rejeitado por performance.

- **Consequencias**:
  - Saida valida para repositorios DwC que consomem `dynamicProperties` em JSON estrito.
  - Single-column dynamicProperties agora produz `{"col":"valor"}` em vez de raw — quebra de comportamento documentada em CHANGELOG.
  - 0.21s para 100k linhas x 4 colunas — bem abaixo de qualquer threshold percebido pelo usuario.
  - Modal "Adicionar termo" agora navegavel: termos agrupados por classe DwC com search nativo do selectize.
  - Zero novas deps; zero novos `!important`; bundle CSS regenerado via `data-raw/build_css.R`.

## ADR-087: Export como bundle ZIP (CSV IPT-ready + XLSX Excel-safe + mapping_guide.txt) com round-trip via aliases

- **Data**: 2026-05-10
- **Status**: Aprovado
- **Contexto**: Tres problemas convergiram numa unica entrega:
  1. **Bug critico de export**: usuario clicava em Baixar e recebia o HTML inteiro do app salvo como `dwc_export_<data>.csv`, com modal travado em 90% e app congelado. Causa: `downloadButton` estava dentro de `<div style="display: none;">` e Shiny suspende outputs ocultos por padrao (`suspendWhenHidden = TRUE`), entao o `<a href>` nunca recebia o URL do endpoint. Click num `<a href="" download="dwc_export_<data>.csv">` faz o navegador baixar a URL atual (a propria pagina do app) com o nome `.csv`. Endpoint nunca era chamado, logo `download_finish_channel` nunca chegava ao cliente, modal travava em 90%, e `is_exporting(FALSE)` (que mora no `finally` do callback nunca-chamado) nao disparava — botao Baixar ficava permanentemente desabilitado.
  2. **Excel-corrupcao em duplo-clique**: usuarios sobem o `.csv` exportado no IPT, mas frequentemente abrem antes no Excel via duplo-clique para inspecao. Excel re-interpreta tipos: datas ISO viram locale (`2024-01-15` -> `15/01/2024` em pt-BR), numeros grandes viram notacao cientifica, zeros a esquerda somem. Re-salvar e mandar pro IPT corrompe o registro DwC.
  3. **Conhecimento de mapping descartado a cada planilha**: todo o trabalho que o usuario investe mapeando colunas do dataset dele para termos DwC e jogado fora — nao ha canal para outro pesquisador da mesma instituicao receber esse mapeamento, nem para o proprio Rostrum aprender e auto-aplicar em planilhas semelhantes futuras.

- **Decisao**:
  1. **Fix imediato do bug de export**: `shiny::outputOptions(output, "download_real", suspendWhenHidden = FALSE)` apos o `downloadHandler` em `mod_preview.R` (alinha com padrao ja existente em `mod_mapping.R:553` para `file_uploaded`). Modal de loading ganha botao Cancelar explicito (mantendo `easyClose = FALSE` per ADR-009) que reseta `is_exporting(FALSE)` em caso de bug futuro.
  2. **Export passa a ser `.zip`** contendo TRES arquivos:
     - `dwc_export_<data>.csv` — UTF-8 sem BOM (per ENCODING_RULES.md), IPT-ready, **com colunas brutas nao-mapeadas preservadas no fim** (eram descartadas antes — `process_for_export_with_unmapped()` em `utils_export.R` envolve `process_for_export()` e faz `cbind` das colunas que nao foram source de nenhum mapping).
     - `dwc_export_<data>.xlsx` — todas celulas forcadas a `character` antes da escrita via `writexl::write_xlsx()` (helper `write_xlsx_text_only()`). Sobrevive duplo-clique no Excel sem corromper datas/numeros.
     - `mapping_guide_<data>.txt` — texto plano dual-purpose: legivel por humano (cabecalho com instrucoes bilingue PT/EN, lista pares `Coluna -> Termo`, lista termos obrigatorios faltantes, lista colunas brutas nao-usadas) E parseavel por Saira (header magico `# saira:mapping:v1` na linha 1). **Sem dados embutidos** — apenas vocabulario de mapping (PII-safe).
  3. **Round-trip via aliases (NAO templates)**: ao subir o `.txt` na aba Inicio (mesmo dropzone do CSV de dados) OU clicando em Importar modelo na sidebar do Mapeamento, Saira detecta o magico, abre modal de confirmacao, e popula `rostrum_aliases` (scope=personal, confidence=1.0, reviewed=1) via `import_mapping_guide_to_aliases()`. Cada par vira UM alias persistente no `rostrum.sqlite` local do usuario. Aliases sao consultados pelo motor em todo automap subsequente via `rostrum_apply_alias_overrides()` ja existente — proximas planilhas com colunas de mesmo nome auto-mapeiam com badge ALIAS.
  4. **Bug colateral corrigido**: `rostrum_apply_alias_overrides` lookva aliases com `user_id = ""` (env `SAIRA_USER` vazia), mas `rostrum_upsert_alias` promovia `""` -> `"anonymous"` ao salvar. Mismatch fazia o filtro de visibilidade em `rostrum_list_aliases_for_column:780` rejeitar aliases personal por NA `user_id_norm`. Fix: engine tambem promove `""` -> `"anonymous"` antes do lookup. Esse bug afetava tambem `rostrum_record_alias_override` (selecao manual de coluna), so nunca foi pego porque ninguem testou sem `SAIRA_USER` setado.

- **Consequencias**:
  - +2 deps (`writexl` >= 1.4.0, `zip` >= 2.3.0) — pequenas, sem JVM.
  - ENCODING_RULES.md regra 4 estendida para permitir `.xlsx` no bundle (CSV continua canonico).
  - Round-trip social funcional: usuario A exporta -> manda `.zip` para B -> B sobe so o `.txt` (no dropzone OU no botao Importar modelo da sidebar do Mapeamento) -> aliases ficam no `rostrum.sqlite` de B -> proximo upload de B com colunas de mesmo nome auto-mapeia com badge ALIAS. Sem expor dados de A para B.
  - Colunas perdidas voltam: pessoa pode editar manualmente colunas nao-DwC no fim do CSV depois.
  - Sistema de aliases passa a funcionar de fato em sessoes sem `SAIRA_USER` setado (correcao do bug colateral).
  - Sidebar do Mapeamento ganha 4o botao Importar modelo (`btn-outline-secondary`, agrupado com Adicionar termo como acao auxiliar). Deteccao no upload da Inicio fica como fallback.
  - Modal de loading do export agora cancelavel via botao Cancelar (sem violar `easyClose = FALSE` do ADR-009).
  - Test isolation: `test-mod-mapping-server.R` agora usa `withr::local_envvar(SAIRA_USER = ...)` para nao depender do estado real do `rostrum.sqlite` local do dev (problema que so apareceu apos o fix do bug colateral, quando aliases ficaram visiveis).

- **Alternativas rejeitadas**:
  - `.csv` unico com truque de `="..."` em datas — quebra IPT (formula nao e valor literal por DwC).
  - `.xlsx` unico como saida principal — viola ENCODING_RULES.md (CSV continua mandatorio para IPT).
  - **Template Rostrum** como mecanismo de aprendizado em vez de aliases — usuario pediu aprendizado **por coluna** (alias-based, granular, acumulativo) e nao por configuracao inteira (template-based, all-or-nothing). Aliases compoem com aliases de outras planilhas; templates sobrescrevem.
  - `saira_template.csv` como segundo arquivo no bundle (proposto na V3 do plano) — usuario rejeitou: nao via motivo de o vocabulario precisar ser CSV; `.txt` e mais natural e legivel para humano.
  - Embutir dados parciais no guide para "ajudar" — usuario rejeitou: o guide e so vocabulario, sem PII / dados reais.
  - Mudar `easyClose = TRUE` no modal de loading para destravar — viola ADR-009 explicitamente. Botao Cancelar preserva o spirit (sem fechamento acidental).
  - Aceitar `.xlsx` ou `.zip` como input no upload — recusado por scope creep. Round-trip via `.txt` so ja resolve o caso de uso pretendido.

## ADR-088: Remocao das colunas de auditoria `validacao_manual` e `motivo_revisao` do export (reverte ADR-051)

- **Data**: 2026-05-11
- **Status**: Aprovado (reverte parcialmente ADR-051)
- **Contexto**: ADR-051 (2026-03-02) decidiu integrar a revisao manual de nomes ao export adicionando **sempre** as colunas `validacao_manual` (logico) e `motivo_revisao` (texto) ao `.csv` baixado, mesmo quando nao havia revisao alguma. Justificativa original: "simplifica consumo downstream" — codigo que le o export nao precisa fazer `if column exists` para todo registro. Em uso real, o usuario reportou que:
  1. Toda planilha exportada carregava essas duas colunas com `FALSE` / `""` em todas as linhas, mesmo quando ele nunca tinha aberto a aba Validacao > Nomes (caso comum: usuario subiu, mapeou, exportou).
  2. No upload pro IPT precisava explicar para cada dataset por que as colunas existiam e o que significavam — atrito desproporcional para algo que beneficiava apenas consumidores hipoteticos de pipeline.
  3. A rastreabilidade da revisao manual, que era a razao das colunas, ja esta coberta pelo `mapping_guide.txt` do bundle ZIP (ADR-087) — outro canal mais explicito.
- **Decisao**: `apply_name_review_payload()` nao escreve mais `validacao_manual` nem `motivo_revisao` no df de saida. As correcoes de `scientificName` (substituicao do nome quando o usuario marca "Corrigir" e digita um nome novo) continuam sendo aplicadas silenciosamente — esse e o trabalho util da revisao manual, separado da auditoria. A funcao fica com responsabilidade unica: aplicar correcoes ao `scientificName`.
- **Consequencias**:
  - Export `.csv` / `.xlsx` ganha 2 colunas a menos. CSV de qualquer planilha exportada fica mais limpo e compativel com IPT sem campos extras pra explicar.
  - Codigo de `apply_name_review_payload()` em `R/utils_export.R` simplificado (linhas 18-21, 102-117 removidas; bloco `correct_mask` em 112-126 reduzido para so o replacement).
  - Pipeline preserva a parte util: se usuario corrige "Panthera onza" -> "Panthera onca" via UI, o export reflete o nome corrigido. A diferenca e que ninguem sabe **a partir do export sozinho** quais linhas foram corrigidas. Quem precisar dessa info usa o `mapping_guide.txt` (que lista mappings) ou os logs server-side.
  - `LESSONS.md:141` invertido: o bullet antigo defendia "audit cols sempre"; o novo defende "nunca, rastreabilidade no mapping_guide.txt".
  - 5 testes em `test-utils-export.R` que assertavam presenca das audit cols reescritos para assertar **ausencia**; nome do nome corrigido permanece como invariante testado.
- **Alternativas rejeitadas**:
  - **Manter a politica antiga (audit cols sempre)** — usuario veto explicito; ruido visual e atrito IPT.
  - **Tornar condicional (so emitir se houve revisao)** — proposta intermediaria do plano original; usuario rejeitou: "essas colunas nao e para aparecerem de maneira nenhuma, nem se eu validar os nomes". Decisao binaria final: extincao.
  - **Mover audit cols para o `mapping_guide.txt`** — sub-considerado, recusado por scope. O `.txt` ja lista mappings de coluna -> termo; adicionar entries de revisao por linha o tornaria denso demais. Se houver demanda futura, vira ADR separado.

## ADR-089: Pills de classe (filtro + navegacao) e tira de obrigatorios no header do mapeamento

- **Data**: 2026-05-15
- **Status**: Aprovado
- **Contexto**: A aba de mapeamento era um scroll unico longo com headers de secao por classe DwC; o filtro de classe vivia em checkboxes na sidebar. Duas dores: (1) para chegar numa classe especifica a pessoa rolava muito; (2) para saber quais campos obrigatorios ainda faltavam ela ia ate a aba de Pre-visualizacao e voltava — e o painel de readiness la comia ~200px acima da planilha. Nao havia como sanity-check de um mapping sem sair da aba.
- **Decisao**:
  1. **Pills de classe (filtro + navegacao)**: barra horizontal sticky no topo do painel de mapeamento, uma pill por classe DwC + pill "Todas", reusando o primitivo CSS `.stream-pill` (de validate-names/coords). As pills sao o estado de visibilidade (multi-select toggle, todas visiveis por padrao; clicar pill ativa esconde a classe, clicar pill inativa mostra). Clicar uma pill que volta a ficar ativa tambem rola a `.mapping-scroll-container` ate a secao daquela classe. Substitui inteiramente os checkboxes de categoria da sidebar. Estado em `selected_classes_rv` (reactiveVal); observers via loop estatico sobre o catalogo de 12 classes (`names(class_tr_keys_map)`), superset verificado de `all_filter_categories()`.
  2. **Scroll apos render**: a secao de uma classe so existe no DOM apos `output$mapping_ui` re-renderizar. Handler inline `tags$script` (mesmo padrao guard + `Shiny.addCustomMessageHandler` ja usado em `mod_preview.R`), canal `saira-mapping-scroll-to-class`, com retry via `requestAnimationFrame` (cap ~40 frames) ate o anchor `cat_anchor_<slug>` existir; aborta gracioso (classe fica visivel, so sem scroll). Anchors sao `id` nas divs `.category-header`.
  3. **Tira de obrigatorios no header**: os 6 termos obrigatorios (`scientificName`, `eventDate`, `decimalLatitude`, `decimalLongitude`, `basisOfRecord`, `occurrenceID`) viram chips com status ao vivo dentro do `bslib::card_header` do mapeamento. **Semantica mapped-based** (escolha explicita do usuario, nao value-based): o chip vira `is-mapped` no instante em que uma coluna e atribuida ao termo (o `renderUI` le `rv$map_values`/`input[[map_<term>]]` e reusa `is_field_mapped`), independente de a coluna ter dados. Difere de proposito do antigo painel da Pre-visualizacao (que era value-based, so OK se a coluna tinha valor). `occurrenceID` sempre OK (UUID automatico). O painel de readiness da Pre-visualizacao foi removido (libera ~200px para a planilha); as chaves i18n `preview_readiness_*` foram reusadas.
  4. **Previa no card**: apos um termo padrao ser mapeado, uma linha mono discreta (`.field-card-sample`) com **um** unico exemplo *processado* (mesma logica do export — `build_term_value` — estilo IPT), via `processed_preview_for_term(term, val, 1L)`. Renderizada em **uma** linha com `text-overflow: ellipsis`; depende de `min-width: 0` em `.field-card` (item do grid `.two-column-layout`) para o ellipsis agir e textos longos (ex.: `occurrenceRemarks`) nao estourarem o card. So termos select padrao (nao occurrenceID/datasetName/modified/license/language/basisOfRecord/dynamicProperties). [Atualizado: a redacao original dizia `~3 valores ... via preview_values_for_column()`; previa virou valor processado (LESSONS: previa de card) e depois um unico exemplo com clip de uma linha.]
- **Consequencias**:
  - `mod_mapping_server` mantem o contrato de lista nomeada (ADR-054) inalterado — pills e tira sao estado de UI interno.
  - Removidas como mortas: `compute_preview_readiness()`/`compute_preview_unique_id_status()`/`format_preview_percent()` (`utils_preview.R`), `syncing_select_all`/`category_choices()` (`mod_mapping.R`), regras CSS `.category-filter-*` e `.preview-readiness-*`. Mantidos `is_preview_filled_value`/`is_preview_empty_column` (usados pelo realce de coluna vazia da DataTable), `prepare_preview_data`, `validate_preview_download_requirements`.
  - **Guardrail**: a `.mapping-class-pillbar` precisa ser o **primeiro filho dentro** da `.mapping-scroll-container` (o ancestral com `overflow-y:auto`) para o `position: sticky; top: 0` funcionar — nao colocar no `card_header` (fora do container de scroll). Mover o ancestral de scroll quebra o sticky.
- **Alternativas rejeitadas**:
  - **Barra de nav so navegacao, mantendo checkboxes da sidebar** e **pills na sidebar (filtro+nav)** — usuario escolheu a barra de topo que filtra+navega (mais IPT-like, recupera espaco da sidebar).
  - **Tira value-based (paridade com o painel antigo)** — usuario escolheu mapped-based para feedback instantaneo enquanto mapeia; resolveu tambem a questao de manter ou nao `compute_preview_readiness` (extinta).
  - **Manter o painel de readiness na Pre-visualizacao tambem** — recusado: duplicacao e nao recupera espaco da planilha.
  - **Loop dinamico de observers por classe via input JS delegado** — mais codigo, sem padrao existente; loop estatico sobre o catalogo de 12 (superset) e suficiente e cirurgico.

## ADR-090: Mascaramento de coordenadas de especies sensiveis via generalizacao por grade

- **Data**: 2026-05-17
- **Status**: Aprovado
- **Contexto**: Publicar ocorrencias de especies ameacadas no IPT/GBIF com localidade precisa cria risco real (coleta predatoria, pressao de captura). O usuario tinha a Lista Nacional Oficial de Especies Ameacadas do MMA (Portaria 443/2014, anexos flora + fauna) num `.md` de tabela Markdown e queria: (1) flaggar registros cuja especie esta na lista, (2) substituir as coordenadas no pacote IPT por versoes imprecisas, (3) ainda entregar ao pesquisador uma planilha separada com as coordenadas reais para controle dele. Pediu explicitamente algo simples, sem complicar o app.
- **Decisao**:
  1. **Generalizacao por grade, nao jitter aleatorio / entrada manual / apagamento**: `generalize_coord(x, grid = 0.1)` arredonda lat/lon para uma grade mais grossa (default `0.1` grau ~ 11 km) via `round(round(x/grid)*grid, 6)`. Reprodutivel, defensavel, mantem o ponto na regiao/pais certo — pratica recomendada GBIF/TDWG/SiBBr. Jitter aleatorio pode jogar o ponto no mar/municipio errado e nao e reprodutivel; entrada manual e trabalho e erro.
  2. **Lista como artefato empacotado, nao SQLite que o usuario sobe**: `data-raw/redlist_brasil_mma.md` (fonte) -> `data-raw/generate_sensitive_species.R` -> `inst/extdata/sensitive_species.rds` (`scientificName` + `match_key`, 4455 taxa, dedupe por `match_key`). Mesmo padrao de `country_aliases.rds` (ADR-014 `create_rds_cache`). Sem migracao de schema, versionado, simples. Parser robusto: mantem so linhas cujo cell 1 e inteiro **e** ultimo cell e categoria valida (`VU|EN|CR|CR (PEX)`); especie e o penultimo cell — funciona para os dois layouts (flora 5 cells, fauna 6 com coluna Ordem) e rejeita titulos, headers, separadores e legenda de rodape.
  3. **Uma unica funcao pura compartilhada por display e export**: `R/utils_sensitive.R`. `flag_sensitive_species()` e a unica fonte da verdade — usada tanto pela pill na aba Validacao > Nomes quanto pelo `mask_sensitive_coordinates()` do export. Sem propagar reativo novo pela cadeia de modulos (o contrato de `mod_validate_names` ja e divida tecnica conhecida; nao foi piorado).
  4. **Casa pelo `scientificName` resolvido**: tanto a lista quanto o nome a comparar passam pela **mesma** normalizacao do validador (`normalize_scientific_name(remove_authors=TRUE, ignore_qualifiers=TRUE)` -> `normalize_for_matching`). Logo um registro enviado sob sinonimo, que o validador resolve para o nome aceito, ainda casa. Match e rank-exato (subsp./var. mantidos; `normalize_scientific_name` so remove `cf./aff./sp.` e autores, **nao** colapsa epiteto infraespecifico): so o taxon listado e mascarado, nao a especie inteira.
  5. **Campos DwC autopreenchidos no mascaramento**: `dataGeneralizations` (frase com grau e km), `informationWithheld` (coordenada precisa retida, disponivel mediante solicitacao) e `coordinateUncertaintyInMeters` = `max(existente, lado-da-celula)` (~11132 m para 0.1; nunca **abaixa** uma incerteza ja declarada). Os 3 termos ja existem em `dwc_full_catalog.rds` (217 termos, classes Record-level/Location) entao `order_columns_dwc_canonical()` os ordena sozinho — nenhuma mudanca de vocabulario foi necessaria.
  6. **Preview na tela permanece real**; o mascaramento so vale para o bundle IPT. Sinal na tela = pill "Sensivel" + (futuramente) contagem. `mask_sensitive_coordinates()` roda sobre o `full_data` ja processado (que ja tem `occurrenceID` de `add_occurrence_ids`), no handler de `mod_preview.R`, **depois** de `process_for_export_with_unmapped()` — ordem obrigatoria para o arquivo companion poder chavear por `occurrenceID`.
  7. **Arquivo companion no ZIP**: quando `n_masked > 0`, `sensitive_real_coords_<data>.csv` (linha 1 = aviso i18n com `#`, depois `occurrenceID`, `scientificName` e as coordenadas **reais**) entra no `zip::zipr`. Quando `n_masked == 0` o ZIP e byte-identico ao comportamento anterior (caminho no-op de risco zero).
- **Consequencias**:
  - Especies do MMA com coordenadas exportadas para o IPT saem generalizadas e autodocumentadas; pesquisador retem as reais num arquivo privado claramente rotulado "nao publicar".
  - `R/utils_sensitive.R` novo (puro, sem Shiny). `mod_validate_names.R`: +coluna oculta `.is_sensitive` (target 4, `visible=FALSE`) e pill no render de `scientificName` reusando `.vn-status-badge badge-warning` (sem CSS novo, sem rebuild). `mod_preview.R`: 2 chamadas no handler, `utils_export.R` intocado.
  - +4 chaves i18n. `test-utils-sensitive.R` (46 testes) + extensoes em `test-mod-validate-names-server.R` e `test-utils-export.R`.
  - Grade exposta como argumento de funcao (default 0.1), **sem** controle de UI por ora — simplicidade pedida pelo usuario. Categoria (VU/EN/CR) existe na fonte mas e descartada (flag unico, decisao do usuario); disponivel se precisao por nivel for desejada no futuro.
  - Degradacao graciosa: `sensitive_species.rds` ausente/invalido -> `warning()` + lista zero-row -> mascaramento vira no-op, validacao e export nao quebram.
  - Limitacao conhecida: nome do MMA pode ser sinonimo relativo ao backbone GBIF/FloraBR/FaunaBR enquanto o validador resolve para outro nome aceito -> esse registro escapa do flag. Aceito como best-effort; expansao da lista com sinonimos do backbone fica como ADR futuro se houver demanda.
- **Alternativas rejeitadas**:
  - **Jitter aleatorio em raio** — nao reprodutivel, pode mover ponto para fora do pais/municipio; rejeitado a favor de grade.
  - **Pesquisador digita coordenadas generalizadas** — trabalho manual e propenso a erro; a grade e objetiva e automatica.
  - **Apagar coordenadas + so `informationWithheld`** — perde uso cientifico do dado sem necessidade; generalizacao preserva utilidade regional.
  - **Lista numa tabela do `rostrum.sqlite` que o usuario sobe** — exige migracao de schema e UI de upload; RDS empacotado e mais simples e versionado (pedido explicito de simplicidade).
  - **Adicionar `dataGeneralizations`/`informationWithheld` ao `dwc_full_catalog.rds`** — desnecessario: verificado que ja estao no catalogo de 217 termos; evitou edicao de `build_dwc_full_catalog.R` e download da TDWG.
  - **Propagar um reativo novo de sensibilidade por mod_mapping -> validate -> preview** — acoplamento e divida; uma funcao pura chamada nos dois pontos (display + export) e suficiente e cirurgica.
  - **Mascarar tambem o preview na tela** — recusado: pesquisador precisa ver o dado real enquanto trabalha; mascaramento e so do artefato IPT.

## ADR-091: Despacho real de stage1_parallel_strategy e paridade multicore nos testes

- **Data**: 2026-05-17
- **Status**: Aprovado
- **Contexto**: `rostrum_stage1_run_term_map()` validava e logava a opcao `stage1_parallel_strategy` mas sempre chamava `future::plan(future::multisession)` independente do valor. Alem disso, `future::multisession` cria processos R frescos que nao conseguem `loadNamespace("saira")` quando o pacote esta carregado apenas via `pkgload::load_all()` (nao instalado) — o que e o caso em `devtools::test()` localmente e no CI (`scripts/release_gate.R` passo 1/6). O teste de paridade `stage1 parallel multisession matches sequential decisions` falhava com 3 erros pre-existentes toda vez que a suite era rodada via `devtools::test()`, exigindo `devtools::install()` como workaround.
- **Decisao**:
  1. **Despacho correto da estrategia**: `rostrum_stage1_run_term_map()` agora seleciona o plano com base em `options$stage1_parallel_strategy`. `"multisession"` → `future::multisession` (padrao, seguro em todas as plataformas). `"multicore"` → `future::multicore` se `parallelly::supportsMulticore()` for `TRUE` (fork, herda o namespace do processo pai — funciona com `load_all`); caso contrario cai silenciosamente para `future::multisession` com um log de debug. `"sequential"` ja era tratado pelo early-return `can_parallel`.
  2. **Contrato `rostrum_options()` estendido**: `stage1_parallel_strategy` agora aceita `c("multisession", "multicore", "sequential")`. Default permanece `"multisession"` (comportamento de producao inalterado — o pacote esta instalado em producao).
  3. **Teste de paridade dividido em dois**:
     - **multisession**: guarda `skip_if(pkgload::is_dev_package("saira"), ...)` — salta de forma limpa sob `devtools::test()` / `load_all`; roda e deve passar sob `R CMD check` (pacote instalado no check temporario, passo 5/6 do release gate).
     - **multicore**: guarda `skip_on_os("windows")` + `skip_if_not(parallelly::supportsMulticore())` — roda em Linux/macOS mesmo sob `load_all` (fork herda o namespace), verifica determinismo real parallel. Zero falhas em `devtools::test()` no CI ubuntu.
- **Consequencias**: suite fica verde (`FAIL 0`) sob `devtools::test()` sem precisar de `devtools::install()`. Paridade multicore fornece cobertura genuina do path paralelo em load_all. Paridade multisession continua verificada no check instalado.
- **Alternativas rejeitadas**:
  - Forcar workers a `pkgload::load_all()` — fragil, lento, logica de dev no codigo de producao.
  - Usar `future::plan(sequential)` no setup dos testes — nao exercita o path paralelo real.
  - `devtools::install()` antes dos testes no CI — custo de tempo, e contorna o problema sem fix.

## ADR-092: Generalizacao graduada de especies sensiveis (metodo de 4 categorias do Chapman 2020) e controle por especie

- **Data**: 2026-05-19
- **Status**: Aprovado
- **Supersede parcial**: ADR-090 (revoga as decisoes "grade unica 0.1 fixa" e "sem UI / sem reativo novo"; o restante do ADR-090 — generalizacao por grade vs jitter, lista empacotada, funcao pura, casamento por scientificName resolvido, companion CSV, no-op byte-identico — permanece valido).
- **Contexto**: Auditoria do recurso de mascaramento contra o GBIF *Current Best Practices for Generalizing Sensitive Species Occurrence Data* (Chapman 2020). O metodo central ja estava correto, mas tres lacunas vs. o documento: (1) nivel unico 0.1 para toda a lista, enquanto o documento recomenda o metodo graduado de 4 categorias (Tabela 7) e critica explicitamente niveis unicos; (2) so `decimalLatitude/Longitude` eram generalizadas — campos verbatim/locality reverteriam a generalizacao (Chapman sec. 3 e 3.4); (3) sem `coordinatePrecision`. Alem disso, a lista MMA e so um *gatilho* (Chapman sec. 2 / Afterword): o custodiante decide caso a caso, e nome trocado/sinonimo fora do MMA escapava (limitacao conhecida do ADR-090). Decisoes de mapeamento e UI confirmadas com o usuario.
- **Decisao**:
  1. **Categoria carregada na lista**: `generate_sensitive_species.R` passa a extrair a categoria MMA (`VU|EN|CR|CR (PEX)`, ja validada pelo `category_re`). `sensitive_species.rds` ganha coluna `category`; dedupe por `match_key` mantem a **mais restritiva** (CR(PEX)>CR>EN>VU). Loader retrocompativel: RDS antigo sem `category` -> `warning()` + tudo tratado como CR.
  2. **Mapeamento MMA -> Chapman (ordinal conservador)**: CR(PEX)=Cat1=1.0, CR=Cat2=0.1, EN=Cat3=0.01, VU=Cat4=0.001 grau. Cat1 = arredondamento a 1 grau (opcao documentada na Tabela 6/7 do Chapman, "rounded to 1 degree") — sem ramo especial de remocao de colunas no preset padrao.
  3. **Presets de esquema** (`sensitive_grid_for_category(cat, scheme)`): `conservador` (recomendado, padrao), `cat1_omit` (CR(PEX) com lat/long vazias + `informationWithheld`), `cautela` (CR(PEX) omitida, CR=1, EN=0.1, VU=0.01). Grade `NA` = "coordenadas nao divulgadas".
  4. **Decisao por especie**: `sensitive_resolve(names, decisions)` — o payload da aba Validacao > Nomes (marcacoes do pesquisador) vence; linhas nao tocadas caem no auto-match MMA. Permite marcar especie fora do MMA e desmarcar especie MMA (decisao de custodiante, com aviso i18n). `flag_sensitive_species()` agora delega a `sensitive_category_for()` (pill inalterada).
  5. **Scrub anti-reversao** (Chapman sec. 3, "replaced with appropriate wording — not blank/null"): em linhas sensiveis, `verbatimLatitude/Longitude`, `verbatimCoordinates`, `footprintWKT`, `locality`, `verbatimLocality`, `georeferenceRemarks`, `locationRemarks` (apenas colunas ja existentes) recebem o texto de `informationWithheld`. `coordinatePrecision` = grade da linha (precisao fornecida); ja esta no `dwc_full_catalog.rds` entao `order_columns_dwc_canonical()` o ordena.
  6. **Fluxo entre modulos via attr (espelha `review_export_payload`)**: `attr(result_r, "sensitivity_payload")` em `mod_validate_names`; `app_server` extrai e passa `sensitivity_payload_r` a `mod_preview_server`. Sem nova cadeia de reativos — mesma mecanica ja validada (ADR-054). Esta e a "nova UI + novo reativo" que o ADR-090 recusou por simplicidade; reaberto a pedido explicito do usuario.
  7. **UI**: pill clicavel mostrando a categoria + afordancia "+ marcar" para nao listados (handler delegado em `filter_callback_js`, padrao existente; sem CSS novo obrigatorio) -> modal de marcar/desmarcar + categoria. Painel de preset na Pre-visualizacao (radio + tabela categoria->grade + desativar), exibido so quando ha registros sensiveis; mascaramento LIGADO por padrao (conservador).
- **Consequencias**:
  - Generalizacao por registro conforme a categoria; documentacao DwC por linha (`dataGeneralizations` com categoria, `informationWithheld`, `coordinateUncertaintyInMeters` = `max(existente, lado-da-celula)`, `coordinatePrecision`). Companion CSV ganha `category`.
  - `+15` chaves i18n; `sensitive_data_generalizations` passa a 3 args (categoria, grau, km). `DESCRIPTION` 0.2.5 -> 0.2.6.
  - `mask_sensitive_coordinates()` muda de assinatura (`grid=0.1` -> `decisions/scheme/enabled`); chamadores e testes atualizados. `enabled=FALSE` ou sem registro sensivel -> no-op byte-identico (caminho de risco zero preservado).
  - Citacao explicita do documento Chapman (2020) GBIF na fonte e nos docs.
- **Alternativas rejeitadas**:
  - **Manter nivel unico 0.1** — desvia do metodo graduado que o documento recomenda e critica niveis unicos (caso SANBI).
  - **CR(PEX) sempre com coordenada omitida (interpretacao estrita da Cat1)** — disponivel como preset `cat1_omit`/`cautela`, mas nao o padrao: Chapman favorece reter dado verdadeiro (Principios 2-3) e 1 grau ja e Cat1 valida; CR(PEX) ("possivelmente extinta") tem menor risco de coleta.
  - **Curar uma sublista-gatilho menor (sensivel != ameacado)** — fora de escopo; o controle por especie (marcar/desmarcar) ja entrega a decisao caso-a-caso do custodiante sem reestruturar a lista.
  - **Novo reativo dedicado mod_mapping->validate->preview** — desnecessario; o padrao attr/payload ja existe e foi reusado.
  - **Widgets inline (checkbox/select) por linha na DT** — fragil; o padrao acao->modal->reactiveValues->payload ja e o estabelecido para revisao.

## ADR-093: Painel "Nomes Processados" passa a listar todos os nomes (incluindo aceitos) com pill "Aceitos" e sem limite de janela pos-execucao

- **Data**: 2026-05-19
- **Status**: Aprovado
- **Supersede parcial**: Design implicito do stream window (`.vn_stream_window_limit = 100L` como limite absoluto).
- **Contexto**: O painel "Nomes Processados" foi concebido como fila de revisao incremental: mostrava apenas nomes problematicos (nao_encontrados/ambiguos/sinonimos) e aplicava um teto de 100 itens para proteger o render durante a execucao em streaming. Nomes aceitos (ex.: *Harpia harpyja*) eram excluidos por design. Apos a implementacao do mascaramento de coordenadas (ADR-092), o "Relatorio de Nomes" passou a contabilizar nomes validos (ex.: 297 validos), gerando confusao: o usuario esperava ver todos os nomes processados no painel esquerdo, separados por pills, da mesma forma que o relatorio. A inconsistencia ficou clara com nomes como *Harpia harpyja* (aceito por GBIF, exibido no relatorio mas ausente no painel).
- **Decisao**:
  1. **Pill "Aceitos" adicionada**: `"accepted"` entra em `.vn_stream_filter_values`; `stream_filter_counts` computa a contagem; `filter_stream_df` tem ramo `accepted = status_vec == "accepted"`; `pill_defs` inclui a nova pill com classe `pill-success`. O observer do loop de `stream_filter_values` em `mod_validate_names.R` registra automaticamente o handler de clique.
  2. **Limite de janela removido pos-execucao**: `stream_window` aceita `limit = NULL` (sem cap) alem do inteiro existente. A chamada no render usa `limit = if (isTRUE(rv$running)) stream_window_limit else NULL` — durante a execucao em streaming o teto de 100 continua ativo (protege render incremental); apos conclusao todos os nomes aparecem.
  3. **Filtro padrao pos-execucao permanece `"problems"`**: a aterrissagem na aba continua na fila de revisao para nao mudar o fluxo de trabalho existente; o usuario acessa aceitos via pill explicita.
  4. **Nota semantica**: `stream_df` e por nome unico processado (nao por linha de dataset); `"Todos"` pos-execucao reflete o total de nomes unicos, que pode diferir dos contadores do relatorio (por-linha). Isso e correto para um painel de *nomes*, nao de *ocorrencias*.
- **Consequencias**:
  - `i18n.json` ganha chave `validate_names_stream_filter_accepted` (pt: "Aceitos", en: "Accepted").
  - Testes de `stream_filter_counts` e `filter_stream_df` cobrem o ramo `accepted`.
  - `stream_window` com `NULL` retorna todos os registros sem trunc; testes para o comportamento sem cap adicionados.
- **Alternativas rejeitadas**:
  - **Manter fila de revisao + adicionar apenas help text** — nao resolve a expectativa do usuario de ver todos os nomes; o mismatch continuaria visivelmente injustificado.
  - **Remover o teto absolutamente (inclusive durante streaming)** — prejudicaria UX durante execucao incremental; manter o teto apenas durante `rv$running` preserva performance sem sacrificar completude pos-execucao.
  - **Mostrar contadores do relatorio no painel esquerdo** — enganoso; as contagens sao de fontes diferentes (unico vs. por-linha). O caminho correto e tornar o painel completo, nao simular completude via contadores emprestados.

## ADR-094: Painel de mascaramento achatado para o metodo Chapman 2020 (5 niveis globais) + desacoplamento Preview <-> processed_data

- **Data**: 2026-05-19
- **Status**: Aprovado
- **Supersede parcial**: ADR-092 (cai a parte de "scheme presets por categoria MMA" e "categoria editavel no modal por especie"). Preserva: deteccao via lista MMA, override booleano por especie em Validacao > Nomes, pill MMA visual, companion CSV, no-op byte-identico, scrub de campos vazadores de coordenada.
- **Contexto**: Apos a v0.2.5 (ADR-092), duas regressoes ficaram evidentes:
  1. **Performance**: o card de mascaramento na aba Preview chamava `sensitive_overview()` -> `download_data()` -> `download_data_r` = `processed_data_r` (full `build_processed_mapping_df` agora sobre o catalogo de 217 DwC terms). Ao trocar de aba apos mapear `scientificName`, qualquer aba consumidora ficava ~1 min bloqueada — reincidencia direta do antipattern coberto por ADR-020 e LESSONS:31 ("nao acoplar output rapido a reactive de processamento completo"). Causa-raiz: `sensitive_overview` precisava de apenas 3 colunas (`scientificName`, `decimalLatitude`, `decimalLongitude`), mas arrastava o pipeline completo.
  2. **UX**: o desenho original do ADR-092 usava 3 *schemes* nomeados (`conservador`, `cat1_omit`, `cautela`) que mapeavam grades diferentes por categoria MMA da especie (VU/EN/CR/CR PEX). Cada label do `radioButtons` repetia inline as 4 transicoes categoria->grade, gerando texto longo que o flex default do `.form-check` espremia numa coluna estreita; `.sensitive-panel`/`.sensitive-grid-table` ainda nao tinham CSS algum no projeto. Alem disso, a logica de grade-por-categoria contraria a leitura literal da Tabela 7 do Chapman 2020, em que o custodiante escolhe **um** nivel de generalizacao para todos os registros sensiveis (a lista do MMA e gatilho de deteccao, nao mapeamento de grade).
- **Decisao**:
  1. **Engine global de 5 niveis Chapman**: `sensitive_generalization_levels()` = `c("extreme","high","medium","low","not_sensitive")`. `sensitive_generalization_grid(level)` mapeia tier -> grau (1, 0.1, 0.01, 0.001, NA). `mask_sensitive_coordinates(df, decisions, generalization, enabled, lang)` aplica a mesma grade a **todas** as linhas sensiveis; `not_sensitive` ou `enabled=FALSE` -> no-op byte-identico. Substitui `sensitive_scheme_levels()`/`sensitive_grid_for_category()`/`sensitive_scheme_grid_table()` que foram removidos.
  2. **UI achatada na aba Preview**: `radioButtons` com 5 opcoes (default `"low"`, recomendado); tabela informativa com 5 linhas (espelha Tabela 7); CSS dedicado em `inst/app/www/css/17-sensitive-panel.css` (zero `!important`, orcamento mantido em 11/13). Removido o checkbox "Desativar mascaramento" — `"not_sensitive"` no radio cumpre o mesmo papel.
  3. **Override por especie preservado, simplificado**: `mod_validate_names.R` mantem o modal de marcar/desmarcar especie como sensivel, mas SEM o `selectInput` de categoria — o payload reduz para `(scientificName, sensitive)`. A pill "Sensivel" no stream continua exibindo a categoria MMA (CR/EN/VU/CR PEX) para overrides nao-MMA cai-se em "—" (em-dash) para nao quebrar a string JS `Sensivel · {cat}`.
  4. **Decoupling de performance** (raiz da regressao): `mod_mapping_server()` ganha slot `sensitive_overview_input_r` no return-list (ADR-054) — uma reativa leve que projeta `(scientificName, decimalLatitude, decimalLongitude)` direto de `raw_data_r() + rv$map_values`, sem materializar `processed_data_r`. Mesmo padrao dos gates leves existentes (`validation_gate_r`, `coord_validation_gate_r`). `mod_preview_server` ganha parametro `sensitive_overview_input_r` e o usa em `sensitive_overview()` no lugar de `download_data()`. O download handler do bundle IPT continua usando `download_data_r` (correto — export precisa do dataset processado completo).
- **Consequencias**:
  - API muda: `mask_sensitive_coordinates(..., scheme=)` -> `mask_sensitive_coordinates(..., generalization=)`. `sensitivity_payload` reduz para `(scientificName, sensitive)`. Tres funcoes removidas do `utils_sensitive.R`. Testes atualizados (todos passando, 84 em `test-utils-sensitive.R`).
  - i18n: removidas chaves `sensitive_scheme_*`, `sensitive_disable_label`, `sensitive_category_label`, `sensitive_cat_full_*`, `sensitive_coords_withheld[_short]`. Adicionadas `sensitive_generalization_label`, `sensitive_gen_{extreme,high,medium,low,not_sensitive}`, `sensitive_grid_unmasked`.
  - Comportamento: usuario agora **escolhe uma grade unica** para todos os registros sensiveis (independente do nivel de ameaca MMA da especie). Para um custodiante que queira tratamento diferenciado por especie, o fluxo continua: marcar/desmarcar especies individualmente em Validacao > Nomes; a grade aplicada e a global.
  - Performance: o card de mascaramento aparece em < 1s mesmo em datasets grandes; a aba Preview deixa de bloquear ate `build_mapped_result` rodar. Validate Names/Coords seguem sujeitos ao custo legitimo de processar o dataset completo, mas pelo menos a Preview nao concorre mais pela mesma fila reativa single-threaded.
- **Alternativas rejeitadas**:
  - **Manter `scheme` por categoria MMA + so adicionar 4o esquema "liberal"** — desenho original do ADR-092 ja era mais complexo do que a Tabela 7 exige; cada esquema novo multiplicava combinacoes ortogonais (5 niveis × 4 categorias × N estados de "omitida"). A leitura literal do Chapman e radicalmente mais simples: o custodiante escolhe um nivel.
  - **bindCache em `processed_data`** — discutido no plano; o ganho seria marginal (Shiny ja faz cache reativo natural; o cache so ajuda quando dependencias invalidam e a entrada bate na chave), e o custo de digest no data.frame inteiro a cada invocacao adicionava risco. Preferimos a correcao cirurgica (decoupling do Preview).
  - **Gatear `output$sensitive_panel` por aba ativa** (`req(input$main_nav == "preview")`) — solucao mais barata mas fragil: depende de o ID `main_nav` viver no UI raiz e nao mudar; alem disso, mesmo dentro da aba Preview o card chamaria `download_data_r` no primeiro render. O decoupling via projecao leve resolve raiz, nao sintoma.

## ADR-095: Ingestao de pacotes Camtrap DP (ZIP) com conversao para Darwin Core Occurrence Core e skip de remascara para linhas pre-generalizadas

- **Data**: 2026-05-20
- **Status**: Aprovado
- **Contexto**: Pesquisadores que trabalham com armadilhas fotograficas publicam dados no padrao Camtrap DP (Frictionless Data Package: `datapackage.json` + `deployments.csv` + `media.csv` + `observations.csv`). Hoje a Saira so aceita um CSV/XLSX achatado de ocorrencias, o que forca quem baixa pacotes de Wildlife Insights / Agouti / GBIF a converter manualmente para DwC antes do upload — friccao alta e propensa a erro. Alem disso, parte desses pacotes ja chega com coordenadas generalizadas pelo publisher (politicas de protecao de especies sensiveis aplicadas upstream). O pipeline atual de `mask_sensitive_coordinates()` (ADR-090/092/094) sobrescreve incondicionalmente — empilhando generalizacao sobre dado ja generalizado e descartando metadados (`dataGeneralizations`, `informationWithheld`) que o publisher possa ter populado.
- **Decisao**:
  1. **Upload como ZIP unico**: `R/mod_upload.R` ganha um `bslib::input_switch` "Subir pacote Camtrap DP". Quando ligado, `file_kind()` aceita apenas `.zip` e valida via `is_camtrap_dp_zip()` (presenca de `datapackage.json` na listagem do zip). UI dinamica: o dropzone hint troca para o copy Camtrap DP, e o painel "campos DwC obrigatorios" e substituido por uma lista compacta dos 4 arquivos esperados. Modos pre-existentes (CSV de dados; TXT de mapping guide ADR-087) seguem inalterados quando o switch esta desligado.
  2. **Conversao para Darwin Core Occurrence Core via `camtrapdp::write_dwc()`**: `R/utils_camtrap.R` (puro, sem Shiny) implementa `is_camtrap_dp_zip()`, `read_camtrap_dp_zip()` (descompacta em tempdir, chama `camtrapdp::read_camtrapdp()` no descriptor, tolerando layout root ou nested), e `convert_camtrap_to_dwc_occurrence()` (chama `camtrapdp::write_dwc()` para um tempdir e le `dwc_occurrence.csv` de volta via `read_biodiversity_csv()` — reuso direto do detector de encoding/delimitador testado). A saida e uma `data.frame` plana que entra no pipeline existente como `raw_data()`, preservando o contrato ADR-054 do `mod_mapping`.
  3. **`camtrapdp` em `Suggests`, nao `Imports`**: o pacote arrasta dependencias pesadas (`V8`, `jsonld`, `EML`, `jqr` — com requisito de sistema `libjq-dev`). Mantendo em Suggests, o instalador padrao da Saira nao precisa do toolchain extra; quem ativar o modo recebe um erro amigavel via `require_camtrapdp()` se o pacote nao estiver presente. Mesmo padrao de `rnaturalearthhires` (cache opcional para mapas em alta resolucao).
  4. **Skip de remascara via dois sinais ortogonais**: `mask_sensitive_coordinates()` em `R/utils_sensitive.R` ganha a constante `SENSITIVE_ALREADY_MASKED_THRESHOLD_M = 1000` (metros). Uma linha e tratada como pre-generalizada pelo publisher (e *completamente pulada*) se *qualquer um* dos sinais abaixo bater:
     - **`coordinateUncertaintyInMeters >= 1000`** — captura Chapman categorias 2 (`round_coordinates(x, 1)` ~ 11–15 km) e 3 (`round_coordinates(x, 2)` ~ 1.1–1.6 km).
     - **`dataGeneralizations` nao-vazio** — captura Chapman categoria 4 (`round_coordinates(x, 3)` ~ 112–157 m, abaixo do threshold numerico). Per PDF do `camtrapdp` v0.5.0 p.26: "dwc:dataGeneralizations: set if x$coordinatePrecision is defined" — ou seja, o sinal e *garantido por contrato* pelo pacote upstream sempre que houver generalizacao, nao e heuristico.
     
     Linhas puladas: nao entram em `result$masked` (preservam coordenadas + metadados originais incluindo `dataGeneralizations`/`informationWithheld` se populados upstream) e nao entram em `result$real` (nao temos os originais para registrar). Contador `result$n_skipped_already_masked` adicionado para transparencia em UIs futuras de relatorio. **Decisao revisada apos leitura do PDF**: a primeira rodada da v1 usava apenas o sinal numerico — leitura do PDF revelou que isso re-mascararia pacotes generalizados via `round_coordinates(x, 3)`, sobrescrevendo o `dataGeneralizations` que o publisher preencheu.
  6. **Conversao via retorno invisivel do `write_dwc()` (PDF p.25)**: `write_dwc(x, directory)` escreve `occurrence.csv` + `multimedia.csv` + `meta.xml` no disco e tambem retorna invisivelmente `list(occurrence = <tibble>, multimedia = <tibble>)` com os dados transformados (verificado empiricamente contra `camtrapdp` v0.5.0). `convert_camtrap_to_dwc_occurrence()` captura esse retorno (`result[["occurrence"]]` com fallback `result[[1]]`) em vez de reler do disco — mais rapido, sem dependencia de filename, e mais robusto a renomeacoes entre versoes do pacote.
  7. **Mensagem de sucesso explicita filtragem para `observationType = "animal"` (PDF p.25)**: `write_dwc()` so emite linhas de Occurrence para observacoes de animais — humanos, veiculos, blanks, unknowns e unclassified ficam de fora. A i18n `upload_camtrap_success` cita esse filtro explicitamente para o usuario nao ser surpreendido por uma contagem menor que a do pacote original.
  5. **Escopo v1 deliberadamente reduzido**: so ingestao. Nao reconstruimos pacote Camtrap DP no export (esse caminho saudavel para round-trip de validacao/republicacao foge do proposito Darwin Core da Saira e dobraria a superficie de testes). Nao oferecemos Event Core como target (Occurrence Core encaixa direto no resto do pipeline, Event exigiria adaptar `mod_mapping`/`mod_preview`/`utils_export`).
- **Consequencias**:
  - `DESCRIPTION`: bump `0.2.6` -> `0.3.0`; nova entrada `camtrapdp (>= 0.3.0)` em Suggests; nova linha `'utils_camtrap.R'` em Collate.
  - i18n: 7 chaves novas (`upload_camtrap_toggle`, `upload_camtrap_dropzone_hint`, `upload_camtrap_expected_files_title`, `upload_camtrap_success`, `err_camtrap_invalid_zip`, `err_camtrap_pkg_missing`, `sensitive_skipped_already_masked`).
  - CSS: regra unica `.upload-mode-toggle` em `inst/app/www/css/13-upload.css` (zero `!important`, orcamento mantido em 11/13). Bundle regenerado via `data-raw/build_css.R`.
  - Testes: novo arquivo `tests/testthat/test-utils-camtrap.R` (7 testes — 6 estruturais + 1 conversao-real com `skip_if_not_installed("camtrapdp")`; fixture construida em tempfile dentro do teste para evitar versionar binario). Novo caso em `test-utils-sensitive.R` cobrindo `n_skipped_already_masked` e preservacao de metadados. Fixture compartilhada `make_df()` ajustada: `coordinateUncertaintyInMeters` da row 1 de `"3000"` para `"100"` — valor era incidental ao teste de pmax(existing, grid_uncertainty); novo limiar de 1000 nao afeta o ponto original do teste.
  - Pipeline: `mask_sensitive_coordinates()` agora skips em vez de overrita. Comportamento de "nunca abaixar uncertainty pre-existente" via `pmax()` continua valido apenas no intervalo `[grid_uncertainty, 1000m)`. Acima de 1000m, a linha e considerada pre-generalizada e nao tocada.
- **Alternativas rejeitadas**:
  - ~~**Honrar tambem `informationWithheld` / `dataGeneralizations` nao-vazios como sinais de pre-mask**: mais robusto (sinais TDWG explicitos), mas o usuario optou por um sinal unico para nao multiplicar superficie.~~ **PROMOVIDO PARA A DECISAO (item 4)** apos leitura do PDF do `camtrapdp` v0.5.0 p.26: a populacao de `dataGeneralizations` por `write_dwc()` quando `coordinatePrecision` esta definido e um *contrato* documentado, nao uma heuristica frouxa. Honrar esse sinal cobre 100% dos casos de generalizacao via `round_coordinates()` upstream. `informationWithheld` continua de fora — sinal menos consistente entre publishers, pode entrar em uma evolucao futura se aparecer caso real.
  - **Multi-arquivo via `fileInput(multiple = TRUE)`**: aceitaria 4 CSVs descompactados de uma vez. Mais flexivel para quem ja extraiu o pacote, mas dobra validacao (conjunto completo? ordem? extras?) e exige rework do dropzone. ZIP unico casa com como GBIF/Wildlife Insights/Agouti exportam por padrao.
  - **Event Core como target**: mais fiel ao modelo camtrap (uma linha por evento com observacoes associadas) mas exigiria adaptar todas as etapas do pipeline downstream. Adiavel para uma evolucao futura se aparecer demanda real.
  - **Export de volta em Camtrap DP (round-trip)**: aumentaria muito o escopo da v1 e foge do proposito DwC da Saira.
  - **`camtrapdp` em Imports**: forcaria todo instalador da Saira a ter `libjq-dev` no sistema — quebra setups onde a Saira e usada so para o fluxo CSV tradicional.
  - **Heuristica geometrica de "coordenadas em grid redondo"**: tem falso-positivo (coords legitimas podem cair em grid por acaso). So util combinada com outros sinais; rejeitada para v1.
  - **Threshold mais alto (10000m)**: detectaria so generalizacoes obvias (>= 0.1 graus), mas perderia publishers que aplicam grade fina (0.01 graus ~ 1100m). 1000m e gentil mas captura a faixa relevante; ajuste futuro possivel se aparecer falso-positivo (ex.: rows com GPS legitimamente impreciso de 1-2 km).

---

## ADR-096: Ampliacao do modo Camtrap para CSVs soltos e exports Wildlife Insights (estende ADR-095)

- **Data**: 2026-05-20
- **Status**: Aprovado
- **Contexto**: A v1 do modo Camtrap (ADR-095) exigia que o ZIP contivesse `datapackage.json` — caminho canonico do `camtrapdp::read_camtrapdp()`. Na pratica, esse descriptor so existe quando o publisher monta o pacote Frictionless completo (ex.: publicacao via Agouti, GBIF Camtrap DP). A maioria dos projetos de armadilha fotografica nao chega assim: o Wildlife Insights — plataforma mais usada para gerenciar dados de camera trap em projetos com IA de reconhecimento — exporta uma pasta de CSVs proprietarios (`cameras.csv`, `deployments.csv`, `images_<project>.csv`, `projects.csv`) com colunas snake_case e schema proprio (`is_blank`, `wi_taxon_id`, `cv_confidence`, `number_of_objects`, `identified_by`), sem nenhum `datapackage.json`. O fluxo da v1 rejeitava esse upload com mensagem cripitica ("datapackage.json nao encontrado"), forcando o usuario a montar manualmente um descriptor — friccao alta, especialmente para usuarios de campo. Pesquisadores tambem podem ter apenas os CSVs Camtrap DP soltos (extraidos do pacote oficial, sem o JSON) e ficam bloqueados pelo mesmo motivo.
- **Decisao**:
  1. **Detectar tres formatos de entrada** no nivel do listing do ZIP (sem extracao):
     - **`datapackage_zip`**: contem `datapackage.json` (fluxo original ADR-095, inalterado).
     - **`camtrap_csv_zip`**: contem `deployments.csv` + `observations.csv` (com `media.csv` opcional) e *nao* contem `datapackage.json`. Sao CSVs Camtrap DP soltos.
     - **`wildlife_insights_zip`**: contem `deployments.csv` + `projects.csv` + pelo menos um `images*.csv`. E um export Wildlife Insights.

     `detect_camtrap_source(path)` retorna a constante string ou `NA_character_`. `is_camtrap_dp_zip()` virou shim `!is.na(detect_camtrap_source(path))`, mantendo o branch no `mod_upload.R` sem renomes em cascata.
  2. **Sintetizar descriptor Frictionless minimo para os dois novos formatos**: `synthesize_camtrap_descriptor(dir, lang)` constroi via `list()` -> `jsonlite::write_json(auto_unbox = TRUE)` um `datapackage.json` apontando para Camtrap DP 1.0.2 (ultima versao suportada pelo `camtrapdp` per PDF p.17). Cada recurso (`deployments` / `media` / `observations`) leva `profile = "tabular-data-resource"` (string literal, exigida pelo `frictionless`), `format`, `mediatype`, `encoding`, e `schema` apontando para a URL oficial do table-schema do tdwg/camtrap-dp 1.0.2. O descriptor e gravado no tempdir do upload e consumido pelo mesmo `camtrapdp::read_camtrapdp()` do fluxo v1. `id` usa `urn:uuid:` com 16 bytes via `ids::random_id()` (ja em Imports); evita `uuid` como dependencia direta.
  3. **Normalizador Wildlife Insights -> Camtrap DP**: `wi_to_camtrap_csv(input_dir, lang)` le os 4 CSVs do WI e escreve `deployments.csv` + `media.csv` + `observations.csv` em `<input_dir>/_camtrap_normalized/` com o conjunto **completo** de colunas canonicas do Camtrap DP 1.0.2 (mesmo as opcionais, com NA). Derivacoes nao-triviais:
     - **`observationType`**: cascata explicita — `is_blank == 1` -> `"blank"`; `genus == "Homo"` -> `"human"`; `class == "Vehicle"` ou `common_name` contem "Vehicle" -> `"vehicle"`; taxonomia toda em branco -> `"unknown"`; resto -> `"animal"`. Casa com o filtro de `write_dwc()` (PDF p.25) que so emite Occurrence para `"animal"`.
     - **`scientificName`**: cascata `paste(genus, species)` (se ambos) -> `genus` -> `family` -> `order` -> `class`; NA quando tudo em branco. Garante que linhas `"animal"` tenham nome cientifico minimo para o pipeline downstream de validacao.
     - **`classificationMethod`**: `identified_by == "Computer Vision"` -> `"machine"`, resto -> `"human"`. Espelha o vocabulario do schema oficial.
     - **`classificationProbability`**: WI grava `cv_confidence` em 0–100; reescalado para 0–1 quando o max da coluna for > 1. Bayesiano: tolera tanto datasets antigos quanto novos sem flag manual.
     - **`eventID` / `eventStart` / `eventEnd`**: `eventID = deploymentID` (agrupamento por deployment, conforme uso de `parentEventID` pelo `write_dwc()` PDF p.25); `eventStart = eventEnd = timestamp` (uma observacao = um evento media-level). Eventos temporais agregados (sequencing de fotos consecutivas) ficam para uma evolucao futura.
     - **`captureMethod`**: constante `"activityDetection"` (WI e motion-trigger por design).
     - **`favorite`**: deriva de `highlighted` em WI (boolean).
  4. **Set canonico de colunas obrigatorio**: as CSVs normalizadas precisam conter *todas* as colunas do table-schema 1.0.2, mesmo quando NA. Sem isso, `frictionless::read_resource()` (chamado por `camtrapdp::read_camtrapdp()`) le so as colunas declaradas no schema e descarta extras — e `camtrapdp::write_dwc()` quebra ao referenciar colunas como `.data$observationComments` que sumiram na leitura. Verificado empiricamente fazendo round-trip do `camtrapdp::example_dataset()` via `write_camtrapdp()` para extrair o conjunto exato de colunas que o schema espera (28 obs / 24 dep / 11 media).
  5. **Dispatcher unificado em `read_camtrap_dp_zip()`**: a funcao mantem assinatura e callsite no `mod_upload.R`, mas internamente faz dispatch via `detect_camtrap_source()`. Para WI: chama `wi_to_camtrap_csv()` -> `synthesize_camtrap_descriptor()` -> `camtrapdp::read_camtrapdp()`. Para CSVs soltos: chama so `synthesize_camtrap_descriptor()` -> `camtrapdp::read_camtrapdp()`. Anexa `attr(pkg, "saira_camtrap_source")` para o `mod_upload` mostrar o rotulo da fonte detectada no toast de sucesso, sem precisar repassar contexto por parametro.
- **Consequencias**:
  - `R/utils_camtrap.R`: cresce com `detect_camtrap_source()`, `synthesize_camtrap_descriptor()`, `wi_to_camtrap_csv()`, `wi_parse_timestamp()`, `wi_derive_observation_type()`, `wi_build_scientific_name()`, `wi_read_csv()`, `find_csv_root()`. `is_camtrap_dp_zip()` reduzido a shim de 1 linha. `convert_camtrap_to_dwc_occurrence()` inalterado.
  - `R/mod_upload.R`: painel de "arquivos esperados" troca de 4 chips estaticos para 2 grupos rotulados (Camtrap DP CSVs / Wildlife Insights). Toast de sucesso anexa o rotulo da fonte. Branch `file_kind()` inalterado (graca ao shim).
  - i18n: 3 chaves novas (`upload_camtrap_source_camtrap`, `upload_camtrap_source_wi`, `err_camtrap_wi_columns_missing`); 4 chaves reescritas removendo "(com datapackage.json + ...)": `upload_camtrap_dropzone_hint`, `upload_camtrap_expected_files_title`, `upload_camtrap_success`, `err_camtrap_invalid_zip`.
  - Testes: `tests/testthat/test-utils-camtrap.R` reescrito (11 blocos). Cobre deteccao das 3 fontes, shim, normalizador WI (4 categorias de `observationType`, cascata de `scientificName`, escala de `cv_confidence`, join camera make+model), descriptor sintetico (`profile` literal + recursos certos), e tres round-trips end-to-end (descriptor / CSVs soltos / WI) com skip limpo quando `camtrapdp` nao instalado ou URL do profile offline. Suite completa: 3876 PASS / 0 FAIL.
  - Sem mudanca em `DESCRIPTION`: `jsonlite`, `ids`, `zip`, `withr` ja em Imports; `camtrapdp` continua em Suggests.
- **Alternativas rejeitadas**:
  - **Mapear Wildlife Insights direto para Darwin Core Occurrence sem passar por Camtrap DP**: opcao mais curta em codigo (uma funcao de transformacao WI -> DwC), mas duplica a logica de `write_dwc()` (filtro animal-only, derivacao de `eventDate` / `samplingProtocol` / `samplingEffort` / `parentEventID` per PDF p.25). Manter o atalho Camtrap DP no meio reusa contrato auditado upstream e mantem o codigo da Saira pequeno (so a tabela de renomes WI -> Camtrap DP). Tradeoff aceito: precisa do `camtrapdp` instalado para WI tambem — ja era requisito do modo.
  - **Aceitar pasta de CSVs descompactada (multi-upload com `fileInput(multiple = TRUE)`)**: dobra a UI (validacao "todos os arquivos presentes?"), e os exports do WI ja chegam como pasta zipavel. ZIP unico mantem a UX consistente com o fluxo ADR-095.
  - **Reconstruir eventos por proximidade temporal (sequencing de fotos consecutivas)**: melhor fidelidade ao modelo camera-trap, mas exige tunning de threshold de minutos por especie/local. `deploymentID` como `eventID` e uma agregacao grosseira mas suficiente para o `parentEventID` que o `write_dwc()` ja produz. Refinamento adiavel se aparecer demanda concreta.
  - **Manter exigencia do `datapackage.json`** (status quo): rejeitado pelo proprio usuario na sessao de planejamento — descreveu como "a maioria dos projetos nao tem esse JSON". Era barreira artificial.
  - **Cachear o descriptor sintetico em `inst/extdata/`**: micro-optimizacao desnecessaria; gerar via `list()` + `jsonlite` custa milisegundos e mantem o codigo auto-contido (zero arquivo binario para versionar / atualizar).

## ADR-097: Refator do seletor de formato de upload — radiogroup estilizado como tabs (supersede parcial de ADR-095)

- **Data**: 2026-05-20
- **Status**: Aprovado
- **Contexto**: O seletor de formato CSV vs Camtrap DP introduzido em ADR-095 usava um `bslib::input_switch` ("Subir pacote Camtrap DP (ZIP)") no canto superior direito do card de upload. Feedback de UX classificou o componente como "debug UI": peso visual desigual entre CSV (modo default, sem affordance visual) e Camtrap (precisa "ligar" o switch para acessar), estado ativo pouco claro, e o painel "arquivos esperados" na coluna direita usava `.dwc-term-chip` com `padding: 2px 7px` e `border-radius: 4px` — visualmente apertado, parecia placeholder. A troca de modo causava reflow abrupto da coluna direita sem header consistente. A informacao de classe DwC (Record-level / Occurrence / Taxon / Location) com badges coloridos no modo CSV era boa e devia ser mantida — carregava semantica.
- **Decisao**:
  1. **Tab strip CSS-only sobre radiogroup HTML nativo** substitui o `input_switch`. Dois `<label class="upload-mode-tab" for="...">` linkam para `shiny::radioButtons(inputId = ns("upload_mode"), choices = c("csv", "camtrap"))` cujo wrapper `.upload-mode-tabs-input` esta `clip-rect` (visualmente escondido mas no a11y tree). Native radios preservam Tab + Arrow keys + screen reader sem JS adicional. Estado selecionado via `:has(input[value=X]:checked) .upload-mode-tab[data-mode=X]`.
  2. **Scaffold unificado `.format-requirements`** na coluna direita: header persistente `<h5>Requisitos do formato selecionado</h5>` + body que crossfade via `@keyframes format-req-fade` (220ms, opacity + 2px translateY; honra `prefers-reduced-motion`). `min-height: 220px` reserva espaco para evitar layout jump entre modos.
  3. **File-row component** (`.upload-file-list-group`, `.upload-file-row`) substitui os chips no modo Camtrap. Cada linha: icone Font Awesome + nome de arquivo em Space Mono + descricao em Source Serif 4 + badge `is-required` / `is-optional` a direita. 4 arquivos para Camtrap DP (datapackage.json / deployments.csv / observations.csv / media.csv) e 4 para Wildlife Insights (deployments.csv / projects.csv / images_*.csv / cameras.csv).
  4. **Chips coloridos por categoria DwC mantidos no modo CSV** — apenas refino de `padding: 2px 7px` -> `var(--space-1) var(--space-3)` (4px / 12px), `border-radius: 4px` -> `var(--radius-full)`, `gap: 5px` -> `var(--space-2)`. Cores `dwc-group-badge--{record-level|occurrence|taxon|location}` inalteradas (informacao semantica).
  5. **Rename `input$camtrap_mode` (boolean) -> `input$upload_mode` (factor "csv"|"camtrap")**: 4 read sites no `R/mod_upload.R` migrados para `identical(input$upload_mode %||% "csv", "camtrap")`. Contrato de retorno do `mod_upload_server` inalterado — modo continua local ao modulo (mantem ADR-054/ADR-087).
  6. **Helpers puros em `R/utils_upload.R`** (novo): `upload_csv_requirements_ui(required_terms, lang)` e `upload_camtrap_requirements_ui(lang)`. UI builders sem reactive, testaveis. O `output$dwc_required` no servidor reduz a 16 linhas (delega ao helper apropriado).
  7. **Live region polite** `aria-live="polite"` com `output$mode_change_text` anuncia "Formato alterado para X" / "Format changed to X" ao trocar modo.
- **Consequencias**:
  - `R/mod_upload.R`: UI cresce com tab strip + live region (60 linhas); `output$dwc_required` reduz de 113 linhas para 21 linhas (delegacao). 4 novos `output$mode_*` outputs.
  - `R/utils_upload.R`: novo arquivo, 2 funcoes puras (102 linhas total). Conforma `.claude/rules/r-package.md` ("business logic em pure utils_*.R").
  - `inst/app/www/css/13-upload.css`: deleta `.upload-mode-toggle`, adiciona `.upload-mode-tabs*` (+ 65 linhas), `.format-requirements*` (+ 25 linhas), `.upload-file-list*` (+ 75 linhas), refina `.dwc-term-chip` / `.dwc-inline-group-label`, regras `@media (max-width: 576px)` extendidas. Zero novos `!important` (contagem permanece 11/13 no bundle).
  - `inst/extdata/i18n.json`: +14 chaves novas (`upload_mode_csv_title`, `upload_mode_camtrap_title`, `upload_mode_tabs_a11y_label`, `upload_format_requirements_title`, `upload_camtrap_badge_required`, `upload_camtrap_badge_optional`, 7 `upload_camtrap_file_*` para descricoes serif, `a11y_mode_changed`); -2 chaves obsoletas (`upload_camtrap_toggle`, `upload_camtrap_expected_files_title`).
  - Testes: `tests/testthat/test-utils-upload.R` novo (22 assertions sobre os 2 helpers); `tests/testthat/test-mod-upload-server.R` estendido (+3 testes — render Camtrap rows, render DwC chips, rejeicao CSV em modo Camtrap). Total: 30 PASS.
  - **Supersede parcial de ADR-095**: o **item 1** da decisao original (`bslib::input_switch` + `.upload-mode-toggle`) e substituido. Os itens 2–7 (`is_camtrap_dp_zip()`, `read_camtrap_dp_zip()`, `convert_camtrap_to_dwc_occurrence()`, dependencia `camtrapdp` em Suggests, atributo `saira_camtrap_source`, mensagens `upload_camtrap_*`, mantem `dataGeneralizations`) permanecem inalterados.
- **Alternativas rejeitadas**:
  - **`bslib::navset_card_tab()` real**: cada `nav_panel` gera DOM proprio, exigindo dois `shiny::fileInput()` com IDs diferentes — duplica logica de upload, gera conflito de ID em testServer. Rejeitado.
  - **`bslib::input_segmented` ou similar**: nao existe em bslib estavel (>= 0.6) na data desta decisao. Implementar custom binding JS seria overkill para 2 valores.
  - **Cards selecionaveis grandes lado-a-lado** (icone + titulo + descricao em paineis): visualmente mais pesado, "marketing-y"; o usuario rejeitou explicitamente na fase de planejamento ("Tabs sobre o card" foi a escolha).
  - **Unificar tambem o modo CSV no padrao file-row**: rejeitado porque chips DwC representam *termos* (com classe + definicao), nao *arquivos*. Forcar para file-row apagaria o color-coding por classe DwC que e informacao semantica.

## ADR-098: Mascaramento de coordenadas sensiveis desligado por padrao (opt-in deliberado) e campos de coordenada verbatim zerados (supersede parcial de ADR-090/092/094)

- **Data**: 2026-05-21
- **Status**: Aprovado
- **Contexto**: Tres problemas convergentes no fluxo de mascaramento de especies sensiveis. (1) `mask_sensitive_coordinates()` escrevia o texto de `informationWithheld` em `verbatimLatitude`/`verbatimLongitude`/`verbatimCoordinates` nas linhas mascaradas — viola o Darwin Core, que exige campos de coordenada verbatim com coordenadas ou vazios, nunca prosa. (2) ADR-092/094 definiram o painel da aba Preview com mascaramento LIGADO por padrao ("conservador") e o nivel Extrema (1 grau) com selo "Recomendada"; a opcao "Nao sensivel — publicar sem mascaramento" recebia borda tracejada, icone de triangulo de alerta e paleta de aviso no estado selecionado. Visualmente o painel comunicava que mascarar era o caminho esperado e nao mascarar era a escolha de risco — o inverso da orientacao correta. (3) Feedback de pesquisador: coordenadas generalizadas, uma vez publicadas, podem ser reutilizadas em analises e influenciar politicas publicas de conservacao como se fossem precisas; mascarar deve ser uma decisao deliberada para especies ameacadas, nao um default.
- **Decisao**:
  1. **Campos de coordenada verbatim zerados**: em linhas mascaradas, `verbatimLatitude`/`verbatimLongitude`/`verbatimCoordinates` recebem `""`. Os demais leak fields (`footprintWKT`, `locality`, `verbatimLocality`, `georeferenceRemarks`, `locationRemarks`) seguem recebendo o texto de `informationWithheld` como wording de substituicao anti-reversao (Chapman sec. 3). Substitui o item 5 das ADR-090/092 que aplicava o texto a todos os leak fields indistintamente.
  2. **Mascaramento desligado por padrao**: `sensitive_generalization_rv` inicializa em `"not_sensitive"` (era `"low"`). Nenhuma coordenada e mascarada sem acao explicita do pesquisador. Supersede a parte "mascaramento LIGADO por padrao (conservador)" das ADR-092/094.
  3. **Sem nivel "recomendado"**: removido o selo "Recomendada" do cartao Extrema e a chave i18n `sensitive_card_recommended`; o texto "(recomendado)" sai de `sensitive_gen_extreme`. Escolher um nivel de mascaramento e sempre uma decisao do pesquisador.
  4. **Rebalanceamento visual** (mantendo o estilo de cartoes da ADR-094): o cartao "Nao sensivel" perde o icone de alerta e a paleta de aviso (`--warning`) no estado selecionado, passando a um estado neutro/calmo (`--hover-bg` + borda solida `--text-muted`) — le-se como o padrao tranquilo. Os cartoes de nivel alto e extremo, quando selecionados, exibem um alerta de impacto carmim suave (`--error-bg`/`--error-border`/`--error`, nunca vermelho vivo) dentro do cartao.
  5. **Frase de alerta + callout**: nova chave `sensitive_policy_warning` (alerta no cartao alto/extremo selecionado, sobre impacto em politicas publicas de conservacao); nova chave `sensitive_panel_guidance` (callout fixo info-style no painel, mascaramento como excecao); `sensitive_panel_lead` reescrita reforcando que o padrao e publicar sem mascaramento.
- **Consequencias**:
  - `R/utils_sensitive.R`: laco unico de leak fields dividido em `blank_cols` e `scrub_cols`.
  - `R/mod_preview.R`: `reactiveVal("not_sensitive")`; `card_label()` perde o parametro `recommended`/bloco de badge e ganha `warn`; `optout_label` sem icone; callout de orientacao adicionado entre o lead e a grade reusando o componente `.alert .alert-info` do design system (06-alerts.css).
  - `inst/extdata/i18n.json`: `sensitive_information_withheld` com separador `|`; +`sensitive_panel_guidance`, +`sensitive_policy_warning`; -`sensitive_card_recommended`; `sensitive_gen_extreme` e `sensitive_panel_lead` reescritas.
  - `inst/app/www/css/17-sensitive-panel.css`: removidas `.sp-card-top` e `.sp-badge-recommended`; adicionada `.sp-card-warning` e uma regra de margem panel-scoped para `.alert`; estado selecionado do opt-out neutralizado; regras do icone de alerta removidas. Zero novos `!important` (contagem permanece 11 no bundle).
  - Testes: `test-utils-sensitive.R` atualizado (verbatim zerados, separador `|`); `test-mod-preview-server.R` +1 teste (default `not_sensitive`).
- **Alternativas rejeitadas**:
  - **Manter mascaramento ligado por padrao** (postura ADR-092/094, "conservador"): rejeitado — coordenadas generalizadas publicadas por inercia podem distorcer analises e decisoes de politica publica; a decisao tem que ser consciente.
  - **Reordenar "Nao sensivel" para o topo da grade**: rejeitado — quebraria o contrato CSS `:last-child` da ADR-094; neutralizar o estilo do cartao resolve o desbalanceamento sem reordenar.
  - **Vermelho vivo no alerta dos niveis agressivos**: rejeitado a pedido do usuario; carmim suave (`--error-bg`) comunica cautela sem alarmismo.

## ADR-099: Painel de mascaramento reescrito como decisao em duas etapas (publicar vs. generalizar) com niveis por resultado espacial (supersede parcial de ADR-094/098)

- **Data**: 2026-06-09
- **Status**: Aprovado
- **Supersede parcial**: ADR-094 (cai a apresentacao "grade plana de 5 cartoes" e o contrato CSS `.radio:last-child`) e ADR-098 (caem o cartao "Nao sensivel" demovido, as chaves `sensitive_panel_lead`/`sensitive_panel_guidance`/`sensitive_policy_warning` e o `card_label(warn=)` por cartao). **Preserva**: o motor global de 5 niveis (ADR-094: `sensitive_generalization_levels/_grid`, `mask_sensitive_coordinates`), e de ADR-098 o mascaramento DESLIGADO por padrao (`reactiveVal("not_sensitive")`), a ausencia de nivel "recomendado" entre as grades de mascaramento, e o zeramento dos campos verbatim.
- **Contexto**: Mesmo apos a ADR-098 neutralizar o estilo do opt-out, o painel ainda era uma grade plana onde os 4 niveis de mascaramento ocupavam ~80% da area e o opt-out era o 5o item demovido. O layout continuava comunicando "escolha um nivel" (pergunta *qual mascaramento?*) em vez de "decida se precisa mascarar" (*eu preciso mascarar?*). Tres reforcos do vies: (1) os headlines eram a intensidade ("Extrema/Alta/Media/Baixa"), em que "Alta" soa como "mais protecao = melhor"; (2) o resultado espacial real (Estado/Pais) so existia como linha secundaria em `text-muted`; (3) a ordem ia da opcao mais destrutiva (Extrema, 1 grau) para a menos destrutiva, com a mais agressiva no canto superior esquerdo onde o olho comeca. O receio do usuario: a interface induzia uso excessivo de mascaramento.
- **Decisao**:
  1. **Decisao progressiva em duas etapas (progressive disclosure)**. Etapa 1: um `radioButtons` binario `sensitive_mode` em {`publish`,`generalize`} sempre visivel quando ha registros sensiveis. Etapa 2: o seletor de nivel `sensitive_level` em {`low`,`medium`,`high`,`extreme`} dentro de um `shiny::conditionalPanel(condition = "input.sensitive_mode == 'generalize'", ns = ns)`, revelado client-side so quando o usuario opta por generalizar (sem flash de re-render do servidor; o radio fica montado e seu valor permanece registrado).
  2. **"Publicar coordenadas originais" e o cartao primario, pre-selecionado, com selo "Recomendado"** (tratamento `--success`). Reposiciona o selo que a ADR-098 removeu: ele agora marca o caminho seguro (nao mascarar), nao um nivel de mascaramento — coerente com a orientacao da ADR-098.
  3. **Cartoes de nivel liderados pelo resultado espacial** (`sensitive_card_impact_*`: Area local / Cidade ou distrito / Estado ou provincia / Pais ou regiao) + a escala aproximada (~100 m / ~1 km / ~11 km / ~111 km); a categoria Chapman vira tag pequena de referencia (`sensitive_card_num_*`, "Categoria N"). O vocabulario de intensidade (`sensitive_card_name_*`) sai do UI de decisao e permanece apenas na tabela de referencia (`sensitive_gen_*`, Tabela 7 do Chapman no `<details>`).
  4. **Ordem ascendente (low->extreme)** com eixo de custo da esquerda (menor perda de precisao) para a direita (maior perda); faixa-gradiente verde->ambar->vermelho. Os niveis agressivos (3o=Estado, 4o=Pais) recebem cor de cautela na escala (`--warning`/`--error` via `:nth-child(3|4)`) e um **aviso escalonado** abaixo da grade (`sensitive_warn_high`/`sensitive_warn_extreme`), renderizado em output proprio (`sensitive_level_warning`) para que clicar num nivel re-renderize so o aviso, nao o painel inteiro.
  5. **Etapa 2 pre-seleciona `medium` (Cidade/Distrito, ~1 km)** ao entrar no modo generalizar — ponto de partida sensato que protege a localidade exata mas retem valor regional; o usuario move para menos (Area local) ou mais (com aviso).
  6. **Reducao dos dois inputs ao valor unico de export**: dois `observeEvent` (`sensitive_mode`, `sensitive_level`) reduzem a escolha ao `sensitive_generalization_rv` consumido por `mask_sensitive_coordinates(generalization, enabled = gen_level != "not_sensitive")`. Default `not_sensitive` preservado; nenhuma mudanca no motor nem no pipeline de export (ZIP byte-identico ao baseline quando se publica sem mascarar).
- **Consequencias**:
  - `R/mod_preview.R`: `output$sensitive_panel` reescrito (estrutura estatica que NAO le a selecao, eliminando o re-render do painel a cada clique da ADR-098); +`output$sensitive_level_warning`; observer unico `sensitive_generalization` substituido por dois (`sensitive_mode` + `sensitive_level`).
  - `inst/extdata/i18n.json`: +13 chaves (`sensitive_panel_intro` — com `<strong>`/`<span>` de enfase em MMA e "dados precisos", renderizada via `shiny::HTML()`; `sensitive_step_question`, `sensitive_mode_publish_title/_desc`, `sensitive_mode_recommended_badge`, `sensitive_mode_generalize_title/_desc`, `sensitive_level_prompt`, `sensitive_axis_low/_high`, `sensitive_warn_high/_extreme`, `sensitive_table_col_result`); -8 chaves orfas (`sensitive_panel_lead`, `sensitive_panel_guidance`, `sensitive_policy_warning`, `sensitive_card_name_*`, `sensitive_card_optout`).
  - Tabela de referencia Chapman enriquecida: 3a coluna "Resultado espacial" (mapeia categoria -> Area local/Cidade/Estado/Pais), swatch de custo verde->vermelho por nivel e linha "sem mascaramento" tingida como baseline seguro; container arredondado com faixa de cabecalho e zebra. Estilos em `17-sensitive-panel.css`.
  - `inst/app/www/css/17-sensitive-panel.css`: reescrito. Retirado o contrato `.radio:last-child`; novo contrato `.sp-level-radio .radio:nth-child(3|4)` para a sinalizacao de custo (ordem ascendente fixa). Zero novos `!important` (contagem do bundle permanece 11/13).
  - Testes: `test-mod-preview-server.R` +1 teste (reducao mode+level -> valor de export); demais suites sem alteracao. `devtools::test()` verde (FAIL 0).
  - `DESCRIPTION` 0.6.0 -> 0.7.0.
- **Alternativas rejeitadas**:
  - **Manter a grade plana ajustando so o estilo** (postura da ADR-098): rejeitado — neutralizar cores nao remove o enquadramento "qual nivel?"; a grade de 4 cartoes ainda domina a area e empurra para mascarar.
  - **Etapa 2 sem pre-selecao (escolha explicita obrigatoria)**: considerado para minimizar mascaramento acidental, mas o usuario preferiu pre-selecionar Cidade/Distrito (`medium`) — menos atrito, e o default ja nao e agressivo.
  - **Vermelho vivo nos niveis agressivos**: mantida a decisao da ADR-098 (carmim/ambar suaves, sem alarmismo).

## ADR-100: Avaliacao de sensibilidade POR ESPECIE (Chapman Tabela 5, agrupada por categoria MMA) em aba dedicada "Generalizacao", com mapa-guardrail (supersede o tier global da ADR-094 e a localizacao na Preview da ADR-099)

- **Data**: 2026-06-10
- **Status**: Aprovado
- **Supersede parcial**: ADR-094/ADR-099 (cai a "escolha livre de UM tier global" — a grade/cartoes de nivel deixam de definir o grau; e o painel sai da aba Preview). **Preserva**: o motor de 5 niveis e o mapeamento tier->grade (`sensitive_generalization_levels/_grid`), o mascaramento DESLIGADO por padrao (Etapa 1 "publicar", ADR-098), o zeramento dos campos verbatim e o skip de linhas ja generalizadas (ADR-095), e o arquivo companheiro privado de coordenadas reais.
- **Contexto**: O usuario leu Chapman (2020) secoes 2/2.1/2.2. A Tabela 5 ("Decision on release and category of sensitivity") e uma cascata de perguntas sim/nao que *deriva* a categoria (1-4 ou nao-sensivel), em vez de deixar o publicador escolher "de cabeca". Dois requisitos do usuario: (a) o nivel deve ser justificado pela cascata, nao arbitrario; (b) nunca omitir 100% das coordenadas (inutil a longo prazo). A cascata mapeia 1:1 nos tiers existentes: 4.2->Cat1/`extreme` (1 grau ~111 km), 4.3->Cat2/`high` (0.1 grau ~11 km), 4.4->Cat3/`medium` (0.01 grau ~1 km), 4.5->Cat4/`low` (0.001 grau ~100 m), tudo-nao->`not_sensitive`. O tier `extreme` do Saira ja e uma grade de 111 km (resultado regional), nunca remocao de coordenada — atende (b) sem mudanca no motor.
- **Decisao**:
  1. **Por especie, avaliado por grupo de ameaca**: o nivel passa a ser por especie, porem para nao exaurir o usuario com a cascata centenas de vezes, as especies sensiveis detectadas sao agrupadas pela categoria da lista nacional MMA (CR / EN / VU / CR (PEX), + um balde "other" para especies marcadas pelo pesquisador fora da lista). O usuario responde UMA cascata por grupo presente (no maximo 5); cada especie herda o tier do seu grupo. Um editor de excecoes (uma unica cascata compartilhada + `selectizeInput`) permite reavaliar uma especie individual, sobrepondo o grupo.
  2. **Substitui a escolha livre**: a grade de 4 cartoes de nivel (ADR-099) e removida; o nivel so se define respondendo a cascata. A Etapa 1 (publicar vs avaliar) e mantida (gate global opt-in).
  3. **Inavaliado = publicar como esta**: especies sensiveis cujo grupo nao foi avaliado sao publicadas sem generalizacao (presuncao de Chapman a favor da liberacao), com aviso "X de Y avaliadas" para nada ser silenciosamente super/sub-protegido.
  4. **Metadados (Chapman sec. 5)**: `dataGeneralizations` por linha passa a carregar a categoria + a *razao* Chapman (statements 4c-4f, chaves `sensitive_reason_cat1..4`) + uma **justificativa livre** do custodiante (um campo `textAreaInput`, opcional); adicionada uma data de revisao da sensibilidade (`dateInput`, padrao +2 anos, recomendacao gov. australiana de 2-5 anos) e um bloco de restricao de acesso (`<additionalInfo>`) no `eml.xml`, emitido so quando houve mascaramento e posicionado antes de `intellectualRights` (sequencia EML 2.1.1).
  5. **Aba dedicada (separar QA de decisao editorial)**: a avaliacao + generalizacao mora em uma **aba propria "Generalizacao"** (3o item do menu Validacao, depois de Nomes e Coordenadas), NAO espremida na aba de Coordenadas. Motivo: a aba de Coordenadas faz QA tecnico (lat/lon faltando, mar, zero/igual, referencia) e a generalizacao e uma decisao editorial/etica (Chapman, risco, justificativa, revisao) — dois modos mentais distintos cuja juncao sobrecarrega. A aba dedicada da ao mapa o papel de protagonista. A aba de Coordenadas volta ao estado de QA puro (revertida ao `main`); a *deteccao* de sensibilidade continua em Validacao de Nomes.
  6. **Mapa-guardrail proprio contra super-mascaramento**: a nova aba tem seu proprio `leaflet` desenhado para a tarefa: **circulo vazado = original**, **circulo preenchido (laranja) = generalizado**, **linha tracejada = deslocamento**, **vermelho = saiu do pais** (helper puro `generalization_map_preview`, reusa `coords_load_ne_land`/`sf`). Legenda fixa, popups com antes->depois e par de paises. Complementos de UX: **card de Resultado** ao vivo (registros, distribuicao por categoria, N cruzando fronteira, X de Y avaliadas); **grupos em acordeao** (`<details>`, 1o aberto, chip-resumo por grupo); **escada de pre-visualizacao** (clicar Cat 1-4 mostra o resultado daquela categoria no mapa, what-if); **alerta de fronteira em destaque** (card vermelho com par de paises + recomendacao "use Cat 2 em vez de Cat 1"); justificativa + data de revisao em secao final "Confirmar decisao"; tabela Chapman recolhida em `<details>`. Categoria 1 (`extreme`) exibe alerta vermelho com texto verbatim da Tabela 6 + nota (so baixa mobilidade/endemicas; onca = Cat 2). Demonstrado: onca no P.E. do Turvo em `extreme` salta para a Argentina, contradizendo `country`/`stateProvince`.
- **Implementacao**:
  - `R/utils_sensitive.R`: `mask_sensitive_coordinates(generalization=, justification=)` aceita string unica (compat) OU mapa nomeado `scientificName -> tier`; grade aplicada por linha (agrupada por valor de grade, reutilizando `generalize_coord`); justificativa anexada ao `dataGeneralizations`. +`sensitive_reason_statement`, +`resolve_row_tiers`, +`generalization_map_preview` (preview + flag de fronteira).
  - `R/mod_sensitive_coords.R` (NOVO modulo): hospeda a avaliacao (reativos `group_levels_rv`/`species_overrides_rv`/`species_levels_r`, 5 observers de grupo + 2 de excecao, badges, `actual_preview_r`), o mapa-guardrail proprio (`gen_map` + observers de originais e de overlay `gen_overlay`), card de Resultado, escada de pre-visualizacao (`preview_tier_rv`), alerta de fronteira, alerta Cat-1, legenda, secao Confirmar decisao e estado vazio; aplica `apply_coords_correction_payload`/`apply_country_fill_payload` para que o preview reflita o ponto publicado; retorna o reactive `{ levels, justification, review_date, enabled }`.
  - `R/app_ui.R`: novo `nav_panel` "sensitive_coords" no menu Validacao (apos Coordenadas); `R/app_server.R`: chama `mod_sensitive_coords_server` (recebe marks de Nomes + payloads de correcao de Coordenadas) e roteia seu payload -> Preview. **A aba de Coordenadas (`mod_validate_coords.R`, `utils_coords.R`, `15-validate-names.css` e seus testes) foi REVERTIDA ao `main` — sem perfil "Rapido" removido, sem mudancas.**
  - `R/mod_preview.R`: painel de sensibilidade removido; consome `sensitive_generalization_payload_r` (levels/justification/review_date/enabled) no export.
  - `R/utils_export.R`: `build_eml_xml` emite `<additionalInfo>` a partir de `metadata$sensitivity` (n_masked, review_date, lang).
  - `inst/extdata/i18n.json`: +chaves de cascata/grupos/razao/EML, +Cat-1 alert/nota, +justificativa, +`sensitive_map_crosses`, +`nav_generalize` e o conjunto `sc_*`/`sensitive_coords_*` da nova aba. (As chaves `validate_coords_profile_*` permanecem — a aba de Coordenadas nao mudou.)
  - `inst/app/www/css/17-sensitive-panel.css`: base `.sp-*` herdada via wrapper `.sensitive-panel`; +blocos da nova aba (`.sc-*`: pagina, card de Resultado, alerta de fronteira, legenda, escada, estado vazio). Zero novos `!important` (bundle 11/13).
  - Testes: `test-utils-sensitive.R` (per-especie, reason statement, resolve_row_tiers, justificativa, `generalization_map_preview`); `test-utils-export-dwca.R` (bloco EML); novo `test-mod-sensitive-coords-server.R` (cascata->tier, excecao, payload, estado vazio). Os testes da aba de Coordenadas voltaram ao `main`.
  - `DESCRIPTION` 0.7.0 -> 0.8.0.
- **Alternativas rejeitadas**:
  - **Tier global unico (status quo ADR-094)**: rejeitado pelo usuario — uma so escolha para todas as especies nao reflete que ameacas diferem por taxon.
  - **Cascata por especie (uma por taxon)**: fiel ao Chapman mas exaustiva (4 perguntas x N especies); rejeitada em favor do agrupamento por categoria MMA, que limita a ~5 cascatas e mantem resultado por especie via heranca + excecoes.
  - **Override por cartao livre nas excecoes**: rejeitado — reintroduziria escolha arbitraria; a excecao reusa a mesma cascata justificada.
  - **Manter o painel na aba Preview**: rejeitado — sem o mapa ao lado nao da para ver o super-mascaramento (Cat 1 jogando pontos para outro pais), que e o guardrail central.
  - **Espremer o painel na aba de Coordenadas** (tentativa anterior desta ADR): rejeitado apos revisao de UX (usuario + duas IAs externas) — sobrecarga cognitiva por juntar QA tecnico e decisao editorial; o mapa-overlay brigava com as pilulas e os pontos coloridos de issue do QA, e o deslocamento Original->Generalizado nao ficava legivel. O reuso de engenharia (mapa/`sf` ja na aba) nao compensava o custo no modelo mental.
  - **Aba dedicada (escolhida)**: o peso de +1 item de navegacao e baixo num app ja organizado por etapas, e o ganho e grande — o mapa vira protagonista e conta a historia do deslocamento (a onca barrada na fronteira), reforcando a narrativa do premio GBIF. O lookup de pais e helper puro, entao o modulo novo reusa a logica sem duplicar.
- **Refinamento de UX (2026-06-11)**: apos o primeiro contato, a aba ainda confundia. Ajustes (sem mudar motor/export):
  1. **Cascata limitada a Categoria 2**: `determine_tier` perde o ramo `extreme` (pergunta 4.2 sai). A Categoria 1 (~111 km) so e aplicavel via uma **excecao por especie explicita** (`exc_apply_cat1`), reservada a taxons de baixa mobilidade/endemicos.
  2. **Justificativa OBRIGATORIA para Cat 1/2/3**: o payload ganha `needs_justification`; o export (`mod_preview`) bloqueia com aviso quando ha mascaramento Cat 1/2/3 sem texto. Cat 4 (~100 m)/publicar seguem livres. Padrao da data de revisao passa a **+4 anos (48 meses)**, dentro da janela 2–5 anos de Chapman ("Review over time").
  3. **Mapa = ponto real + AREA publicada**: o ponto original vira marcador de alto contraste (anel escuro grosso + preenchimento branco, visivel no satelite); o destino vira o **retangulo da grade** (`leaflet::addRectangles`, `gen +/- g/2`), laranja translucido, **vermelho se a celula sai do pais**. Acaba a leitura "o ponto foi parar na cidade". Mapa reduzido (~400 px) e tabela Chapman ao lado.
  4. **Card de Resultado por especie**: uma linha por especie = pilula MMA + nome -> Categoria N · ~X km. As pilulas `sp-cat-pill--<cat>` passam a ter **cor distinta por categoria** (VU dourado < EN laranja < CR vermelho < CR(PEX) bordo), globais (servem painel e resultado).
  5. **Tabela Chapman em evidencia** (sai do `<details>`), ao lado do mapa, com a linha da Cat 1 marcada "somente casos extremos". Painel de avaliacao enxuto: toggle compacto publicar/avaliar, acordeao exclusivo (`<details name>`), lead sobre a Cat 1.

- **Refatoracao de arquitetura da informacao (2026-06-11, 2a passada)**: ainda com 4 regioes competindo (avaliacao, resultado, mapa, tabela) e o resultado divorciado do mapa, a tela foi reorganizada em **duas colunas: `Decidir` (esq.) | `Consequencia` (dir.)** (sem mudar motor/export/contrato `sensitive_mode`). Supersede partes dos pontos 3 e 5 acima:
  1. **Resultado por especie passa a ficar ACIMA do mapa**, na mesma coluna de "consequencia", para que *resposta -> categoria -> resultado espacial* leia como um objeto so (resultado e mapa sao a mesma informacao em duas codificacoes). `.sc-result` perde o `position: sticky`.
  2. **Cards de estrategia restaurados**: o toggle segmentado (`.sc-mode-toggle`) volta a ser os **dois cards coloridos** "Publicar originais" (verde, recomendado) / "Avaliar sensibilidade" (azul), reusando `.sp-mode-radio` (o usuario sentiu falta do design). CSS `.sc-mode-toggle/.sc-toggle-rec` removido.
  3. **Tabela Chapman -> faixa-escala fina (chips) + tabela fixa**: uma **faixa sempre visivel** sob o mapa (chips Cat 4->1 com km, cada um com seu ponto de cor; o chip "e se" ativo se preenche com a cor da categoria) funde **legenda do mapa + pre-visualizacao + a escala Chapman**; a tabela descritiva completa fica **fixa logo abaixo** (testamos o `bslib::popover` "Tabela completa" mas o usuario achou ruim de clicar -> revertido para painel fixo elegante). Regras `.sensitive-grid-table`/`.sp-grid-swatch` permanecem **globais** (a tabela renderiza em `.sc-consequence-col`, fora de `.sensitive-panel`).
  4. **Grupos mais escaneaveis**: linha de progresso "X de Y grupos avaliados" (`groups_progress`), grupo aberto destacado (`.sp-group[open]` so border, sem sombra), lista de especies como chips, e um explicador unico **"Como funciona a cascata"** (popover, texto curto em lista) no lugar de legalese sempre-ligado.
  5. **Justificativa por categoria**: `justification_prompt` mostra uma orientacao especifica por categoria em jogo (Cat 1/2/3), no lugar de um placeholder generico.
  6. **Fix do mapa (z-order)**: os dois observers (marcadores + celulas) foram fundidos num so pintor que desenha as celulas primeiro e os marcadores "Origem" por ultimo; sob `preferCanvas` a ordem de desenho = ordem de z, entao o marcador real deixava de aparecer sob o retangulo da area de generalizacao. Bundle CSS mantem 11 `!important`.
  7. **Fix do mapa (zoom)**: o pintor nao chama mais `fitBounds`/`setView`; o enquadramento acontece UMA vez por dataset (assinatura dos pontos de origem em `map_fitted_sig_rv`). Antes, cada clique numa pilula what-if reenquadrava o mapa, e a mesma categoria parecia ter tamanhos diferentes em zooms diferentes. Renomes: "Onde esta" -> "Origem", "Area publicada" -> "Area de generalizacao".

## ADR-101: Incerteza de coordenada generalizada alinhada ao point-radius (centro -> canto mais distante), com poligono da celula em footprintWKT (refina ADR-100)

**Contexto.** O `coordinateUncertaintyInMeters` das linhas mascaradas era a **aresta** da celula (`ceil(g x 111320)`, fator plano), que **superestima ~41-50%** o raio real e ignora a convergencia dos meridianos. O *Georeferencing Best Practices* (Chapman & Wieczorek 2020, sec. 2.3.4) e o *Quick Reference Guide* (Zermoglio et al. 2020, sec. 2.3.3) prescrevem, para uma celula publicada como point-radius: coordenada no **centro corrigido** da celula e raio = **distancia do centro ao canto mais distante** (meia-diagonal geodesica); e que o **ideal** e tambem gravar a celula como **poligono** (bounding box, sec. 2.3.4). A sec. 3.4.7 (Combined Uncertainties) diz para **combinar** as fontes, nao tirar o `max`.

**Decisao.**
1. **Raio geodesico centro -> canto mais distante.** Nova `geo_distance_m()` (haversine, R medio WGS84) e `sensitive_grid_uncertainty_m(grid, gen_lon, gen_lat)` calcula o maximo das 4 distancias centro->canto. Depende da latitude (o canto mais distante e o voltado para o equador). Ex.: 0,1deg -> ~7.863 m no equador, ~7.356 m a -30deg (antes: 11.132 m em qualquer lugar).
2. **Combinacao aditiva.** `coordinateUncertaintyInMeters = ceil(raio_celula + incerteza_original)` em vez de `pmax`. Como as linhas com incerteza >= 1000 m sao puladas (ADR-095), o termo original e sempre pequeno; o resultado e o limite garantido de contencao (BP sec. 3.4.7).
3. **`footprintWKT` + `footprintSRS`.** Cada linha mascarada grava o **poligono da celula** (`POLYGON ((...))`, ordem lon lat, anel fechado) e `EPSG:4326`. O `footprintWKT` sai da lista de scrub anti-reversao (o poligono e a celula grosseira, seguro). O snap continua `round(raw/g)*g` (= centro da celula ±g/2, ja correto para point-radius; o canto SW seria "wasteful" pelo BP).
4. **Mapa: circulo de incerteza.** `generalization_map_preview` ganha coluna `unc_m`; o mapa desenha um circulo tracejado de raio `unc_m` (a visao GBIF/point-radius) circunscrevendo o quadrado da celula — fecha a Figura 2 do Chapman (quadrado = celula, circulo = incerteza). Legenda "Incerteza (raio)".

**Consequencias.** Valores DwC exportados mudam (incerteza menor e mais honesta; novas colunas footprint). Mais usabilidade (nao superestima). `quarter-degree`/grids continuam validos. Snap inalterado.

## ADR-102: Correcoes de coordenada refletidas em toda a aba Coordenadas (mapa/tabela/contagens) via familia "corrected"; perfil rapido removido; mapas leaflet estabilizados

**Contexto.** As correcoes aceitas (transposta / preencher-pais / troca+pais) eram um payload aplicado so na exportacao e na Generalizacao; a propria aba Coordenadas continuava mostrando o ponto cru sinalizado (ex.: ponto no mar) ate o export, o que confundia o usuario ("corrigi e nada mudou aqui"). Alem disso: (a) o seletor de perfil `complete/fast` era uma decisao sem valor real (todo dataset deveria rodar as checagens de referencia); (b) os pills de filtro colidiam em cor (referencia = mar = `--info` navy; todas = problemas = accent); (c) dois bugs de render leaflet so-no-browser (ver LESSONS) deixavam marcador desatualizado/sumido.

**Decisao.**
1. **Reflexo em toda a aba.** Nova pura `apply_coord_corrections_to_result(res, coords_corrections, country_fills, occ_ids)` sobrepoe as correcoes ao resultado de `validate_coords_cc_df()`; uma reativa `effective_validation_r()` alimenta **mapa, tabela e contagens** (antes liam `coord_validation_r()` direto). Match por `occurrenceID` capturado no momento da validacao (`rv$validation_occ_ids`, alinhado a `.row_index`) — robusto a reordenacao posterior.
2. **Familia `corrected` (resolvida, nao-problema).** Linhas cuja coordenada mudou viram `diagnostic = diagnostic_family = "corrected"`: cor teal propria (`--coord-corrected #0e7c86`), badge e item de legenda dedicados; **excluidas da contagem de "problems"** (`count_coords_diagnostics`) mas **ainda visiveis** sob o filtro "problemas" (para o usuario ver o ponto migrar do mar para a terra). Preenchimentos de pais atualizam so o valor `country`.
3. **Perfil unico.** Removido o `radioButtons("coord_profile")` (UI/i18n/CSS); a validacao roda sempre `profile = "complete"` (as quatro checagens CoordinateCleaner de referencia). `validate_coords_cc_df()` mantem o parametro `profile` (default complete) por compatibilidade de testes.
4. **Pills alinhados a legenda do mapa.** `reference` -> `--coord-swapped` (roxo, como o dot da legenda; antes navy = mar); `all` -> `pill-muted` (neutro), `problems` -> accent. Seis pills distintos.
5. **Estabilidade leaflet (ver LESSONS).** `gen_map` ganha `suspendWhenHidden = FALSE` (repaint via proxy nao e descartado com a aba oculta). O `renderUI` do container do mapa de Coordenadas (`output$map_panel`) depende SO de `coord_validation_r()` — nunca de `effective_validation_r()`/correcoes — senao recria o widget leaflet a cada correcao e quebra o proxy (sintoma: filtro "Todas" esvaziava o mapa). Item de legenda "Corrigida" passa a ser sempre exibido (fora da dependencia de dados).
6. **Mensagens.** Os tres toasts "aplicada na exportacao" passam a "ja vale na generalizacao e exportacao".

**Consequencias.** A aba Coordenadas vira a fonte unica de verdade visual das correcoes (mapa/tabela/contagens consistentes com o que sera publicado). `coord_family_levels` ganha `"corrected"`. Sem mudanca no payload de export nem no contrato downstream (Generalizacao/Preview seguem aplicando os mesmos payloads). Refina o fluxo de QA das ADR-090/100; nao altera o motor de mascaramento. Zero `!important` novo.

## ADR-103: Aba "Exportacao" como hub de revisao-e-publicacao; fluxo de download realocado da Preview; arquivos auxiliares nomeados pelo dataset

**Contexto.** O botao de download e todo o subsistema de exportacao DwC-A (validacao de termos -> modal de confirmacao -> modal animado com canais de mensagem -> `downloadButton` oculto -> `downloadHandler` que monta o .zip) viviam na aba **Preview**, que deveria ser so leitura. Nao havia uma superficie unica de "revise antes de publicar": o usuario nao via, num so lugar, o que foi corrigido, quais especies serao generalizadas e quais arquivos sairao. Feedback do usuario: (a) "cade o botao de exportar .zip?" — pouco evidente; (b) deveria ser **bloqueado** ate todos os termos obrigatorios estarem mapeados; (c) faltava um indicador de prontidao (health score) e um alerta de risco de alto contraste; (d) os arquivos auxiliares tinham nomes genericos com data (`dwc_export_DATE.xlsx`) em vez de nomes ligados ao dataset.

**Decisao.**
1. **Nova aba Exportacao = hub de revisao + publicacao.** Ultimo passo do fluxo (depois da Generalizacao, antes da Wiki). A Preview vira **somente leitura** (`mod_preview_server(id, mapped_data_r, lang_r)` — sem args de download). O `app_server` repassa os payloads de validacao/generalizacao e os reativos de download para o `mod_export_server`.
2. **Download realocado VERBATIM.** O subsistema sai da Preview para `R/mod_export_download.R::mount_export_download(input, output, session, ...)`, montado de dentro do `mod_export_server` (mesmo namespace). Corpo movido sem reescrever o JS/canais para preservar o fluxo animado (escolha explicita do usuario: "mover o fluxo atual com modal animado"). Botao **"Baixar Pacote .ZIP"** em destaque no topo-direito do cabecalho.
3. **Gate de prontidao sem contradicao visual.** Quando a exportacao esta bloqueada, o botao .ZIP fica **cinza/inerte** (classe `is-inert`, sem `btn-success`) — nunca um botao verde chamativo ao lado de um banner vermelho de erro. A acao verde/clicavel mora **dentro do banner**: "Corrigir termos faltantes ->" (vai para Mapeamento) ou "Adicionar justificativa ->" (vai para Generalizacao), via callback `on_navigate(tab)` -> `bslib::nav_select("main_nav", tab)` no `app_server` (mesmo padrao da auto-nav). O estado do botao usa o **mesmo `export_blocked`** do banner (reativa `blocked_r` passada ao `mount_export_download`), nao so a checagem local de termos — assim botao e banner nunca se contradizem (ex.: justificativa pendente com termos OK bloqueia ambos).
4. **Resumo via pura `build_export_summary()`, layout de relatorio.** Sem logica de export nova: agrega correcoes (nomes corrigidos/confirmados, coords, paises), especies generalizadas (com categoria MMA + tier), prontidao (`readiness_pct`, termos presentes/faltando), `export_blocked`/`justification_pending`/`occurrence_id_present` e a lista de arquivos. Layout em **duas colunas assimetricas** (`flex`: principal ~460px para prontidao + tabela de especies, que precisam de largura; lateral ~300px para correcoes + arquivos) que colapsa para uma coluna e deixa a pagina rolar em vez de espremer o conteudo. UI: **anel de health-score** como heroi do card de prontidao (`conic-gradient` por `--pct`; contagens registros/termos viram texto simples ao lado, sem caixas cinzas; chips de termo aprovado ficam neutros com check verde para o laranja "faltando" saltar), **banner de severidade** (vermelho = bloqueado; amarelo = sem occurrenceID; verde = pronto), **cards de correcao com opacidade reduzida quando valor = 0**, **pills de ameaca reusando `.sp-cat-pill--*`** (mesmas cores das abas Nomes/Generalizacao — VU ouro, EN laranja, CR vermelho), **tooltips de regra** (icone i) na categoria e na generalizacao.
5. **Nomes de arquivo pelo dataset (fonte unica).** Nova pura `export_bundle_filenames(dataset_name, has_sensitive)` (+ `slugify_dataset_name`) compartilhada entre o resumo e o handler. O **trio DwC-A** (`occurrence.txt`, `meta.xml`, `eml.xml`) **mantem os nomes-padrao** (exigencia do IPT/GBIF); os **auxiliares** sao renomeados com slug-do-dataset e hifens: `<slug>-occurrences.xlsx`, `<slug>-mapping-guide.txt`, `<slug>-sensitive-coords.csv` (CSV real so quando ha mascaramento); o proprio .zip vira `<slug>-dwc-archive.zip`. Slug derivado de `custom_values_r()$datasetName` (transliterado para ASCII, minusculo, runs nao-alfanumericos -> hifen); fallback `saira`. Datas saem dos nomes (ja constam em `meta.xml`/`eml.xml`).

**Consequencias.** Preview e Export tornam-se responsabilidades separadas e limpas. `build_export_summary` e `export_bundle_filenames` sao puras e unit-testadas; o resumo e o .zip nunca divergem nos nomes. Reusa `validate_preview_download_requirements`, `mask_sensitive_coordinates`, `apply_*_payload`, `build_meta_xml/eml_xml`, `write_xlsx_text_only`, `build_mapping_guide_txt` (orquestracao, nao reescrita). As chaves i18n de download (`preview_*`) seguem validas; novas chaves `export_*`. As classes do modal (`automap-loading-*`, `preview-export-*`, `preview-download-btn`) seguem no CSS — nada migrou. Zero `!important` novo (bundle = 11; 19 modulos CSS). Refina ADR-100/102; nao altera o motor de mascaramento nem o contrato de export.

## ADR-104: Camtrap DP mapeado por identidade deterministica (AUTO), colunas vazias descartadas, e gate de "input ja renderizado" no observer de sync

**Contexto.** Upload de Camtrap DP auto-registra extra-terms DwC como cards (ADR-095/096) e dispara o auto-map diferido. Tres problemas no fluxo, descobertos em teste manual:
1. **Colunas em branco.** `camtrapdp::write_dwc()` emite um schema fixo de Occurrence; termos sem dado na fonte voltam como colunas **inteiramente vazias** (ex.: `organismID`, `minimum/maximumDepthInMeters`, `identificationVerificationStatus`). Elas viravam cards de mapeamento vazios e colunas de preview so-com-titulo (e o usuario conseguia ate mapear uma a mao para um resultado vazio).
2. **Valor apagado.** O motor aplicava as selecoes (`set_map_value()` escreve `rv$map_values[[term]]` direto), mas o `observe` que sincroniza `input$map_<term>` -> `rv$map_values` recebe `NULL` de um `selectInput` em dois casos indistinguiveis pelo valor: (a) card ainda nao renderizado/ecoado; (b) usuario limpou a selecao. Tratava NULL-com-valor-anterior como (b) e escrevia `""`, apagando o valor programatico na janela entre o set e o eco. Base-terms sobreviviam so por ecoarem primeiro.
3. **Badge errado.** Rodar o motor fuzzy em dado de identidade rebaixava os exact-matches de extra-terms para SUGERIDO (regra "extra-term nao ganha AUTO") e ainda inventava cross-matches espurios (ex.: coluna `decimalLatitude` sugerida para o termo `verbatimLongitude`, applied).

**Decisao.**
1. **Descartar colunas all-blank na conversao.** `convert_camtrap_to_dwc_occurrence()` filtra colunas onde toda celula e NA/vazia (`scientificName` e garantido nao-vazio, entao o nucleo sempre sobrevive). Nada vazio chega ao mapeamento/preview/export.
2. **Gate "ja renderizou" no observer de sync.** Rastrear num `new.env(parent = emptyenv())` **nao-reativo** (`rendered_map_inputs`) quais `map_<term>` ja reportaram valor nao-NULL ao menos uma vez; so interpretar `NULL` como user-clear se o termo ja estiver marcado — senao `next`. Env nao-reativo de proposito (escrever nele nao re-dispara o observer); resetado por upload junto do `preview_cache`. Como `mapping_ui` (`renderUI`) le `rv$map_values[[term]]` **reativamente** para o `selected`, o card nasce selecionado a partir do estado — `updateSelectInput` nao e necessario.
3. **Mapa por identidade para camtrap.** `perform_auto_map()` despacha para `perform_camtrap_automap()` quando `attr(raw_data_r(), "saira_camtrap_source")` existe: cada coluna cujo nome e um termo DwC vira `set_map_value(term, term)` com meta `status = "AUTO", reason = "exact_match"`. Pula o motor fuzzy (sem downgrade, sem ambiguidade, sem cross-match espurio). Vale para o botao "Auto-map" manual e o trigger diferido. Uploads nao-camtrap seguem no motor (o downgrade de extra-term continua valido la, onde o nome coincidente nao garante intencao).

**Consequencias.** Campos de camtrap renderizam pre-preenchidos, badge AUTO, sem colunas/cards vazios. `rv$rostrum_decisions` fica NULL para camtrap (estado de identidade, nao ha decisao fuzzy a explicar) — ja era um estado valido (consumidores de `rostrum_run_stats[["run_id"]]` ja tratam NULL). User-clear real continua funcionando (input ja visto -> NULL vira `""`). Testes: `test-utils-camtrap.R` afirma o descarte de colunas vazias no round-trip canonico; `test-mod-mapping-server.R` reescrito para afirmar `status == "AUTO"` e `rv$map_values` retidos (antes checava decisoes do motor, que agora nao roda para camtrap). Lição generalizada em LESSONS (sync input->estado grava "ja renderizou" fora do canal reativo; e write_dwc fabrica schema fixo com colunas vazias). Sem mudanca de contrato, i18n, CSS ou DESCRIPTION.

## ADR-105: Clamp de precisao na generalizacao (Chapman 2020) -- nunca arredondar para grade mais fina que a existente, mas sempre documentar

**Contexto.** A generalizacao de coordenadas (ADR-090/095) arredonda para uma grade mais grossa por tier (extreme=1, high=0.1, medium=0.01, low=0.001). Mas aplicar uma grade *mais fina* que a precisao que o registro ja tem fabrica precisao inexistente: `generalize_coord("-81.41", 0.001)` -> `-81.410`, sugerindo ~110 m quando o dado so tem 2 casas (~1.1 km). Chapman 2020 e explicito: generalizacao **reduz** precisao, nunca a aumenta (glossario "precision"/"randomization"; sec. 4.1). A 1a iteracao desta ADR fazia *skip* (pular) das linhas iguais-ou-mais-finas -- **errado**: o skip dropava toda a documentacao de protecao (`informationWithheld`, `dataGeneralizations`, scrub de `locality`/verbatim), expondo um registro sensivel. Chapman sec. 5.1 exige a metadata record-level de sensibilidade **independentemente** de a coordenada mudar. Usuario validou contra os PDFs do Chapman exigindo 100% de conformidade.

**Decisao.**
1. **Helpers puros** em `utils_sensitive.R`: `coordinate_decimal_grid(x)` (grade implicita pelas casas decimais, lida da string literal para preservar zeros a direita -- Chapman glossario "precision": 2 casas = 0.01 grau; sem ponto -> grade 1; blank/NA -> NA), `existing_precision_grid(df)` (grade mais grossa por linha entre `decimalLatitude`/`decimalLongitude` e a coluna `coordinatePrecision`; NA quando nao ha sinal) e `sensitive_already_masked_rows(df)` (gate ADR-095 extraido, fonte unica).
2. **Clamp no export** (`mask_sensitive_coordinates`): apos o skip ADR-095, `grade_efetiva = pmax(grade_escolhida, precisao_existente)` por linha -- nunca mais fina que o dado. A linha **NAO e pulada**: e mascarada e documentada na grade efetiva (coords, `coordinatePrecision`, `coordinateUncertaintyInMeters`, footprint, `dataGeneralizations`, `informationWithheld`, scrub). Contador `n_clamped_to_precision` (linhas onde o nivel escolhido era mais fino que o dado). O loop de mascara passou a agrupar por `eff_grid` em vez de `row_grid`.
3. **Precisao provida + retida** (Chapman sec. 4.3 / 5.1): `coordinatePrecision` = grade provida; alem disso `dataGeneralizations` ganha a precisao **original retida** (`sensitive_precision_stored`, i18n) -- nao ha termo DwC adotado para "precisionDataStored", entao vai no texto. Ordem do paste mantem a justificativa do custodiante por ultimo (teste depende disso).
4. **Consistencia no preview** (`generalization_map_preview`): exclui so as linhas ja generalizadas upstream (ADR-095, preservadas) e **clampa** as demais (mostra todas, geradas na grade efetiva). Anexa `attr "n_clamped_to_precision"` e `"n_upstream_preserved"`.
5. **Banner visivel** na aba Generalizacao (`mod_sensitive_coords.R`, `output$precision_lock_alert`): soma os dois atributos e informa quantos registros saem na precisao real do dado. i18n `sc_precision_lock_desc`; CSS `.sc-precision-lock-alert` (estilo info, **flat: borda uniforme, sem barra/sombra a esquerda** -- ver [[card-no-shadow]]).

**Consequencias.** A generalizacao nunca aumenta a precisao aparente E nunca deixa um registro sensivel sem protecao -- 100% alinhado a Chapman 2020 (sec. 4.1-4.3, 5.1, glossario). So `decimalLatitude`/`decimalLongitude`/`coordinatePrecision` inferem precisao (robusto a strings). Fixture com coords de 1 casa + tier `high` (0.1) que virava no-op foi ajustada para 4 casas (preserva o ponto do teste). Testes reescritos em `test-utils-sensitive.R` (helpers + clamp no mask + preview) e `test-mod-sensitive-coords-server.R` (banner com coords inteiras -> clamp para 1 grau). Zero `!important` novo (bundle = 11; 19 modulos CSS). Refina ADR-090/095; nao altera o contrato de export.

## ADR-106: Valores fixos generalizados para termos de nivel-dataset (estende ADR-005)

**Contexto.** A ADR-005 deu inputs customizados de "valor fixo" a quatro termos Record-level (`datasetName`, `modified`, `license`, `language`). Outros termos de nivel-dataset frequentemente tambem precisam de um unico valor constante em TODAS as linhas (`rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation`, `geodeticDatum`). Sem isso, a unica saida era fabricar uma coluna — errado. Reusa o padrao provado do `datasetName` (isolamento da leitura no card builder, ADR-098) para nao reabrir o loop infinito renderUI<->observer.

**Decisao.**
1. **Allowlist unica** `constant_value_terms()` em `utils_dwc.R` — fonte unica consumida por card builder, coletor, observers de meta e injetor de export. Exclui deliberadamente `datasetName/modified/license/language` (mantem seus inputs dedicados da ADR-005), `countryCode` (derivado na aba de validacao de coordenadas) e `basisOfRecord` (tem o assistente por-valor).
2. **UI opt-in sem poluir** (`mod_mapping_cards.R`, `build_constant_value_input`): no card generico, checkbox `usecustom_<term>` que **revela** (via `conditionalPanel`, client-side, sem re-render) uma faixa info "preenche TODAS as linhas" (`.field-allrows-note`) + `textInput` `custom_<term>`. O card fica inalterado ate o opt-in. Leitura do valor isolada (`isolate`) — ADR-098. `geodeticDatum` usa text (placeholder `EPSG:4326`); sem vocab controlada one-off.
   - **Borda "mapeado" e badge EDITADO ao vivo sem re-render.** Como o read do free-text (e do `rv$map_meta`) e isolado no renderUI, a borda verde e o badge so atualizariam no proximo render. Os observers de meta (`input$custom_<term>`/`input$usecustom_<term>`, ~250 ms apos parar de digitar) recomputam o mesmo `is_field_mapped()` e o mesmo `build_badge_info()` do renderUI e enviam `saira-toggle-field-mapped` (custom message; piggyback no IIFE ja existente em `mod_mapping.R`): o JS alterna `field-mapped`/`field-unmapped` e sincroniza o `.field-status-badge` (cria/atualiza/remove) so naquele `#fieldcard_<term>`. Sem re-render (sem blur), sem `shinyjs`, e o estado setado coincide com o proximo render completo (sem divergencia).
   - **Mutuamente exclusivo com o mapeamento de coluna.** Um divisor "OU" (`.field-or-divider`, regra com texto centralizado) separa o seletor de coluna da opcao de valor fixo. Enquanto `usecustom_<term>` esta ligado, o seletor de coluna (com sample e o divisor "OU") e **escondido** por um segundo `conditionalPanel` (`!input.usecustom_<term>`). Sem `shinyjs` (nao e dependencia), o swap client-side e o caminho mais simples e sem risco de loop para tornar a precedencia visivel: o card expressa um intento por vez e uma coluna mapeada nao pode ser silenciosamente sobrescrita pelo valor fixo no export. Destravar (desmarcar) reexibe o seletor com a selecao preservada. O checkbox traz uma dica de consequencia de uma linha (`.fixed-value-hint`, `mapping_fixed_value_hint`: "Ignora o mapeamento e aplica este valor em tudo.") e a faixa info reforca o alcance (`mapping_fills_every_row`: "Este valor preenchera TODAS as linhas deste campo ao exportar os dados.").
3. **Alcance dos termos fora do default.** A opcao aparece em qualquer card presente; termos fora do conjunto base (`references`, `bibliographicCitation`, `geodeticDatum`) ficam acessiveis pelo botao "Adicionar termo" ja existente — a opcao surge assim que o termo e incluido. Sem secao dedicada nova.
4. **Coletor + export.** `collect_constant_values()` (closure no server) le `input$usecustom_<term>`/`input$custom_<term>` sobre a allowlist; reusado por `custom_values_r` (serializacao do mapping guide) e por `build_mapped_result`. `build_processed_mapping_df` ganha `constant_values = list()`: no loop de termos, replica o valor em todas as linhas (`rep`) com precedencia sobre o mapeamento de coluna. Cobre preview e export (ambos chamam `build_mapped_result`); `mod_export*` consome `processed_data_r` sem mudanca.
5. **Coexistencia no export.** `apply_geodetic_datum()` (so preenche linhas vazias) preserva um `geodeticDatum` fixo do usuario; `geodeticDatum` NAO e preenchido na validacao de coordenadas (so no boundary de export, `utils_export.R`).

**Consequencias.** Sete termos de nivel-dataset ganham valor fixo opt-in aplicado a toda a planilha, sem fabricar colunas e sem tocar o UX validado de `datasetName/license/language` (ADR-005 intacta). i18n: `mapping_use_fixed_value`, `mapping_fills_every_row`, `const_placeholder_<term>`. CSS: `.field-allrows-note` (faixa info flat, sem `!important`; bundle = 11, 19 modulos). Tutorial do site (PT+EN, pagina de mapeamento) ganha secao nova com placeholders de imagem. Testes em `test-mod-mapping-server.R` e `test-utils-mapping.R`. Estende ADR-005; reusa ADR-098; nao altera o contrato de retorno de `mod_mapping_server()` (apenas amplia o named list de `custom_values_r`).

## ADR-107: Status de conservacao (IUCN global + MMA nacional) no dynamicProperties, aditivo por provedor, com o primeiro request de rede do app

**Contexto.** O archive publicado nunca registrava o status de ameaca de um taxon, embora metade ja estivesse disponivel localmente: a lista nacional MMA empacotada (`inst/extdata/sensitive_species.rds`) e a categoria IUCN global exposta pelo GBIF num endpoint sem chave. Auto-popular o `dynamicProperties` no export agrega valor real. Decisao do dono: **sempre incluir** (sem checkbox opt-in) e mostrar uma **contagem resumida** acima do report (sem badge por linha, para nao mexer no DT de validacao). As fontes sao **aditivas, atreladas aos provedores que a pessoa escolheu**, nao mutuamente exclusivas. Este e o primeiro request externo do app no boundary de export.

**Decisao.**
1. **Aditivo por provedor (nao exclusivo).** Em `mod_validate_names`, um `conservation_payload` reativo expoe `include_mma <- length(intersect(selected, br_provider_ids)) > 0L`, `include_iucn <- "gbif" %in% selected` (o GBIF e pre-selecionado, entao IUCN fica ligado por padrao salvo se a pessoa o desmarcar) e `taxon_keys = df(scientificName, taxonID, provider)`. As duas fontes podem coexistir num mesmo objeto: `{"mmaThreatStatus":"CR","mmaSource":"Portaria 1.704/2026","iucnRedListCategory":"NT"}`. Um taxon que o GBIF nao avalia simplesmente fica so com as chaves MMA.
2. **Chaves limpas + merge sem concatenacao manual.** Saida MMA = `mmaThreatStatus` (codigo VU/EN/CR/CR (PEX)) + `mmaSource` (portaria); IUCN = `iucnRedListCategory` (o campo `code` do GBIF, ex. `NT`). `merge_dynamic_property(existing, key, value)` (`utils_mapping.R`, ao lado de `build_dynamic_properties_json`) reserializa o objeto plano `{"k":"v"}` reusando `json_escape_string` e a convencao sem-whitespace; vetorizado, `value` NA/blank deixa a linha intacta (nunca escreve chave vazia). String-ops a mao, NAO `jsonlite::toJSON` (ADR-086).
3. **Rede opcional e nao-bloqueante (`utils_threat_status.R`).** `httr2` em **Suggests**; `requireNamespace` gate, `req_timeout` curto, `tryCatch` total e qualquer falha (pacote ausente, offline, erro HTTP, payload inesperado) vira `NA` — nunca quebra nem trava o export. `fetch_gbif_iucn_category(usage_keys)` le `…/species/{key}/iucnRedListCategory` (`code`); `gbif_match_usage_keys(names)` e o fallback keyless `/species/match` so para linhas sem `taxonID` do GBIF. usageKey vem do `taxonID` que o taxadb ja resolveu (strip do prefixo `GBIF:` para a chave numerica nua). Memo por sessao via `create_rds_cache("gbif_iucn"/"gbif_match")` (ADR-014). Como o GBIF e o provedor padrao, IUCN passa a ser o caso **comum**, nao a excecao.
4. **Proveniencia MMA (coluna `source`).** `data-raw/generate_sensitive_species.R` passa a varrer sequencialmente os marcadores de secao (`ANEXO 1/2/3`) e taggear cada linha com a portaria (flora 148/2022, fauna terrestre 1.704/2026, fauna aquatica 1.667/2026); o RDS regenerado ganha `source`. `load_sensitive_species()` injeta `source = NA` para um RDS antigo (backward-compatible); `sensitive_source_for(names)` espelha `sensitive_category_for()`.
5. **Aplicacao no export.** `apply_conservation_status(df, payload)` (`utils_export.R`) roda em `mod_export_download` logo **apos** `apply_name_review_payload` (ve o `scientificName` corrigido) e **antes** de `process_for_export_with_unmapped` (a coluna `dynamicProperties` criada/atualizada herda a ordenacao canonica de graca). Cada fonte e envolvida num `tryCatch` independente: uma falha de rede no IUCN nunca derruba as chaves MMA locais nem o export. O `conservation_payload` e threaded `mod_validate_names` -> `app_server` -> `mod_export_server` -> `mount_export_download` (slot novo com default `NULL`, backward-compatible).
6. **UI (sem checkbox, sem badge por linha).** Uma contagem resumida (`conservation_status_summary_ui` em `mod_validate_names_helpers.R`) acima do report mostra quantos registros recebem MMA (contagem local exata) e quantos serao consultados no IUCN no export. Sem coluna nova no DT.

**Consequencias.** Primeiro request de rede do app (degrada para NA, nunca bloqueia — ver LESSONS). `DESCRIPTION` 0.8.6 -> 0.9.0; `httr2` em Suggests; `Collate` ganha `utils_threat_status.R`; novas funcoes ficam internas (`@noRd`) para evitar dessincronizar `NAMESPACE`/`man`. i18n: `validate_names_conservation_summary_mma`/`_iucn`. CSS: `.vn-conservation-summary`/`.vn-conservation-line` (flat, sem `!important`; bundle = 11). RDS regenerado mantem 4486 taxa. Testes: `merge_dynamic_property` (`test-utils-mapping.R`), `fetch_gbif_iucn_category`/`gbif_match_usage_keys` mockados em `test-utils-threat-status.R`, `apply_conservation_status`/`resolve_iucn_usage_keys` em `test-utils-export.R`, `sensitive_source_for` + backward-compat em `test-utils-sensitive.R`. Reusa ADR-086 (dynamicProperties), ADR-014 (cache), ADR-092 (lista sensivel).
