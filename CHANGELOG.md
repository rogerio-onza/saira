# Changelog

Todas as mudancas notaveis do Finch sao documentadas aqui.
Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).

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
- Classe CSS compartilhada `.finch-table-shell` para padrao visual de DataTables no app inteiro
- Novas chaves i18n de DataTable na validacao de coordenadas (search/length/info/empty/zero/paginacao)
- Diretriz tecnica documentada para uso de `.finch-table-shell` em novas tabelas (`docs/LESSONS.md`) e decisao arquitetural formal (`ADR-030`)

### Alterado
- Estilo da tabela de preview aplicado de forma consistente nas tabelas de `validate_names`, `validate_coords` e `wiki` (header, busca, length menu e paginação)
- Wrappers de tabela unificados para usar `.finch-table-shell` em todos os modulos com `DT::datatable`
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
