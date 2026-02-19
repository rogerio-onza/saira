# Title: Run Finch Application
# Author: Rogério Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Run the Finch Shiny Application
#'
#' Starts the Finch app for biodiversity data standardization
#'
#' @param ... Additional arguments passed to shinyApp
#' @return A Shiny app object
#' @export
run_app <- function(...) {
    options(encoding = "UTF-8")

    # Set max upload file size to 500 MB
    options(shiny.maxRequestSize = 500 * 1024^2)

    # Get path to www directory
    www_path <- system.file("app/www", package = "finch")

    # If running in dev mode, use local path
    if (www_path == "") {
        www_path <- "inst/app/www"
    }

    shiny::addResourcePath("www", www_path)

    shiny::shinyApp(
        ui = app_ui(),
        server = app_server,
        options = list(launch.browser = TRUE),
        ...
    )
}
