# Build the invasive-alien-species lookup used to flag records in name
# validation and to pre-suggest establishmentMeans in the mapping.
#
# Sources -- BOTH NOT VERSIONED (gitignored). Only the generated RDS ships.
#
# 1. data-raw/invasive_species_horus_2023.csv  -- defines WHICH taxa are listed.
#   "Lista de especies exoticas invasoras do Brasil", Instituto Horus, 2023.
#   A CSV export with TWO header rows: the real header, then a second row of
#   field labels ("Nome Cientifico", "Autor", ...) which is dropped below.
#   Column `Supplied Name` carries the clean binomial; `scientificName` carries
#   the authored form and is blank for a handful of taxa, so the canonical name
#   falls back between the two. `Motivo da introducao no Brasil` records why the
#   taxon was brought in (aquarium fish, ornamental plants, ...) and is kept for
#   a future dwc:pathway mapping -- it is NOT a degreeOfEstablishment. This file
#   alone decides membership: the detail export below is used only to describe
#   taxa already here, never to add or remove one.
#
# 2. data-raw/invasive_species_horus_detail.csv  -- describes them.
#   A richer export of the same Horus database, one header row. Supplies the
#   authoritative `origin` (Native / Non-native / Cripto / Hybrid) and the
#   free-text `native_distribution_area`. It also carries impact and EICAT
#   fields that are deliberately NOT consumed here. 468 of the 483 listed taxa
#   match it; the 15 that do not are names this export has since renamed
#   (Sansevieria trifasciata -> Dracaena trifasciata, Schefflera arboricola ->
#   Heptapleurum arboricola, ...). They are kept, because a spreadsheet may
#   still use the old name, and fall back to the CTFB/Flora rule below.
#
# Output: inst/extdata/invasive_species.rds
#   Columns scientificName, match_key, kingdom, vernacularName,
#   introduction_reason, origin_class, native_range and source, deduped by
#   match_key. The match_key uses the SAME normalization the name validator
#   applies, so the list and validated names compare identically (see
#   build_invasive_match_keys in R/utils_invasive.R -- the two must stay in
#   lockstep).
#
#   origin_class splits the list in two, because the Horus list does NOT hold
#   only taxa alien to Brazil. It also carries Brazilian natives that are
#   invasive outside their natural range within the country -- the coati on
#   Fernando de Noronha, Callithrix spp. in Atlantic Forest fragments, Cichla
#   spp. moved between basins. Treating list membership as "alien" labelled
#   roughly a quarter of the list wrongly and pre-filled establishmentMeans =
#   "introduced" for native records.
#
#     "translocated_native"  Horus records origin = Native. Invasive somewhere
#                            in Brazil, but not alien to it.
#     "alien"                everything else.
#
#   Horus is the primary authority here: it built the list, so it is better
#   placed than a general catalogue to say what its own rows mean. CTFB / Flora
#   e Funga do Brasil origin = native is the fallback, and only for the 15 taxa
#   the detail export does not cover.
#
#   The rule only ever DOWNGRADES on positive evidence of nativeness. Non-native,
#   Cripto, Hybrid, blank and unmatched all keep the pre-existing "alien"
#   treatment, so a name that fails to resolve through a synonym cannot silently
#   lose its flag.
#
#   Being classed "alien" says the taxon is alien and invasive in Brazil, which
#   supports establishmentMeans = "introduced". It does NOT determine
#   degreeOfEstablishment: whether an individual is captive, released or
#   invasive is a property of the record, not of the species. A
#   "translocated_native" supports neither: whether a given record sits inside
#   or outside the taxon's natural range is not knowable from the name alone.
#   native_range is shown to the publisher so THEY can judge that; it is free
#   Portuguese prose, not a machine-readable range, and nothing tests it.
#
# Requires, besides the two CSVs, the local BR provider caches that
# brprovider_download_data("faunabr") / ("florabr") populate, for the fallback.
# The provider data versions used are printed at the end so the classification
# stays auditable.
#
# To regenerate (from the project root):
#   Rscript -e "source('data-raw/generate_invasive_species.R')"

pkgload::load_all(".", quiet = TRUE)

src_path <- file.path("data-raw", "invasive_species_horus_2023.csv")
detail_path <- file.path("data-raw", "invasive_species_horus_detail.csv")
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

# Native-status reference from the two Brazilian catalogues Saira already
# depends on. Both are read from the local provider cache; faunabr spells
# origin/taxonomicStatus in lower case and florabr capitalizes them, so both
# are folded before comparison.
br_origin_reference <- function() {
  read_provider <- function(provider_id) {
    path <- .brprovider_rds_path(provider_id)
    if (!file.exists(path)) {
      stop(sprintf(
        paste0(
          "BR provider cache missing for '%s' (%s).\n",
          "Run brprovider_download_data('%s') before regenerating the list."
        ),
        provider_id, path, provider_id
      ))
    }
    df <- readRDS(path)
    keep <- !is.na(df$origin) &
      !is.na(df$taxonomicStatus) &
      tolower(df$taxonomicStatus) %in% c("valid", "accepted")
    out <- data.frame(
      key = normalize_for_matching(
        vapply(
          as.character(df$species[keep]),
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
      ),
      origin = tolower(as.character(df$origin[keep])),
      stringsAsFactors = FALSE
    )
    out[!is.na(out$key) & nzchar(out$key), , drop = FALSE]
  }

  ref <- rbind(read_provider("faunabr"), read_provider("florabr"))
  ref[!duplicated(ref$key), , drop = FALSE]
}

detail <- utils::read.csv(
  detail_path,
  stringsAsFactors = FALSE,
  fileEncoding = "UTF-8-BOM",
  check.names = FALSE
)
detail$key <- normalize_for_matching(
  vapply(
    as.character(detail$scientific_name),
    function(nm) {
      if (is.na(nm) || !nzchar(nm)) {
        return(NA_character_)
      }
      normalize_scientific_name(nm, remove_authors = TRUE, ignore_qualifiers = TRUE)
    },
    FUN.VALUE = character(1),
    USE.NAMES = FALSE
  )
)
detail <- detail[!is.na(detail$key) & nzchar(detail$key), , drop = FALSE]
detail <- detail[!duplicated(detail$key), , drop = FALSE]

detail_idx <- match(match_key, detail$key)
horus_origin <- trimws(as.character(detail$origin[detail_idx]))
native_range <- blank_to_na(detail$native_distribution_area[detail_idx])

# Horus first; the CTFB/Flora rule only fills the gap it leaves.
ref <- br_origin_reference()
br_origin <- ref$origin[match(match_key, ref$key)]
origin_class <- ifelse(
  !is.na(horus_origin) & nzchar(horus_origin),
  ifelse(horus_origin == "Native", "translocated_native", "alien"),
  ifelse(!is.na(br_origin) & br_origin == "native", "translocated_native", "alien")
)

invasive_species <- data.frame(
  scientificName = canonical_name,
  match_key = match_key,
  kingdom = blank_to_na(raw[["Kingdom"]]),
  vernacularName = blank_to_na(raw[["VernacularName"]]),
  # "Motivo da introducao no Brasil" -- escaped, no non-ASCII source literal.
  introduction_reason = blank_to_na(
    raw[["Motivo da introdu\u00e7\u00e3o no Brasil"]]
  ),
  origin_class = origin_class,
  native_range = native_range,
  # Dropped before saving; kept this far so the summary below counts the taxa
  # that actually ship, not the pre-dedupe source rows.
  .classified_by_horus = !is.na(horus_origin) & nzchar(horus_origin),
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

classified_by_horus <- invasive_species$.classified_by_horus
invasive_species$.classified_by_horus <- NULL

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
message(sprintf(
  "  %d alien, %d translocated native; %d classified by Horus, %d by CTFB %s / Flora %s",
  sum(invasive_species$origin_class == "alien"),
  sum(invasive_species$origin_class == "translocated_native"),
  sum(classified_by_horus),
  sum(!classified_by_horus),
  .brprovider_read_meta("faunabr")$local_version,
  .brprovider_read_meta("florabr")$local_version
))
message(sprintf(
  "  %d with a native range, %d with an introduction reason",
  sum(!is.na(invasive_species$native_range)),
  sum(!is.na(invasive_species$introduction_reason))
))
