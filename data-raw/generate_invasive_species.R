# Build the invasive-alien-species lookup used to flag records in name
# validation and to pre-suggest establishmentMeans in the mapping.
#
# Source: data-raw/invasive_species_horus_2023.csv  -- NOT VERSIONED (gitignored)
#   "Lista de especies exoticas invasoras do Brasil", Instituto Horus, 2023.
#   Only the generated RDS ships; the source spreadsheet is kept out of the
#   repository. To regenerate, obtain the Instituto Horus list, save it at the
#   path above and run this script. The taxa currently in the RDS carry
#   source = "Instituto Horus, 2023" so their provenance survives without it.
#   A CSV export with TWO header rows: the real header, then a second row of
#   field labels ("Nome Cientifico", "Autor", ...) which is dropped below.
#   Column `Supplied Name` carries the clean binomial; `scientificName` carries
#   the authored form and is blank for a handful of taxa, so the canonical name
#   falls back between the two. `Motivo da introducao no Brasil` records why the
#   taxon was brought in (aquarium fish, ornamental plants, ...) and is kept for
#   a future dwc:pathway mapping -- it is NOT a degreeOfEstablishment.
#
# Output: inst/extdata/invasive_species.rds
#   Columns scientificName, match_key, kingdom, vernacularName,
#   introduction_reason and source, deduped by match_key. The match_key uses
#   the SAME normalization the name validator applies, so the list and
#   validated names compare identically (see build_invasive_match_keys in
#   R/utils_invasive.R -- the two must stay in lockstep).
#
#   Being on this list says the taxon is alien and invasive in Brazil, which
#   supports establishmentMeans = "introduced". It does NOT determine
#   degreeOfEstablishment: whether an individual is captive, released or
#   invasive is a property of the record, not of the species.
#
# To regenerate (from the project root):
#   Rscript -e "source('data-raw/generate_invasive_species.R')"

pkgload::load_all(".", quiet = TRUE)

src_path <- file.path("data-raw", "invasive_species_horus_2023.csv")
out_path <- file.path("inst", "extdata", "invasive_species.rds")

raw <- utils::read.csv(
  src_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8",
  check.names = FALSE
)

# Row 1 of the data is the source's second header row, not a taxon.
if (nrow(raw) > 0L && identical(trimws(raw[["guid"]][1L]), "")) {
  raw <- raw[-1L, , drop = FALSE]
}

blank_to_na <- function(x) {
  x <- trimws(as.character(x))
  x[!nzchar(x)] <- NA_character_
  x
}

supplied <- blank_to_na(raw[["Supplied Name"]])
authored <- blank_to_na(raw[["scientificName"]])

# Prefer the clean binomial; fall back to the authored form (27 rows ship a
# blank Supplied Name). Authorship is stripped by the normalizer either way.
canonical_name <- ifelse(is.na(supplied), authored, supplied)

# Same normalization the validator uses, so list and validated names match.
canonical <- vapply(
  canonical_name,
  function(nm) {
    if (is.na(nm)) {
      return(NA_character_)
    }
    normalize_scientific_name(
      nm,
      remove_authors = TRUE,
      ignore_qualifiers = TRUE
    )
  },
  FUN.VALUE = character(1),
  USE.NAMES = FALSE
)
match_key <- normalize_for_matching(canonical)

invasive_species <- data.frame(
  scientificName = canonical_name,
  match_key = match_key,
  kingdom = blank_to_na(raw[["Kingdom"]]),
  vernacularName = blank_to_na(raw[["VernacularName"]]),
  # "Motivo da introducao no Brasil" -- escaped, no non-ASCII source literal.
  introduction_reason = blank_to_na(
    raw[["Motivo da introdu\u00e7\u00e3o no Brasil"]]
  ),
  source = "Instituto Horus, 2023",
  stringsAsFactors = FALSE
)

keep <- !is.na(invasive_species$match_key) & nzchar(invasive_species$match_key)
invasive_species <- invasive_species[keep, , drop = FALSE]
invasive_species <- invasive_species[
  order(invasive_species$scientificName), ,
  drop = FALSE
]
invasive_species <- invasive_species[
  !duplicated(invasive_species$match_key), ,
  drop = FALSE
]
rownames(invasive_species) <- NULL

dir.create(
  file.path("inst", "extdata"),
  recursive = TRUE,
  showWarnings = FALSE
)
saveRDS(invasive_species, file = out_path, version = 2)

message(sprintf(
  "Saved %d invasive species (from %d source rows) to %s",
  nrow(invasive_species), nrow(raw), out_path
))
