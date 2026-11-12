# Title: Build the DwC term catalogs from the TDWG vocabulary and curated sources
# Author: Saira maintainers
# Output: inst/extdata/dwc_terms.rds (the default mapping term set)
#         inst/extdata/dwc_full_catalog.rds (base terms first, then the others)
#
# Sources. No generated artifact is read back, so the build does not depend on
# the previous output or on the order of earlier patch scripts (SP-05):
#   - TDWG vocabulary/term_versions.csv: the term list, the class, and the
#     English text of the terms outside the base. Give a saved copy as the
#     first argument to build from a frozen input. With no argument, the
#     script downloads the current file.
#   - data-raw/dwc_base_terms.csv: the tuned definitions, examples, required
#     flag and data type of the default terms.
#   - data-raw/dwc_definitions_pt.csv: PT definitions of the other terms.
#   - data-raw/dwc_definitions_es.csv: ES definitions and card hints.
#   - The default order and the PT/EN card hints below.
#
# Both catalogs are built and validated together in a staging folder. They
# replace the shipped files only when the validation passes, so a failed step
# leaves the previous files as they were.
#
# To regenerate (from the project root):
#   Rscript data-raw/build_dwc_catalogs.R [path/to/term_versions.csv]

tdwg_url <- paste0(
  "https://raw.githubusercontent.com/tdwg/dwc/master/",
  "vocabulary/term_versions.csv"
)

# One schema for both catalogs.
catalog_columns <- c(
  "term", "class", "definition_en", "definition_pt", "examples", "required",
  "data_type", "card_hint_pt", "card_hint_en", "definition_es", "card_hint_es"
)

# Ordered default term list: the "Rede Felinos do Brasil" occurrence template
# (modelo-ocorrencia-rede-felinos-brasil.xlsx), plus commonly needed terms kept
# in the default so date-part composition (year/month/day), high taxonomy,
# verbatim coordinates and catalog identifiers work out of the box. Terms left
# out (disposition, preparations, infraspecificEpithet, verbatimIdentification)
# stay one click away in the "Add term" modal. Typos in the xlsx header
# (decimaLatitude, "family ") are corrected to canonical DwC terms.
ordered_terms <- c(
  # Occurrence identifiers
  "occurrenceID", "catalogNumber",
  # Record-level metadata
  "datasetName", "modified", "type", "license", "rightsHolder", "language",
  "institutionCode", "collectionCode", "basisOfRecord", "informationWithheld",
  # Occurrence
  "occurrenceStatus", "recordedBy",
  # Location
  "locationID", "country", "stateProvince", "county", "locality",
  "decimalLatitude", "decimalLongitude", "verbatimLatitude", "verbatimLongitude",
  "coordinateUncertaintyInMeters", "locationRemarks",
  # Event
  "eventID", "parentEventID", "eventDate", "eventTime", "year", "month", "day",
  "samplingEffort", "sampleSizeValue", "sampleSizeUnit", "samplingProtocol",
  "habitat", "fieldNotes",
  # Record-level (dynamic)
  "dynamicProperties",
  # Taxon
  "kingdom", "phylum", "class", "order", "family", "genus", "specificEpithet",
  "taxonRank", "scientificName", "scientificNameAuthorship", "vernacularName",
  "taxonRemarks",
  # Occurrence (organism traits)
  "individualCount", "sex", "lifeStage", "reproductiveCondition", "behavior",
  # Occurrence (establishment). Both carry a TDWG controlled vocabulary and are
  # filled together by the per-species assistant (ADR-110), so they belong in
  # the default set: having to hunt for them in "Add term" first would defeat
  # the assistant's purpose.
  "establishmentMeans", "degreeOfEstablishment",
  # Identification
  "identifiedBy", "identifiedByID", "dateIdentified", "identificationRemarks",
  "identificationQualifier",
  # Occurrence (media / references / remarks)
  "associatedMedia", "associatedReferences", "occurrenceRemarks"
)

# Required terms (validation gate + IPT minimum) must stay required.
required_terms <- c(
  "occurrenceID", "license", "institutionCode", "basisOfRecord", "recordedBy",
  "eventDate", "scientificName", "country", "stateProvince", "locality",
  "decimalLatitude", "decimalLongitude"
)

# Short card hints. The mapping card grid is three columns wide, so a card gets
# about 339px at 1440px and the description is clamped to two lines. Eleven
# base definitions run past 90 characters and would be cut mid-sentence, so
# they get a short line written for the card. The definitions are never
# edited: the Wiki and the upload requirements panel show the full normative
# text, and the "?" tooltip always shows the definition in full. What each
# hint drops is the usage qualification, not the meaning.
card_hints <- data.frame(
  term = c(
    "coordinateUncertaintyInMeters", "eventID", "locationID",
    "establishmentMeans", "associatedReferences", "sampleSizeValue",
    "identifiedByID", "sampleSizeUnit", "associatedMedia", "lifeStage",
    "degreeOfEstablishment"
  ),
  card_hint_pt = c(
    "Raio de incerteza das coordenadas, em metros. Zero não é válido.",
    "Identificador do evento de amostragem (um local e um tempo).",
    "Identificador do conjunto de informações de Localização.",
    "Se o organismo foi introduzido por ação humana no local.",
    "Literatura associada à Ocorrência: DOI, citação ou URI.",
    "Valor numérico do tamanho da amostra no evento.",
    "Identificadores únicos globais de quem atribuiu o táxon.",
    "Unidade de medida do tamanho da amostra.",
    "Mídias associadas à Ocorrência: URI, DOI ou identificador.",
    "Classe etária ou estágio de vida do organismo no registro.",
    "Grau em que o organismo se estabelece no local."
  ),
  card_hint_en = c(
    "Radius of coordinate uncertainty, in meters. Zero is not valid.",
    "Identifier for the sampling event (one place, one time).",
    "Identifier for the set of Location information.",
    "Whether the organism was introduced by human activity.",
    "Literature associated with the Occurrence: DOI, citation or URI.",
    "Numeric value for the sample size in the event.",
    "Global unique identifiers of whoever assigned the taxon.",
    "Unit of measurement for the sample size.",
    "Media associated with the Occurrence: URI, DOI or identifier.",
    "Age class or life stage of the organism when recorded.",
    "Degree to which the organism establishes at the place."
  ),
  stringsAsFactors = FALSE
)

class_map <- list(
  "http://purl.org/dc/elements/1.1/"                   = "Record-level",
  "http://purl.org/dc/terms/"                          = "Record-level",
  "http://purl.org/dc/terms/Location"                  = "Location",
  "http://rs.tdwg.org/dwc/terms/Event"                 = "Event",
  "http://rs.tdwg.org/dwc/terms/GeologicalContext"     = "GeologicalContext",
  "http://rs.tdwg.org/dwc/terms/Identification"        = "Identification",
  "http://rs.tdwg.org/dwc/terms/MaterialEntity"        = "MaterialEntity",
  "http://rs.tdwg.org/dwc/terms/MaterialSample"        = "MaterialSample",
  "http://rs.tdwg.org/dwc/terms/MeasurementOrFact"     = "MeasurementOrFact",
  "http://rs.tdwg.org/dwc/terms/Occurrence"            = "Occurrence",
  "http://rs.tdwg.org/dwc/terms/Organism"              = "Organism",
  "http://rs.tdwg.org/dwc/terms/ResourceRelationship"  = "ResourceRelationship",
  "http://rs.tdwg.org/dwc/terms/Taxon"                 = "Taxon",
  # DwC-DP classes added to the recommended vocabulary upstream.
  "http://purl.org/dc/terms/Agent"                     = "Agent",
  "http://purl.org/dc/terms/BibliographicResource"     = "BibliographicResource",
  "http://rs.tdwg.org/dwc/terms/Assertion"             = "Assertion",
  "http://rs.tdwg.org/dwc/terms/OrganismInteraction"   = "OrganismInteraction",
  "http://rs.tdwg.org/dwc/terms/MolecularProtocol"     = "MolecularProtocol",
  "http://rs.tdwg.org/dwc/terms/NucleotideAnalysis"    = "NucleotideAnalysis",
  "http://rs.tdwg.org/dwc/terms/NucleotideSequence"    = "NucleotideSequence",
  "http://rs.tdwg.org/dwc/terms/Protocol"              = "Protocol",
  "http://rs.tdwg.org/dwc/terms/Provenance"            = "Provenance"
)

# Per-term class overrides for upstream quirks. agentRoleOrder belongs to Agent
# but ships with an empty organized_in in term_versions.csv, so it would
# otherwise fall through to Record-level.
term_class_overrides <- c(agentRoleOrder = "Agent")

map_class <- function(term_local_name, organized_in) {
  cls <- vapply(organized_in, function(x) {
    if (is.na(x) || !nzchar(x)) return("Record-level")
    hit <- class_map[[x]]
    if (is.null(hit)) "Record-level" else hit
  }, FUN.VALUE = character(1), USE.NAMES = FALSE)
  ov <- term_class_overrides[term_local_name]
  cls[!is.na(ov)] <- ov[!is.na(ov)]
  cls
}

# Recommended properties of term_versions.csv, without the UseWithIRI variants.
# The same local name can exist in dc: and dcterms:, so the namespace priority
# is dwc: > dcterms: > dc:.
read_tdwg_terms <- function(path) {
  raw <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  use_with_iri <- "http://rs.tdwg.org/dwc/terms/attributes/UseWithIRI"
  active <- raw[
    raw$status == "recommended" &
      raw$rdf_type == "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property" &
      raw$organized_in != use_with_iri, , drop = FALSE
  ]
  ns_priority <- c(
    "http://rs.tdwg.org/dwc/terms/"    = 1L,
    "http://purl.org/dc/terms/"        = 2L,
    "http://purl.org/dc/elements/1.1/" = 3L
  )
  prio <- vapply(active$organized_in, function(x) {
    hit <- which(startsWith(x, names(ns_priority)))
    if (length(hit)) ns_priority[[hit[[1]]]] else 4L
  }, FUN.VALUE = integer(1), USE.NAMES = FALSE)
  active <- active[order(prio), , drop = FALSE]
  active <- active[!duplicated(active$term_localName), , drop = FALSE]
  data.frame(
    term          = active$term_localName,
    class         = map_class(active$term_localName, active$organized_in),
    definition_en = trimws(active$definition),
    examples      = trimws(active$examples),
    stringsAsFactors = FALSE
  )
}

read_source_csv <- function(path) {
  df <- utils::read.csv(path, stringsAsFactors = FALSE, encoding = "UTF-8")
  chr <- vapply(df, is.character, logical(1))
  df[chr] <- lapply(df[chr], function(x) {
    x[is.na(x)] <- ""
    trimws(x)
  })
  stopifnot(!any(duplicated(df$term)))
  df
}

build_dwc_catalogs <- function(tdwg, sources_dir) {
  base_src <- read_source_csv(file.path(sources_dir, "dwc_base_terms.csv"))
  pt <- read_source_csv(file.path(sources_dir, "dwc_definitions_pt.csv"))
  es <- read_source_csv(file.path(sources_dir, "dwc_definitions_es.csv"))

  missing <- setdiff(ordered_terms, tdwg$term)
  if (length(missing)) {
    stop("Base terms not in the TDWG vocabulary: ", paste(missing, collapse = ", "))
  }
  missing <- setdiff(ordered_terms, base_src$term)
  if (length(missing)) {
    stop("Base terms not in dwc_base_terms.csv: ", paste(missing, collapse = ", "))
  }

  bi <- match(ordered_terms, base_src$term)
  base <- data.frame(
    term          = ordered_terms,
    class         = tdwg$class[match(ordered_terms, tdwg$term)],
    definition_en = base_src$definition_en[bi],
    definition_pt = base_src$definition_pt[bi],
    examples      = base_src$examples[bi],
    required      = as.logical(base_src$required[bi]),
    data_type     = base_src$data_type[bi],
    stringsAsFactors = FALSE
  )
  others <- tdwg[!tdwg$term %in% ordered_terms, , drop = FALSE]
  others <- others[order(others$term), , drop = FALSE]
  others$definition_pt <- pt$definition_pt[match(others$term, pt$term)]
  others$required <- FALSE
  others$data_type <- "string"
  full <- rbind(base, others[, names(base)])

  hi <- match(full$term, card_hints$term)
  full$card_hint_pt <- ifelse(is.na(hi), "", card_hints$card_hint_pt[hi])
  full$card_hint_en <- ifelse(is.na(hi), "", card_hints$card_hint_en[hi])
  ei <- match(full$term, es$term)
  full$definition_es <- es$definition_es[ei]
  full$card_hint_es <- es$card_hint_es[ei]
  rownames(full) <- NULL

  for (lang in c("pt", "es")) {
    col <- paste0("definition_", lang)
    empty <- full$term[is.na(full[[col]]) | !nzchar(full[[col]])]
    if (length(empty)) {
      stop("Terms without a ", toupper(lang), " definition (add them to ",
           "data-raw/dwc_definitions_", lang, ".csv): ", paste(empty, collapse = ", "))
    }
  }

  base <- full[seq_along(ordered_terms), , drop = FALSE]
  rownames(base) <- NULL
  list(base = base[catalog_columns], full = full[catalog_columns])
}

# Checks both catalogs together. Any failure stops before the shipped files
# are replaced.
validate_dwc_catalogs <- function(cats) {
  base <- cats$base
  full <- cats$full
  n <- length(ordered_terms)
  stopifnot(
    identical(names(base), catalog_columns),
    identical(names(full), catalog_columns),
    identical(base$term, ordered_terms),
    identical(full[seq_len(n), , drop = FALSE], base),
    !is.unsorted(full$term[-seq_len(n)]),
    !any(duplicated(full$term)),
    !anyNA(full),
    is.logical(full$required),
    all(base$required[match(required_terms, base$term)]),
    !any(full$required[-seq_len(n)])
  )
  for (lang in c("en", "pt", "es")) {
    def <- full[[paste0("definition_", lang)]]
    hint <- full[[paste0("card_hint_", lang)]]
    stopifnot(all(nzchar(def)))
    # Every language hints the same terms, and a hint that is not shorter
    # than its definition gives the card nothing.
    stopifnot(identical(nzchar(hint), nzchar(full$card_hint_en)))
    stopifnot(all(nchar(hint[nzchar(hint)]) < nchar(def[nzchar(hint)])))
  }
  invisible(TRUE)
}

# `rename` exists so a test can fail one replacement.
publish_dwc_catalogs <- function(cats, out_dir, rename = file.rename) {
  files <- c(base = "dwc_terms.rds", full = "dwc_full_catalog.rds")
  validate_dwc_catalogs(cats)
  staging <- tempfile("dwc_catalogs_", tmpdir = out_dir)
  dir.create(staging)
  on.exit(unlink(staging, recursive = TRUE), add = TRUE)
  staged <- stats::setNames(file.path(staging, files), names(files))
  for (k in names(files)) saveRDS(cats[[k]], staged[[k]])
  # The files that replace the shipped ones are the ones validated.
  validate_dwc_catalogs(lapply(staged, readRDS))

  # Two files cannot be replaced in one atomic step. The previous catalogs
  # wait in staging, and a failed replacement puts both back.
  targets <- file.path(out_dir, files)
  backups <- file.path(staging, paste0(files, ".previous"))
  had <- file.exists(targets)
  moved <- rep(FALSE, length(files))
  replaced <- rep(FALSE, length(files))
  ok <- tryCatch({
    for (i in which(had)) moved[i] <- rename(targets[i], backups[i])
    stopifnot(all(moved[had]))
    for (i in seq_along(files)) replaced[i] <- rename(staged[[i]], targets[i])
    stopifnot(all(replaced))
    TRUE
  }, error = function(e) e)
  if (!isTRUE(ok)) {
    unlink(targets[replaced])
    file.rename(backups[moved], targets[moved])
    stop("Could not publish the catalogs, the previous ones are back: ",
         conditionMessage(ok), call. = FALSE)
  }
  invisible(targets)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  tdwg_path <- if (length(args)) {
    args[[1]]
  } else {
    message("Downloading TDWG term_versions.csv...")
    tmp <- tempfile(fileext = ".csv")
    utils::download.file(tdwg_url, tmp, quiet = TRUE)
    tmp
  }
  cats <- build_dwc_catalogs(read_tdwg_terms(tdwg_path), "data-raw")
  out <- publish_dwc_catalogs(cats, file.path("inst", "extdata"))
  message("Saved: ", paste(out, collapse = ", "), " (", nrow(cats$base), " base terms, ",
          nrow(cats$full), " in the full catalog)")
}
