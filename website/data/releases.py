# Curated, bilingual release highlights for the website "Novidades / Releases"
# page. This is the single source of truth for that page: the pre-render script
# (website/scripts/build_releases.py) turns it into styled cards in both PT and
# EN. The canonical, exhaustive log stays in the repo-root CHANGELOG.md (English
# only); here we keep only recent, user-facing highlights.
#
# To add a release: prepend a new dict at the top of RELEASES with the version,
# the date (YYYY-MM-DD) and a short list of highlights in both languages. Each
# highlight is (type, text) where type is one of: "added", "changed", "fixed".
# Wrap code/term names in `backticks`, which render as <code>.

RELEASES = [
    {
        "version": "0.9.7",
        "date": "2026-07-30",
        "pt": [
            ("changed", "**O aplicativo abre cerca de 5x mais rápido.** Carregar o pacote levava 5,78 s e agora leva 1,04 s. Toda a diferença era a camada geográfica usada nas checagens de mar e de referência, que era carregada na abertura mesmo para quem nunca valida coordenadas. Agora ela é carregada na primeira vez em que é realmente necessária, ao clicar em validar coordenadas, e fica em memória pelo resto da sessão. A análise não mudou: no mesmo conjunto de dados, cada linha sai com o mesmo diagnóstico e o mesmo código ISO3."),
            ("changed", "**O mapeamento ficou muito mais rápido em planilhas grandes.** Quatro auxiliares que leem um mês, um ano ou um pedaço de nome científico eram chamados uma vez por registro, embora uma coluna tenha no máximo algumas dezenas de valores distintos. Em 50 mil registros: o intervalo de datas montado a partir de quatro colunas (mês e ano de início e fim) caiu de 36,1 s para 0,27 s. Além disso, quando a planilha já traz o próprio `occurrenceID`, o Saíra não gera mais um conjunto inteiro de identificadores aleatórios só para descartá-los."),
            ("changed", "**A barra de progresso não disputa mais espaço com a validação que ela reporta.** Durante uma consulta taxonômica, o painel inteiro de configuração era reconstruído umas 16 vezes por segundo, na mesma linha de execução que fazia as consultas. Agora só a barra se atualiza a cada passo, e a lista de nomes que vai aparecendo redesenha bem mais rápido em execuções longas."),
            ("fixed", "**Trocar o idioma não liga mais as duas opções da validação de nomes.** Desligar \"remover autores\" ou \"ignorar qualificadores\" e depois alternar entre português e inglês religava as duas chaves, mudando em silêncio como a próxima validação trataria os seus nomes."),
        ],
        "en": [
            ("changed", "**The app starts about 5x faster.** Loading the package took 5.78 s and now takes 1.04 s. All of the difference was the geographic layer used by the sea and reference checks, loaded at startup even for people who never validate coordinates. It is now loaded the first time it is actually needed, when you click validate coordinates, and kept in memory for the rest of the session. The analysis did not change: on the same dataset every row comes out with the same diagnostic and the same ISO3 code."),
            ("changed", "**Column mapping is much faster on a large spreadsheet.** Four helpers that read a single month, year or scientific-name token were being called once per record, even though a column has at most a few dozen distinct values. Over 50,000 records: the date interval assembled from four columns (start and end month and year) dropped from 36.1 s to 0.27 s. On top of that, when your spreadsheet already brings its own `occurrenceID`, Saíra no longer generates a whole set of random identifiers just to discard them."),
            ("changed", "**The progress bar no longer competes with the validation it reports.** During a taxonomic run the entire configuration panel was rebuilt about 16 times per second, on the same thread doing the queries. Now only the bar repaints on each step, and the stream of names redraws far faster on long runs."),
            ("fixed", "**Switching the language no longer turns the two name-validation options back on.** Turning off \"remove authors\" or \"ignore qualifiers\" and then switching between Portuguese and English put both switches back on, silently changing how the next validation would treat your names."),
        ],
    },
    {
        "version": "0.9.6",
        "date": "2026-07-29",
        "pt": [
            ("changed", "**Versão de manutenção, sem nenhuma mudança no aplicativo.** O Saíra 0.9.6 se comporta exatamente como o 0.9.5. A limpeza foi toda interna: avisos de empacotamento e de documentação que vinham acumulando desde versões anteriores, e a configuração do analisador de código alinhada ao estilo real do projeto. As notas completas estão no lançamento correspondente no GitHub."),
        ],
        "en": [
            ("changed", "**Maintenance release, with no changes to the app.** Saíra 0.9.6 behaves exactly like 0.9.5. The cleanup is entirely internal: packaging and documentation warnings that had been accumulating since earlier versions, plus a linter configuration that now matches the project's real style. The full notes are on the corresponding GitHub release."),
        ],
    },
    {
        "version": "0.9.5",
        "date": "2026-07-29",
        "pt": [
            ("added", "**`establishmentMeans` e `degreeOfEstablishment` agora se preenchem para a planilha inteira, uma resposta por esp\u00e9cie.** Os dois t\u00eam vocabul\u00e1rio controlado do TDWG (7 e 11 valores) e descrevem a **esp\u00e9cie**, n\u00e3o a linha. Um assistente lista as esp\u00e9cies distintas da coluna mapeada em `scientificName`, com a contagem de registros de cada uma, e pergunta os dois valores uma vez por t\u00e1xon. Esp\u00e9cies da lista de ex\u00f3ticas invasoras j\u00e1 chegam sugeridas como `introduced`; o grau nunca \u00e9 sugerido, porque depende do registro. Se voc\u00ea tamb\u00e9m mapear uma coluna, os valores dela vencem e o assistente s\u00f3 completa os brancos."),
            ("added", "**A valida\u00e7\u00e3o de nomes passou a sinalizar esp\u00e9cies ex\u00f3ticas invasoras.** A lista brasileira do **Instituto H\u00f3rus** (483 t\u00e1xons, animais e plantas) vem embutida no app, ent\u00e3o a verifica\u00e7\u00e3o \u00e9 local, offline e instant\u00e2nea. Os t\u00e1xons recebem a etiqueta **Ex\u00f3tica invasora** no relat\u00f3rio, e a p\u00edlula de filtro **Invasoras** isola s\u00f3 eles nos Nomes Processados."),
            ("added", "**O card `dynamicProperties` mostra o JSON que vai gerar.** Abaixo do editor de chaves aparece o objeto montado para a primeira linha (por exemplo `{\"cor\":\"Mel\u00e2nico\"}`), atualizado a cada edi\u00e7\u00e3o de chave."),
            ("fixed", "**Trocar o idioma n\u00e3o apaga mais o mapeamento.** Alternar entre portugu\u00eas e ingl\u00eas relia o arquivo enviado e entregava uma tabela nova ao restante do app, que corretamente a lia como um upload novo: o mapeamento era limpo, os dois assistentes perdiam as respostas e os caches eram descartados."),
            ("fixed", "**O card de mapeamento sempre diz o que fez com a coluna escolhida.** Quando a coluna est\u00e1 mapeada mas as primeiras linhas est\u00e3o vazias, o card diz isso com todas as letras, em vez de n\u00e3o mostrar nada e ficar id\u00eantico a um card sem mapeamento."),
            ("changed", "**As telas de tabela e valida\u00e7\u00e3o ficaram mais r\u00e1pidas.** Os r\u00f3tulos passaram a ser resolvidos uma vez por valor distinto, e n\u00e3o uma vez por linha. Em 50 mil registros: os selos da tabela de coordenadas ca\u00edram de 1,9 s para 0,005 s, e a busca de tradu\u00e7\u00e3o ficou 5,5x mais r\u00e1pida."),
            ("changed", "**A planilha de exemplo dos tutoriais passou a ser o conjunto de demonstra\u00e7\u00e3o completo** do Sa\u00edra: 1.075 ocorr\u00eancias, 48 esp\u00e9cies brasileiras reais dos seis biomas do pa\u00eds, com imperfei\u00e7\u00f5es deliberadas para exercitar as valida\u00e7\u00f5es."),
        ],
        "en": [
            ("added", "**`establishmentMeans` and `degreeOfEstablishment` can now be filled for a whole spreadsheet, one answer per species.** Both carry a TDWG controlled vocabulary (7 and 11 values) and describe the **species**, not the row. An assistant lists the distinct species in the column mapped to `scientificName`, with a record count for each, and asks for both values once per taxon. Species on the invasive alien list arrive pre-filled as `introduced`; the degree is never suggested, because it depends on the record. If you also map a column, its values win and the assistant only fills the blanks."),
            ("added", "**Name validation now flags invasive alien species.** The Brazilian **Instituto H\u00f3rus** list (483 taxa, animals and plants) is bundled with the app, so the check is local, offline and instant. Taxa get an **Invasive alien** badge in the report, and an **Invasive** filter pill narrows Processed Names down to just those."),
            ("added", "**The `dynamicProperties` card shows the JSON it will generate.** Under the key editor you now see the object assembled for the first row (for example `{\"cor\":\"Mel\u00e2nico\"}`), refreshed on every key edit."),
            ("fixed", "**Switching the interface language no longer wipes your mapping.** Changing between Portuguese and English re-read the uploaded file and handed the rest of the app a new table, which it correctly read as a fresh upload: the mapping was cleared, both assistants lost their answers and the caches were dropped."),
            ("fixed", "**A mapping card always says what it did with the column you picked.** When the column is mapped but its first rows are empty, the card says so explicitly instead of rendering nothing and looking exactly like an unmapped card."),
            ("changed", "**Table and validation screens got faster.** Labels are now resolved once per distinct value instead of once per row. Over 50,000 records: the coordinate table badges went from 1.9 s to 0.005 s, and the translation lookup is 5.5x faster."),
            ("changed", "**The tutorials' downloadable sample is now Sa\u00edra's full demonstration dataset**: 1,075 occurrences, 48 real Brazilian species from all six Brazilian biomes, with deliberate imperfections that exercise the validations."),
        ],
    },
    {
        "version": "0.9.4",
        "date": "2026-07-01",
        "pt": [
            ("added", "**Vocabulário Darwin Core sincronizado com o TDWG (de 217 para 262 termos).** 45 novos termos e 9 novas classes (Agent, Assertion, BibliographicResource, MolecularProtocol, NucleotideAnalysis, NucleotideSequence, OrganismInteraction, Protocol, Provenance), cada um com definição em português — disponíveis na Wiki e em \"Adicionar termo\". Oito termos foram reclassificados para a classe correspondente no TDWG (por exemplo, `catalogNumber` passou a `MaterialEntity`)."),
            ("fixed", "**A licença escolhida no mapeamento passou a ser refletida no EML exportado.** O `intellectualRights` do `eml.xml` gera CC0 1.0, CC-BY 4.0 ou CC-BY-NC 4.0 conforme o mapeamento, no formato do GBIF/IPT."),
            ("fixed", "**Corrigido um bug que impedia um termo adicionado manualmente (via \"Adicionar termo\") de aparecer no mapeamento.** O termo passou a ser inserido normalmente e a tela rola até o card recém-criado."),
            ("fixed", "**Importar um guia de mapeamento passou a exibir os cards dos termos fora do conjunto padrão** (por exemplo, um `geodeticDatum` herdado de outro conjunto de dados)."),
            ("fixed", "**Na pré-visualização, o cabeçalho Darwin Core permanece fixo ao rolar as linhas**, mantendo visíveis os nomes dos termos e os valores mapeados."),
            ("fixed", "**`fundingAttribution` passou a ser declarado no namespace Audiovisual Core (`ac:`) no `meta.xml`.**"),
        ],
        "en": [
            ("added", "**Darwin Core vocabulary synced with TDWG (from 217 to 262 terms).** 45 new terms and 9 new classes (Agent, Assertion, BibliographicResource, MolecularProtocol, NucleotideAnalysis, NucleotideSequence, OrganismInteraction, Protocol, Provenance), each with a Portuguese definition — available in the Wiki and the \"Add term\" modal. Eight terms were re-classified to their corresponding TDWG class (for example, `catalogNumber` is now `MaterialEntity`)."),
            ("fixed", "**The license chosen in the mapping is now reflected in the exported EML.** The `eml.xml` `intellectualRights` produces CC0 1.0, CC-BY 4.0 or CC-BY-NC 4.0 according to the mapping, in the GBIF/IPT format."),
            ("fixed", "**Fixed a bug that prevented a manually added term (via \"Add term\") from appearing in the mapping.** The term is now inserted normally and the page scrolls to the newly created card."),
            ("fixed", "**Importing a mapping guide now shows the cards for terms outside the default set** (for example, a `geodeticDatum` carried over from another dataset)."),
            ("fixed", "**In the Preview, the Darwin Core header stays fixed while you scroll the rows**, keeping the term names and mapped values visible."),
            ("fixed", "**`fundingAttribution` is now declared under the Audiovisual Core namespace (`ac:`) in `meta.xml`.**"),
        ],
    },
    {
        "version": "0.9.3",
        "date": "2026-06-25",
        "pt": [
            ("changed", "**A aba Ajuda virou uma central de recursos.** Saiu o passo a passo (que repetia os tutoriais do site) e entrou uma seção de **Recursos** em destaque: link direto para os **tutoriais** no site, os **links úteis** (Darwin Core / TDWG, SiBBr, GBIF), um link direto para os **issues no GitHub** e os três PDFs de boas práticas do GBIF (Chapman 2020; Chapman & Wieczorek 2020; Zermoglio et al. 2020). Um **FAQ** condensado abre com um clique, e o card **Construído com** agora lista todas as dependências, cada uma com link para o pacote."),
            ("fixed", "**O mapeamento agora responde na hora.** Selecionar uma coluna, marcar \"usar data de hoje\" ou escolher uma licença não trava mais a tela por segundos — cada clique é praticamente instantâneo, mesmo ao concatenar várias colunas (por exemplo no `eventDate`)."),
            ("fixed", "**`modified` vira data pura** ao marcar \"usar data de hoje\": sem hora nem fuso, igual ao seletor de data manual."),
            ("fixed", "**`eventDate` e `dateIdentified` já aparecem em ISO 8601 na pré-visualização** do mapeamento (igual ao arquivo exportado), e datas sem zero à esquerda (`2/9/2021`) agora convertem; a ordem dia/mês é decidida por coluna a partir dos próprios dados."),
        ],
        "en": [
            ("changed", "**The Help tab is now a resource hub.** The step-by-step recap (which duplicated the website tutorials) was dropped for a **Resources** section in evidence: a direct link to the **tutorials** on the site, the **useful links** (Darwin Core / TDWG, SiBBr, GBIF), a direct **GitHub issues** link, and the three GBIF best-practice PDFs (Chapman 2020; Chapman & Wieczorek 2020; Zermoglio et al. 2020). A condensed **FAQ** opens with one click, and the **Built with** card now lists every dependency, each linking to its package."),
            ("fixed", "**Mapping is now instant.** Picking a column, ticking \"use today's date\" or choosing a license no longer freezes the screen for seconds — every click is effectively instant, even when concatenating several columns (e.g. into `eventDate`)."),
            ("fixed", "**`modified` is written as a plain date** when \"use today's date\" is checked: no time or timezone, matching the manual date picker."),
            ("fixed", "**`eventDate` and `dateIdentified` now show in ISO 8601 in the mapping preview** (matching the exported file), and unpadded dates (`2/9/2021`) now convert; day/month order is decided per column from the data itself."),
        ],
    },
    {
        "version": "0.9.1",
        "date": "2026-06-22",
        "pt": [
            ("added", "**Arquivos separados por tabulação (`.tsv`) agora são aceitos no upload.** O leitor já detectava o delimitador, mas o filtro do seletor de arquivos e a validação só aceitavam `.csv`/`.txt`; agora `.tsv` aparece no seletor e passa na validação."),
        ],
        "en": [
            ("added", "**Tab-separated (`.tsv`) files are now accepted on upload.** The reader already detected the delimiter, but the file-picker filter and validation only allowed `.csv`/`.txt`; now `.tsv` is offered in the picker and passes validation."),
        ],
    },
    {
        "version": "0.9.0",
        "date": "2026-06-20",
        "pt": [
            ("added", "**Status de conservação automático no export**: cada registro de um táxon avaliado ganha, no `dynamicProperties`, a categoria de ameaça **MMA** (com a portaria que o listou) quando você usa uma base brasileira, e/ou a categoria **IUCN** global (consultada no GBIF) quando usa o GBIF. A consulta ao GBIF é opcional e não-bloqueante: offline, a chave IUCN é apenas omitida e a exportação segue normal."),
            ("added", "**Valor fixo para mais termos de nível-dataset**: `rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation` e `geodeticDatum` podem receber um único valor aplicado a todas as linhas, em vez de mapear uma coluna."),
            ("changed", "**Generalização de coordenadas 100% Chapman 2020**: nunca arredonda para uma precisão mais fina do que o dado já tem (sem inventar precisão) e nunca descarta os metadados de proteção."),
            ("fixed", "**Pacotes Camtrap DP** agora mapeiam de forma limpa: colunas vazias descartadas, valores auto-mapeados preservados e badges **AUTO** para as colunas que já são termos Darwin Core."),
        ],
        "en": [
            ("added", "**Automatic conservation status on export**: every record of an assessed taxon gets, in `dynamicProperties`, the **MMA** threat category (with the portaria that listed it) when you use a Brazilian database, and/or the global **IUCN** category (looked up on GBIF) when you use GBIF. The GBIF lookup is optional and non-blocking: offline, the IUCN key is simply omitted and the export proceeds normally."),
            ("added", "**Fixed value for more dataset-level terms**: `rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation` and `geodeticDatum` can take a single value applied to every row instead of mapping a column."),
            ("changed", "**Coordinate generalization is now fully Chapman 2020-compliant**: it never rounds to a finer precision than the data already has (no invented precision) and never drops the protection metadata."),
            ("fixed", "**Camtrap DP packages** now map cleanly: empty columns dropped, auto-mapped values preserved, and **AUTO** badges for columns that already are Darwin Core terms."),
        ],
    },
    {
        "version": "0.8.6",
        "date": "2026-06-19",
        "pt": [
            ("fixed", "Na **validação de nomes**, a tabela do relatório agora **rola** e a **paginação fica acessível** quando há mais de 10 nomes; antes a 10ª linha e os controles ficavam cortados."),
        ],
        "en": [
            ("fixed", "In **name validation**, the report table now **scrolls** and **pagination is reachable** with more than 10 names; previously the 10th row and the controls were clipped."),
        ],
    },
    {
        "version": "0.8.5",
        "date": "2026-06-18",
        "pt": [
            ("changed", "**Lista nacional de fauna ameaçada atualizada para as portarias de 2026**: fauna terrestre pela Portaria MMA nº 1.704/2026 e fauna aquática (peixes e invertebrados) pela Portaria GM/MMA nº 1.667/2026. A flora segue a Portaria MMA nº 148/2022."),
        ],
        "en": [
            ("changed", "**National threatened-fauna list updated to the 2026 ordinances**: terrestrial fauna from Portaria MMA nº 1.704/2026 and aquatic fauna (fish and invertebrates) from Portaria GM/MMA nº 1.667/2026. Flora still follows Portaria MMA nº 148/2022."),
        ],
    },
    {
        "version": "0.8.4",
        "date": "2026-06-16",
        "pt": [
            ("added", "Nova página **Tecnologias e créditos** (PT e EN) reunindo, num só lugar, todos os pacotes R que o Saíra usa, os dados públicos embutidos e suas fontes, e os créditos de método."),
            ("added", "**Análise de acesso sem cookies** (Umami) no site, para acompanhar as visitas sem coletar dados pessoais."),
        ],
        "en": [
            ("added", "A new **Technologies and credits** page (PT and EN) gathering, in one place, every R package Saíra uses, the bundled public data and its provenance, and method credits."),
            ("added", "**Cookieless analytics** (Umami) on the site, to monitor visits without collecting personal data."),
        ],
    },
    {
        "version": "0.8.3",
        "date": "2026-06-16",
        "pt": [
            ("added", "Nova página **Novidades** com os destaques de cada versão, e um **badge de versão** na barra de navegação."),
            ("added", "Foto da **saíra-pintor** na página inicial e **capturas de tela em inglês** nos tutoriais em EN; clique numa captura para **ampliá-la**."),
            ("changed", "O site agora destaca o **SiBBr** à frente do GBIF, valorizando a plataforma brasileira."),
        ],
        "en": [
            ("added", "A new **Releases** page with each version's highlights, and a **version badge** in the navbar."),
            ("added", "A **Saíra-pintor** photo on the home page and **English screenshots** in the EN tutorials; click any screenshot to **zoom in**."),
            ("changed", "The site now leads with **SiBBr** ahead of GBIF, foregrounding the Brazilian platform."),
        ],
    },
    {
        "version": "0.8.2",
        "date": "2026-06-16",
        "pt": [
            ("added", "Novo tutorial dedicado de **generalização de espécies sensíveis** no site de ajuda (PT e EN)."),
            ("fixed", "Resetar o mapeamento ou reenviar um arquivo na mesma sessão agora **limpa as abas seguintes** (Nomes, Coordenadas e Generalização), sem decisões antigas presas ao conjunto anterior."),
        ],
        "en": [
            ("added", "A dedicated **sensitive-species generalization** tutorial on the help site (PT and EN)."),
            ("fixed", "Resetting the mapping or re-uploading a file in the same session now **clears the downstream tabs** (Names, Coordinates and Generalization), so stale decisions from the previous dataset no longer linger."),
        ],
    },
    {
        "version": "0.8.1",
        "date": "2026-06-15",
        "pt": [
            ("changed", "A aba **Generalização** agora rola por inteiro e a lista de espécies pode ser **filtrada por nível de ameaça** (VU, EN, CR…)."),
            ("changed", "Uploads que já trazem um `occurrenceID` **mantêm o identificador** em vez de receber um UUID aleatório, preservando IDs de armadilha fotográfica e a procedência."),
            ("fixed", "Grandes conjuntos de armadilha fotográfica **não travam mais** o mapa de generalização nem o mapeamento (correções de desempenho)."),
            ("fixed", "Carimbos de data/hora do **Wildlife Insights** não assumem mais um fuso UTC falso."),
        ],
        "en": [
            ("changed", "The **Generalization** tab now scrolls in full and the species list can be **filtered by threat level** (VU, EN, CR…)."),
            ("changed", "Uploads that already carry an `occurrenceID` now **keep the identifier** instead of getting a random UUID, preserving camera-trap IDs and provenance."),
            ("fixed", "Large camera-trap datasets **no longer freeze** the generalization map or the mapping step (performance fixes)."),
            ("fixed", "**Wildlife Insights** timestamps no longer falsely claim a UTC timezone."),
        ],
    },
    {
        "version": "0.8.0",
        "date": "2026-06-14",
        "pt": [
            ("added", "Nova aba **Exportação**: uma central de revisão e publicação, com um indicador de **prontidão** (\"X% pronto para publicar\") e o download do Darwin Core Archive."),
            ("changed", "O mascaramento de coordenadas sensíveis virou uma **avaliação espécie por espécie**, guiada pela tabela de decisão de Chapman, em uma aba **Generalização** própria."),
            ("changed", "As correções de coordenadas agora **refletem na aba inteira** (mapa, tabela e contagens), não só na exportação."),
        ],
        "en": [
            ("added", "A new **Export** tab: a review-then-publish hub with a **readiness** indicator (\"X% ready to publish\") and the Darwin Core Archive download."),
            ("changed", "Sensitive-coordinate masking became a **per-species assessment**, driven by Chapman's decision table, in a dedicated **Generalization** tab."),
            ("changed", "Coordinate corrections now **reflect across the whole tab** (map, table and counts), not only at export."),
        ],
    },
    {
        "version": "0.7.0",
        "date": "2026-06-09",
        "pt": [
            ("changed", "Mascaramento de coordenadas sensíveis reformulado em uma **decisão de dois passos** (publicar o original vs. generalizar)."),
            ("changed", "Site de ajuda reescrito: landing page renovada e **tutoriais completos** reescritos em PT e EN."),
            ("changed", "Licença alterada de **MIT para GPL-3**."),
        ],
        "en": [
            ("changed", "Sensitive-coordinate masking reworked into a **two-step decision** (publish the original vs. generalize)."),
            ("changed", "Help site rewritten: a polished landing page and **full tutorials** reworked in PT and EN."),
            ("changed", "License changed from **MIT to GPL-3**."),
        ],
    },
    {
        "version": "0.6.0",
        "date": "2026-06-04",
        "pt": [
            ("added", "**Correção de coordenadas transpostas**: conserto em um clique quando latitude/longitude estão trocadas ou com o sinal invertido."),
            ("added", "**Preencher país a partir das coordenadas**: deriva um país em branco a partir do ponto no mapa."),
            ("added", "**Modelos de mapeamento v2**: exporte um guia reutilizável e restaure-o fielmente via **Importar modelo**."),
        ],
        "en": [
            ("added", "**Transposed-coordinate correction**: a one-click fix when latitude/longitude are swapped or sign-flipped."),
            ("added", "**Fill country from coordinates**: derive a blank country from the point on the map."),
            ("added", "**Mapping templates v2**: export a reusable guide and restore it faithfully via **Import template**."),
        ],
    },
    {
        "version": "0.5.0",
        "date": "2026-05-25",
        "pt": [
            ("added", "**Offline-first**: fontes e ícones agora vêm embarcados, então o Saíra funciona com tipografia e ícones completos **sem conexão com a internet**."),
        ],
        "en": [
            ("added", "**Offline-first**: fonts and icons are now bundled, so Saíra renders with full typography and icons **with no internet connection**."),
        ],
    },
]
