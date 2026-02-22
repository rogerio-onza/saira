# Licoes Aprendidas

Conhecimento reutilizavel extraido do desenvolvimento do Finch.
Indexado por **tema** -- consulte antes de implementar algo similar.

---

## R Package Structure

- **Linhas vazias no DESCRIPTION** quebram `pkgload::load_all()`. Todo campo deve seguir imediatamente o anterior.
- **Todo pacote usado com `::`** precisa estar no `Imports` do DESCRIPTION. Exemplo: `here`, `jsonlite`.
- **`pkgload::load_all()`** carrega todos os arquivos de `R/` automaticamente -- nao precisa de `source()` em cada modulo.
- **Diretorio de trabalho**: `pkgload::load_all()` precisa ser chamado a partir do diretorio que contem `DESCRIPTION`.

## Shiny / Reactive Patterns

- **`renderUI` recria inputs** a cada invalidacao. Usar `isolate(input$...)` para preservar valores do usuario entre re-renders.
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
- **Web components com nome de tag customizado (ex.: `<lottie-player>`) nao devem ser criados com `shiny::tags$`**: em cenarios com hifen no nome da tag, isso pode disparar `attempt to apply non-function`. Preferir HTML explicito (`shiny::HTML(...)`) ou construcao de tag custom segura.
- **Falha visual nao pode bloquear fluxo funcional**: em eventos de arranque (`start_requested -> run_requested`), envolver `showModal()` em `tryCatch` e manter o disparo do processamento mesmo quando a UI de loading falhar.

## CSS / Bootstrap / bslib

- **`fileInput` gera `input-group`** do Bootstrap. Nao forcar flex externo -- estilizar o `input-group` diretamente.
- **Variaveis CSS referenciadas no codigo devem existir no `:root`**. Gradientes com variaveis indefinidas resultam em UI invisivel (ex: texto branco em fundo transparente).
- **Evitar `!important` como estrategia padrao**: prefira seletores mais especificos e ordem de carregamento correta para sobrescrever estilos do tema `bslib`.
- **`border-radius` em inputs conectados**: primeiro elemento `X 0 0 X`, segundo `0 X X 0`.
- **`backdrop-filter: blur()`** em modais cria efeito "debaixo d'agua" indesejado. Usar escurecimento simples (`rgba(0,0,0,0.45)`).
- **Scroll container**: usar `scrollbar-gutter: stable` para evitar sobreposicao da barra de rolagem sobre conteudo.
- **`dataTables_length select` pode sobrepor seta e valor** quando herda padding generico de `form-select`; aplicar regra especifica com `padding-right` maior e `background-position` evita colisao visual.
- **Padrao oficial de tabelas do app**: toda `DT::datatable` deve ficar dentro de `.finch-table-shell` para herdar header azul, paginacao compacta e dimensoes consistentes de busca/length menu.
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

## i18n / Internacionalizacao

- **Todo texto visivel** deve passar por `tr(key, lang_r())`. Strings inline do tipo `if (lang == "pt") "X" else "Y"` violam o sistema i18n.
- **Encoding UTF-8** deve ser verificado ao editar `data_dictionary.R`. Caracteres acentuados podem corromper se o editor salvar em Latin-1.
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

## Performance

- **`sapply()` element-wise** eh lento com 99k+ linhas. Vetorizar parsing de datas testando cada formato em lote.
- **`as.Date(..., format=...)` sem mascara previa** pode aceitar entradas parcialmente e gerar anos incorretos (ex: `0023`). Usar regex estrita por formato antes de parsear.
- **Ano com 2 digitos (`DD/MM/YY`)** precisa de regra de seculo explicita. No Finch: cutoff dinamico (`YY <= ano atual (2d) -> 20YY`, senao `19YY`).
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

## Package Check / Deploy

- Em pacote R, evitar `source()` dentro de arquivos em `R/`; carregar funcoes via namespace previne divergencia entre ambiente dev e tarball.
- Em testes executados por `R CMD check`, nao depender de caminho local para `R/*.R`; preferir `getFromNamespace()` para funcoes internas.
- Para arquivos de teste (ex.: RDS), preferir `system.file(..., package = "finch")` com fallback de desenvolvimento quando necessario.
- Ao adicionar chamadas `pkg::fun()`, garantir dependencia declarada em `Imports` para evitar warning de dependencia nao declarada.
- Ao introduzir `leaflet` em modulo Shiny, declarar `leaflet` em `DESCRIPTION::Imports`; uso apenas com `leaflet::` nao elimina a necessidade no check do pacote.
- Dependencias espaciais do CoordinateCleaner em fluxo principal devem ser declaradas explicitamente em `Imports` (`CoordinateCleaner`, `countrycode`, `sf`, `rnaturalearth`, `rnaturalearthdata`) para reduzir drift entre ambientes.
- Para remover warning de portabilidade por non-ASCII em `R/*.R`, usar escapes Unicode (`\\uXXXX`) preserva o valor das strings em runtime sem mudar API.
- Quando criar scripts auxiliares em `data-raw/`, adicionar `^data-raw$` em `.Rbuildignore` evita levar material de geracao para o build final do pacote.
- Quando o app usa `addResourcePath("www", ...)`, assets internos devem manter prefixo `www/` nas URLs de runtime (`www/lottie/...`, `www/custom.css`, etc.). Trocar para caminho sem prefixo pode gerar 404 em runtime.
