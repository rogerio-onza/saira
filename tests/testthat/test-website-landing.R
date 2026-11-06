# The landing species connect by data-sp keys, not by their order (SP-15).
# website/ is not in the installed package, so the check runs from a checkout.

website_dir <- testthat::test_path("..", "..", "website")

run_landing_check <- function(dir) {
    python <- Sys.which("python3")
    testthat::skip_if(!nzchar(python), "python3 is needed for the landing check")
    out <- suppressWarnings(system2(
        python, c(shQuote(file.path(website_dir, "scripts", "check_landing.py")), shQuote(dir)),
        stdout = TRUE, stderr = TRUE
    ))
    list(status = attr(out, "status") %||% 0L, output = paste(out, collapse = "\n"))
}

copy_landing <- function() {
    dir <- withr::local_tempdir(.local_envir = parent.frame())
    for (f in c("assets/js/landing.js", "index.qmd", "en/index.qmd", "es/index.qmd")) {
        dir.create(dirname(file.path(dir, f)), recursive = TRUE, showWarnings = FALSE)
        file.copy(file.path(website_dir, f), file.path(dir, f))
    }
    dir
}

testthat::test_that("the three home pages agree with the landing species data", {
    testthat::skip_if_not(dir.exists(website_dir), "website/ is not in the installed package")
    result <- run_landing_check(normalizePath(website_dir))
    testthat::expect_equal(result$status, 0L, info = result$output)
})

testthat::test_that("the landing check stops on a reordered, missing or unknown species", {
    testthat::skip_if_not(dir.exists(website_dir), "website/ is not in the installed package")
    dir <- copy_landing()
    es <- file.path(dir, "es", "index.qmd")
    lines <- readLines(es, encoding = "UTF-8")
    pins <- grep('class="lp-pin"', lines)
    # A reordered pin in one language keeps its key: the check passes.
    lines[pins] <- lines[rev(pins)]
    writeLines(lines, es, useBytes = TRUE)
    testthat::expect_equal(run_landing_check(dir)$status, 0L)

    # A card moved away from its pin fails.
    cards <- grep('class="lp-card', lines)
    swapped <- lines
    swapped[cards[1:2]] <- sub('data-sp="[^"]+"', "", lines[cards[1:2]])
    swapped[cards[1]] <- sub('class="lp-card"', 'class="lp-card" data-sp="boana-buriti"', swapped[cards[1]])
    writeLines(swapped, es, useBytes = TRUE)
    result <- run_landing_check(dir)
    testthat::expect_equal(result$status, 1L)
    testthat::expect_match(result$output, "es/index.qmd: a .lp-card has no data-sp", fixed = TRUE)
    testthat::expect_match(result$output, "repeats data-sp boana-buriti", fixed = TRUE)

    # A new species without ROWS data fails the build explicitly.
    lines[pins[1]] <- sub('data-sp="[^"]+"', 'data-sp="puma-concolor"', lines[pins[1]])
    writeLines(lines, es, useBytes = TRUE)
    result <- run_landing_check(dir)
    testthat::expect_equal(result$status, 1L)
    testthat::expect_match(result$output, ".lp-pin puma-concolor has no ROWS entry", fixed = TRUE)
})

testthat::test_that("each hero photo connects to its biome by key, not by order", {
    testthat::skip_if_not(dir.exists(website_dir), "website/ is not in the installed package")
    dir <- copy_landing()
    en <- file.path(dir, "en", "index.qmd")
    lines <- readLines(en, encoding = "UTF-8")
    photos <- grep('class="lp-photo', lines)
    # Reordered photos keep their keys: the check passes.
    lines[photos] <- lines[rev(photos)]
    writeLines(lines, en, useBytes = TRUE)
    testthat::expect_equal(run_landing_check(dir)$status, 0L)

    # Two photos that swap keys show the wrong species: the check fails. The
    # first match of a key in the line is its data-sp, before the file name.
    keys <- sub('.*data-sp="([^"]+)".*', "\\1", lines[photos[1:2]])
    swapped <- lines
    swapped[photos[1]] <- sub(keys[1], keys[2], lines[photos[1]], fixed = TRUE)
    swapped[photos[2]] <- sub(keys[2], keys[1], lines[photos[2]], fixed = TRUE)
    writeLines(swapped, en, useBytes = TRUE)
    result <- run_landing_check(dir)
    testthat::expect_equal(result$status, 1L)
    testthat::expect_match(result$output, paste0("the .lp-photo ", keys[2], " shows"), fixed = TRUE)

    # A photo without a key fails.
    lines[photos[1]] <- sub(' data-sp="[^"]+"', "", lines[photos[1]])
    writeLines(lines, en, useBytes = TRUE)
    result <- run_landing_check(dir)
    testthat::expect_equal(result$status, 1L)
    testthat::expect_match(result$output, "en/index.qmd: a .lp-photo has no data-sp", fixed = TRUE)
})
