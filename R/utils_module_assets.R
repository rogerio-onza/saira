# Behavior factories of the module UIs live in inst/app/www/module-*.js and
# load as one dependency (ADR-170). R renders only a call with a JSON
# configuration, so IDs and translated text never become code.
module_behavior_dependency <- function() {
    htmltools::htmlDependency(
        name = "saira-module-behavior",
        version = as.character(utils::packageVersion("saira")),
        src = c(file = system.file("app", "www", package = "saira")),
        all_files = FALSE,
        script = c(
            "module-app-ui.js", "module-export-download.js", "module-export.js",
            "module-mapping-loading.js", "module-mapping.js", "module-preview.js",
            "module-sensitive-coords.js", "module-upload.js", "module-validate-coords.js",
            "module-validate-names.js", "module-wiki.js", "module-utils-coords.js"
        )
    )
}

# `table_context` passes the DT callback's `table` to the factory.
module_behavior_call <- function(name, config = list(), table_context = FALSE) {
    config_json <- jsonlite::toJSON(config, auto_unbox = TRUE, null = "null")
    # Keep translated text and dataset values inside a script-safe JSON string.
    config_json <- gsub("<", "\\u003c", config_json, fixed = TRUE)
    paste0(
        "window.sairaModuleBehavior.", name, "(", config_json,
        if (isTRUE(table_context)) ", table" else "", ")"
    )
}

module_behavior_html <- function(name, config = list()) {
    htmltools::attachDependencies(
        shiny::HTML(module_behavior_call(name, config)),
        module_behavior_dependency()
    )
}

module_behavior_on_render <- function(widget, name, config = list()) {
    widget <- htmlwidgets::onRender(widget, module_behavior_call(name, config))
    widget$dependencies <- c(widget$dependencies, list(module_behavior_dependency()))
    widget
}
