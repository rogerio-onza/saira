# Tests for session-staleness detection (R/utils_version.R)

test_that("saira_session_is_stale flags divergent loaded vs installed versions", {
    res <- saira_session_is_stale(loaded = "0.3.0", installed = "0.9.1")
    expect_true(res$stale)
    expect_identical(res$loaded, "0.3.0")
    expect_identical(res$installed, "0.9.1")
})

test_that("saira_session_is_stale is FALSE when versions match (e.g. load_all/dev)", {
    res <- saira_session_is_stale(loaded = "0.9.1", installed = "0.9.1")
    expect_false(res$stale)
})

test_that("saira_session_is_stale never flags when a lookup is unavailable", {
    expect_false(saira_session_is_stale(loaded = NA_character_, installed = "0.9.1")$stale)
    expect_false(saira_session_is_stale(loaded = "0.9.1", installed = NA_character_)$stale)
    expect_false(saira_session_is_stale(loaded = NA_character_, installed = NA_character_)$stale)
})

test_that("live lookup is not stale under load_all (no dev false positive)", {
    # Under pkgload::load_all() both getNamespaceVersion() and packageVersion()
    # resolve to the repo DESCRIPTION, so a dev session must never be flagged.
    res <- saira_session_is_stale()
    expect_false(res$stale)
    expect_identical(res$loaded, res$installed)
})

test_that("saira_running_version returns the loaded namespace version", {
    # Under load_all this equals the repo DESCRIPTION version.
    expect_identical(
        saira_running_version(),
        as.character(utils::packageVersion("saira"))
    )
})

test_that("saira_releases_url is language-aware", {
    expect_match(saira_releases_url("pt"), "/novidades\\.html$")
    expect_match(saira_releases_url("en"), "/en/releases\\.html$")
    expect_match(saira_releases_url("es"), "/es/novedades\\.html$")
    # Unknown/blank language falls back to the English page, like tr().
    expect_match(saira_releases_url(""), "/en/releases\\.html$")
    expect_true(startsWith(saira_releases_url("pt"), "https://rogerio-onza.github.io/saira"))
})

test_that("notify_session_stale is a no-op for a current session", {
    # status$stale = FALSE must return invisibly FALSE without needing a session.
    res <- notify_session_stale(
        session = NULL,
        lang_r = function() "pt",
        status = list(stale = FALSE, loaded = "0.9.1", installed = "0.9.1")
    )
    expect_false(res)
})

# New release check (ADR-215) ----------------------------------------------

test_that("release_tag_version reads vX.Y.Z tags and rejects the rest", {
    expect_identical(release_tag_version("v1.0.1"), "1.0.1")
    expect_identical(release_tag_version("1.2.3"), "1.2.3")
    expect_true(is.na(release_tag_version("v1.0.1-rc.1")))
    expect_true(is.na(release_tag_version("latest")))
    expect_true(is.na(release_tag_version(NA_character_)))
    expect_true(is.na(release_tag_version(NULL)))
})

test_that("is_newer_release is TRUE only for a strictly higher version", {
    expect_true(is_newer_release("1.0.1", "1.0.0"))
    expect_true(is_newer_release("1.1.0", "1.0.9"))
    expect_false(is_newer_release("1.0.0", "1.0.0"))
    expect_false(is_newer_release("0.9.9", "1.0.0"))
    expect_false(is_newer_release(NA_character_, "1.0.0"))
    expect_false(is_newer_release("1.0.1", NA_character_))
})

test_that("update_check_enabled honors SAIRA_PUBLIC and SAIRA_NO_UPDATE_CHECK", {
    withr::local_envvar(SAIRA_PUBLIC = "", SAIRA_NO_UPDATE_CHECK = "")
    expect_true(update_check_enabled())
    withr::local_envvar(SAIRA_PUBLIC = "true")
    expect_false(update_check_enabled())
    withr::local_envvar(SAIRA_PUBLIC = "", SAIRA_NO_UPDATE_CHECK = "1")
    expect_false(update_check_enabled())
})

test_that("update check cache is fresh for one day, failures included", {
    path <- withr::local_tempfile(fileext = ".json")
    now <- as.POSIXct("2026-11-12 12:00:00", tz = "UTC")
    expect_null(read_update_check_cache(path, now))

    expect_true(write_update_check_cache(path, "1.0.1", now))
    expect_identical(read_update_check_cache(path, now + 3600)$latest, "1.0.1")
    expect_null(read_update_check_cache(path, now + 25 * 3600))
    expect_null(read_update_check_cache(path, now - 60))

    write_update_check_cache(path, NA_character_, now)
    cached <- read_update_check_cache(path, now + 60)
    expect_false(is.null(cached))
    expect_true(is.na(cached$latest))
})

fake_update_job <- function(tag, alive_polls = 1L) {
    polls <- 0L
    list(
        is_alive = function() {
            polls <<- polls + 1L
            polls <= alive_polls
        },
        get_result = function() tag,
        kill = function() TRUE
    )
}

run_new_release_reactive <- function(..., elapse_ms = 3000) {
    out <- NULL
    args <- list(...)
    shiny::testServer(function(input, output, session) {
        rv <- do.call(new_release_reactive, c(list(session), args))
    }, {
        # One step per poll: a single long elapse() fires the first timer only.
        for (i in seq_len(elapse_ms %/% 1000)) session$elapse(1000)
        out <<- rv()
    })
    out
}

test_that("new_release_reactive publishes a newer release and caches it", {
    path <- withr::local_tempfile(fileext = ".json")
    got <- run_new_release_reactive(
        current = "1.0.0", enabled = TRUE, cache_path = path,
        start_job = function() fake_update_job("v1.0.1")
    )
    expect_identical(as.vector(got), "1.0.1")
    expect_identical(read_update_check_cache(path)$latest, "1.0.1")
})

test_that("new_release_reactive stays NULL for the same version or a failure", {
    path <- withr::local_tempfile(fileext = ".json")
    expect_null(run_new_release_reactive(
        current = "1.0.1", enabled = TRUE, cache_path = path,
        start_job = function() fake_update_job("v1.0.1")
    ))
    path2 <- withr::local_tempfile(fileext = ".json")
    expect_null(run_new_release_reactive(
        current = "1.0.0", enabled = TRUE, cache_path = path2,
        start_job = function() fake_update_job(NA_character_)
    ))
    expect_null(run_new_release_reactive(
        current = "1.0.0", enabled = TRUE, cache_path = path2,
        start_job = function() NULL
    ))
})

test_that("new_release_reactive uses a fresh cache and starts no job", {
    path <- withr::local_tempfile(fileext = ".json")
    write_update_check_cache(path, "1.2.0")
    got <- run_new_release_reactive(
        current = "1.0.0", enabled = TRUE, cache_path = path,
        start_job = function() stop("must not start a job")
    )
    expect_identical(as.vector(got), "1.2.0")
})

test_that("new_release_reactive opens the panel once per release", {
    path <- withr::local_tempfile(fileext = ".json")
    write_update_check_cache(path, "1.0.1")
    run <- function() {
        run_new_release_reactive(
            current = "1.0.0", enabled = TRUE, cache_path = path,
            start_job = function() stop("must not start a job")
        )
    }
    expect_true(attr(run(), "auto_open"))
    expect_identical(read_update_shown(path), "1.0.1")
    expect_false(attr(run(), "auto_open"))
    # The daily refresh keeps the mark, a later release opens again.
    write_update_check_cache(path, "1.0.1")
    expect_false(attr(run(), "auto_open"))
    write_update_check_cache(path, "1.1.0")
    expect_true(attr(run(), "auto_open"))
})

test_that("new_release_reactive does nothing when the check is off", {
    path <- withr::local_tempfile(fileext = ".json")
    got <- run_new_release_reactive(
        current = "1.0.0", enabled = FALSE, cache_path = path,
        start_job = function() stop("must not start a job")
    )
    expect_null(got)
    expect_false(file.exists(path))
})

test_that("update_check_job returns NA when the network call fails", {
    expect_true(is.na(update_check_job("http://127.0.0.1:9/none", timeout_s = 1)))
})

test_that("version_badge_ui is the plain releases link without a newer release", {
    html <- as.character(version_badge_ui("1.0.0", NULL, "pt", desktop = FALSE))
    expect_match(html, "class=\"ver-badge\"", fixed = TRUE)
    expect_no_match(html, "has-update", fixed = TRUE)
})

test_that("version_badge_ui shows the copy command for an R install", {
    html <- as.character(version_badge_ui("1.0.0", "1.0.1", "en", desktop = FALSE))
    expect_match(html, "has-update", fixed = TRUE)
    expect_match(html, "Saíra v1.0.1 is available", fixed = TRUE)
    expect_match(html, "data-copy=\"pak::pak(&quot;rogerio-onza/saira&quot;)\"", fixed = TRUE)
    expect_no_match(html, SAIRA_RELEASES_PAGE, fixed = TRUE)
})

test_that("version_badge_ui links the installer in the desktop app", {
    html <- as.character(version_badge_ui("1.0.0", "1.0.1", "pt", desktop = TRUE))
    expect_match(html, SAIRA_RELEASES_PAGE, fixed = TRUE)
    expect_match(html, "Baixar instalador", fixed = TRUE)
    expect_no_match(html, "data-copy", fixed = TRUE)
})

test_that("version_badge_ui asks the page to open the panel only when flagged", {
    flagged <- as.character(version_badge_ui("1.0.0", structure("1.0.1", auto_open = TRUE), "en", FALSE))
    expect_match(flagged, "data-auto-open=\"true\"", fixed = TRUE)
    seen <- as.character(version_badge_ui("1.0.0", structure("1.0.1", auto_open = FALSE), "en", FALSE))
    expect_no_match(seen, "data-auto-open", fixed = TRUE)
})
