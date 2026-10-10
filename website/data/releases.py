# Curated, trilingual release highlights for the website "Novidades / Releases
# / Novedades" page. This is the single source of truth for that page: the
# pre-render script (website/scripts/build_releases.py) turns it into styled
# cards in PT, EN and ES. The canonical, exhaustive log stays in the repo-root CHANGELOG.md (English
# only); here we keep only recent, user-facing highlights.
#
# To add a release: prepend a new dict at the top of RELEASES with the version,
# the date (YYYY-MM-DD) and a short list of highlights in all three languages. Each
# highlight is (type, text) where type is one of: "added", "changed", "fixed".
#
# Style: one line per change, `**scope**: what changed`. No trailing period, no
# second sentence, no before/after anecdote. The scope is the area of the app
# (Mapeamento, Coordenadas, Site) or the Darwin Core term, in `backticks` when
# it is a term. At most 4 items per version.

RELEASES = [
    {
        "version": "0.11.2",
        "date": "2026-09-11",
        "pt": [
            ("changed", "**Licença**: o arquivo publica o nome da licença (`CC BY 4.0`), não a URL do texto legal"),
            ("fixed", "**Guia de mapeamento**: lista só as colunas não mapeadas que o CSV realmente carrega"),
        ],
        "en": [
            ("changed", "**License**: the file publishes the license name (`CC BY 4.0`), not the legalcode URL"),
            ("fixed", "**Mapping guide**: lists only the unmapped columns the CSV actually carries"),
        ],
        "es": [
            ("changed", "**Licencia**: el archivo publica el nombre de la licencia (`CC BY 4.0`), no la URL del texto legal"),
            ("fixed", "**Guía de mapeo**: lista solo las columnas no mapeadas que el CSV realmente trae"),
        ],
    },
    {
        "version": "0.11.1",
        "date": "2026-09-10",
        "pt": [
            ("fixed", "**Upload**: toda coluna entra como texto, então nenhum valor se perde por não caber num tipo"),
        ],
        "en": [
            ("fixed", "**Upload**: every column is read as text, so no value is lost for not fitting a type"),
        ],
        "es": [
            ("fixed", "**Carga**: toda columna se lee como texto, así ningún valor se pierde por no caber en un tipo"),
        ],
    },
    {
        "version": "0.11.0",
        "date": "2026-09-03",
        "pt": [
            ("added", "**Coordenadas**: coordenadas em UTM viram graus decimais, com a zona que você confirma no mapa"),
            ("added", "**`scientificName`**: a autoria sai do nome e vai para `scientificNameAuthorship`"),
            ("fixed", "**Mapeamento**: uma coluna cujo cabeçalho tem espaço sobrando volta a ser mapeada"),
            ("fixed", "**Exportação**: o aviso de colunas não publicadas ignora as que estão vazias em todas as linhas"),
        ],
        "en": [
            ("added", "**Coordinates**: UTM coordinates convert to decimal degrees, with the zone you confirm on the map"),
            ("added", "**`scientificName`**: the authorship moves out of the name into `scientificNameAuthorship`"),
            ("fixed", "**Mapping**: a column whose header carries a stray space maps again"),
            ("fixed", "**Export**: the unpublished-columns warning ignores columns empty in every row"),
        ],
        "es": [
            ("added", "**Coordenadas**: las coordenadas UTM pasan a grados decimales, con la zona que usted confirma en el mapa"),
            ("added", "**`scientificName`**: la autoría sale del nombre y va a `scientificNameAuthorship`"),
            ("fixed", "**Mapeo**: una columna con un espacio sobrante en el encabezado vuelve a mapearse"),
            ("fixed", "**Exportación**: el aviso de columnas no publicadas ignora las que están vacías en todas las filas"),
        ],
    },
    {
        "version": "0.10.3",
        "date": "2026-08-21",
        "pt": [
            ("fixed", "**Datas**: toda data é publicada em ISO 8601, qualquer que seja o separador digitado na planilha"),
            ("fixed", "**`eventDate`**: dia, mês e ano de início e fim formam um intervalo ISO 8601"),
            ("added", "**Datas**: aviso no Mapeamento e na Exportação quando o ano está fora de 1600 e o ano atual"),
        ],
        "en": [
            ("fixed", "**Dates**: every date is published in ISO 8601, whatever separator the spreadsheet used"),
            ("fixed", "**`eventDate`**: day, month and year for each end compose an ISO 8601 interval"),
            ("added", "**Dates**: a warning in Mapping and Export when the year falls outside 1600 and the current year"),
        ],
        "es": [
            ("fixed", "**Fechas**: toda fecha se publica en ISO 8601, sea cual sea el separador de la hoja de cálculo"),
            ("fixed", "**`eventDate`**: día, mes y año de inicio y fin forman un intervalo ISO 8601"),
            ("added", "**Fechas**: aviso en Mapeo y Exportación cuando el año está fuera de 1600 y el año actual"),
        ],
    },
    {
        "version": "0.10.2",
        "date": "2026-08-20",
        "pt": [
            ("fixed", "**`establishmentMeans` e `degreeOfEstablishment`**: a exportação publica apenas os termos do vocabulário Darwin Core"),
            ("fixed", "**Exportação**: a coluna continua no CSV quando um valor fixo sobrescreve o mapeamento"),
            ("fixed", "**Mapeamento**: importar um guia restaura os valores fixos"),
            ("fixed", "**Generalização**: a decisão sobrevive a uma edição no Mapeamento"),
        ],
        "en": [
            ("fixed", "**`establishmentMeans` and `degreeOfEstablishment`**: the export publishes only Darwin Core controlled terms"),
            ("fixed", "**Export**: a column keeps its place in the CSV when a fixed value overrides its mapping"),
            ("fixed", "**Mapping**: importing a guide restores the fixed values"),
            ("fixed", "**Generalization**: the decision survives an edit in Mapping"),
        ],
        "es": [
            ("fixed", "**`establishmentMeans` y `degreeOfEstablishment`**: la exportación publica solo los términos del vocabulario Darwin Core"),
            ("fixed", "**Exportación**: la columna sigue en el CSV cuando un valor fijo sobrescribe el mapeo"),
            ("fixed", "**Mapeo**: importar una guía restaura los valores fijos"),
            ("fixed", "**Generalización**: la decisión se mantiene tras una edición en Mapeo"),
        ],
    },
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
        "es": [
            ("added", "**`occurrenceID`**: tarjeta para elegir la columna de identificadores, con aviso de valores repetidos"),
            ("fixed", "**Fauna BR**: la descarga vuelve a funcionar, con los estados de ocurrencia completos"),
            ("fixed", "**Estado de amenaza del MMA**: se aplica solo a registros en Brasil"),
            ("fixed", "**`eventDate`**: día, mes y año en columnas separadas forman una fecha ISO 8601"),
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
        "es": [
            ("added", "**Mapeo**: vista de lista con los 66 términos, columna de origen y valor de ejemplo"),
            ("changed", "**Mapeo**: tres columnas de tarjetas y píldoras de clase con el trabajo pendiente"),
            ("changed", "**Alias**: el nombre de una columna se memoriza en la exportación, no en cada elección"),
            ("fixed", "**Mapeo**: elegir una columna ya no bloquea la pantalla en hojas de cálculo grandes"),
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
        "es": [
            ("changed", "**Inicio**: la aplicación abre cerca de 5x más rápido"),
            ("changed", "**Mapeo**: armar el `eventDate` a partir de varias columnas es instantáneo"),
            ("changed", "**Validación de nombres**: la barra de progreso ya no retrasa la validación"),
            ("fixed", "**Idioma**: las opciones de la validación de nombres se mantienen tras el cambio"),
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
        "es": [
            ("changed", "**Mantenimiento**: sin cambios en la aplicación, solo limpieza de empaquetado, documentación y lint"),
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
        "es": [
            ("added", "**`establishmentMeans` y `degreeOfEstablishment`**: un asistente completa los dos por especie, con el vocabulario TDWG"),
            ("added", "**Validación de nombres**: especies exóticas invasoras señaladas con la lista del Instituto Hórus (483 taxones)"),
            ("added", "**`dynamicProperties`**: la tarjeta muestra el JSON que va a generar"),
            ("fixed", "**Idioma**: cambiar de idioma ya no borra el mapeo"),
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
        "es": [
            ("added", "**Vocabulario Darwin Core**: sincronizado con TDWG, de 217 a 262 términos"),
            ("fixed", "**EML**: la licencia elegida en el mapeo se refleja en la exportación"),
            ("fixed", "**Mapeo**: un término agregado manualmente vuelve a aparecer"),
            ("fixed", "**Vista previa**: el encabezado Darwin Core queda fijo al desplazar las filas"),
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
        "es": [
            ("changed", "**Ayuda**: la pestaña es ahora un centro de tutoriales, enlaces, issues, PDF de GBIF y preguntas frecuentes"),
            ("fixed", "**Mapeo**: elegir una columna o una licencia ya no bloquea la pantalla"),
            ("fixed", "**`modified`**: con \"usar la fecha de hoy\", se escribe como fecha simple, sin hora ni zona horaria"),
            ("fixed", "**`eventDate` y `dateIdentified`**: se muestran en ISO 8601, y las fechas sin cero a la izquierda se convierten"),
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
        "es": [
            ("added", "**Carga**: se aceptan archivos `.tsv` en el selector y en la validación"),
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
        "es": [
            ("added", "**Exportación**: `dynamicProperties` lleva la categoría de amenaza del MMA y la global de la UICN"),
            ("added", "**Valor fijo**: `rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation` y `geodeticDatum`"),
            ("changed", "**Generalización**: 100% Chapman 2020, nunca redondea más allá de la precisión del dato"),
            ("fixed", "**Camtrap DP**: columnas vacías descartadas y valores automapeados preservados"),
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
        "es": [
            ("fixed", "**Validación de nombres**: la tabla del informe se desplaza y la paginación queda accesible"),
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
        "es": [
            ("changed", "**Lista del MMA**: fauna amenazada actualizada a las ordenanzas 1.704/2026 y 1.667/2026"),
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
        "es": [
            ("added", "**Sitio**: nueva página Tecnologías y créditos, con paquetes de R, datos incluidos y fuentes"),
            ("added", "**Sitio**: análisis de acceso sin cookies (Umami)"),
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
        "es": [
            ("added", "**Sitio**: página de Novedades con los destacados de cada versión y distintivo de versión en la barra de navegación"),
            ("added", "**Sitio**: foto de la saíra-pintor en la portada y capturas en inglés en los tutoriales EN"),
            ("changed", "**Sitio**: SiBBr pasa a aparecer antes que GBIF"),
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
        "es": [
            ("added", "**Sitio**: tutorial dedicado a la generalización de especies sensibles (PT y EN)"),
            ("fixed", "**Mapeo**: reiniciar o volver a cargar un archivo limpia las pestañas siguientes"),
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
        "es": [
            ("changed", "**Generalización**: la pestaña se desplaza completa y la lista filtra por nivel de amenaza"),
            ("changed", "**`occurrenceID`**: las cargas que ya traen el identificador lo mantienen"),
            ("fixed", "**Rendimiento**: los conjuntos grandes de cámaras trampa ya no bloquean el mapa"),
            ("fixed", "**Wildlife Insights**: las marcas de fecha y hora ya no asumen una zona UTC falsa"),
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
        "es": [
            ("added", "**Exportación**: nueva pestaña de revisión y publicación, con indicador de preparación y descarga del DwC-A"),
            ("changed", "**Generalización**: pestaña propia, con evaluación especie por especie según la tabla de Chapman"),
            ("changed", "**Coordenadas**: las correcciones se reflejan en el mapa, la tabla y los conteos"),
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
        "es": [
            ("changed", "**Generalización**: el enmascaramiento pasa a ser una decisión en dos pasos"),
            ("changed", "**Sitio**: página de inicio renovada y tutoriales reescritos en PT y EN"),
            ("changed", "**Licencia**: de MIT a GPL-3"),
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
        "es": [
            ("added", "**Coordenadas**: corrección en un clic para latitud/longitud intercambiadas o con signo invertido"),
            ("added", "**Coordenadas**: completar el país vacío a partir del punto en el mapa"),
            ("added", "**Plantillas de mapeo**: exporte una guía reutilizable y restáurela con Importar plantilla"),
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
        "es": [
            ("added", "**Offline-first**: fuentes e íconos incluidos, Saíra funciona sin conexión"),
        ],
    },
]
