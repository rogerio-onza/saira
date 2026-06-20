# Build the sensitive-species lookup used to mask coordinates on export.
#
# Source: data-raw/redlist_brasil_mma.md
#   Official MMA Brazilian national list of threatened species, a Markdown
#   table built from three DOU portarias: flora (ANEXO 1) from Portaria MMA
#   no 148 de 2022 (updates Portaria 443/2014); terrestrial fauna (ANEXO 2)
#   from Portaria MMA no 1.704 de 2026 (updates Portaria 444/2014); aquatic
#   fauna (ANEXO 3) from Portaria GM/MMA no 1.667 de 2026 (revokes 445/2014).
#   Row layouts vary by annex, but the species name is always the
#   second-to-last cell and the category the last cell. Threatened categories
#   are VU, EN, CR and CR (PEX); the 2026 fauna lists spell the last one
#   CR (PE) -- same meaning -- and it is canonicalized to CR (PEX) below.
#   Extinct tags (EX, RE, EW) are intentionally excluded from masking.
#
# Output: inst/extdata/sensitive_species.rds
#   A table with columns scientificName, match_key, category
#   (VU/EN/CR/CR (PEX)) and source (the portaria that listed the taxon),
#   deduped by match_key keeping the most restrictive category. The
#   match_key uses the SAME normalization the name validator applies, so
#   the list and validated names compare identically. The category drives
#   the per-record generalization grid on export (ADR-092); the source
#   feeds the mmaSource conservation-status field on export.
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

category_re <- "^(VU|EN|CR|CR \\(PE\\)|CR \\(PEX\\))$"

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

# Portaria provenance per annex. The source file is a flat Markdown table with
# three standalone section markers ("ANEXO 1/2/3"); track which annex each row
# falls under so the export can cite the portaria a taxon's listing comes from.
annex_source <- c(
  "1" = "Portaria 148/2022",   # ANEXO 1 - flora (Portaria MMA 148/2022)
  "2" = "Portaria 1.704/2026", # ANEXO 2 - fauna terrestre (Portaria MMA 1.704/2026)
  "3" = "Portaria 1.667/2026"  # ANEXO 3 - fauna aquatica (Portaria GM/MMA 1.667/2026)
)

current_source <- NA_character_
parsed <- list()
for (line in lines) {
  marker <- regmatches(line, regexec("^ANEXO\\s+([123])\\s*$", line))[[1L]]
  if (length(marker) == 2L) {
    current_source <- unname(annex_source[[marker[[2L]]]])
    next
  }
  row <- parse_row(line)
  if (is.null(row)) {
    next
  }
  parsed[[length(parsed) + 1L]] <- c(row, source = current_source)
}

raw_names <- vapply(parsed, function(x) unname(x[["species"]]), character(1L))
raw_cats <- vapply(parsed, function(x) unname(x[["category"]]), character(1L))
raw_source <- vapply(parsed, function(x) unname(x[["source"]]), character(1L))

# The 2026 fauna portarias spell "possibly extinct" CR (PE); the flora list
# (and the rest of the app, i18n included) uses CR (PEX). Same meaning, so
# canonicalize to a single label that flows unchanged downstream.
raw_cats[raw_cats == "CR (PE)"] <- "CR (PEX)"

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
  source = raw_source,
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
