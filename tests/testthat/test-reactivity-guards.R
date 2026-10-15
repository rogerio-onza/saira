# Title: Guards for the reactivity fixes behind the recent performance work
#
# Each fix here removed a re-render or a rebuild, and each regression would
# still produce the same HTML. So these tests check what re-ran, not what came
# out: a functional test passes with the regression in place.

mapping_guard_df <- function() {
    data.frame(
        especie = c("Panthera onca", "Leopardus pardalis"),
        ambiente = c("forest", "savanna"),
        stringsAsFactors = FALSE
    )
}

testthat::test_that("picking a column does not rebuild the card grid", {
    # PR #51: a pick updates its own card through push_card_state(), so the
    # grid (about 50 selectize inputs) renders only on a structural change.
    # build_field_card() is called only by that render, so its call count is
    # the render count.
    builds <- 0L
    real_build <- build_field_card
    testthat::local_mocked_bindings(
        build_field_card = function(...) {
            builds <<- builds + 1L
            real_build(...)
        },
        .package = "saira"
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(mapping_guard_df()),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            testthat::expect_gt(builds, 0L)
            after_first_render <- builds

            session$setInputs(map_habitat = "ambiente")
            session$flushReact()

            testthat::expect_identical(rv$map_values$habitat, "ambiente")
            testthat::expect_identical(builds, after_first_render)
        }
    )
})

testthat::test_that("picking a column does not re-render the class pill bar", {
    # output$class_pills must not read rv$map_meta, or every pick recreates the
    # pill buttons. The "All" label is looked up only by that render.
    pill_renders <- 0L
    real_tr <- tr
    testthat::local_mocked_bindings(
        tr = function(key, lang = "en") {
            if (identical(key, "mapping_pill_all")) {
                pill_renders <<- pill_renders + 1L
            }
            real_tr(key, lang)
        },
        .package = "saira"
    )

    shiny::testServer(
        mod_mapping_server,
        args = list(
            raw_data_r = shiny::reactive(mapping_guard_df()),
            lang_r = shiny::reactive("en")
        ),
        {
            session$flushReact()
            testthat::expect_gt(pill_renders, 0L)
            after_first_render <- pill_renders

            session$setInputs(map_habitat = "ambiente")
            session$flushReact()

            testthat::expect_identical(rv$map_values$habitat, "ambiente")
            testthat::expect_identical(pill_renders, after_first_render)
        }
    )
})

testthat::test_that("app_server hands the generalization module its tab gate", {
    # ADR-114: without active_r, is_active() defaults to TRUE, and every mapping
    # edit rebuilds the whole mapped frame for a map nobody is looking at. The
    # module keeps working, so no functional test notices the missing argument.
    calls_to <- function(expr, fname) {
        if (!is.call(expr)) return(list())
        hits <- if (identical(expr[[1L]], as.name(fname))) list(expr) else list()
        c(hits, do.call(c, lapply(as.list(expr), calls_to, fname = fname)))
    }

    hits <- calls_to(body(app_server), "mod_sensitive_coords_server")
    testthat::expect_length(hits, 1L)
    testthat::expect_true("active_r" %in% names(hits[[1L]]))
})
