#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom DBI dbConnect dbDisconnect dbExecute dbGetQuery dbWithTransaction dbIsValid dbExistsTable
#' @importFrom RSQLite SQLite
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom digest digest2int
#' @importFrom stringr str_detect str_trim str_split str_replace_all
#' @importFrom shiny moduleServer NS reactive reactiveVal reactiveValues observeEvent req
#' @importFrom shiny renderUI showNotification validate need
#' @importFrom withr with_tempdir defer
## usethis namespace: end
NULL

# Pre-warm only the caches that are cheap and needed on the first screen: every
# entry below is a sub-100ms JSON/RDS read that pulls no extra namespace.
#
# The Natural Earth land reference is deliberately NOT pre-warmed. It is loaded
# lazily by coords_load_ne_land(10L) inside validate_coords_cc_df(), its only
# consumer, which runs from the Validate coordinates button behind a blocking
# progress modal. Warming it here cost ~5.8s of every package load: ~4.4s to
# load the `terra` namespace and ~1.4s to convert the stored sf to a SpatVector.
# `terra` is in Imports but intentionally absent from NAMESPACE (it is `::`-only,
# like sf/taxadb/leaflet/DT), so it stays lazy unless something forces it --
# which is exactly what this line used to do. ne_land_env caches process-wide,
# so the first validation pays the cost once and every later run is warm.
.onLoad <- function(libname, pkgname) {
    tryCatch(load_i18n_dict(), error = function(e) NULL)
    tryCatch(load_dwc_terms_rds(), error = function(e) NULL)
    tryCatch(get_dwc_full_catalog(), error = function(e) NULL)
    tryCatch(load_invasive_species(), error = function(e) NULL)
    tryCatch(coords_load_aliases(), error = function(e) NULL)
    tryCatch(coords_build_fuzzy_reference(), error = function(e) NULL)
}
