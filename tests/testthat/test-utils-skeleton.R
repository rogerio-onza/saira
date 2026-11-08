test_that("each skeleton kind is hidden from screen readers", {
    for (kind in c("cards", "pills", "vocab", "rows")) {
        html <- as.character(loading_skeleton(kind))
        expect_match(html, 'class="saira-skeleton"', fixed = TRUE)
        expect_match(html, 'aria-hidden="true"', fixed = TRUE)
    }
    expect_error(loading_skeleton("table"))
})

test_that("the cards skeleton uses the grid of the mapping cards", {
    html <- as.character(loading_skeleton("cards"))
    expect_match(html, 'class="mapping-card-grid"', fixed = TRUE)
    expect_equal(lengths(regmatches(html, gregexpr('class="skeleton-card"', html))), 6L)
})

test_that("an output keeps its id and gets the skeletons in order", {
    out <- with_loading_skeleton(shiny::uiOutput("panel"), c("pills", "rows"))
    html <- as.character(out)
    expect_match(html, 'id="panel"', fixed = TRUE)
    expect_match(html, "shiny-html-output", fixed = TRUE)
    expect_lt(regexpr("skeleton-pill", html), regexpr("skeleton-table", html))
})
