# Build the public demo dataset served at website/assets/exemplo/ocorrencias-demo.csv
#
# When to run: after adding a feature whose behaviour should be visible on the
# demo spreadsheet. Run from the repo root:
#
#   Rscript data-raw/build_demo_dataset.R
#
# The demo is the fastest manual regression check available: loading it once
# should make every validation, assistant and export rule fire at least once.
# The script is idempotent -- it rebuilds from the first `n_base` rows of the
# current file and drops the columns and edge-case block it appends itself, so
# re-running never doubles anything.
#
# Every block below states the app behaviour it exists to trigger. Adding a
# feature without adding its case here is what let the demo drift three
# releases behind the app.

demo_path <- "website/assets/exemplo/ocorrencias-demo.csv"

# The real-occurrence base this script builds on. Rows beyond it are the
# curated edge cases appended at the bottom.
n_base <- 1075L

added_cols <- c("dia_inicio", "dia_fim", "codigo_pais")

base <- utils::read.csv(
    demo_path,
    colClasses = "character",
    encoding = "UTF-8",
    check.names = FALSE
)
base <- base[seq_len(min(n_base, nrow(base))), setdiff(names(base), added_cols),
             drop = FALSE]
rownames(base) <- NULL

set.seed(20260814)
n <- nrow(base)

# --- Day columns -------------------------------------------------------------
# Triggers ADR-117: mapping dia_inicio + mes_inicio + ano_inicio to eventDate
# composes one ISO 8601 date. `detect_eventdate_dmy_roles()` matches "dia",
# "mes" and "ano" as whole words, so these names resolve. Mapping the four
# mes/ano columns instead still exercises the older start/end interval path.
# Blanks keep the "day missing, month and year present" case reachable.
base$dia_inicio <- sprintf("%02d", sample.int(28L, n, replace = TRUE))
base$dia_fim <- base$dia_inicio
blank_day <- sample.int(n, 45L)
base$dia_inicio[blank_day] <- ""
base$dia_fim[blank_day] <- ""

# --- countryCode -------------------------------------------------------------
# Gives the MMA Brazil-scoping rule (ADR-121) a second column to resolve from,
# and lets the non-Brazil block below be recognised even where `pais` is blank.
base$codigo_pais <- "BR"

# --- Blank and upper-case country -------------------------------------------
# Blank `pais` on rows with valid coordinates is what makes the fill-from-
# coordinates step do any work. The upper-case rows exercise the casing match
# added in 0.10.1: filled values follow the casing the column already uses.
base$pais[sample.int(n, 18L)] <- ""
base$pais[sample.int(n, 30L)] <- "BRASIL"

# --- Blank catalogue numbers -------------------------------------------------
# Makes the occurrenceID card report a mixed count: some identifiers preserved
# from the column, the rest derived from the row. The two duplicate values
# already present in the base data keep the duplicate warning reachable.
base$numero_tombo[sample.int(n, 28L)] <- ""

# --- Curated edge cases ------------------------------------------------------
# One row per behaviour that the real-occurrence base never reaches.

# `taxon` carries the shared species fields; `...` overrides anything else.
row_tpl <- function(taxon = list(), ...) {
    defaults <- list(
        numero_tombo = "", especie = "", autoria = "", familia = "",
        genero = "", nome_comum = "", dia_inicio = "15", mes_inicio = "06",
        ano_inicio = "2023", dia_fim = "15", mes_fim = "06", ano_fim = "2023",
        coletor = "R. Nunes", determinador = "R. Nunes",
        tipo_de_registro = "Observação", pais = "Brasil",
        codigo_pais = "BR", estado = "", municipio = "", localidade = "",
        latitude = "", longitude = "", numero_individuos = "1",
        ambiente = ""
    )
    utils::modifyList(utils::modifyList(defaults, taxon), list(...))
}

onca <- list(
    especie = "Panthera onca", autoria = "(Linnaeus, 1758)",
    familia = "Felidae", genero = "Panthera", nome_comum = "Onça-pintada"
)
anta <- list(
    especie = "Tapirus terrestris", autoria = "(Linnaeus, 1758)",
    familia = "Tapiridae", genero = "Tapirus", nome_comum = "Anta"
)

cases <- list(
    # Coordinates: latitude and longitude transposed. The pair is a real
    # Pantanal point written the wrong way round, which the validator flags as
    # a swap rather than as an out-of-range value.
    row_tpl(onca, numero_tombo = "MN-9000001", estado = "Mato Grosso do Sul",
            municipio = "Miranda", localidade = "RPPN Caiman",
            latitude = "-56.31851", longitude = "-19.91491",
            ambiente = "Planície de inundação do Pantanal"),
    row_tpl(anta, numero_tombo = "MN-9000002", estado = "Amazonas",
            municipio = "Tefé", localidade = "RDS Mamirauá",
            latitude = "-64.77121", longitude = "-3.11479",
            ambiente = "Várzea amazônica"),

    # Coordinates that disagree with the country column, and a point sitting on
    # a country capital, which is the classic "centroid instead of locality"
    # record. Both are CoordinateCleaner tests, not range tests.
    #
    # Comma decimal separators are deliberately NOT represented here. A single
    # comma row cannot survive the reader: readr guesses the column as numeric
    # and reads the comma as a grouping mark, so "-9,19672" arrives as NA when
    # the rest of the column uses dots, and as -919672 when the whole column
    # uses commas. clean_coordinate_separators() runs at export, long after.
    row_tpl(onca, numero_tombo = "MN-9000003", pais = "Peru",
            codigo_pais = "PE", estado = "Alagoas",
            municipio = "Murici", localidade = "ESEC de Murici",
            latitude = "-9.19672", longitude = "-35.89378",
            ambiente = "Floresta Atlântica"),
    row_tpl(anta, numero_tombo = "MN-9000004", estado = "Distrito Federal",
            municipio = "Brasília", localidade = "Sem localidade registrada",
            latitude = "-15.79390", longitude = "-47.88280",
            ambiente = "Cerrado"),

    # Coordinates: outside the valid range for the axis.
    row_tpl(onca, numero_tombo = "MN-9000005", estado = "Ceará",
            municipio = "Quixadá", localidade = "Serra do Estevão",
            latitude = "-95.24310", longitude = "-38.98271",
            ambiente = "Caatinga"),
    row_tpl(anta, numero_tombo = "MN-9000006", estado = "Bahia",
            municipio = "Lençóis", localidade = "Chapada Diamantina",
            latitude = "-12.56180", longitude = "-198.40220",
            ambiente = "Campo rupestre"),

    # Coordinates: null island, and a point that falls in the sea.
    row_tpl(onca, numero_tombo = "MN-9000007", estado = "Bahia",
            municipio = "Ilhéus", localidade = "Sem localidade registrada",
            latitude = "0", longitude = "0", ambiente = "Floresta Atlântica"),
    row_tpl(anta, numero_tombo = "MN-9000008", estado = "Bahia",
            municipio = "Itacaré", localidade = "Litoral sul",
            latitude = "-13.50000", longitude = "-37.20000",
            ambiente = "Zona costeira"),

    # Coordinates present, country blank: the fill-from-coordinates step names
    # the country; the casing rule decides how it is written.
    row_tpl(onca, numero_tombo = "MN-9000009", pais = "", codigo_pais = "",
            estado = "Mato Grosso", municipio = "Poconé",
            localidade = "Transpantaneira", latitude = "-16.55000",
            longitude = "-56.62000", ambiente = "Pantanal"),
    row_tpl(anta, numero_tombo = "MN-9000010", pais = "", codigo_pais = "",
            estado = "Amapá", municipio = "Oiapoque",
            localidade = "PARNA Montanhas do Tumucumaque",
            latitude = "2.80000", longitude = "-52.00000",
            ambiente = "Floresta de terra firme"),

    # Records outside Brazil (ADR-121). Panthera onca is MMA VU, so before the
    # rule these rows left the export claiming Brazilian legal status. The
    # IUCN category, being a global assessment, still applies to them.
    row_tpl(onca, numero_tombo = "MN-9000011", pais = "Peru",
            codigo_pais = "PE", estado = "Madre de Dios",
            municipio = "Manu", localidade = "Parque Nacional del Manu",
            latitude = "-12.25000", longitude = "-70.90000",
            ambiente = "Floresta amazônica"),
    row_tpl(onca, numero_tombo = "MN-9000012", pais = "Bolívia",
            codigo_pais = "BO", estado = "La Paz", municipio = "San Buenaventura",
            localidade = "Parque Nacional Madidi", latitude = "-14.45000",
            longitude = "-67.90000", ambiente = "Floresta amazônica"),
    row_tpl(anta, numero_tombo = "MN-9000013", pais = "Argentina",
            codigo_pais = "AR", estado = "Misiones", municipio = "Puerto Iguazú",
            localidade = "Parque Nacional Iguazú", latitude = "-25.68000",
            longitude = "-54.45000", ambiente = "Floresta Atlântica"),
    row_tpl(onca, numero_tombo = "MN-9000014", pais = "Paraguai",
            codigo_pais = "PY", estado = "Alto Paraguay",
            municipio = "Bahía Negra", localidade = "PARNA Río Negro",
            latitude = "-20.23000", longitude = "-58.17000",
            ambiente = "Pantanal"),

    # Exotic invasive species: pre-fills establishmentMeans = "introduced" in
    # the mapping assistant.
    row_tpl(numero_tombo = "MN-9000015", especie = "Sus scrofa",
            autoria = "Linnaeus, 1758", familia = "Suidae", genero = "Sus",
            nome_comum = "Javali", tipo_de_registro = "Armadilha fotográfica",
            estado = "Minas Gerais", municipio = "Santana do Riacho",
            localidade = "PARNA da Serra do Cipó", latitude = "-19.28000",
            longitude = "-43.58000", numero_individuos = "4",
            ambiente = "Cerrado"),
    row_tpl(numero_tombo = "MN-9000016", especie = "Sus scrofa",
            autoria = "Linnaeus, 1758", familia = "Suidae", genero = "Sus",
            nome_comum = "Javali", tipo_de_registro = "Observação em campo",
            estado = "São Paulo", municipio = "Iporanga",
            localidade = "PETAR", latitude = "-24.52000",
            longitude = "-48.68000", numero_individuos = "2",
            ambiente = "Floresta Atlântica"),
    row_tpl(numero_tombo = "MN-9000017", especie = "Artocarpus heterophyllus",
            autoria = "Lam.", familia = "Moraceae", genero = "Artocarpus",
            nome_comum = "Jaqueira",
            tipo_de_registro = "Material preservado (herbário)",
            estado = "Rio de Janeiro", municipio = "Rio de Janeiro",
            localidade = "PARNA da Tijuca", latitude = "-22.95000",
            longitude = "-43.28000", ambiente = "Floresta Atlântica"),

    # Brazilian natives invasive outside their natural range. Membership of the
    # same Hórus list, but they must not be labelled alien or carry
    # establishmentMeans = "introduced".
    row_tpl(numero_tombo = "MN-9000018", especie = "Nasua nasua",
            autoria = "(Linnaeus, 1766)", familia = "Procyonidae",
            genero = "Nasua", nome_comum = "Quati",
            tipo_de_registro = "Registro fotográfico",
            estado = "Pernambuco", municipio = "Fernando de Noronha",
            localidade = "PARNA Marinho de Fernando de Noronha",
            latitude = "-3.85400", longitude = "-32.42800",
            numero_individuos = "3", ambiente = "Ilha oceânica"),
    row_tpl(numero_tombo = "MN-9000019", especie = "Cichla kelberi",
            autoria = "Kullander & Ferreira, 2006", familia = "Cichlidae",
            genero = "Cichla", nome_comum = "Tucunaré-amarelo",
            tipo_de_registro = "Coleta", estado = "Minas Gerais",
            municipio = "Capitólio", localidade = "Represa de Furnas",
            latitude = "-20.67000", longitude = "-46.32000",
            numero_individuos = "6", ambiente = "Reservatório"),

    # Names: three-part names are subspecies and fill infraspecificEpithet,
    # while an author in the same position is still read as authorship
    # (ADR-119).
    row_tpl(numero_tombo = "MN-9000020", especie = "Rhea americana americana",
            autoria = "(Linnaeus, 1758)", familia = "Rheidae", genero = "Rhea",
            nome_comum = "Ema", estado = "Rio Grande do Sul",
            municipio = "Santa Vitória do Palmar", localidade = "Coxilha das Lombas",
            latitude = "-33.52000", longitude = "-53.37000",
            numero_individuos = "5", ambiente = "Campos sulinos"),
    row_tpl(numero_tombo = "MN-9000021", especie = "Ateles paniscus paniscus",
            autoria = "(Linnaeus, 1758)", familia = "Atelidae",
            genero = "Ateles", nome_comum = "Macaco-aranha-de-cara-vermelha",
            estado = "Pará", municipio = "Melgaço",
            localidade = "FLONA de Caxiuanã", latitude = "-1.74128",
            longitude = "-51.45921", numero_individuos = "4",
            ambiente = "Floresta de terra firme"),
    row_tpl(anta, numero_tombo = "MN-9000022",
            especie = "Tapirus terrestris Linnaeus", estado = "Acre",
            municipio = "Xapuri", localidade = "RESEX Chico Mendes",
            latitude = "-10.65000", longitude = "-68.50000",
            ambiente = "Floresta de terra firme"),

    # Names: an accepted synonym, and a name no database resolves.
    row_tpl(numero_tombo = "MN-9000023", especie = "Cebus apella",
            autoria = "(Linnaeus, 1758)", familia = "Cebidae",
            genero = "Cebus", nome_comum = "Macaco-prego",
            estado = "Bahia", municipio = "Una", localidade = "REBIO de Una",
            latitude = "-15.28000", longitude = "-39.07000",
            numero_individuos = "7", ambiente = "Floresta Atlântica"),
    row_tpl(numero_tombo = "MN-9000024", especie = "Panthera onça",
            autoria = "(Linnaeus, 1758)", familia = "Felidae",
            genero = "Panthera", nome_comum = "Onça-pintada",
            estado = "Mato Grosso", municipio = "Poconé",
            localidade = "Transpantaneira", latitude = "-16.55000",
            longitude = "-56.62000", ambiente = "Pantanal"),
    row_tpl(numero_tombo = "MN-9000025", especie = "Especie indeterminada",
            familia = "Indeterminada", genero = "Indeterminado",
            nome_comum = "Não identificado", estado = "Roraima",
            municipio = "Uiramutã", localidade = "PARNA do Monte Roraima",
            latitude = "5.19000", longitude = "-60.73000",
            ambiente = "Campo de altitude"),

    # occurrenceID: a value repeated across three rows, which the card reports
    # as duplicates and GBIF would reject.
    row_tpl(onca, numero_tombo = "MN-9000026", estado = "Tocantins",
            municipio = "Mateiros", localidade = "PARNA do Jalapão",
            latitude = "-10.55000", longitude = "-46.42000",
            ambiente = "Cerrado"),
    row_tpl(onca, numero_tombo = "MN-9000026", estado = "Tocantins",
            municipio = "Mateiros", localidade = "PARNA do Jalapão",
            latitude = "-10.56000", longitude = "-46.43000",
            ambiente = "Cerrado"),
    row_tpl(anta, numero_tombo = "MN-9000026", estado = "Tocantins",
            municipio = "Mateiros", localidade = "PARNA do Jalapão",
            latitude = "-10.57000", longitude = "-46.44000",
            ambiente = "Cerrado"),

    # Dates: a day without a month, and a month without a year. Neither
    # composes, so both keep the generic collapse instead of an invented date.
    row_tpl(onca, numero_tombo = "MN-9000027", dia_inicio = "07",
            mes_inicio = "", dia_fim = "07", mes_fim = "",
            estado = "Goiás", municipio = "Alto Paraíso de Goiás",
            localidade = "PARNA da Chapada dos Veadeiros",
            latitude = "-14.13000", longitude = "-47.52000",
            ambiente = "Cerrado"),
    row_tpl(anta, numero_tombo = "MN-9000028", ano_inicio = "",
            ano_fim = "", estado = "Maranhão", municipio = "Barreirinhas",
            localidade = "PARNA dos Lençóis Maranhenses",
            latitude = "-2.75000", longitude = "-42.83000",
            ambiente = "Restinga")
)

extra <- do.call(rbind, lapply(cases, function(x) {
    as.data.frame(x, stringsAsFactors = FALSE)
}))

out <- rbind(base[, names(extra), drop = FALSE], extra)

readr::write_csv(out, demo_path, quote = "all", na = "")

message(sprintf(
    "build_demo_dataset: %d rows (%d base + %d edge cases), %d columns -> %s",
    nrow(out), nrow(base), nrow(extra), ncol(out), demo_path
))
