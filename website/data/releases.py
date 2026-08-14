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
        "version": "0.10.1",
        "date": "2026-08-14",
        "pt": [
            ("fixed", "**O download do Fauna BR voltou a funcionar.** O Catálogo Taxonômico da Fauna do Brasil mudou o formato dos dados de novo, e os estados de ocorrência voltaram a vir preenchidos."),
            ("fixed", "**O status de ameaça do MMA não é mais gravado em registros de outros países.** A lista da Portaria é nacional; uma onça registrada no Peru saía do export alegando status legal brasileiro."),
            ("added", "**O card de `occurrenceID` deixa você apontar a coluna que já carrega seus identificadores**, e avisa quando ela repete um valor."),
            ("fixed", "**Dia, mês e ano em colunas separadas agora formam uma data ISO 8601.** Antes o `eventDate` saía como `12 | 2 | 1809` em vez de `1809-02-12`."),
        ],
        "en": [
            ("fixed", "**The Fauna BR download works again.** The Catálogo Taxonômico da Fauna do Brasil changed its data format once more, and states of occurrence are populated again."),
            ("fixed", "**The MMA threat status is no longer written onto records from other countries.** The Portaria list is national; a jaguar recorded in Peru left the export claiming Brazilian legal status."),
            ("added", "**The `occurrenceID` card lets you point at the column that already carries your identifiers**, and warns when that column repeats a value."),
            ("fixed", "**Day, month and year in separate columns now compose one ISO 8601 date.** `eventDate` used to come out as `12 | 2 | 1809` instead of `1809-02-12`."),
        ],
    },
    {
        "version": "0.10.0",
        "date": "2026-08-04",
        "pt": [
            ("changed", "**A tela de mapeamento foi reorganizada.** Cabem três colunas de cards, e as pílulas de classe mostram onde ainda falta trabalho."),
            ("added", "**Uma visão em lista mostra os 66 termos de uma vez**, com a coluna de origem e um valor de exemplo lado a lado."),
            ("fixed", "**O mapeamento não trava mais em planilhas grandes.** Escolher uma coluna volta a responder na hora."),
            ("changed", "**Saíra memoriza o nome de uma coluna quando você exporta**, não a cada escolha que você ainda está experimentando."),
        ],
        "en": [
            ("changed", "**The mapping screen was reworked.** It fits three columns of cards, and the class pills show where work is still pending."),
            ("added", "**A list view shows all 66 terms at once**, with the source column and an example value side by side."),
            ("fixed", "**Mapping no longer freezes on a large spreadsheet.** Picking a column responds immediately again."),
            ("changed", "**Saíra remembers a column name when you export**, not on every selection you are still trying out."),
        ],
    },
    {
        "version": "0.9.7",
        "date": "2026-07-30",
        "pt": [
            ("changed", "**O aplicativo abre cerca de 5x mais rápido.** A camada geográfica das checagens de coordenadas agora só carrega quando você valida coordenadas."),
            ("changed", "**O mapeamento ficou muito mais rápido em planilhas grandes.** Montar o `eventDate` a partir de várias colunas agora é praticamente instantâneo."),
            ("changed", "**A barra de progresso não atrasa mais a validação de nomes.** Agora só a barra se atualiza a cada passo, em vez do painel inteiro."),
            ("fixed", "**Trocar o idioma não religa mais as opções da validação de nomes.** Desligar \"remover autores\" ou \"ignorar qualificadores\" agora sobrevive à troca."),
        ],
        "en": [
            ("changed", "**The app starts about 5x faster.** The geographic layer used by the coordinate checks now loads only when you validate coordinates."),
            ("changed", "**Column mapping is much faster on a large spreadsheet.** Assembling `eventDate` from several columns is now effectively instant."),
            ("changed", "**The progress bar no longer slows down the name validation.** Only the bar repaints on each step now, instead of the whole panel."),
            ("fixed", "**Switching the language no longer turns the name-validation options back on.** Turning off \"remove authors\" or \"ignore qualifiers\" now survives the switch."),
        ],
    },
    {
        "version": "0.9.6",
        "date": "2026-07-29",
        "pt": [
            ("changed", "**Versão de manutenção, sem mudanças no aplicativo.** A limpeza foi interna: avisos de empacotamento e de documentação, e a configuração do analisador de código."),
        ],
        "en": [
            ("changed", "**Maintenance release, with no changes to the app.** The cleanup is internal: packaging and documentation warnings, plus the linter configuration."),
        ],
    },
    {
        "version": "0.9.5",
        "date": "2026-07-29",
        "pt": [
            ("added", "**`establishmentMeans` e `degreeOfEstablishment` agora se preenchem para a planilha inteira.** Um assistente pergunta os dois valores uma vez por espécie, com vocabulário do TDWG."),
            ("added", "**A validação de nomes sinaliza espécies exóticas invasoras.** A lista do Instituto Hórus (483 táxons) vem embutida, então a checagem é local e instantânea."),
            ("added", "**O card `dynamicProperties` mostra o JSON que vai gerar**, montado para a primeira linha e atualizado a cada edição de chave."),
            ("fixed", "**Trocar o idioma não apaga mais o mapeamento.** Alternar entre português e inglês relia o arquivo, e o app tratava aquilo como um upload novo."),
        ],
        "en": [
            ("added", "**`establishmentMeans` and `degreeOfEstablishment` can now be filled for a whole spreadsheet.** An assistant asks for both values once per species, using the TDWG vocabulary."),
            ("added", "**Name validation flags invasive alien species.** The Instituto Hórus list (483 taxa) is bundled with the app, so the check is local and instant."),
            ("added", "**The `dynamicProperties` card shows the JSON it will generate**, assembled for the first row and refreshed on every key edit."),
            ("fixed", "**Switching the interface language no longer wipes your mapping.** Changing between Portuguese and English re-read the file, and the app treated that as a new upload."),
        ],
    },
    {
        "version": "0.9.4",
        "date": "2026-07-01",
        "pt": [
            ("added", "**Vocabulário Darwin Core sincronizado com o TDWG: de 217 para 262 termos**, cada novo termo com definição em português na Wiki e em \"Adicionar termo\"."),
            ("fixed", "**A licença escolhida no mapeamento passou a ser refletida no EML exportado**, como CC0 1.0, CC-BY 4.0 ou CC-BY-NC 4.0."),
            ("fixed", "**Um termo adicionado manualmente volta a aparecer no mapeamento**, com a tela rolando até o card recém-criado."),
            ("fixed", "**Na pré-visualização, o cabeçalho Darwin Core fica fixo ao rolar as linhas**, mantendo visíveis os nomes dos termos."),
        ],
        "en": [
            ("added", "**Darwin Core vocabulary synced with TDWG: 217 to 262 terms**, each new term with a Portuguese definition in the Wiki and in \"Add term\"."),
            ("fixed", "**The license chosen in the mapping is now reflected in the exported EML**, as CC0 1.0, CC-BY 4.0 or CC-BY-NC 4.0."),
            ("fixed", "**A manually added term shows up in the mapping again**, with the page scrolling to the newly created card."),
            ("fixed", "**In the Preview, the Darwin Core header stays fixed while you scroll the rows**, keeping the term names visible."),
        ],
    },
    {
        "version": "0.9.3",
        "date": "2026-06-25",
        "pt": [
            ("changed", "**A aba Ajuda virou uma central de recursos**: tutoriais, links úteis, issues no GitHub, os PDFs de boas práticas do GBIF e um FAQ."),
            ("fixed", "**O mapeamento responde na hora.** Selecionar uma coluna ou escolher uma licença não trava mais a tela por segundos."),
            ("fixed", "**`modified` vira data pura** ao marcar \"usar data de hoje\": sem hora nem fuso, igual ao seletor manual."),
            ("fixed", "**`eventDate` e `dateIdentified` aparecem em ISO 8601 na pré-visualização**, e datas sem zero à esquerda (`2/9/2021`) agora convertem."),
        ],
        "en": [
            ("changed", "**The Help tab is now a resource hub**: tutorials, useful links, GitHub issues, the GBIF best-practice PDFs and a condensed FAQ."),
            ("fixed", "**Mapping responds instantly.** Picking a column or choosing a license no longer freezes the screen for seconds."),
            ("fixed", "**`modified` is written as a plain date** when \"use today's date\" is checked: no time and no timezone."),
            ("fixed", "**`eventDate` and `dateIdentified` show in ISO 8601 in the preview**, and unpadded dates (`2/9/2021`) now convert."),
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
            ("added", "**Status de conservação automático no export**: o `dynamicProperties` leva a categoria de ameaça do MMA e, com o GBIF, a categoria global da IUCN."),
            ("added", "**Valor fixo para mais termos de nível-dataset**: `rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation` e `geodeticDatum`."),
            ("changed", "**Generalização de coordenadas 100% Chapman 2020**: nunca arredonda para uma precisão mais fina do que o dado já tem."),
            ("fixed", "**Pacotes Camtrap DP mapeiam de forma limpa**: colunas vazias descartadas, valores auto-mapeados preservados e badges **AUTO** nos termos Darwin Core."),
        ],
        "en": [
            ("added", "**Automatic conservation status on export**: `dynamicProperties` carries the MMA threat category and, with GBIF, the global IUCN category."),
            ("added", "**Fixed value for more dataset-level terms**: `rightsHolder`, `institutionCode`, `collectionCode`, `country`, `references`, `bibliographicCitation` and `geodeticDatum`."),
            ("changed", "**Coordinate generalization is now fully Chapman 2020-compliant**: it never rounds to a finer precision than the data already has."),
            ("fixed", "**Camtrap DP packages now map cleanly**: empty columns dropped, auto-mapped values preserved, and **AUTO** badges on Darwin Core terms."),
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
