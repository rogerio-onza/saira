# Curated, bilingual release highlights for the website "Novidades / Releases"
# page. This is the single source of truth for that page: the pre-render script
# (website/scripts/build_releases.py) turns it into styled cards in both PT and
# EN. The canonical, exhaustive log stays in the repo-root CHANGELOG.md (English
# only); here we keep only recent, user-facing highlights.
#
# To add a release: prepend a new dict at the top of RELEASES with the version,
# the date (YYYY-MM-DD) and a short list of highlights in both languages. Each
# highlight is (type, text) where type is one of: "added", "changed", "fixed".
#
# Style: one line per change, `**scope**: what changed`. No trailing period, no
# second sentence, no before/after anecdote. The scope is the area of the app
# (Mapeamento, Coordenadas, Site) or the Darwin Core term, in `backticks` when
# it is a term. At most 4 items per version.

RELEASES = [
    {
        "version": "0.10.1",
        "date": "2026-08-14",
        "pt": [
            ("added", "**`occurrenceID`**: card para escolher a coluna de identificadores, com aviso de valores repetidos"),
            ("fixed", "**Fauna BR**: download voltou a funcionar, com os estados de ocorrência preenchidos"),
            ("fixed", "**Status de ameaça do MMA**: aplicado apenas a registros no Brasil"),
            ("fixed", "**`eventDate`**: dia, mês e ano em colunas separadas formam uma data ISO 8601"),
        ],
        "en": [
            ("added", "**`occurrenceID`**: a card to pick the identifier column, with a warning on repeated values"),
            ("fixed", "**Fauna BR**: the download works again, with states of occurrence populated"),
            ("fixed", "**MMA threat status**: applied only to records in Brazil"),
            ("fixed", "**`eventDate`**: day, month and year in separate columns compose an ISO 8601 date"),
        ],
    },
    {
        "version": "0.10.0",
        "date": "2026-08-04",
        "pt": [
            ("added", "**Mapeamento**: visão em lista com os 66 termos, coluna de origem e valor de exemplo"),
            ("changed", "**Mapeamento**: três colunas de cards e pílulas de classe com o trabalho pendente"),
            ("changed", "**Aliases**: o nome de uma coluna é memorizado na exportação, não a cada escolha"),
            ("fixed", "**Mapeamento**: escolher uma coluna não trava mais em planilhas grandes"),
        ],
        "en": [
            ("added", "**Mapping**: a list view with all 66 terms, source column and example value"),
            ("changed", "**Mapping**: three columns of cards and class pills showing the pending work"),
            ("changed", "**Aliases**: a column name is learned on export, not on every selection"),
            ("fixed", "**Mapping**: picking a column no longer freezes on a large spreadsheet"),
        ],
    },
    {
        "version": "0.9.7",
        "date": "2026-07-30",
        "pt": [
            ("changed", "**Inicialização**: o app abre cerca de 5x mais rápido"),
            ("changed", "**Mapeamento**: montar o `eventDate` a partir de várias colunas ficou instantâneo"),
            ("changed", "**Validação de nomes**: a barra de progresso não atrasa mais a validação"),
            ("fixed", "**Idioma**: as opções da validação de nomes sobrevivem à troca"),
        ],
        "en": [
            ("changed", "**Startup**: the app opens about 5x faster"),
            ("changed", "**Mapping**: assembling `eventDate` from several columns is now instant"),
            ("changed", "**Name validation**: the progress bar no longer slows the validation down"),
            ("fixed", "**Language**: the name-validation options survive a switch"),
        ],
    },
    {
        "version": "0.9.6",
        "date": "2026-07-29",
        "pt": [
            ("changed", "**Manutenção**: sem mudanças no aplicativo, apenas limpeza de empacotamento, documentação e lint"),
        ],
        "en": [
            ("changed", "**Maintenance**: no changes to the app, only packaging, documentation and lint cleanup"),
        ],
    },
    {
        "version": "0.9.5",
        "date": "2026-07-29",
        "pt": [
            ("added", "**`establishmentMeans` e `degreeOfEstablishment`**: assistente preenche os dois por espécie, com vocabulário TDWG"),
            ("added", "**Validação de nomes**: espécies exóticas invasoras sinalizadas pela lista do Instituto Hórus (483 táxons)"),
            ("added", "**`dynamicProperties`**: o card mostra o JSON que vai gerar"),
            ("fixed", "**Idioma**: trocar de idioma não apaga mais o mapeamento"),
        ],
        "en": [
            ("added", "**`establishmentMeans` and `degreeOfEstablishment`**: an assistant fills both per species, using the TDWG vocabulary"),
            ("added", "**Name validation**: invasive alien species flagged against the bundled Instituto Hórus list (483 taxa)"),
            ("added", "**`dynamicProperties`**: the card shows the JSON it will generate"),
            ("fixed", "**Language**: switching language no longer wipes the mapping"),
        ],
    },
    {
        "version": "0.9.4",
        "date": "2026-07-01",
        "pt": [
            ("added", "**Vocabulário Darwin Core**: sincronizado com o TDWG, de 217 para 262 termos"),
            ("fixed", "**EML**: a licença escolhida no mapeamento é refletida no export"),
            ("fixed", "**Mapeamento**: um termo adicionado manualmente volta a aparecer"),
            ("fixed", "**Pré-visualização**: o cabeçalho Darwin Core fica fixo ao rolar as linhas"),
        ],
        "en": [
            ("added", "**Darwin Core vocabulary**: synced with TDWG, from 217 to 262 terms"),
            ("fixed", "**EML**: the license chosen in the mapping is reflected in the export"),
            ("fixed", "**Mapping**: a manually added term shows up again"),
            ("fixed", "**Preview**: the Darwin Core header stays fixed while the rows scroll"),
        ],
    },
    {
        "version": "0.9.3",
        "date": "2026-06-25",
        "pt": [
            ("changed", "**Ajuda**: a aba virou uma central de tutoriais, links, issues, PDFs do GBIF e FAQ"),
            ("fixed", "**Mapeamento**: selecionar coluna ou licença não trava mais a tela"),
            ("fixed", "**`modified`**: com \"usar data de hoje\", vira data pura, sem hora nem fuso"),
            ("fixed", "**`eventDate` e `dateIdentified`**: exibidos em ISO 8601, e datas sem zero à esquerda convertem"),
        ],
        "en": [
            ("changed", "**Help**: the tab is now a hub of tutorials, links, issues, GBIF PDFs and a FAQ"),
            ("fixed", "**Mapping**: picking a column or a license no longer freezes the screen"),
            ("fixed", "**`modified`**: with \"use today's date\", written as a plain date, no time or timezone"),
            ("fixed", "**`eventDate` and `dateIdentified`**: shown in ISO 8601, and unpadded dates convert"),
        ],
    },
    {
        "version": "0.9.1",
        "date": "2026-06-22",
        "pt": [
            ("added", "**Upload**: arquivos `.tsv` são aceitos no seletor e na validação"),
        ],
        "en": [
            ("added", "**Upload**: `.tsv` files are accepted in the picker and in validation"),
        ],
    },
    {
        "version": "0.9.0",
        "date": "2026-06-20",
        "pt": [
            ("added", "**Export**: `dynamicProperties` leva a categoria de ameaça do MMA e a global da IUCN"),
            ("added", "**Valor fixo**: `rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation` e `geodeticDatum`"),
            ("changed", "**Generalização**: 100% Chapman 2020, nunca arredonda além da precisão do dado"),
            ("fixed", "**Camtrap DP**: colunas vazias descartadas e valores auto-mapeados preservados"),
        ],
        "en": [
            ("added", "**Export**: `dynamicProperties` carries the MMA threat category and the global IUCN one"),
            ("added", "**Fixed value**: `rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation` and `geodeticDatum`"),
            ("changed", "**Generalization**: fully Chapman 2020, never rounding beyond the data's precision"),
            ("fixed", "**Camtrap DP**: empty columns dropped and auto-mapped values preserved"),
        ],
    },
    {
        "version": "0.8.6",
        "date": "2026-06-19",
        "pt": [
            ("fixed", "**Validação de nomes**: a tabela do relatório rola e a paginação fica acessível"),
        ],
        "en": [
            ("fixed", "**Name validation**: the report table scrolls and pagination is reachable"),
        ],
    },
    {
        "version": "0.8.5",
        "date": "2026-06-18",
        "pt": [
            ("changed", "**Lista MMA**: fauna ameaçada atualizada para as portarias 1.704/2026 e 1.667/2026"),
        ],
        "en": [
            ("changed", "**MMA list**: threatened fauna updated to ordinances 1.704/2026 and 1.667/2026"),
        ],
    },
    {
        "version": "0.8.4",
        "date": "2026-06-16",
        "pt": [
            ("added", "**Site**: nova página Tecnologias e créditos, com pacotes R, dados embutidos e fontes"),
            ("added", "**Site**: análise de acesso sem cookies (Umami)"),
        ],
        "en": [
            ("added", "**Site**: a new Technologies and credits page, with R packages, bundled data and sources"),
            ("added", "**Site**: cookieless analytics (Umami)"),
        ],
    },
    {
        "version": "0.8.3",
        "date": "2026-06-16",
        "pt": [
            ("added", "**Site**: página Novidades com os destaques de cada versão e badge de versão na navbar"),
            ("added", "**Site**: foto da saíra-pintor na home e capturas em inglês nos tutoriais EN"),
            ("changed", "**Site**: SiBBr passa a vir antes do GBIF"),
        ],
        "en": [
            ("added", "**Site**: a Releases page with each version's highlights and a version badge in the navbar"),
            ("added", "**Site**: a Saíra-pintor photo on the home page and English screenshots in the EN tutorials"),
            ("changed", "**Site**: SiBBr now comes ahead of GBIF"),
        ],
    },
    {
        "version": "0.8.2",
        "date": "2026-06-16",
        "pt": [
            ("added", "**Site**: tutorial dedicado de generalização de espécies sensíveis (PT e EN)"),
            ("fixed", "**Mapeamento**: resetar ou reenviar um arquivo limpa as abas seguintes"),
        ],
        "en": [
            ("added", "**Site**: a dedicated sensitive-species generalization tutorial (PT and EN)"),
            ("fixed", "**Mapping**: resetting or re-uploading a file clears the downstream tabs"),
        ],
    },
    {
        "version": "0.8.1",
        "date": "2026-06-15",
        "pt": [
            ("changed", "**Generalização**: a aba rola por inteiro e a lista filtra por nível de ameaça"),
            ("changed", "**`occurrenceID`**: uploads que já trazem o identificador o mantêm"),
            ("fixed", "**Desempenho**: conjuntos grandes de armadilha fotográfica não travam mais o mapa"),
            ("fixed", "**Wildlife Insights**: os carimbos de data/hora não assumem mais um fuso UTC falso"),
        ],
        "en": [
            ("changed", "**Generalization**: the tab scrolls in full and the list filters by threat level"),
            ("changed", "**`occurrenceID`**: uploads that already carry the identifier keep it"),
            ("fixed", "**Performance**: large camera-trap datasets no longer freeze the map"),
            ("fixed", "**Wildlife Insights**: timestamps no longer claim a false UTC timezone"),
        ],
    },
    {
        "version": "0.8.0",
        "date": "2026-06-14",
        "pt": [
            ("added", "**Export**: nova aba de revisão e publicação, com indicador de prontidão e download do DwC-A"),
            ("changed", "**Generalização**: aba própria, com avaliação espécie por espécie pela tabela de Chapman"),
            ("changed", "**Coordenadas**: as correções refletem no mapa, na tabela e nas contagens"),
        ],
        "en": [
            ("added", "**Export**: a new review-and-publish tab, with a readiness indicator and the DwC-A download"),
            ("changed", "**Generalization**: its own tab, with a per-species assessment from Chapman's table"),
            ("changed", "**Coordinates**: corrections reflect in the map, the table and the counts"),
        ],
    },
    {
        "version": "0.7.0",
        "date": "2026-06-09",
        "pt": [
            ("changed", "**Generalização**: mascaramento reformulado em decisão de dois passos"),
            ("changed", "**Site**: landing page renovada e tutoriais reescritos em PT e EN"),
            ("changed", "**Licença**: de MIT para GPL-3"),
        ],
        "en": [
            ("changed", "**Generalization**: masking reworked into a two-step decision"),
            ("changed", "**Site**: a polished landing page and tutorials rewritten in PT and EN"),
            ("changed", "**License**: from MIT to GPL-3"),
        ],
    },
    {
        "version": "0.6.0",
        "date": "2026-06-04",
        "pt": [
            ("added", "**Coordenadas**: correção em um clique para latitude/longitude trocadas ou com sinal invertido"),
            ("added", "**Coordenadas**: preencher país em branco a partir do ponto no mapa"),
            ("added", "**Modelos de mapeamento**: exporte um guia reutilizável e restaure-o via Importar modelo"),
        ],
        "en": [
            ("added", "**Coordinates**: a one-click fix for swapped or sign-flipped latitude/longitude"),
            ("added", "**Coordinates**: fill a blank country from the point on the map"),
            ("added", "**Mapping templates**: export a reusable guide and restore it via Import template"),
        ],
    },
    {
        "version": "0.5.0",
        "date": "2026-05-25",
        "pt": [
            ("added", "**Offline-first**: fontes e ícones embarcados, o Saíra roda sem conexão"),
        ],
        "en": [
            ("added", "**Offline-first**: bundled fonts and icons, Saíra runs with no connection"),
        ],
    },
]
