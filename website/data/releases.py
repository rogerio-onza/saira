# Curated, bilingual release highlights for the website "Novidades / Releases"
# page. This is the single source of truth for that page: the pre-render script
# (website/scripts/build_releases.py) turns it into styled cards in both PT and
# EN. The canonical, exhaustive log stays in the repo-root CHANGELOG.md (English
# only); here we keep only recent, user-facing highlights.
#
# To add a release: prepend a new dict at the top of RELEASES with the version,
# the date (YYYY-MM-DD) and a short list of highlights in both languages. Each
# highlight is (type, text) where type is one of: "added", "changed", "fixed".
# Wrap code/term names in `backticks` — they render as <code>.

RELEASES = [
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
            ("changed", "Uploads que já trazem um `occurrenceID` **mantêm o identificador** em vez de receber um UUID aleatório — preservando IDs de armadilha fotográfica e a procedência."),
            ("fixed", "Grandes conjuntos de armadilha fotográfica **não travam mais** o mapa de generalização nem o mapeamento (correções de desempenho)."),
            ("fixed", "Carimbos de data/hora do **Wildlife Insights** não assumem mais um fuso UTC falso."),
        ],
        "en": [
            ("changed", "The **Generalization** tab now scrolls in full and the species list can be **filtered by threat level** (VU, EN, CR…)."),
            ("changed", "Uploads that already carry an `occurrenceID` now **keep the identifier** instead of getting a random UUID — preserving camera-trap IDs and provenance."),
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
