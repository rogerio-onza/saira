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
    # Unknown/blank language falls back to the PT page.
    expect_match(saira_releases_url(""), "/novidades\\.html$")
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
