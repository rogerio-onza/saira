# Build the sensitive-species lookup used to mask coordinates on export.
#
# Source: data-raw/redlist_brasil_mma.md
#   Official MMA Brazilian national list of threatened species
#   (Portaria MMA 443 de 2014, flora and fauna anexos), a Markdown table.
#   Two row layouts coexist. Flora rows hold five cells: number, legacy
#   marker, family, species, category. Fauna rows hold six: number,
#   marker, order, family, species, category. The species name is always
#   the second-to-last cell and the category the last cell. Valid
#   categories are VU, EN, CR and CR (PEX).
#
# Output: inst/extdata/sensitive_species.rds
#   A table with columns scientificName and match_key, deduped by
#   match_key. The match_key uses the SAME normalization the name
#   validator applies, so the list and validated names compare
#   identically.
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
  species
}

raw_names <- unlist(lapply(lines, parse_row), use.names = FALSE)
raw_names <- unique(trimws(raw_names))

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
  stringsAsFactors = FALSE
)
keep <- !is.na(sensitive_species$match_key) &
  nzchar(sensitive_species$match_key)
sensitive_species <- sensitive_species[keep, , drop = FALSE]
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
