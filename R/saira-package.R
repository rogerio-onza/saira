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

.onLoad <- function(libname, pkgname) {
    tryCatch(load_i18n_dict(), error = function(e) NULL)
    tryCatch(load_dwc_terms_rds(), error = function(e) NULL)
    tryCatch(coords_load_aliases(), error = function(e) NULL)
}
