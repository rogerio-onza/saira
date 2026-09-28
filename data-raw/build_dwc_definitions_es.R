# Title: Add Spanish DwC definitions and card hints to the term catalogs
# Author: Rogerio Nunes Oliveira
# Date: 2026-09-27
#
# Input:  data-raw/dwc_definitions_es.csv (term, definition_es, card_hint_es)
# Output: inst/extdata/dwc_terms.rds and inst/extdata/dwc_full_catalog.rds,
#         each with the columns definition_es and card_hint_es
#
# This step is separate from build_dwc_full_catalog.R because that script
# downloads the TDWG vocabulary again, which can change the English text.
# This step only adds the Spanish columns and changes no other column.
#
# Run it after build_dwc_full_catalog.R or build_dwc_terms.R, because those
# scripts write the .rds files without the Spanish columns.
#
# To regenerate (from the project root):
#   source(here::here("data-raw/build_dwc_definitions_es.R"))

es_path <- file.path("data-raw", "dwc_definitions_es.csv")
es <- utils::read.csv(es_path, stringsAsFactors = FALSE, encoding = "UTF-8")
es$definition_es <- trimws(es$definition_es)
es$card_hint_es[is.na(es$card_hint_es)] <- ""
es$card_hint_es <- trimws(es$card_hint_es)
stopifnot(!any(duplicated(es$term)))

add_es_columns <- function(df) {
  idx <- match(df$term, es$term)
  missing <- df$term[is.na(idx) | !nzchar(es$definition_es[idx])]
  if (length(missing) > 0L) {
    stop("Terms without an ES definition (add them to ", es_path, "): ",
         paste(missing, collapse = ", "))
  }
  df$definition_es <- es$definition_es[idx]
  df$card_hint_es <- es$card_hint_es[idx]

  # The ES hints must cover the same terms as the PT/EN hints, and a hint
  # that is not shorter than its definition gives the card no benefit.
  if ("card_hint_en" %in% names(df)) {
    stopifnot(identical(nzchar(df$card_hint_es), nzchar(df$card_hint_en)))
  }
  hinted <- nzchar(df$card_hint_es)
  stopifnot(all(nchar(df$card_hint_es[hinted]) < nchar(df$definition_es[hinted])))
  df
}

for (path in file.path("inst", "extdata",
                       c("dwc_terms.rds", "dwc_full_catalog.rds"))) {
  df <- readRDS(path)
  df <- add_es_columns(df)
  saveRDS(df, path)
  message("Saved: ", path, " (", nrow(df), " terms with ES definitions)")
}
