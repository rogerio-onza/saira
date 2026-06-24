# Title: Run Saira Application
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-08
# Version: 1.0

#' Run the Saira Shiny Application
#'
#' Starts the Saira app for biodiversity data standardization
#'
#' @param ... Additional arguments passed to shinyApp
#' @return A Shiny app object
#' @export
run_app <- function(...) {
    # Set max upload file size to 500 MB
    options(shiny.maxRequestSize = 500 * 1024^2)

    # Surface unhandled Shiny errors as R warnings (visible in server logs)
    options(shiny.error = function() {
        warning("[Sa\u00EDra] Unhandled error in Shiny reactive context", call. = FALSE)
    })

    # Warn (server logs) when the loaded namespace is older than the installed
    # package: the user updated Saira without restarting R. The in-app banner is
    # raised in app_server() via notify_session_stale().
    stale <- saira_session_is_stale()
    if (isTRUE(stale$stale)) {
        warning(sprintf(
            "[Sa\u00EDra] Session is running v%s but v%s is installed on disk. Restart R to load the update.",
            stale$loaded, stale$installed
        ), call. = FALSE)
    }

    # Get path to www directory
    www_path <- system.file("app/www", package = "saira")

    # If running in dev mode, use local path
    if (www_path == "") {
        www_path <- "inst/app/www"
    }

    shiny::addResourcePath("www", www_path)

    shiny::shinyApp(
        ui = app_ui(),
        server = app_server,
        options = list(launch.browser = getOption("shiny.launch.browser", interactive())),
        ...
    )
}
