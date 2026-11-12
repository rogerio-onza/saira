# Desktop entry point: run the installed package, never pkgload or renv.
local({
    options(shiny.launch.browser = FALSE)

    # The Electron shell sets these folders. A manual Rscript run sets them here,
    # so desktop models and provider caches stay apart from the regular app.
    base <- Sys.getenv("SAIRA_DESKTOP_HOME", unset = "")
    if (!nzchar(base)) {
        base <- Sys.getenv("LOCALAPPDATA", unset = "")
        if (!nzchar(base)) base <- tools::R_user_dir("saira-desktop", "data")
        base <- file.path(base, "saira-desktop")
        Sys.setenv(
            R_USER_DATA_DIR = file.path(base, "data"),
            R_USER_CACHE_DIR = file.path(base, "cache")
        )
    }
    if (!nzchar(Sys.getenv("SAIRA_DATA_DIR"))) {
        Sys.setenv(SAIRA_DATA_DIR = tools::R_user_dir("saira", "data"))
    }

    # R has a process group of its own, so a hard kill of the shell leaves R
    # alive with the port in use. The handle keeps the start time of the shell,
    # so a new process with the same PID does not count as the shell.
    shell_pid <- Sys.getenv("SAIRA_DESKTOP_SHELL_PID", unset = "")
    if (nzchar(shell_pid)) {
        shell <- ps::ps_handle(as.integer(shell_pid))
        watch_shell <- function() {
            if (!ps::ps_is_running(shell)) quit(save = "no")
            later::later(watch_shell, 5)
        }
        watch_shell()
    }

    saira::run_app()
})
