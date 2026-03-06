# Licoes Aprendidas

Conhecimento reutilizavel extraido do desenvolvimento do Saira.
Indexado por **tema** -- consulte antes de implementar algo similar.

---

## R Package Structure

- **Linhas vazias no DESCRIPTION** quebram `pkgload::load_all()`. Todo campo deve seguir imediatamente o anterior.
- **Todo pacote usado com `::`** precisa estar no `Imports` do DESCRIPTION. Exemplo: `here`, `jsonlite`.
- **`pkgload::load_all()`** carrega todos os arquivos de `R/` automaticamente -- nao precisa de `source()` em cada modulo.
- **Diretorio de trabalho**: `pkgload::load_all()` precisa ser chamado a partir do diretorio que contem `DESCRIPTION`.
- **Rename de pacote sem compat legada exige varredura por string literal**: atualizar `Package`, `library()`, `test_check()`, `system.file(package=...)`, `asNamespace()` e `getFromNamespace()` no mesmo ciclo evita ambiente parcialmente quebrado.

## Shiny / Reactive Patterns

- **`uiOutput` fica vazio no carregamento inicial**: o container HTML existe no DOM desde o primeiro render, mas o conteudo so chega apos o servidor processar o `renderUI` e enviar via WebSocket. Para titulos de nav e outros elementos proeminentes, incluir texto estatico como fallback visual e esconde-lo via CSS (`:has(:not(:empty))`) elimina o flash de branco sem remover a reatividade de idioma.
- **`renderUI` recria inputs** a cada invalidacao. Usar `isolate(input$...)` para preservar valores do usuario entre re-renders.
- **Controles externos de DataTable renderizados via `renderUI`** devem usar eventos delegados (`$(document).on(...)`) com namespace por instancia; binding direto no elemento tende a quebrar busca/filtros quando o DOM e recriado.
- **Checkboxes de selecao unica**: `checkboxGroupInput` + `observeEvent` no server para forcar single-select. Mantem a estetica de checkbox quadrado.
- **Loops bloqueantes** em Shiny sincrono nao atualizam UI durante execucao. Progresso real requer HTML estatico + atualizacao JS client-side.
- **`shiny::toJSON`** pode nao estar disponivel em todas as versoes. Preferir `jsonlite::toJSON(...)` com dependencia declarada.
- **`uiOutput` em `placeholder`** de `fileInput` nao funciona. Usar `update*` no server.
- **Inputs dinamicos em paginas/modal**: evitar `observe` continuo lendo todos os `input$*` do conjunto; sincronizar estado por snapshot em eventos explicitos (ex.: `Salvar`, `Anterior`, `Proxima`) reduz cascata reativa.
- **`downloadButton` com label dinamico**: evitar `uiOutput` aninhado dentro do proprio `downloadButton`; renderizar o botao completo via `renderUI` em um container dedicado.
- **`downloadButton` ja tem icone padrao**: ao montar label com `icon("download")`, definir `icon = NULL` ou usar label textual + argumento `icon` explicito para evitar duplicacao visual.
- **Confirmacao antes de download**: para modal de confirmacao/progresso, usar `actionButton` visivel e acionar um `downloadButton` oculto via `sendCustomMessage` preserva o `downloadHandler` sem quebrar UX.
- **Validacao taxonomica longa tambem precisa de modal bloqueante**: em fluxos com `taxadb`, usar barra/fases estimadas client-side no padrao Rostrum evita percepcao de travamento.
- **Evitar `req()` silencioso em handlers de acao (`observeEvent`)**: em botoes de validacao/export, prefira checagem explicita com `showNotification` para nao aparentar "clique sem efeito" quando o reactive upstream estiver vazio.
- **Nao conectar output de visualizacao rapida a reactive de processamento completo**: se a tabela de preview depender do mesmo reactive usado para export completo, qualquer remapeamento pode bloquear a UX.
- **Separar canais reativos por intencao de uso**: manter um `reactive` leve para UI (`head(...)`) e um `reactive` completo para acoes explicitas (download/validacao) reduz latencia percebida sem perder fidelidade no arquivo final.
- **Nao usar `mapped_data` completo para habilitar botao de acao**: checagens de prontidao de UI (ex.: habilitar `Validar nomes`) devem depender de sinal leve do modulo de origem, nao de pipeline completo.
- **Gates reativos leves evitam latencia na troca de abas**: apos mapear `scientificName`, voltar para a aba de validacao pode ficar lento se `quick_inputs()` materializar `processed_data`; um gate com `status = no_data/missing_scientific/ok` elimina esse acoplamento.
- **Para validacoes distintas, use gates leves distintos**: compartilhar gate de nomes na aba de coordenadas gera contrato ambiguo; prefira um gate dedicado (`validation_gate_coords`) com campos especificos do dominio.
- **Compatibilidade progressiva em modulos Shiny**: ao introduzir canal reativo leve novo (`validation_gate_r`), manter fallback legado para `mapped_data_r()` evita quebrar chamadas antigas de `mod_validate_names_server`.
- **Gate leve nao pode quebrar quando upstream usa `req()`**: se o gate consome reactive de upload (`raw_data_r`) que faz `req(input$file)`, capturar `shiny.silent.error` e retornar estado estavel (`no_data`) evita UI em branco antes do upload.
- **Em encadeamento por flags (`start_requested`/`run_requested`), `ignoreInit = TRUE` pode suprimir o primeiro ciclo util**: quando a flag muda de `FALSE -> TRUE` pela primeira vez, o observer pode nao executar em ambiente de teste. Para eventos internos de orquestracao, preferir `ignoreInit = FALSE`.
- **`session$onFlushed()` nem sempre e a melhor ancora para teste de servidor**: para fluxos de execucao sincrona em `testServer`, disparo direto de estado costuma ser mais estavel que depender de flush de UI.
- **Quando o modulo define filtro pos-execucao por padrao (ex.: `problems`)**, os testes devem refletir esse contrato antes de afirmar contagem de `all`.
- **Feedback imediato em clique + trabalho pesado**: em `observeEvent` de acao longa, usar estrategia em duas fases (`starting` agora + processamento pesado no proximo flush com `session$onFlushed`) evita o efeito de "cliquei e nada aconteceu".
- **Filtro de stream sensivel a status deve ser server-side quando afeta decisao de UX**: manter `stream_filter` em `reactiveValues` evita divergencia entre estado visual e estado de dados (dispensa `runjs` para regra de negocio).
- **Quando houver estado pre-validacao sem dados, substituir empty-state por instrucoes acionaveis** melhora escaneabilidade sem tocar na logica de execucao.
- **Assets estaticos CSS podem ficar stale no browser** em iteracoes de UI. Adicionar versionamento no `href` (`custom.css?v=...`) reduz falso negativo de validacao visual.
- **Dropzone custom sobre `fileInput` deve preservar o input real**: se for remover a caixa nativa (`.input-group`), reanexar o `input[type=file]` no container custom e manter `dispatchEvent("change")` garante compatibilidade com o binding do Shiny.
- **`dataTransfer.types` varia entre navegadores**: para detectar arquivos no drag-and-drop, usar fallback em cadeia (`contains`, `indexOf`, `item`) evita regressao silenciosa quando `includes` nao esta disponivel.
- **Contratos de atributos reativos compartilhados devem ser validados por capacidade**: antes de consumir `attr(reactive, "validation_gate")`, checar se os campos esperados existem; em ausencia, aplicar fallback seguro no dado canonico.
- **Quando uma aba precisa expor metadados para outra sem quebrar contrato de retorno**, anexar um atributo reativo opcional (ex.: `review_export_payload`) e manter fallback nulo no consumidor evita breaking change.
- **Modal multi-etapa em Shiny deve ser centralizado em helper unico**: alternar modos por estado (`rv$mode`) reduz duplicacao de observers e evita drift de comportamento entre caminhos de confirmacao/edicao.
- **Web components com nome de tag customizado (ex.: `<lottie-player>`) nao devem ser criados com `shiny::tags$`**: em cenarios com hifen no nome da tag, isso pode disparar `attempt to apply non-function`. Preferir HTML explicito (`shiny::HTML(...)`) ou construcao de tag custom segura.
- **Falha visual nao pode bloquear fluxo funcional**: em eventos de arranque (`start_requested -> run_requested`), envolver `showModal()` em `tryCatch` e manter o disparo do processamento mesmo quando a UI de loading falhar.
- **Em rework de modulo para shell tri-coluna, consolidar outputs por intencao (config/stream/report)** reduz acoplamento entre cards e evita cascata de re-render em layouts com muitos `uiOutput`s fragmentados.
- **Toolbar externa de DataTable em modulo reativo exige eventos delegados com namespace por instancia** para manter busca/paginacao funcionais apos recreacao de DOM por `renderUI`.
- **Fallback de startup em modulo deve ser tipado e observavel**: quando dependencia estatica falha (ex.: `get_dwc_terms()`), retornar estrutura vazia com schema esperado + log explicito evita crash silencioso.

## CSS / Bootstrap / bslib

- **`fileInput` gera `input-group`** do Bootstrap. Nao forcar flex externo -- estilizar o `input-group` diretamente.
- **Variaveis CSS referenciadas no codigo devem existir no `:root`**. Gradientes com variaveis indefinidas resultam em UI invisivel (ex: texto branco em fundo transparente).
- **Evitar `!important` como estrategia padrao**: prefira seletores mais especificos e ordem de carregamento correta para sobrescrever estilos do tema `bslib`.
- **Boxes informativos nao devem usar borda grossa unilateral**: evitar padrao de "linha grossa na esquerda"; usar borda completa fina e semantica para `alert`, `notification` e caixas de suporte.
- **Seta de dropdown em pseudo-elemento deve usar escape CSS**: prefira `content: '\25BE'` em vez de caractere literal para evitar glitch de encoding (`â–¾`).
- **Navbar precisa de alinhamento explicito entre nav-links e seletor de idioma**: definir `align-items: center`, altura minima coerente e `gap` entre itens evita desalinhamento horizontal/vertical.
- **`selectInput` no navbar precisa de largura coerente com o padding interno**: manter `width` compativel com `padding-right` e `background-position` evita sobreposicao da seta sobre o texto selecionado.
- **`bslib::page_navbar` pode renderizar links como `ul.navbar-nav > li > a` (sem classes `.nav-item/.nav-link`)**: em regressao de espacamento/padding no header, estilizar tambem o markup `li > a` e nao depender apenas de classes BS5.
- **Seletor de idioma com poucas opcoes no navbar funciona melhor sem selectize**: usar `selectize = FALSE` evita sobreposicao visual da seta e reduz custo de inicializacao.
- **`border-radius` em inputs conectados**: primeiro elemento `X 0 0 X`, segundo `0 X X 0`.
- **`backdrop-filter: blur()`** em modais cria efeito "debaixo d'agua" indesejado. Usar escurecimento simples (`rgba(0,0,0,0.45)`).
- **Scroll container**: usar `scrollbar-gutter: stable` para evitar sobreposicao da barra de rolagem sobre conteudo.
- **`dataTables_length select` pode sobrepor seta e valor** quando herda padding generico de `form-select`; aplicar regra especifica com `padding-right` maior e `background-position` evita colisao visual.
- **Padrao oficial de tabelas do app**: toda `DT::datatable` deve ficar dentro de `.saira-table-shell` para herdar header azul, paginacao compacta e dimensoes consistentes de busca/length menu.
- **Ao alterar `pageLength` por controle externo**, aplicar `table.page.len(len)` seguido de `table.page('first').draw('page')` evita o falso sintoma de "nao mudou para 15" quando a tabela estava em pagina posterior.
- **Quando stats, filtros, mapa e tabela evoluem em ritmos diferentes**, prefira `uiOutput`s separados por painel em vez de um `results_panel` monolitico; isso reduz acoplamento de layout e simplifica manutencao.
- **Full-width por modulo e melhor com override contextual**: usar seletor local (`.tab-content > .tab-pane:has(.validate-coords-page)`) permite remover sobras laterais de uma aba sem quebrar o layout global.
- **Legenda de mapa deve seguir o contrato de dados usado em pills/tabela**: quando filtros usam familias (`validity`, `country`, `sea`, etc.), a legenda precisa usar as mesmas familias para evitar ambiguidade cognitiva.
- **Cores de cluster do Leaflet nao representam tipo de issue**: sempre explicitar em nota de UI quando clustering estiver ativo para evitar leitura errada da legenda.
- **`reference` precisa de explicacao textual na legenda**: sem contexto (capitais/centroides/GBIF/instituicoes), usuarios interpretam `reference` como erro absoluto de coordenada.
- **Mudanca de basemap deve ser rollout controlado**: se trocar tiles por vetor gerar regressao de exibicao de pontos/clusters, voltar rapido ao basemap padrao reduz risco para o usuario final.
- **`fitBounds` deve ser calculado no `leafletProxy` com os pontos filtrados**: usar bbox fixa na inicializacao cria viés regional e piora UX; com pills ativas, o enquadramento precisa refletir o subconjunto atual.
- **Quando a informacao e curta e essencial (onboarding/obrigatorios)**, prefira exibir categorias sempre visiveis em grupos compactos a esconder conteudo atras de tabs clicaveis.
- **Nao depender de `!important` para resolver regressao visual local**: priorizar estrutura de layout (grid/flex), seletores claros e ordem de carregamento previsivel.
- **Tooltip por hover em cards clicaveis precisa de fallback para touch**: em mobile/tablet, exibir descricao inline via media query (`hover: none`/`pointer: coarse`) evita perda de contexto.
- **Em dropzone de superficie inteira, separar copy visual do input nativo**: manter um bloco de texto central com `pointer-events: none` evita captura acidental de clique e simplifica evolucao de layout.
- **Ao mover texto funcional para dentro do ponto de acao, manter hierarquia tipografica do design system**: instrucao em `font-sans` e metadado tecnico (ex.: tamanho maximo) em `font-mono` melhora leitura sem poluir a interface.
- **Se o JS remove markup nativo em runtime, limpar CSS dependente desse markup**: evita regras mortas e estados visuais incoerentes apos refactor.
- **Redesign local de modulo deve usar escopo CSS dedicado**: para telas premium como `help` e `wiki`, prefira classes-raiz (`.help-module`, `.wiki-module`) para impedir regressao transversal em outras abas.
- **Acordeao renderizado por `renderUI` precisa de binding resiliente**: usar event delegation em `document` (`closest('[data-*]')`) evita perder eventos quando o DOM da aba e recriado por busca/idioma.
- **Para acessibilidade em acordeao custom, sincronizar estado visual e ARIA no mesmo ponto**: sempre atualizar `is-open`, `aria-expanded` e `aria-hidden` juntos evita discrepancia entre leitor de tela e animacao.
- **Layout tri-coluna com paineis laterais fixos fica mais estavel com token de offset de header no `:root`** (`calc(100vh - var(--offset))`) em vez de hardcode espalhado por seletor.
- **Quando paineis laterais fixos (240/340) precisarem de mais respiro, priorize full-width do shell antes de mexer nas larguras fixas**: remover `max-width` local e zerar padding lateral do `tab-pane` melhora espaco util sem quebrar contrato visual.
- **Em tabela estreita com 3 colunas no painel fixo, definir largura explicita por coluna e tipografia/celula por intencao reduz o efeito de espremido**: `scientificName` priorizada, `status` compacta e `taxonomicStatus` com quebra controlada.
- **Badges semanticos reutilizaveis (`badge-success/warning/error/info/muted`) simplificam consistencia visual** entre stream e tabela quando ambos representam o mesmo status de dominio.
- **Icone de busca em `textInput` custom so fica estavel com contrato completo de geometria**: use wrapper imediato com `position: relative`, icone absoluto com caixa fixa (`14x14`) e centralizacao real (`top: 50%` + `translateY(-50%)`), e reserve espaco no input com `padding-left` dedicado.
- **No card de busca do Shiny, zere o espacamento herdado antes de ajustar pixel**: definir `margin-bottom: 0` para `.shiny-input-container` e `.control-label` evita deslocamento vertical do icone e elimina o efeito de lupa "fora da caixa".
- **Troca de tipografia global exige tokens, nao hardcodes por modulo**: manter `font-family` literal (ex.: IBM Plex) em blocos locais cria regressao silenciosa; prefira `var(--font-*)` em todo componente reutilizavel.
- **Carregamento de Google Fonts deve ficar no shell da app (`app_ui`)**: evitar `@import` em `custom.css` reduz duplicacao de request e facilita governanca de versao/weights.
- **Adicionar `rel="preconnect"` antes dos `<link>` de CDN reduz latencia de fontes**: inserir preconnect para `fonts.googleapis.com`, `fonts.gstatic.com` (com `crossorigin`) e `cdnjs.cloudflare.com` antes dos stylesheets permite ao browser pre-estabelecer DNS + TCP + TLS antes de precisar dos arquivos, economizando 100-300ms em conexoes lentas.
- **CSS `:has()` e ferramenta valida para substituicao progressiva de conteudo reativo**: `.container:has(.dynamic:not(:empty)) .static { display: none }` esconde o fallback estatico assim que o servidor popula o elemento dinamico, sem JS adicional. Suporte amplo em browsers modernos (Chrome 105+, Firefox 121+, Safari 15.4+).
- **Mono em tamanhos muito pequenos (< 0.85rem) precisa de ajuste fino**: em badges/tabelas compactas, `letter-spacing` leve e `tabular nums` melhoram legibilidade sem alterar layout.
- **Animacao de remocao em listas reativas deve ter fallback de acessibilidade**: sempre adicionar `@media (prefers-reduced-motion: reduce)` para desativar transicoes de `fade/collapse`.
- **Backdrop de modal custom deve usar token de overlay do design system**: centralizar em `var(--overlay)` + blur leve evita divergencia de contraste entre modais.
- **`hidden.bs.modal` dispara no elemento `.modal`, nao em filhos**: ao registrar listener de cleanup em script dentro do modal body, usar `el.closest('.modal')` para subir ao ancestor correto; sem isso, eventos DOM que borbulham para cima nunca alcancam o listener e o cleanup nunca executa.
- **Quando `resolve_review_target()` retorna NULL, feedback ao usuario e obrigatorio**: retorno silencioso sem notificacao viola LESSONS de UX (evitar `req()` silencioso em handlers de acao) e impede diagnostico pelo usuario.

## i18n / Internacionalizacao

- **Todo texto visivel** deve passar por `tr(key, lang_r())`. Strings inline do tipo `if (lang == "pt") "X" else "Y"` violam o sistema i18n.
- **Encoding UTF-8** deve ser verificado ao editar `data_dictionary.R`. Caracteres acentuados podem corromper se o editor salvar em Latin-1.
- **Encoding de metadados do pacote e mais seguro com escapes Unicode**: para campos como `Authors@R`/`Description`, `\uXXXX` reduz risco de mojibake entre editores/SO.
- **Placeholder de `selectInput`** nao aceita `uiOutput` -- usar `update*Input()` no server.
- **`DT::datatable` precisa de objeto `language` completo** em apps bilingues: incluir `emptyTable`, `zeroRecords` e `paginate.first/last/next/previous` evita sobras de texto no idioma errado.
- **Ao adicionar novas labels de tabela/filtros em modulo bilingue, atualizar a suite de i18n no mesmo ciclo** previne regressao silenciosa de traducao.

## DwC / Dados de Biodiversidade

- **Separador de entrada**: `;` (padrao brasileiro). Virgula NAO eh delimitador de tokens.
- **Separador de saida DwC**: ` | ` (pipe com espacos).
- **`scientificName`** eh campo de selecao unica -- nao aceitar multiplas colunas.
- **Validacao taxonomica**: deduplicar `scientificName` antes de consultar e depois propagar resultados por join.
- **Cascata de provedores**: primeiro provedor com match define o veredito; nao combinar provedores simultaneamente para evitar conflito taxonomico.
- **Falha parcial de provedor nao deve abortar cascata**: registrar erro por provedor e continuar com os demais aumenta resiliencia sem mudar contrato do relatorio.
- **`cc_coun` pode ser ruidoso em producao**: em bases com muitos pontos de costa/fronteira, mismatch de pais tende a gerar falso alerta operacional; trate como check opcional quando o foco e triagem rapida.
- **Fluxo principal de coordenadas deve priorizar sinais acionaveis**: para uso de produto, `sea`, `swapped` e `reference` costumam trazer melhor relacao utilidade/ruido.
- **Para checks de consistencia por pais no CoordinateCleaner, `countryCode` e obrigatorio na pratica**: quando planilha nao traz `countryCode`, converter `country` para ISO3 no pipeline evita bloquear o usuario por estrutura de entrada.
- **Conversao de pais precisa de fallback em cadeia, nao de origem unica**: tentar `iso3c`, depois `iso2c`, depois `country.name`, com mapa minimo de aliases comuns, reduz `country_unresolved` em dados heterogeneos.
- **Para aumentar cobertura sem inflar falso positivo, usar cascata em camadas**: `iso3c -> iso2c -> CLDR multilíngue -> aliases -> fuzzy` funciona melhor que pular direto para fuzzy.
- **Aliases de pais devem ficar em artefato versionado (`.rds`) e nao hard-coded em funcao**: isso reduz risco de regressao ao evoluir cobertura e facilita manutencao por script em `data-raw/`.
- **Fuzzy em nomes de pais precisa ser conservador e sempre ultima camada**: exigir tamanho minimo, limite de distancia relativa e melhor match unico evita conversoes erradas em siglas curtas.
- **Derivacao taxonomica**: a partir de `scientificName`, eh possivel derivar `genus`, `specificEpithet` e `taxonRank`. Regra: apenas completar campos vazios/NA, nunca sobrescrever.
- **`eventDate` com 4 colunas**: parser especial (startMonth, startYear, endMonth, endYear) -> `YYYY-MM/YYYY-MM`. Em falha, manter valor bruto sem bloquear.
- **Licencas Creative Commons** tem multiplas formas de URL. Normalizar removendo `http(s)://`, `/legalcode`, e `/` final antes de comparar.
- **NA no CSV exportado**: usar `readr::write_csv(na = "")` para produzir celulas vazias.
- **`basisOfRecord` nao deve usar concatenacao**: tratar como vocabulario controlado de valor unico por linha, com assistente dedicado e saida vazia para valores nao mapeados.
- **Auto-sugestao segura para vocabulario controlado**: limitar a match exato case-insensitive dos termos canonicos reduz falso positivo e acelera mapeamento manual.
- **Home e Preview devem compartilhar a mesma definicao de obrigatorios DwC** para evitar sinais contraditorios ao usuario (onboarding vs prontidao real de export).
- **Quando revisao manual altera `scientificName` no export, o match deve usar normalizacao canonica por `query_name`** (mesmas opcoes da validacao) para propagar correcao em todas as ocorrencias equivalentes.
- **Colunas de auditoria no export devem existir sempre**: mesmo sem payload de revisao, incluir defaults (`validacao_manual = FALSE`, `motivo_revisao = ""`) simplifica consumo downstream.

## Performance

- **`sapply()` element-wise** eh lento com 99k+ linhas. Vetorizar parsing de datas testando cada formato em lote.
- **`as.Date(..., format=...)` sem mascara previa** pode aceitar entradas parcialmente e gerar anos incorretos (ex: `0023`). Usar regex estrita por formato antes de parsear.
- **Ano com 2 digitos (`DD/MM/YY`)** precisa de regra de seculo explicita. No Saira: cutoff dinamico (`YY <= ano atual (2d) -> 20YY`, senao `19YY`).
- **RDS estatico** (como `dwc_terms.rds`) nao deve ser relido do disco a cada mudanca reativa. Cachear na primeira leitura.
- **Quando houver artefatos estaticos correlatos** (ex.: termos e sinonimos), aplicar o mesmo padrao de cache para manter consistencia arquitetural e evitar "ilhas" de I/O repetido.
- **Preview de assistente em dataset grande**: limitar mapeamento ao subconjunto exibido (ex.: primeiras 5 linhas) e usar lookup vetorizado para contagens globais evita recomputacao pesada a cada interacao de UI.
- **`vapply(x, f, ...)` com funcao escalar em 96k+ elementos** eh ordens de magnitude mais lento que equivalente vetorizado. `trimws()`, `tolower()`, `%in%` sao nativamente vetorizados em R e operam em C; criar versoes vetorizadas de helpers (`normalize_keys`, `sanitize_terms`) em vez de aplicar a versao escalar via `vapply`/`for`.
- **`head(..., 100)` deve acontecer antes do processamento caro**: se o subset for aplicado depois do pipeline completo, o custo total permanece O(n) e o preview continua lento.
- **Evitar geracao de UUID em massa no caminho de preview**: IDs completos para todo dataset devem ser gerados apenas no fluxo completo; no preview, IDs leves para 100 linhas sao suficientes.
- **Reutilizar a mesma funcao pura com datasets diferentes (subset vs completo)**: aplicar `build_processed_mapping_df(...)` tanto no preview leve quanto no fluxo completo evita divergencia funcional e mantem manutencao simples.
- **Consultas taxonomicas**: sempre consultar `taxadb` em lote e sobre nomes unicos para reduzir custo e I/O de banco local.
- **Separar "prontidao" de "processamento" na validacao taxonomica**: ler apenas estado de mapeamento para habilitar/desabilitar botao e deixar `prepare_taxadb_inputs()`/taxadb para o clique explicito reduz recalculo O(n) em navegacao.
- **CoordinateCleaner em volume alto exige poda de candidatos**: executar checks espaciais apenas em linhas com coordenadas formalmente validas reduz custo sem perder cobertura relevante.
- **Perfis de execucao (`complete`/`fast`) ajudam a manter UX previsivel**: para bases grandes, oferecer subset de checks evita travamento percebido e permite diagnostico incremental.
- **Preservar cardinalidade e crucial em validacao de qualidade**: pipeline deve sempre manter `nrow(out) == nrow(in)` e apenas marcar diagnosticos, sem excluir linhas do usuario.
- **Resolucao de pais em vetor grande deve operar sobre valores unicos e re-expandir depois**: `unique -> resolver em lote -> map de volta` reduz custo sem mudar semantica.
- **Caches separados para aliases e referencia fuzzy evitam reconstrucoes caras por chamada**: ler `country_aliases.rds` e montar codelist apenas uma vez por sessao melhora throughput do pipeline.

## Testes

- **`testthat.R`** na raiz de `tests/` eh o runner padrao do pacote.
- **Testes de regressao**: ao corrigir bug de badges/estado reativo, adicionar teste que alterna filtros e verifica estabilidade.
- **Funcoes puras em `utils_*.R`** devem ser testaveis sem carregar Shiny. Extrair logica dos modulos para utilities.
- **Extracao de reactive para funcao pura**: para preservar contrato e observabilidade, retornar lista composta com `data` e contadores auxiliares (ex.: `eventdate_failure_count`) e sincronizar estado reativo no modulo.
- **Caches globais exigem reset explicito em teste**: usar setup/teardown com helper interno de reset para eliminar dependencia de ordem entre casos.
- **Quando a suite ja existe, expandir cobertura em vez de recriar do zero**: reduz churn e preserva historico de regressao.
- **Para testes de I/O, usar fixtures temporarias deterministicas** (incluindo BOM UTF-8 e delimitadores em empate) para garantir reproducibilidade sem dependencias externas.
- **Cobrir funcoes de pipeline e funcoes auxiliares separadamente** (`process_for_export` + helpers), para localizar regressao com menor custo de diagnostico.
- **Para modulos Shiny, validar contrato de retorno com `session$getReturned()`** em `testServer` reduz acoplamento com detalhes internos de `output$*`.
- **Testar gatilho de custo pesado, nao apenas resultado final**: alem de conferir dataframe final, validar se o caminho pesado roda apenas em acoes explicitas (ex.: download/validar) previne regressao de performance.
- **Mockar wrappers do motor espacial e melhor que mockar pacote externo inteiro**: em testes unitarios de coordenadas, stubs locais para `cc_*` e resolucao de pais deixam os cenarios deterministicos e rapidos.
- **Cobrir prioridade de diagnostico como regra explicita**: testes devem verificar que cada linha recebe um unico diagnostico final, mesmo quando varias flags estao ativas.
- **Em modulo com filtro padrao pos-run, validar primeiro o estado default e depois os cliques de pills**: isso evita falso negativo de teste por expectativa desalinhada com UX real.
- **Cobrir contrato com canal principal + canal leve auxiliar**: quando modulo retorna reactive completo e expoe preview leve por atributo interno, testes devem verificar ambos os contratos para garantir wiring correto no `app_server`.
- **Ao combinar resultados de provedores**: alinhar colunas antes de `rbind` para evitar erro quando resultados possuem schemas diferentes.
- **`data.frame` com vetores nomeados**: definir `row.names = NULL` evita erro de rownames NA quando o vetor carrega nomes inesperados.
- **Testar caminho leve sem tocar no caminho pesado**: usar contador de chamadas no `mapped_data_r()` em `testServer` confirma que `quick_inputs()`/`can_run_validation()` nao materializam dados completos quando o gate leve esta presente.
- **Para UX de acoes longas, testar transicao de estado e nao so resultado final**: validar estados intermediarios (`starting`, `running`) reduz regressao de feedback visual em cliques.
- **Em testes de resolucao de pais, cobrir casos adversariais de fuzzy e obrigatorio**: alem dos matches esperados, validar entradas sem solucao (`xyzxyz`) e ambiguas para evitar falso positivo silencioso.
- **Benchmark funcional deve acompanhar mudancas em fallback de pais**: manter budget explicito (ex.: 10k linhas < 1s em ambiente local) ajuda a detectar regressao de performance cedo.
- **Ao endurecer parser de CSV, cobrir BOM + arquivo vazio no mesmo ciclo**: isso evita regressao em `detect_delimiter()` para entradas exportadas por Notepad/Excel.
- **Para hardening de startup, adicionar teste de modulo com dependencia mockada em erro**: validar que o modulo sobe mesmo com falha externa previne regressao de disponibilidade.

## Package Check / Deploy

- Em pacote R, evitar `source()` dentro de arquivos em `R/`; carregar funcoes via namespace previne divergencia entre ambiente dev e tarball.
- Em testes executados por `R CMD check`, nao depender de caminho local para `R/*.R`; preferir `getFromNamespace()` para funcoes internas.
- Para arquivos de teste (ex.: RDS), preferir `system.file(..., package = "saira")` com fallback de desenvolvimento quando necessario.
- Ao adicionar chamadas `pkg::fun()`, garantir dependencia declarada em `Imports` para evitar warning de dependencia nao declarada.
- Ao introduzir `leaflet` em modulo Shiny, declarar `leaflet` em `DESCRIPTION::Imports`; uso apenas com `leaflet::` nao elimina a necessidade no check do pacote.
- Dependencias espaciais do CoordinateCleaner em fluxo principal devem ser declaradas explicitamente em `Imports` (`CoordinateCleaner`, `countrycode`, `sf`, `rnaturalearth`, `rnaturalearthdata`) para reduzir drift entre ambientes.
- Para remover warning de portabilidade por non-ASCII em `R/*.R`, usar escapes Unicode (`\\uXXXX`) preserva o valor das strings em runtime sem mudar API.
- Quando criar scripts auxiliares em `data-raw/`, adicionar `^data-raw$` em `.Rbuildignore` evita levar material de geracao para o build final do pacote.
- Quando o app usa `addResourcePath("www", ...)`, assets internos devem manter prefixo `www/` nas URLs de runtime (`www/lottie/...`, `www/custom.css`, etc.). Trocar para caminho sem prefixo pode gerar 404 em runtime.

## Upload / Dropzone (2026-02-23)

- **Separar responsabilidade visual evita regressao recorrente**: tratar dropzone (`upload-dropzone`) e progresso nativo (`upload-native-input`) como blocos distintos simplifica manutencao e impede que a barra "vaze" para dentro da area de arrastar/soltar.
- **No `fileInput` do Shiny, remover apenas o shell visual (`.input-group`) e mais seguro que substituir o componente inteiro**: manter o `input[type=file]` real preserva binding, upload e lifecycle nativo.
- **Se o JS faz detach de markup nativo, o seletor de busca do input precisa cobrir os dois contextos (dropzone e container irmao)** para evitar quebra quando o DOM muda entre iteracoes.
- **A barra de progresso do Shiny recebe estilo inline no elemento `#<id>_progress`**: para largura realmente integral, usar seletor especifico com `width/min-width/max-width` e `!important` no escopo local.
- **Container de progress com `border/background` vira "chip involuntario"**: para mostrar apenas a barra verde, deixar o container transparente e aplicar a aparencia somente em `.progress-bar`.
- **Espacamento com chips precisa de valor explicito**: definir `margin-bottom` da progress evita variacao herdada do Bootstrap e permite ajuste fino (neste caso, `0px`).
- **Guardrail CSS dedicado reduz regressao visual**: esconder progresso dentro da dropzone (`display: none !important` no escopo `.upload-dropzone`) evita retorno acidental do problema em refactors futuros.
- **Mudancas de UX sensiveis exigem validacao visual por screenshot a cada iteracao**: em upload, pequenos detalhes de margem/borda alteram percepcao de qualidade e precisam de confirmacao rapida com imagem.

### CoordinateCleaner / Mapa

- **Convencao Natural Earth: numero menor = maior detalhe**: `scale = 10` (1:10M, ~1km) > `scale = 50` (1:50M, ~2km) > `scale = 110` (1:110M, ~10km). A documentacao do `cc_sea` diz o contrario ("Higher numbers equal higher detail") — esta errada.
- **`cc_sea(scale = 10)` requer `rnaturalearthhires`**: pacote de ~37MB disponivel no R-universe do ropensci, nao no CRAN. Usar `requireNamespace` com fallback para `scale = 50` garante robustez.
- **Clustering do Leaflet (`markerClusterOptions`) esconde a posicao real dos pontos**: para diagnostico visual de coordenadas, pontos individuais sao essenciais. Usar raio adaptativo (menor para muitos pontos) + `preferCanvas = TRUE` para performance.
- **Nota de precisao visivel reduz confusao do usuario**: quando o motor de validacao usa dados simplificados, um chip de alerta (`alert-warning`) na legenda evita que o usuario descarte pontos costeiros legitimos.

## CSS Build / Modularizacao (Onda 5)

- **CSS monolitico deve ser fatorado por dominio com build deterministico**: ordenar modulos por numero (`00-tokens` a `16-help`) preserva cascata; script de build (`data-raw/build_css.R`) gera artefato final com header `GENERATED FILE`.
- **Guardrails de CSS bundle devem validar header e completude**: testar que `custom.css` comeca com header gerado e que todos os modulos em `css/` estao incluidos no bundle previne drift silencioso.
- **Contagem de linhas e smoke test minimo valido para CSS split**: `sum(modulos) + 1 header == bundle` confirma integridade sem render visual.

## i18n / Externalizar Dicionario (Onda 5)

- **Migrar dicionario i18n de R inline para JSON facilita manutencao e tooling externo**: `jsonlite::fromJSON` com `simplifyVector = FALSE` preserva estrutura de lista nomeada identica ao formato original.
- **BOM removal deve ser inline quando dependencia de load order nao e garantida**: em pacotes R, `data_dictionary.R` (d) carrega antes de `utils_io.R` (u); usar `sub("^\uFEFF", "", raw)` em vez de `strip_bom()` evita `could not find function` em tempo de source.
- **Cache in-process com `new.env(parent = emptyenv())` e padrao seguro para dados estaticos**: evita releitura do disco e isolamento via `emptyenv()` previne poluicao de namespace.
- **`.onLoad()` e o lugar correto para aquecer caches de dados estaticos do pacote**: chamar `load_i18n_dict()` em `.onLoad()` com `tryCatch` silencioso garante que o cache esteja pronto antes do primeiro `tr()` no build da UI; falha silenciosa preserva compatibilidade com ambientes sem o artefato (testes parciais, dev sem `inst/`).
- **Script one-shot de export (`data-raw/export_i18n.R`) nao deve fazer parte do build regular**: existe para migracao; alteracoes futuras devem ser feitas diretamente no JSON.

## Refatoracao de Modulos Shiny (Onda 5)

- **Ao extrair funcoes de `moduleServer` para arquivo separado, closures locais perdem escopo**: `custom_language_choices()` definida dentro de `mod_mapping_server()` nao e visivel em `mod_mapping_cards.R`. Inlinar a logica ou mover para utils.
- **Retorno de modulo como `list()` nomeada e superior a `attr()` em reactive**: auto-documentado, verificavel com `expect_named()`, e extensivel sem breaking change.
- **Ao refatorar modulo grande, limpar dead code no mesmo ciclo**: closures que deixam de ser chamadas apos extracao devem ser removidas imediatamente para evitar confusao.

## E2E / shinytest2 (Onda 5)

- **Testes E2E com `shinytest2` devem usar `skip_if_not_installed("shinytest2")`**: permite que a suite unitaria rode sem dependencia de chromote/browser.
- **Release gate com etapas numeradas explicita a ordem de verificacao**: unit -> guardrails -> integridade i18n -> E2E -> R CMD check cobre progressivamente do mais rapido ao mais lento.
- **Gate por env var e mais explicito que `skip_if_not_installed` para suites custosas**: `if (!identical(Sys.getenv("RUN_E2E"), "true")) skip(...)` garante que E2E nunca roda acidentalmente em `devtools::test()` mesmo com `shinytest2` instalado.
- **`AppDriver$new(app = shinyApp(ui, server))` e mais robusto que `app_dir`**: elimina dependencia de `app.R`/`server.R` existirem no diretorio raiz, instavel em ambientes de check.
- **Evitar `withr` em scripts de release gate**: `Sys.setenv()`/`Sys.unsetenv()` sao base R e nao exigem declaracao em DESCRIPTION; `withr::with_envvar()` quebraria o script em ambientes sem o pacote instalado.

## Rostrum / Ondas 0-1

- **Sampling de scoring precisa ser deterministico por coluna**: seed derivada do conteudo (`digest::digest2int`) + `withr::with_seed` elimina flutuacao entre execucoes.
- **Golden fixture de scoring e necessario para proteger regressao de formula**: sem baseline versionado, alteracao pequena em score passa despercebida.
- **Migracao SQLite deve rodar em `BEGIN IMMEDIATE` com rollback garantido**: `busy_timeout` sozinho nao impede estado parcial em mid-failure.
- **`schema_version` deve ser idempotente e monotono**: migracao repetida para a mesma versao nao pode inserir duplicado.
- **Evolucao de sinonimos V1->V2 precisa de adaptador explicito**: mapear `lang=any` para `language=mul` e preservar `name_score` como `confidence` evita perda de compatibilidade.
- **Com `renv`, novas dependencias no `DESCRIPTION` exigem sincronizacao imediata do lockfile**: sem isso, `load_all` e CI podem divergir entre ambientes.

## Rostrum / Onda 3

- **Composicao de Stage 2 precisa respeitar override manual antes de qualquer heuristica**: se `manual_overrides[[term]]` estiver preenchido, a composicao deve ser abortada para o termo.
- **Guard de circularidade deve ser baseado em lineage de termos, nao em coluna**: rastrear `composed_from` por termo evita loops indiretos (`A <- B` e depois `B <- A`).
- **Composicao de `scientificName` deve ser conservadora**: promover apenas para `SUGERIDO`, com explain detalhado e sem auto-aplicar composicao multi-coluna.
- **Composicao de `eventDate` precisa validar calendario real**: aceitar `2024-02-29` e rejeitar `2023-02-29` evita falso positivo silencioso.
- **Fallback para `verbatim*` funciona melhor como etapa pos-conflito (Stage 3.5)**: aplicado antes disso, pode influenciar indevidamente a escolha principal.
- **Fallback `verbatim*` nunca deve sobrescrever mapeamento existente do alvo**: usar condicao "target livre" reduz regressao em datasets com coluna verbatim ja mapeada.
- **Vetorizacao de parser row-wise traz ganho direto**: substituir loop por operacoes vetorizadas em `build_eventdate_interval()` reduz custo em cenarios 20k+ linhas.

## Rostrum / Ondas 4-5

- **Stage 3 so fica confiavel com criterio deterministico explicito**: ordenar por score sem desempate alfabetico final pode gerar variacao silenciosa entre execucoes.
- **Regra de ambiguidade precisa ser float-safe e centralizada**: usar `gap < ambiguity_gap - sqrt(eps)` em helper unico evita drift entre branchs de conflito.
- **Conflito de candidatos e fallback de perdedor devem ser desacoplados**: primeiro resolver vencedor/perdedor, depois aplicar `verbatim*` com guard (`score` minimo + alvo livre) reduz sobrescrita indevida.
- **Fallback pos-conflito pode mascarar teste de perdedor se nao houver bloqueio por termo**: quando um termo teve alternativas, bloquear fallback "primario" evita resultado enganoso no target `verbatim*`.
- **Aliases locais precisam de transacao em toda write (`BEGIN IMMEDIATE`)**: sem lock explicito, upsert e undo por sessao ficam sujeitos a corrida em uso multiusuario.
- **Precedencia por escopo deve ser aplicada no lookup, nao na escrita**: manter `personal > institution > public` no read path simplifica manutencao e permite coexistencia de regras.
- **`deprecated` deve filtrar no lookup, nao apagar historico**: preservar linha + evento auditavel viabiliza investigacao de regressao e rollback.
- **Batch undo por `run_id` fica pratico quando eventos e aliases compartilham chave operacional**: sem `run_id` indexado em eventos, rollback em lote vira scan custoso.

## Provedores BR (faunabr / florabr)

- **`verbose = FALSE` em `get_faunabr()` / `get_florabr()` impede o download**: ambos os pacotes condicionam o bloco de `httr::GET` a `if (verbose)`; o `utils::unzip()` roda incondicionalmente logo apos. Sempre passar `verbose = TRUE` internamente na camada wrapper do saira, desacoplando a verbosidade propria do saira da verbosidade dos pacotes externos.
- **Artifact check deve verificar o artefato final, nao intermediario**: `get_faunabr()` extrai `taxon.txt` do zip como passo intermediario e gera `CompleteBrazilianFauna.gz` como saida persistida; `load_faunabr()` le apenas o `.gz`. Verificar `taxon.txt` pode gerar falso negativo se o pacote limpar temporarios apos merge; verificar `CompleteBrazilianFauna.gz` e o contrato correto.
- **Warnings de extracao de zip devem ser escalados a erros no wrapper**: `utils::unzip()` emite `warning()` (nao `stop()`) em falha de extracao; o `tryCatch(error=...)` do wrapper nao captura warnings. Usar `withCallingHandlers(warning=...)` para interceptar e converter em `stop()` com mensagem descritiva antes que o warning seja engolido.
- **O warning do dbplyr (`check_from argument of tbl_sql()`) e upstream e nao bloqueante**: emitido internamente pelo dbplyr >= 2.5.0 quando `taxadb` constroi queries SQL; nao e acionavel no codigo do saira. Suprimir com `withCallingHandlers` escopado nas chamadas a `taxadb::filter_name()` para manter console limpo sem mascarar outros warnings.
- **Diagnostico de download deve separar causa de sintoma**: "cannot open the connection" (sintoma) esconde "zip nao foi baixado porque verbose=FALSE" (causa). Ao investigar falha de provider, verificar primeiro se o arquivo `.zip` existe no tempdir antes de suspeitar do servidor remoto.
- **Bootstrap e refresh precisam de contratos diferentes**: primeiro download sem cache deve ser sincrono e falhar com erro claro; refresh de versao com cache existente deve ser assincrono para nao bloquear validacao.
- **Metadata por provider reduz regressao operacional**: persistir `status`, `local_version`, `last_checked_at`, `last_updated_at`, `last_error` e `retry_after_at` evita comportamento "caixa preta" em falhas intermitentes.
- **Lock em arquivo por provider evita corrida entre cliques/sessoes**: sem lock (`<provider>.update.lock`), dois disparos simultaneos podem sobrescrever cache e produzir estado inconsistente.
- **Escrita atomica e obrigatoria para cache grande**: salvar em `.tmp`, validar leitura, renomear para `.rds` e manter `.rds.bak` protege contra corrupcao parcial quando download/processamento falha no meio.
- **Falha de update nao deve invalidar cache local valido**: quando o refresh remoto falha, manter `.rds` anterior e marcar `update_failed` preserva continuidade para o usuario final.
- **`update_failed` com cache disponivel deve ser revertido para `up_to_date` na proxima leitura de status**: manter o badge de erro mesmo com dados usaveis confunde o usuario. A regra de reset deve ser simetrica a regra `never_downloaded → up_to_date`: se `has_data && status == "update_failed"`, reverter o status operacional (mantendo `last_error` para diagnostico).
- **Toda string visivel em funcoes de badge e notificacao deve usar `tr()`**: hardcodes de texto em ingles dentro de closures de modulo passam despercebidos em revisao de codigo por nao aparecerem no dicionario. Padrao: adicionar chave no `i18n.json`, chamar `tr("chave", lang_r())`, e incluir a chave na suite `test-utils-i18n.R` no mesmo ciclo.

## CRAN Submission

- **`Remotes:` proibido no CRAN**: mover dependencia nao-CRAN para `Suggests` +
  fallback gracioso (ou usar `Additional_repositories`). Nunca submeter com
  `Remotes:` no DESCRIPTION.
- **`LazyData: true` esta deprecated**: remover se nao houver artefatos em `data/`
  que precisem de lazy loading; `inst/extdata/` nao precisa de lazy.
- **`<<-` em handlers de `tryCatch`**: padrao correto e
  `result <- tryCatch(fn(), error = function(e) e)` seguido de
  `inherits(result, "error")`. Nao usar super-assignment para capturar erro.
- **`get(fn, envir = asNamespace("pkg"))` em producao**: acessar API publica
  explicitamente via `pkg::fn`. Reservar `:::` e `asNamespace` apenas para
  testes internos.
- **`@importFrom` obrigatorio para todas as dependencias**: centralizar em arquivo
  `R/saira-package.R` com bloco `## usethis namespace: start/end` e regenerar
  NAMESPACE com `devtools::document()`.
- **Funcoes exportadas exigem roxygen completo**: toda funcao com `@export` precisa
  de `@title`, `@description`, `@param`, `@return` e pelo menos um `@examples`.
- **`getFromNamespace()` nos testes**: substituir por `saira:::fn` para funcoes
  internas ou chamar diretamente para funcoes exportadas. Em loops dinamicos,
  usar `get(fn, envir = asNamespace("saira"), inherits = FALSE)`.
- **`launch.browser = TRUE` hardcoded**: substituir por
  `getOption("shiny.launch.browser", interactive())` para compatibilidade com
  ambientes headless (Docker, CI).
- **`.Rbuildignore` deve excluir artefatos de dev**: incluir `^\.claude$` e
  `^PLAN_.*\.md` para evitar incluir configs e planos de dev no tarball.
