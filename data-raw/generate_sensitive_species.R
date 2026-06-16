# Build the sensitive-species lookup used to mask coordinates on export.
#
# Source: data-raw/redlist_brasil_mma.md
#   Official MMA Brazilian national list of threatened species
#   (Portaria MMA no 148 de 2022, which updates the flora/fauna anexos of
#   Portarias 443/2014 and 444/2014), a Markdown table.
#   Two row layouts coexist. Flora rows hold five cells: number, legacy
#   marker, family, species, category. Fauna rows hold six: number,
#   marker, order, family, species, category. The species name is always
#   the second-to-last cell and the category the last cell. Valid
#   categories are VU, EN, CR and CR (PEX).
#
# Output: inst/extdata/sensitive_species.rds
#   A table with columns scientificName, match_key and category
#   (VU/EN/CR/CR (PEX)), deduped by match_key keeping the most
#   restrictive category. The match_key uses the SAME normalization the
#   name validator applies, so the list and validated names compare
#   identically. The category drives the per-record generalization grid
#   on export (ADR-092).
#
# To regenerate (from the project root):
#   Rscript -e "source('data-raw/generate_sensitive_species.R')"

pkgload::load_all(".", quiet = TRUE)

src_path <- file.path("data-raw", "redlist_brasil_mma.md")
out_path <- file.path("inst", "extdata", "sensitive_species.rds")

lines <- readLines(src_path, encoding = "UTF-8", warn = FALSE)

# Strip a leading UTF-8 BOM without using a non-ASCII source literal.
bom <- rawToChar(as.raw(c(0xEF, 0xBB, 0xBF)))
Encoding(bom) <- "UTF-8"
if (length(lines) > 0L) {
  lines[1L] <- sub(paste0("^", bom), "", lines[1L])
}

category_re <- "^(VU|EN|CR|CR \\(PEX\\))$"

parse_row <- function(line) {
  if (!grepl("|", line, fixed = TRUE)) {
    return(NULL)
  }
  cells <- strsplit(line, "|", fixed = TRUE)[[1]]
  cells <- trimws(cells)
  # Markdown rows start with a pipe, so split yields an empty leading
  # token; R's strsplit already drops the trailing empty from the
  # closing pipe. Drop the leading one, then strip trailing empty cells.
  if (length(cells) > 0L && !nzchar(cells[1L])) {
    cells <- cells[-1L]
  }
  while (length(cells) > 0L && !nzchar(cells[length(cells)])) {
    cells <- cells[-length(cells)]
  }
  if (length(cells) < 3L) {
    return(NULL)
  }
  row_id <- cells[1L]
  category <- cells[length(cells)]
  species <- cells[length(cells) - 1L]
  # Keep only real data rows: integer row number plus a valid category
  # code. This alone rejects titles, header rows, dash separators, blank
  # rows and the footer legend, for both flora and fauna layouts.
  if (!grepl("^[0-9]+$", row_id) || !grepl(category_re, category)) {
    return(NULL)
  }
  tokens <- strsplit(species, "\\s+")[[1]]
  tokens <- tokens[nzchar(tokens)]
  # Scientific genus names are plain Latin (no accents) and capitalized.
  if (length(tokens) < 2L || !grepl("^[A-Z]", tokens[1L])) {
    return(NULL)
  }
  # Threat category drives the generalization grid on export (ADR-092).
  c(species = trimws(species), category = trimws(category))
}

parsed <- lapply(lines, parse_row)
parsed <- parsed[!vapply(parsed, is.null, logical(1L))]
raw_names <- vapply(parsed, function(x) unname(x[["species"]]), character(1L))
raw_cats <- vapply(parsed, function(x) unname(x[["category"]]), character(1L))

# Same normalization the validator uses, so list and validated names match.
canonical <- vapply(
  raw_names,
  function(nm) {
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

sensitive_species <- data.frame(
  scientificName = raw_names,
  match_key = match_key,
  category = raw_cats,
  stringsAsFactors = FALSE
)
keep <- !is.na(sensitive_species$match_key) &
  nzchar(sensitive_species$match_key)
sensitive_species <- sensitive_species[keep, , drop = FALSE]
# On a match_key collision keep the most restrictive category so the same
# normalized taxon never gets a weaker generalization than the list asks for.
cat_rank <- c("VU" = 1L, "EN" = 2L, "CR" = 3L, "CR (PEX)" = 4L)
rank <- cat_rank[sensitive_species$category]
rank[is.na(rank)] <- 0L
sensitive_species <- sensitive_species[
  order(-rank, sensitive_species$scientificName), ,
  drop = FALSE
]
sensitive_species <- sensitive_species[
  !duplicated(sensitive_species$match_key), ,
  drop = FALSE
]
sensitive_species <- sensitive_species[
  order(sensitive_species$scientificName), ,
  drop = FALSE
]
rownames(sensitive_species) <- NULL

dir.create(
  file.path("inst", "extdata"),
  recursive = TRUE,
  showWarnings = FALSE
)
saveRDS(sensitive_species, file = out_path, version = 2)

message(sprintf(
  "Saved %d sensitive species (from %d parsed names) to %s",
  nrow(sensitive_species), length(raw_names), out_path
))
