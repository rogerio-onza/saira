# Desktop entry point: run the installed package, never pkgload or renv.
local({
    options(shiny.launch.browser = FALSE)

    # The Electron shell sets these folders. A manual Rscript run sets them here,
    # so preview models and provider caches stay apart from the regular app.
    base <- Sys.getenv("SAIRA_DESKTOP_HOME", unset = "")
    if (!nzchar(base)) {
        base <- Sys.getenv("LOCALAPPDATA", unset = "")
        if (!nzchar(base)) base <- tools::R_user_dir("saira-desktop-preview", "data")
        base <- file.path(base, "saira-desktop-preview")
        Sys.setenv(
            R_USER_DATA_DIR = file.path(base, "data"),
            R_USER_CACHE_DIR = file.path(base, "cache")
        )
    }
    if (!nzchar(Sys.getenv("SAIRA_DATA_DIR"))) {
        Sys.setenv(SAIRA_DATA_DIR = tools::R_user_dir("saira", "data"))
    }

    saira::run_app()
})
