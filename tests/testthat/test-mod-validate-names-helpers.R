test_that("format_provider_labels: known providers return display labels", {
    expect_equal(saira:::format_provider_labels(c("gbif", "florabr")), c("GBIF", "Flora BR"))
    expect_equal(saira:::format_provider_labels("faunabr"), "Fauna BR")
    expect_equal(saira:::format_provider_labels("gbif"), "GBIF")
})

test_that("format_provider_labels: unknown provider falls back to uppercase", {
    expect_equal(saira:::format_provider_labels("xyz"), "XYZ")
})

test_that("format_provider_labels: empty/NA input returns character(0)", {
    expect_equal(saira:::format_provider_labels(character(0)), character(0))
    expect_equal(saira:::format_provider_labels(NA_character_), character(0))
    expect_equal(saira:::format_provider_labels(""), character(0))
})

test_that("normalize_provider_failures: NULL/empty returns empty df with correct schema", {
    out <- saira:::normalize_provider_failures(NULL)
    expect_equal(nrow(out), 0L)
    expect_named(out, c("provider", "error"))

    out2 <- saira:::normalize_provider_failures(data.frame())
    expect_equal(nrow(out2), 0L)
})

test_that("normalize_provider_failures: valid df passes through", {
    df <- data.frame(provider = "gbif", error = "timeout", stringsAsFactors = FALSE)
    out <- saira:::normalize_provider_failures(df)
    expect_equal(nrow(out), 1L)
    expect_equal(out$provider, "gbif")
    expect_equal(out$error, "timeout")
})

test_that("normalize_provider_failures: rows with NA provider are dropped", {
    df <- data.frame(
        provider = c("gbif", NA, ""),
        error = c("e1", "e2", "e3"),
        stringsAsFactors = FALSE
    )
    out <- saira:::normalize_provider_failures(df)
    expect_equal(nrow(out), 1L)
    expect_equal(out$provider, "gbif")
})

test_that("stream_window: returns df unchanged when fewer rows than limit", {
    df <- data.frame(
        display_order = 1:5,
        validation_status = rep("accepted", 5),
        stringsAsFactors = FALSE
    )
    out <- saira:::stream_window(df, limit = 10L)
    expect_equal(nrow(out), 5L)
})

test_that("stream_window: limits rows and sorts descending by display_order", {
    df <- data.frame(
        display_order = 1:10,
        validation_status = rep("accepted", 10),
        stringsAsFactors = FALSE
    )
    out <- saira:::stream_window(df, limit = 3L)
    expect_equal(nrow(out), 3L)
    expect_equal(out$display_order, c(10L, 9L, 8L))
})

test_that("stream_window: empty df returns as-is", {
    df <- data.frame(validation_status = character(0), stringsAsFactors = FALSE)
    out <- saira:::stream_window(df)
    expect_equal(nrow(out), 0L)
})

test_that("normalize_status_for_filter: canonical passthrough", {
    expect_equal(saira:::normalize_status_for_filter("accepted"), "accepted")
    expect_equal(saira:::normalize_status_for_filter("synonym"), "synonym")
    expect_equal(saira:::normalize_status_for_filter("not_found"), "not_found")
    expect_equal(saira:::normalize_status_for_filter("ambiguous"), "ambiguous")
    expect_equal(saira:::normalize_status_for_filter("ignored"), "ignored")
})

test_that("normalize_status_for_filter: legacy values mapped correctly", {
    expect_equal(saira:::normalize_status_for_filter("unresolved"), "ambiguous")
    expect_equal(saira:::normalize_status_for_filter("invalid"), "ignored")
})

test_that("normalize_status_for_filter: unknown/empty defaults to not_found", {
    expect_equal(saira:::normalize_status_for_filter(""), "not_found")
    expect_equal(saira:::normalize_status_for_filter(NA), "not_found")
    expect_equal(saira:::normalize_status_for_filter("GARBAGE"), "not_found")
})

test_that("is_problem_status_key: problem statuses return TRUE", {
    expect_true(saira:::is_problem_status_key("not_found"))
    expect_true(saira:::is_problem_status_key("ambiguous"))
    expect_true(saira:::is_problem_status_key("synonym"))
    expect_true(saira:::is_problem_status_key("unresolved"))  # mapped to ambiguous
})

test_that("is_problem_status_key: non-problem statuses return FALSE", {
    expect_false(saira:::is_problem_status_key("accepted"))
    expect_false(saira:::is_problem_status_key("ignored"))
})

test_that("stream_filter_counts: all zeros for empty df", {
    out <- saira:::stream_filter_counts(data.frame())
    expect_equal(out[["all"]], 0L)
    expect_equal(out[["problems"]], 0L)
})

test_that("stream_filter_counts: correct totals", {
    df <- data.frame(
        validation_status = c("accepted", "not_found", "ambiguous", "synonym", "ignored"),
        query_name = c("A", "B", "C", "D", "E"),
        stringsAsFactors = FALSE
    )
    out <- saira:::stream_filter_counts(df)
    expect_equal(out[["all"]], 5L)
    expect_equal(out[["not_found"]], 1L)
    expect_equal(out[["ambiguous"]], 1L)
    expect_equal(out[["synonym"]], 1L)
    expect_equal(out[["ignored"]], 1L)
    expect_equal(out[["problems"]], 3L)  # not_found + ambiguous + synonym
})

test_that("stream_filter_counts: reviewed keys reduce problem count", {
    df <- data.frame(
        validation_status = c("not_found", "ambiguous"),
        query_name = c("A", "B"),
        stringsAsFactors = FALSE
    )
    out <- saira:::stream_filter_counts(df, reviewed_keys = "A")
    expect_equal(out[["not_found"]], 0L)  # A reviewed
    expect_equal(out[["ambiguous"]], 1L)  # B not reviewed
    expect_equal(out[["problems"]], 1L)
})

test_that("stream_filter_counts: invasive counts species-list hits, not statuses", {
    df <- data.frame(
        validation_status = c("accepted", "accepted", "not_found"),
        query_name = c("Sus scrofa", "Panthera onca", "Felis catus"),
        stringsAsFactors = FALSE
    )
    out <- saira:::stream_filter_counts(df)
    # Sus scrofa and Felis catus are on the Horus list; Panthera onca is not.
    # The count is independent of validation_status (one of the two hits is a
    # not_found row).
    expect_equal(out[["invasive"]], 2L)
    expect_equal(out[["all"]], 3L)
})

test_that("filter_stream_df: 'invasive' keeps only listed taxa", {
    df <- data.frame(
        validation_status = c("accepted", "accepted", "synonym"),
        query_name = c("Sus scrofa", "Panthera onca", "Felis catus"),
        stringsAsFactors = FALSE
    )
    out <- saira:::filter_stream_df(df, "invasive")
    expect_equal(out$query_name, c("Sus scrofa", "Felis catus"))
})

test_that("the two list groups count and filter apart in the stream", {
    df <- data.frame(
        validation_status = c("accepted", "accepted", "accepted"),
        query_name = c("Sus scrofa", "Nasua nasua", "Panthera onca"),
        stringsAsFactors = FALSE
    )
    counts <- saira:::stream_filter_counts(df)
    # The coati is on the list but native, so it must not be counted as an
    # exotic invader -- that was the bug reported from the processed-names tab.
    expect_equal(counts[["invasive"]], 1L)
    expect_equal(counts[["translocated"]], 1L)

    expect_equal(
        saira:::filter_stream_df(df, "invasive")$query_name, "Sus scrofa"
    )
    expect_equal(
        saira:::filter_stream_df(df, "translocated")$query_name, "Nasua nasua"
    )
})

test_that("invasive_stream_note_ui states what the list actually says", {
    alien <- as.character(saira:::invasive_stream_note_ui("Sus scrofa", "pt"))
    expect_true(grepl("badge-error", alien, fixed = TRUE))
    expect_false(grepl("badge-translocated", alien, fixed = TRUE))

    native <- as.character(saira:::invasive_stream_note_ui("Nasua nasua", "pt"))
    expect_true(grepl("badge-translocated", native, fixed = TRUE))
    expect_false(grepl("badge-error", native, fixed = TRUE))

    expect_null(saira:::invasive_stream_note_ui("Panthera onca", "pt"))
})

test_that("the detail lines render only where the source records them", {
    # The coati and the tegu have no motivo, so they get the range line alone
    # rather than an empty "Introduzida para:" prefix.
    for (name in c("Nasua nasua", "Salvator merianae")) {
        note <- as.character(saira:::invasive_stream_note_ui(name, "pt"))
        expect_true(grepl("Distribui", note, fixed = TRUE))
        expect_false(grepl("Introduzida para:", note, fixed = TRUE))
    }
    both <- as.character(saira:::invasive_stream_note_ui("Cichla kelberi", "pt"))
    expect_true(grepl("Distribui", both, fixed = TRUE))
    expect_true(grepl("Introduzida para:", both, fixed = TRUE))
})

test_that("filter_stream_df: 'invasive' ignores reviewed and exiting keys", {
    df <- data.frame(
        validation_status = c("accepted", "accepted"),
        query_name = c("Sus scrofa", "Panthera onca"),
        stringsAsFactors = FALSE
    )
    # Neither a review nor an exit animation changes whether a taxon is on the
    # list -- unlike the status-based filters, which suppress reviewed rows.
    out <- saira:::filter_stream_df(
        df, "invasive",
        reviewed_keys = "Sus scrofa", exiting_keys = "Panthera onca"
    )
    expect_equal(out$query_name, "Sus scrofa")
})

test_that("filter_stream_df: 'all' returns full df", {
    df <- data.frame(
        validation_status = c("accepted", "not_found"),
        query_name = c("A", "B"),
        stringsAsFactors = FALSE
    )
    out <- saira:::filter_stream_df(df, "all")
    expect_equal(nrow(out), 2L)
})

test_that("filter_stream_df: 'not_found' keeps only unreviewed not_found", {
    df <- data.frame(
        validation_status = c("accepted", "not_found", "not_found"),
        query_name = c("A", "B", "C"),
        stringsAsFactors = FALSE
    )
    out <- saira:::filter_stream_df(df, "not_found", reviewed_keys = "B")
    expect_equal(nrow(out), 1L)
    expect_equal(out$query_name, "C")
})

test_that("filter_stream_df: exiting_keys always included", {
    df <- data.frame(
        validation_status = c("accepted", "not_found"),
        query_name = c("A", "B"),
        stringsAsFactors = FALSE
    )
    # B is not_found and reviewed, but in exiting → still shown
    out <- saira:::filter_stream_df(df, "not_found", reviewed_keys = "B", exiting_keys = "B")
    expect_equal(nrow(out), 1L)
    expect_equal(out$query_name, "B")
})

test_that("stream_filter_after_completion: empty df returns 'all'", {
    expect_equal(saira:::stream_filter_after_completion(data.frame()), "all")
    expect_equal(saira:::stream_filter_after_completion(NULL), "all")
})

test_that("stream_filter_after_completion: non-empty df returns 'problems'", {
    df <- data.frame(x = 1L)
    expect_equal(saira:::stream_filter_after_completion(df), "problems")
})

test_that("status_style_map: accepted status", {
    out <- saira:::status_style_map("accepted")
    expect_equal(out$key, "accepted")
    expect_equal(out$badge_class, "badge-success")
})

test_that("status_style_map: synonym status", {
    out <- saira:::status_style_map("synonym")
    expect_equal(out$key, "synonym")
    expect_equal(out$badge_class, "badge-info")
})

test_that("status_style_map: ambiguous and unresolved both map to ambiguous", {
    expect_equal(saira:::status_style_map("ambiguous")$key, "ambiguous")
    expect_equal(saira:::status_style_map("unresolved")$key, "ambiguous")
})

test_that("status_style_map: unknown defaults to not_found", {
    out <- saira:::status_style_map("GARBAGE")
    expect_equal(out$key, "not_found")
    expect_equal(out$badge_class, "badge-error")
})

test_that("review_status_context: ambiguous context", {
    out <- saira:::review_status_context("ambiguous", lang = "pt")
    expect_equal(out$header_class, "vn-review-header-warning")
    expect_equal(out$icon, "circle-question")
})

test_that("review_status_context: synonym context", {
    out <- saira:::review_status_context("synonym", lang = "pt")
    expect_equal(out$header_class, "vn-review-header-info")
    expect_equal(out$icon, "code-compare")
})

test_that("review_status_context: not_found fallback", {
    out <- saira:::review_status_context("not_found", lang = "pt")
    expect_equal(out$header_class, "vn-review-header-error")
    expect_equal(out$icon, "circle-xmark")
})

test_that("render_review_name_em: returns HTML em tag", {
    out <- saira:::render_review_name_em("Homo sapiens")
    expect_s3_class(out, "html")
    expect_true(grepl("<em>Homo sapiens</em>", as.character(out), fixed = TRUE))
})

test_that("render_review_name_em: escapes HTML special characters", {
    out <- saira:::render_review_name_em("<script>")
    expect_false(grepl("<script>", as.character(out), fixed = TRUE))
    expect_true(grepl("&lt;script&gt;", as.character(out), fixed = TRUE))
})

test_that("normalize_status_vec matches the scalar helper element by element", {
    values <- c(
        "accepted", "SYNONYM", "unresolved", "invalid", "not_found",
        "ambiguous", "ignored", "", "bogus", "accepted"
    )
    expected <- vapply(
        values, saira:::normalize_status_for_filter,
        FUN.VALUE = character(1), USE.NAMES = FALSE
    )

    expect_equal(saira:::normalize_status_vec(values), expected)
})

test_that("normalize_status_vec handles empty, NA and factor inputs", {
    expect_equal(saira:::normalize_status_vec(character(0)), character(0))
    expect_equal(saira:::normalize_status_vec(NA_character_), "not_found")
    expect_equal(
        saira:::normalize_status_vec(factor(c("accepted", "invalid"))),
        c("accepted", "ignored")
    )
})

# ADR-113: stream_window truncates the index, not the frame ------------------

test_that("stream_window returns the same rows and order after the index-first change", {
    # display_order is deliberately non-monotone and out of step with row order,
    # so ordering the index and ordering the frame can be told apart.
    df <- data.frame(
        query_name = paste0("name-", 1:10),
        display_order = c(3L, 9L, 1L, 7L, 10L, 2L, 8L, 4L, 6L, 5L),
        stringsAsFactors = FALSE
    )

    out <- saira:::stream_window(df, limit = 4L)
    expect_equal(nrow(out), 4L)
    expect_equal(out$display_order, c(10L, 9L, 8L, 7L))
    expect_equal(out$query_name, c("name-5", "name-2", "name-7", "name-4"))
    expect_null(attr(out, "row.names.orig"))
    expect_equal(rownames(out), as.character(1:4))
})

test_that("stream_window keeps every row when limit is NULL", {
    # ADR-093: the 100-row cap applies only while a run is in flight. After the
    # run the panel shows the whole stream, so limit = NULL must not truncate.
    df <- data.frame(
        query_name = paste0("name-", 1:10),
        display_order = c(3L, 9L, 1L, 7L, 10L, 2L, 8L, 4L, 6L, 5L),
        stringsAsFactors = FALSE
    )

    out <- saira:::stream_window(df, limit = NULL)
    expect_equal(nrow(out), 10L)
    expect_equal(out$display_order, 10:1)

    out_inf <- saira:::stream_window(df, limit = Inf)
    expect_equal(nrow(out_inf), 10L)
    expect_equal(out_inf$display_order, 10:1)
})

test_that("stream_window still adds display_order when the column is absent", {
    df <- data.frame(query_name = c("a", "b", "c"), stringsAsFactors = FALSE)
    out <- saira:::stream_window(df, limit = 2L)
    expect_equal(out$query_name, c("c", "b"))
    expect_equal(out$display_order, c(3L, 2L))
})
