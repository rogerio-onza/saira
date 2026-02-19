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
- **Compatibilidade progressiva em modulos Shiny**: ao introduzir canal reativo leve novo (`validation_gate_r`), manter fallback legado para `mapped_data_r()` evita quebrar chamadas antigas de `mod_validate_names_server`.
- **Feedback imediato em clique + trabalho pesado**: em `observeEvent` de acao longa, usar estrategia em duas fases (`starting` agora + processamento pesado no proximo flush com `session$onFlushed`) evita o efeito de "cliquei e nada aconteceu".
- **Filtro de stream sensivel a status deve ser server-side quando afeta decisao de UX**: manter `stream_filter` em `reactiveValues` evita divergencia entre estado visual e estado de dados (dispensa `runjs` para regra de negocio).
- **Quando houver estado pre-validacao sem dados, substituir empty-state por instrucoes acionaveis** melhora escaneabilidade sem tocar na logica de execucao.
- **Assets estaticos CSS podem ficar stale no browser** em iteracoes de UI. Adicionar versionamento no `href` (`custom.css?v=...`) reduz falso negativo de validacao visual.

## CSS / Bootstrap / bslib

- **`fileInput` gera `input-group`** do Bootstrap. Nao forcar flex externo -- estilizar o `input-group` diretamente.
- **Variaveis CSS referenciadas no codigo devem existir no `:root`**. Gradientes com variaveis indefinidas resultam em UI invisivel (ex: texto branco em fundo transparente).
- **Evitar `!important` como estrategia padrao**: prefira seletores mais especificos e ordem de carregamento correta para sobrescrever estilos do tema `bslib`.
- **`border-radius` em inputs conectados**: primeiro elemento `X 0 0 X`, segundo `0 X X 0`.
- **`backdrop-filter: blur()`** em modais cria efeito "debaixo d'agua" indesejado. Usar escurecimento simples (`rgba(0,0,0,0.45)`).
- **Scroll container**: usar `scrollbar-gutter: stable` para evitar sobreposicao da barra de rolagem sobre conteudo.
- **`dataTables_length select` pode sobrepor seta e valor** quando herda padding generico de `form-select`; aplicar regra especifica com `padding-right` maior e `background-position` evita colisao visual.
- **Padrao oficial de tabelas do app**: toda `DT::datatable` deve ficar dentro de `.finch-table-shell` para herdar header azul, paginacao compacta e dimensoes consistentes de busca/length menu.
- **Quando a informacao e curta e essencial (onboarding/obrigatorios)**, prefira exibir categorias sempre visiveis em grupos compactos a esconder conteudo atras de tabs clicaveis.
- **Nao depender de `!important` para resolver regressao visual local**: priorizar estrutura de layout (grid/flex), seletores claros e ordem de carregamento previsivel.
- **Tooltip por hover em cards clicaveis precisa de fallback para touch**: em mobile/tablet, exibir descricao inline via media query (`hover: none`/`pointer: coarse`) evita perda de contexto.

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
- **Cobrir contrato com canal principal + canal leve auxiliar**: quando modulo retorna reactive completo e expoe preview leve por atributo interno, testes devem verificar ambos os contratos para garantir wiring correto no `app_server`.
- **Ao combinar resultados de provedores**: alinhar colunas antes de `rbind` para evitar erro quando resultados possuem schemas diferentes.
- **`data.frame` com vetores nomeados**: definir `row.names = NULL` evita erro de rownames NA quando o vetor carrega nomes inesperados.
- **Testar caminho leve sem tocar no caminho pesado**: usar contador de chamadas no `mapped_data_r()` em `testServer` confirma que `quick_inputs()`/`can_run_validation()` nao materializam dados completos quando o gate leve esta presente.
- **Para UX de acoes longas, testar transicao de estado e nao so resultado final**: validar estados intermediarios (`starting`, `running`) reduz regressao de feedback visual em cliques.

## Package Check / Deploy

- Em pacote R, evitar `source()` dentro de arquivos em `R/`; carregar funcoes via namespace previne divergencia entre ambiente dev e tarball.
- Em testes executados por `R CMD check`, nao depender de caminho local para `R/*.R`; preferir `getFromNamespace()` para funcoes internas.
- Para arquivos de teste (ex.: RDS), preferir `system.file(..., package = "finch")` com fallback de desenvolvimento quando necessario.
- Ao adicionar chamadas `pkg::fun()`, garantir dependencia declarada em `Imports` para evitar warning de dependencia nao declarada.
- Para remover warning de portabilidade por non-ASCII em `R/*.R`, usar escapes Unicode (`\\uXXXX`) preserva o valor das strings em runtime sem mudar API.
