# Title: Build complete DwC term catalog from TDWG vocabulary
# Author: Rogerio Nunes Oliveira
# Date: 2026-05-06
# Version: 1.0
#
# Output: inst/extdata/dwc_full_catalog.rds
#
# Scope: all recommended dwc: + dcterms: properties (~217 terms),
# excluding UseWithIRI technical variants. Deduplicates dc:/dcterms:
# conflicts keeping dcterms: as the authoritative namespace.
#
# Merge strategy:
#   - Base terms (dwc_terms.rds) retain definition_pt, required, data_type
#   - New terms: required = FALSE, data_type = "string"; definition_pt is
#     filled from data-raw/dwc_definitions_pt.csv (curated PT-BR translations
#     of every non-base recommended term). Base PT always wins on conflict.
#   - The build asserts 100% PT coverage and fails loudly if any term is
#     left without a Portuguese definition.
#
# To regenerate (from the project root):
#   source(here::here("data-raw/build_dwc_full_catalog.R"))

tdwg_url <- paste0(
  "https://raw.githubusercontent.com/tdwg/dwc/master/",
  "vocabulary/term_versions.csv"
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
    if (!nzchar(x) || is.na(x)) return("Record-level")
    hit <- class_map[[x]]
    if (is.null(hit)) "Record-level" else hit
  }, FUN.VALUE = character(1), USE.NAMES = FALSE)
  ov <- term_class_overrides[term_local_name]
  cls[!is.na(ov)] <- ov[!is.na(ov)]
  cls
}

message("Downloading TDWG term_versions.csv...")
tmp <- tempfile(fileext = ".csv")
utils::download.file(tdwg_url, tmp, quiet = TRUE)
raw <- utils::read.csv(tmp, stringsAsFactors = FALSE, encoding = "UTF-8")

use_with_iri <- "http://rs.tdwg.org/dwc/terms/attributes/UseWithIRI"
active <- raw[
  raw$status == "recommended" &
  raw$rdf_type == "http://www.w3.org/1999/02/22-rdf-syntax-ns#Property" &
  raw$organized_in != use_with_iri,
]
message("  Recommended properties (ex-UseWithIRI): ", nrow(active))

# Deduplicate: same term_localName may exist in dc: and dcterms: namespaces.
# Priority: dwc: > dcterms: > dc:
ns_priority <- c(
  "http://rs.tdwg.org/dwc/terms/"    = 1L,
  "http://purl.org/dc/terms/"        = 2L,
  "http://purl.org/dc/elements/1.1/" = 3L
)
active$ns_prio <- vapply(active$organized_in, function(x) {
  for (ns in names(ns_priority)) {
    if (startsWith(x, ns)) return(ns_priority[[ns]])
  }
  4L
}, FUN.VALUE = integer(1))
active <- active[order(active$ns_prio), ]
active <- active[!duplicated(active$term_localName), ]
message("  After deduplication: ", nrow(active), " terms")

base_path <- file.path("inst", "extdata", "dwc_terms.rds")
base <- readRDS(base_path)
message("  Base terms loaded: ", nrow(base))

catalog <- data.frame(
  term          = active$term_localName,
  class         = map_class(active$term_localName, active$organized_in),
  definition_en = trimws(active$definition),
  definition_pt = "",
  examples      = trimws(active$examples),
  required      = FALSE,
  data_type     = "string",
  stringsAsFactors = FALSE
)

for (col in c("definition_pt", "required", "data_type")) {
  idx_catalog <- match(base$term, catalog$term)
  valid       <- !is.na(idx_catalog)
  catalog[idx_catalog[valid], col] <- base[[col]][valid]
}

# Fill PT for non-base terms from the curated translation file. Only fills
# rows still empty after the base merge, so base PT definitions always win.
pt_path <- file.path("data-raw", "dwc_definitions_pt.csv")
pt_csv  <- utils::read.csv(pt_path, stringsAsFactors = FALSE,
                           encoding = "UTF-8")
pt_csv$definition_pt <- trimws(pt_csv$definition_pt)
empty_pt <- !nzchar(trimws(catalog$definition_pt))
pt_idx   <- match(catalog$term[empty_pt], pt_csv$term)
catalog$definition_pt[empty_pt] <- pt_csv$definition_pt[pt_idx]
catalog$definition_pt[is.na(catalog$definition_pt)] <- ""
message("  PT translations merged from ", pt_path, " (",
        sum(!is.na(pt_idx)), " filled)")

base_order   <- match(base$term, catalog$term)
base_order   <- base_order[!is.na(base_order)]
extra_idx    <- setdiff(seq_len(nrow(catalog)), base_order)
extra_sorted <- extra_idx[order(catalog$term[extra_idx])]
catalog      <- catalog[c(base_order, extra_sorted), ]
rownames(catalog) <- NULL

message(
  "  Final catalog: ", nrow(catalog), " terms (",
  sum(catalog$required), " required, ",
  sum(nzchar(catalog$definition_pt)), " with PT translation)"
)

missing_pt <- catalog$term[!nzchar(trimws(catalog$definition_pt))]
if (length(missing_pt) > 0L) {
  stop("Terms without a PT definition (add them to ",
       "data-raw/dwc_definitions_pt.csv): ",
       paste(missing_pt, collapse = ", "))
}
stopifnot(sum(nzchar(trimws(catalog$definition_pt))) == nrow(catalog))

out_path <- file.path("inst", "extdata", "dwc_full_catalog.rds")
saveRDS(catalog, out_path)
message("Saved: ", out_path)

stopifnot(all(base$term %in% catalog$term))
message("Sanity check passed: all base terms present in full catalog.")
