# Title: Preview Module
# Author: Rogerio Nunes Oliveira
# Date: 2026-02-15
# Version: 3.0

#' Preview Module UI
#'
#' @param id Module ID
#' @return Shiny UI tagList
#' @export
mod_preview_ui <- function(id) {
    ns <- shiny::NS(id)

    shiny::tagList(
        shiny::div(
            class = "container-fluid preview-page",
            shiny::uiOutput(ns("table_or_message"))
        ),
        # The Use, Undo and Apply controls live inside re-rendered cells, so one
        # delegated handler per control serves every row (as in Coordinates).
        shiny::tags$script(module_behavior_html("previewFixControls", list(
            useId = ns("use"), blankId = ns("blank"), undoId = ns("undo"), otherId = ns("other"),
            vocabApplyId = ns("vocab_apply"), vocabSectionId = ns("vocab_section"),
            focusId = ns("focus"), fixNextChannel = ns("fix_next"), tableId = ns("rows_table"),
            modeId = ns("mode"), contentId = ns("table_or_message"), copyId = ns("copy_set")
        )))
    )
}

#' Preview Module Server
#'
#' Shows the first 100 mapped records (Table) and, on request, every cell
#' problem in the full dataset (Problems), where the user can correct it. The
#' corrections are kept as edits over the mapped frame, so the downstream tabs
#' and the export read the corrected data. The download/export flow lives in
#' the Export tab (ADR-103).
#'
#' @param id Module ID
#' @param mapped_data_r Reactive data frame with the lightweight mapped preview
#' @param lang_r Reactive language value
#' @param full_data_r Reactive full mapped data frame. Read only while the
#'   tab shows and for the nav count, because building it costs the full
#'   mapping pipeline (ADR-021).
#' @param raw_data_r Reactive uploaded data frame, for the record panel.
#' @param reset_signal_r Reactive that changes on re-upload or a Mapping reset.
#' @param on_navigate Function(tab, term) that opens another tab.
#' @param active_r Reactive, TRUE while the Preview tab is open. On each entry
#'   the tab opens Problems when there is something to correct.
#' @param refresh_r Reactive whose change recounts the open problems for the
#'   nav badge, or NULL to count on every change of the full data.
#' @return A reactive with legacy attributes by default, or a named list of
#'   reactives when return_contract is \code{"list"}.
#'   attribute `edited_data_r` and the open-problem count (NA without data) in
#'   attribute `problems_n_r`.
#' @param return_contract Return a legacy reactive (default) or a named list of reactives.
#' @export
mod_preview_server <- function(id, mapped_data_r, lang_r, full_data_r = mapped_data_r,
                               raw_data_r = NULL, reset_signal_r = NULL,
                               on_navigate = NULL, active_r = NULL,
                               refresh_r = NULL, return_contract = c("legacy", "list")) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # One row per correction: row (NA = every cell of the term holding
        # `from`), term, from (the mapped value it replaces) and to.
        edits_rv <- shiny::reactiveVal(NULL)
        filter_rv <- shiny::reactiveVal("problems")
        # Exact copies the user left out of the package (rows of the upload).
        left_out_rv <- shiny::reactiveVal(integer(0))

        if (!is.null(reset_signal_r)) {
            shiny::observeEvent(reset_signal_r(), {
                edits_rv(NULL)
                left_out_rv(integer(0))
                filter_rv("problems")
            }, ignoreInit = TRUE)
        }

        preview_data <- shiny::reactive({
            shiny::req(mapped_data_r())
            df <- apply_preview_edits(mapped_data_r(), edits_rv())
            prepare_preview_data(df, max_rows = 100L)
        })

        corrected_data_r <- shiny::reactive({
            apply_preview_edits(full_data_r(), edits_rv())
        })

        # The tabs after this one read unique identifiers (ADR-152).
        edited_data_r <- shiny::reactive({
            replace_repeated_ids(corrected_data_r(), basis = full_data_r(),
                                 ignore = rows_left_out_r())
        })

        copies_r <- shiny::reactive({
            exact_copy_rows(if (is.function(raw_data_r)) raw_data_r())
        })

        # The cells the Preview edits change, for the export change list.
        preview_changes_r <- shiny::reactive({
            edits <- edits_rv()
            if (!is.data.frame(edits) || !nrow(edits)) return(NULL)
            cell_changes(full_data_r(), corrected_data_r(), unique(edits$term))
        })

        # Only rows that are still copies: a new upload can change them.
        rows_left_out_r <- shiny::reactive({
            sort(intersect(left_out_rv(), copies_r()$row))
        })

        # Both modes stay rendered while the tab shows, so a mode switch
        # sends nothing to the server (ADR-158). A hidden tab suspends the
        # outputs, so they do not scan while another tab shows.
        problems_r <- shiny::reactive({
            df <- full_data_r()
            shiny::req(is.data.frame(df))
            drop_copy_id_problems(detect_preview_problems(df), copies_r())
        })

        # Problems with no correction yet, for the nav badge and the Problems
        # option. Counting builds the full mapped frame (ADR-021), so the caller
        # decides when through refresh_r.
        problems_n_r <- shiny::reactive({
            df <- tryCatch(full_data_r(), shiny.silent.error = function(e) NULL)
            if (!is.data.frame(df) || nrow(df) == 0L) {
                return(NA_integer_)
            }
            sum(is.na(preview_problem_edit(problems_r(), edits_rv())))
        })
        if (!is.null(refresh_r)) {
            problems_n_r <- problems_n_r |>
                shiny::bindEvent(refresh_r(), edits_rv(), ignoreNULL = FALSE)
        }

        # The mode the tab opens in. It runs before the tab renders, so the
        # first render already shows the right mode.
        entry_mode_rv <- shiny::reactiveVal("table")
        if (!is.null(active_r)) {
            shiny::observeEvent(active_r(), {
                shiny::req(isTRUE(active_r()), is.data.frame(mapped_data_r()), nrow(mapped_data_r()) > 0L)
                open <- is.na(preview_problem_edit(problems_r(), edits_rv()))
                mode <- if (any(open)) "problems" else "table"
                entry_mode_rv(mode)
                shiny::updateRadioButtons(session, "mode", selected = mode)
            }, priority = 10)
        }

        # Index of the edit that corrects each problem (NA when none).
        problem_edit_r <- shiny::reactive({
            preview_problem_edit(problems_r(), edits_rv())
        })

        output$table_or_message <- shiny::renderUI({
            df <- mapped_data_r()
            lang <- lang_r()
            if (is.null(df) || !is.data.frame(df) || ncol(df) == 0L || nrow(df) == 0L) {
                return(shiny::div(
                    class = "preview-empty-state",
                    ph_icon("table", class = "ph-3x"),
                    shiny::h4(tr("preview_no_data_title", lang)),
                    shiny::p(tr("preview_no_data", lang))
                ))
            }
            mode <- shiny::isolate(input$mode %||% entry_mode_rv())
            # The module script shows the part of the picked mode (ADR-158).
            mode_part <- function(tag, part) {
                htmltools::tagAppendAttributes(
                    tag, `data-mode` = part,
                    class = if (!identical(mode, part)) "is-off"
                )
            }
            # The title shares the row of the DT length and search controls,
            # so the table gets the height the page header used to take.
            shiny::div(
                class = "preview-table-shell saira-table-shell",
                shiny::div(
                    class = "preview-card-head",
                    shiny::h2(class = "preview-card-title", tr("preview_title", lang)),
                    shiny::div(
                        class = "saira-seg",
                        `data-seg-target` = ns("mode_body"),
                        shiny::radioButtons(
                            ns("mode"), label = NULL, inline = TRUE, selected = mode,
                            choiceNames = list(
                                seg_choice(tr("preview_mode_table", lang)),
                                seg_choice(tr("preview_mode_problems", lang),
                                           shiny::uiOutput(ns("problems_n"), inline = TRUE))
                            ),
                            choiceValues = list("table", "problems")
                        )
                    ),
                    mode_part(shiny::span(class = "preview-card-subtitle", tr("preview_subtitle", lang)), "table")
                ),
                # One box for both modes, so motion.js slides in the mode the
                # user picks (ADR-156).
                shiny::div(
                    id = ns("mode_body"),
                    mode_part(shiny::div(class = "preview-mode-part", DT::dataTableOutput(ns("datatable"))), "table"),
                    mode_part(
                        shiny::div(class = "preview-mode-part preview-problems", shiny::uiOutput(ns("problems_panel"))),
                        "problems"
                    )
                )
            )
        })

        output$problems_n <- shiny::renderUI({
            seg_count(problems_n_r(), action = TRUE)
        })

        output$datatable <- DT::renderDataTable({
            shiny::req(preview_data())

            preview_df <- preview_data()
            empty_mask <- vapply(
                preview_df,
                FUN = is_preview_empty_column,
                FUN.VALUE = logical(1)
            )
            empty_indices <- which(empty_mask) - 1L

            truncation_js <- DT::JS(module_behavior_call("previewTruncateCell"))

            column_defs <- list(
                list(
                    targets = "_all",
                    render = truncation_js
                )
            )

            if (length(empty_indices) > 0L) {
                column_defs[[length(column_defs) + 1L]] <- list(
                    targets = as.integer(empty_indices),
                    className = "preview-col-empty"
                )
            }

            # I() keeps a single index an array in the JSON.
            init_complete_js <- DT::JS(module_behavior_call(
                "previewMarkEmptyColumns", list(emptyColumns = I(as.integer(empty_indices)))
            ))

            DT::datatable(
                preview_df,
                container = preview_table_container(names(preview_df)),
                options = list(
                    pageLength = 15,
                    lengthMenu = c(15, 25, 50, 100),
                    # Search first: both controls float right, next to the title.
                    dom = "flrtip",
                    scrollX = TRUE,
                    # Frozen DwC header: the table owns its vertical scroll so the
                    # header row (the DwC term names) stays visible while scrolling
                    # rows. The preview tab is taken out of the page-scroll
                    # override (12-overrides.css), so only the table body scrolls.
                    # The offset reserves room for the header (--app-header-height,
                    # ADR-128), the title row with the DT search and the info/pagination
                    # row. Tune the 170px if that layout changes.
                    scrollY = "calc(100vh - var(--app-header-height) - 170px)",
                    scrollCollapse = TRUE,
                    autoWidth = FALSE,
                    columnDefs = column_defs,
                    initComplete = init_complete_js,
                    language = preview_dt_language(lang_r())
                ),
                class = "display compact stripe",
                rownames = FALSE,
                # previewTruncateCell escapes every cell. A second escape on
                # the server showed "&" as "&amp;".
                escape = FALSE
            )
        })

        shiny::outputOptions(output, "datatable", priority = 10)

        # --- Problems mode ---------------------------------------------------

        family_counts_r <- shiny::reactive({
            p <- problems_r()
            open <- is.na(problem_edit_r())
            counts <- table(factor(p$family[open], levels = unique(preview_problem_types$family)))
            c(problems = sum(open), as.list(counts), copy = nrow(copies_r()), edited = sum(!open))
        })

        output$problems_panel <- shiny::renderUI({
            p <- problems_r()
            lang <- lang_r()
            if (nrow(p) == 0L && nrow(copies_r()) == 0L) {
                return(shiny::div(class = "preview-fix-none", ph_icon("check"), " ",
                                  tr("preview_fix_none", lang)))
            }
            shiny::tagList(
                shiny::p(class = "preview-fix-hint", tr("preview_fix_hint", lang)),
                shiny::uiOutput(ns("fix_pills")),
                shiny::uiOutput(ns("fix_banner")),
                # Vocabulary on the left, the per-row fixes and the record on
                # the right, so no page or list needs more than one scroll.
                shiny::div(
                    class = "preview-fix-cols",
                    shiny::uiOutput(ns("vocab_section"), class = "preview-fix-vocab-col"),
                    shiny::uiOutput(ns("rows_section"), class = "preview-fix-rows-col")
                ),
                shiny::uiOutput(ns("copies_section"))
            )
        })

        output$fix_pills <- shiny::renderUI({
            counts <- family_counts_r()
            active <- filter_rv()
            lang <- lang_r()
            classes <- c(problems = "pill-problems", vocab = "pill-info", date = "pill-error",
                         year = "pill-warning", interval = "pill-warning",
                         date_mismatch = "pill-warning", time = "pill-warning",
                         count = "pill-warning", uncertainty = "pill-warning",
                         measure = "pill-warning",
                         coord = "pill-error", name = "pill-warning", country = "pill-warning",
                         formula = "pill-error",
                         empty = "pill-error", id = "pill-reference", copy = "pill-reference",
                         edited = "pill-edited")
            # Only the types with something left to correct, plus the active one.
            keys <- c("problems", unique(preview_problem_types$family), "copy", "edited")
            keys <- keys[keys == "problems" | keys == active |
                             vapply(keys, function(k) counts[[k]] > 0L, logical(1))]
            shiny::div(
                class = "coords-filter-pills preview-fix-pills",
                lapply(keys, function(key) {
                    shiny::actionButton(
                        ns(paste0("fix_filter_", key)),
                        label = shiny::tagList(
                            shiny::tags$span(class = "pill-label", tr(paste0("preview_fix_pill_", key), lang)),
                            shiny::tags$span(class = "pill-count", counts[[key]])
                        ),
                        class = trimws(paste("stream-pill has-count", classes[[key]],
                                             if (identical(active, key)) "active" else ""))
                    )
                })
            )
        })

        lapply(c("problems", unique(preview_problem_types$family), "copy", "edited"), function(key) {
            shiny::observeEvent(input[[paste0("fix_filter_", key)]], {
                filter_rv(key)
            }, ignoreInit = TRUE)
        })

        output$fix_banner <- shiny::renderUI({
            p <- problems_r()
            info <- preview_problem_banner(p, nrow(full_data_r()))
            if (is.null(info)) return(NULL)
            lang <- lang_r()
            # A blank cell is not a format problem and has no example (B49).
            message <- if (identical(info$type, "required_empty")) {
                sprintf(
                    tr("preview_fix_banner_empty", lang),
                    format(round(100 * info$share)), info$count,
                    htmltools::htmlEscape(info$term)
                )
            } else {
                sprintf(
                    tr("preview_fix_banner", lang),
                    format(round(100 * info$share)),
                    htmltools::htmlEscape(tr(paste0("preview_fix_diag_", info$type), lang)),
                    htmltools::htmlEscape(info$term),
                    htmltools::htmlEscape(info$example)
                )
            }
            shiny::div(
                class = "preview-fix-banner", role = "status",
                ph_icon("triangle-exclamation"),
                shiny::p(shiny::HTML(message)),
                if (is.function(on_navigate)) {
                    shiny::actionButton(ns("go_mapping"), tr("preview_fix_banner_go", lang),
                                        class = "btn btn-primary btn-sm")
                }
            )
        })

        shiny::observeEvent(input$go_mapping, {
            info <- preview_problem_banner(problems_r(), nrow(full_data_r()))
            if (is.function(on_navigate)) on_navigate("mapping", info$term)
        }, ignoreInit = TRUE)

        # --- Vocabulary, grouped by value ------------------------------------

        vocab_groups_r <- shiny::reactive({
            p <- problems_r()
            hit <- problem_edit_r()
            ids <- which(p$family == "vocab")
            if (!length(ids)) return(NULL)
            key <- paste(p$term[ids], p$value[ids], sep = "\r")
            first <- ids[!duplicated(key)]
            g <- data.frame(
                id = first,
                term = p$term[first],
                value = p$value[first],
                suggestion = p$suggestion[first],
                n = as.integer(table(key)[paste(p$term[first], p$value[first], sep = "\r")]),
                edit = hit[first],
                stringsAsFactors = FALSE
            )
            # One term together, its most frequent value first.
            g[order(match(g$term, vocabulary_terms), -g$n), , drop = FALSE]
        })

        output$vocab_section <- shiny::renderUI({
            shiny::req(filter_rv() %in% c("problems", "vocab", "edited"))
            g <- vocab_groups_r()
            if (is.null(g)) return(NULL)
            if (identical(filter_rv(), "edited")) g <- g[!is.na(g$edit), , drop = FALSE]
            if (!nrow(g)) return(NULL)
            lang <- lang_r()
            edits <- edits_rv()
            items <- lapply(seq_len(nrow(g)), function(i) {
                term <- g$term[i]
                key <- paste(term, g$value[i], sep = "|")
                # An applied value shrinks to one line in its place, as the
                # compact Mapping rows (ADR-137): the order stays, and the open
                # values get the room.
                if (!is.na(g$edit[i])) {
                    to <- edits$to[g$edit[i]]
                    return(shiny::div(
                        class = "preview-vocab-item is-done", `data-key` = key,
                        shiny::span(class = "pf-mono", term),
                        shiny::span(class = "pf-bad", g$value[i]),
                        ph_icon("arrow-right"),
                        shiny::span(class = "pf-done", if (nzchar(to)) to else tr("preview_fix_blank", lang)),
                        shiny::span(class = "coord-issue-badge coord-issue-badge-edited", tr("preview_fix_edited", lang)),
                        shiny::tags$a(href = "#", class = "preview-fix-undo", `data-id` = g$id[i],
                                      tr("preview_fix_undo", lang))
                    ))
                }
                sugg <- if (is.na(g$suggestion[i])) character(0) else strsplit(g$suggestion[i], "|", fixed = TRUE)[[1]]
                pick <- if (length(sugg) == 1L) sugg else ""
                others <- setdiff(vocabulary_concepts(term), sugg)
                opt <- function(v, label = v) shiny::tags$option(value = v, selected = if (identical(v, pick)) NA, label)
                shiny::div(
                    class = "preview-vocab-item", `data-key` = key,
                    shiny::div(
                        class = "preview-vocab-line",
                        shiny::span(class = "pf-mono", term),
                        shiny::span(class = "pf-bad", g$value[i]),
                        shiny::span(class = "pf-muted preview-vocab-n",
                                    if (g$n[i] == 1L) tr("preview_fix_rows_one", lang) else sprintf(tr("preview_fix_rows_n", lang), g$n[i]))
                    ),
                    shiny::div(
                        class = "preview-vocab-line",
                        shiny::tags$select(
                            class = "form-select form-select-sm preview-vocab-select",
                            `aria-label` = term,
                            opt("", tr("preview_fix_choose", lang)),
                            if (length(sugg)) shiny::tags$optgroup(label = tr("preview_fix_suggested", lang), lapply(sugg, opt)),
                            shiny::tags$optgroup(label = tr("preview_fix_vocab_all", lang), lapply(others, opt)),
                            opt("__blank__", tr("preview_fix_blank", lang))
                        ),
                        shiny::tags$button(
                            type = "button", class = "btn btn-primary btn-sm preview-vocab-apply",
                            `data-id` = g$id[i], disabled = if (!nzchar(pick)) NA,
                            sprintf(tr("preview_fix_apply_n", lang), g$n[i])
                        )
                    )
                )
            })
            shiny::div(
                class = "preview-fix-section",
                shiny::div(class = "preview-fix-section-head",
                           shiny::h3(tr("preview_fix_vocab_title", lang)),
                           shiny::span(tr("preview_fix_vocab_desc", lang))),
                shiny::div(class = "preview-vocab-list", items)
            )
        })

        shiny::observeEvent(input$vocab_apply, {
            p <- problems_r()
            id <- suppressWarnings(as.integer(input$vocab_apply$id))
            if (length(id) != 1L || is.na(id) || id < 1L || id > nrow(p)) return(invisible(NULL))
            to <- as.character(input$vocab_apply$to %||% "")
            if (identical(to, "__blank__")) to <- ""
            parsed <- parse_preview_edit(p$term[id], to)
            if (!is.null(parsed$error)) {
                notify_fix(tr(parsed$error, lang_r()), "error")
                return(invisible(NULL))
            }
            n <- add_edit(NA_integer_, p$term[id], p$value[id], parsed$value)
            notify_fix(sprintf(tr("preview_fix_saved", lang_r()), n), "message")
        }, ignoreInit = TRUE)

        # --- Per row -----------------------------------------------------------

        # The rows the table shows. A correction patches them through the proxy,
        # so the page and the search stay where the person left them (ADR-129).
        rows_base_r <- shiny::reactive({
            p <- problems_r()
            key <- filter_rv()
            ids <- which(p$family != "vocab")
            if (identical(key, "edited")) {
                ids <- ids[!is.na(shiny::isolate(problem_edit_r()))[ids]]
            } else if (!identical(key, "problems")) {
                ids <- ids[p$family[ids] == key]
            }
            ids
        })
        rows_proxy <- DT::dataTableProxy("rows_table")

        build_rows_df <- function(ids) {
            p <- problems_r()[ids, , drop = FALSE]
            hit <- problem_edit_r()[ids]
            edits <- edits_rv()
            lang <- lang_r()
            same_key <- preview_fix_key(problems_r())
            same_n <- as.integer(table(same_key)[preview_fix_key(p)]) - 1L

            diag_class <- ifelse(p$family %in% c("date", "empty"), "coord-issue-badge-error",
                                 "coord-issue-badge-warning")
            diag <- paste0("<span class=\"coord-issue-badge ", diag_class, "\">",
                           vapply(p$type, function(t) tr(paste0("preview_fix_diag_", t), lang), character(1)),
                           "</span>")
            fixed <- !is.na(hit)
            fix <- ifelse(fixed, edits$to[hit], "")
            # A fix in another cell names that cell's term.
            moved <- fixed & edits$term[hit] != p$term
            fix[moved] <- paste0(edits$term[hit[moved]], ": ", fix[moved])
            action <- rep("", length(ids))
            action[fixed] <- paste0(
                "<span class=\"coord-issue-badge coord-issue-badge-edited\">", tr("preview_fix_edited", lang),
                "</span> <a href=\"#\" class=\"preview-fix-undo\" data-id=\"", ids[fixed], "\">",
                tr("preview_fix_undo", lang), "</a>",
                ifelse(is.na(edits$row[hit[fixed]]) & same_n[fixed] > 0L,
                       paste0(" <span class=\"pf-muted\">", sprintf(tr("preview_fix_same_n", lang), same_n[fixed]), "</span>"),
                       "")
            )
            use <- !fixed & !is.na(p$suggestion)
            action[use] <- paste0(
                "<button type=\"button\" class=\"btn btn-primary btn-sm preview-fix-use\" data-id=\"",
                ids[use], "\">", tr("preview_fix_use", lang), "</button>"
            )
            blank <- !fixed & !p$term %in% preview_required_terms
            action[blank] <- paste0(
                action[blank], ifelse(use[blank], " ", ""),
                "<button type=\"button\" class=\"btn btn-outline-secondary btn-sm preview-fix-blank\" data-id=\"",
                ids[blank], "\">", tr("preview_fix_leave_empty", lang), "</button>"
            )
            other <- match(p$type, preview_other_fix$type)
            other_ok <- !fixed & !is.na(other)
            if (any(other_ok)) {
                action[other_ok] <- paste0(
                    action[other_ok], ifelse(nzchar(action[other_ok]), " ", ""),
                    "<button type=\"button\" class=\"btn btn-primary btn-sm preview-fix-other\" data-id=\"",
                    ids[other_ok], "\">",
                    vapply(preview_other_fix$label[other[other_ok]], tr, character(1), lang = lang),
                    "</button>"
                )
            }
            # A repeated id left as it is shows the id the export writes.
            auto <- rep("", length(ids))
            open_id <- !fixed & p$type == "id_duplicate"
            if (any(open_id)) {
                auto[open_id] <- as.character(edited_data_r()$occurrenceID[p$row[open_id]])
            }
            many <- !fixed & (p$bulk | other_ok) & same_n > 0L
            action[many] <- paste0(action[many], " <span class=\"pf-muted\">",
                                   sprintf(tr("preview_fix_same_n", lang), same_n[many]), "</span>")

            out <- data.frame(
                row = p$row,
                term = p$term,
                diag = diag,
                value = ifelse(nzchar(p$value), p$value, tr("preview_fix_empty_value", lang)),
                fix = fix,
                action = action,
                suggestion = ifelse(fixed | is.na(p$suggestion), "", p$suggestion),
                auto = auto,
                stringsAsFactors = FALSE
            )
            out
        }

        refresh_rows <- function() {
            ids <- shiny::isolate(rows_base_r())
            if (!length(ids)) return(invisible(NULL))
            DT::replaceData(rows_proxy, shiny::isolate(build_rows_df(ids)),
                            resetPaging = FALSE, rownames = FALSE)
        }

        output$rows_section <- shiny::renderUI({
            shiny::req(!identical(filter_rv(), "vocab"), length(rows_base_r()) > 0L)
            lang <- lang_r()
            shiny::div(
                class = "preview-fix-section",
                shiny::div(class = "preview-fix-section-head",
                           shiny::h3(tr("preview_fix_rows_title", lang)),
                           shiny::span(tr("preview_fix_rows_desc", lang)),
                           shiny::div(class = "preview-fix-same",
                                      shiny::checkboxInput(ns("same_value"), tr("preview_fix_same_value", lang),
                                                           value = shiny::isolate(input$same_value) %||% TRUE))),
                # Only under the ID pill, so the other lists stay short.
                if (identical(filter_rv(), "id")) {
                    shiny::div(class = "preview-fix-note", ph_icon("info"),
                               shiny::p(tr("preview_fix_id_note", lang)))
                },
                DT::dataTableOutput(ns("rows_table")),
                shiny::uiOutput(ns("record_panel"))
            )
        })

        output$rows_table <- DT::renderDataTable({
            ids <- rows_base_r()
            shiny::req(length(ids) > 0L)
            df <- shiny::isolate(build_rows_df(ids))
            lang <- lang_r()
            fix_js <- DT::JS(module_behavior_call("previewFixValueCell", list(
                emptyValue = tr("preview_fix_empty_value", lang),
                auto = tr("preview_fix_auto", lang),
                suggestion = tr("preview_fix_suggestion", lang),
                placeholderTaxon = tr("preview_fix_placeholder_taxon", lang),
                placeholder = tr("preview_fix_placeholder", lang)
            )))
            focus_js <- DT::JS(module_behavior_call("previewFocusRow"))
            # The value is escaped on the server. The span cuts a long value,
            # because Scroller needs rows of one height.
            cut_js <- DT::JS(module_behavior_call("previewCutCell"))
            DT::datatable(
                df,
                # Translated headers only: the data keeps its column names, so a
                # server-side request sent before a language change still finds
                # its columns (DT alerts "column name not found" otherwise).
                colnames = c(
                    tr("preview_fix_col_row", lang), tr("preview_fix_col_term", lang),
                    tr("preview_fix_col_diag", lang), tr("preview_fix_col_value", lang),
                    tr("preview_fix_col_fix", lang), " ", "suggestion", "auto"
                ),
                # No pages: the rows scroll inside the table, and the record
                # below it stays on screen. 09-preview.css sets the height.
                extensions = "Scroller",
                options = list(
                    dom = "ti",
                    deferRender = TRUE,
                    scroller = TRUE,
                    scrollY = "var(--pf-rows-height)",
                    scrollCollapse = TRUE,
                    autoWidth = FALSE,
                    columnDefs = list(
                        list(targets = 3L, render = cut_js),
                        list(targets = 4L, render = fix_js, className = "pf-fix-cell"),
                        list(targets = c(6L, 7L), visible = FALSE),
                        list(targets = 5L, orderable = FALSE),
                        list(targets = c(0L, 1L, 3L), className = "pf-mono")
                    ),
                    language = preview_dt_language(lang),
                    drawCallback = focus_js
                ),
                class = "display compact validate-results-table preview-rows-table",
                rownames = FALSE,
                escape = c(1L, 2L, 4L),
                selection = "none",
                # Only the Correction column takes an edit.
                editable = list(target = "cell", disable = list(columns = c(0L, 1L, 2L, 3L, 5L, 6L)))
            )
        })

        output$record_panel <- shiny::renderUI({
            focus <- input$focus
            lang <- lang_r()
            row <- suppressWarnings(as.integer(focus$row))
            raw <- if (is.function(raw_data_r)) raw_data_r()
            # The panel keeps its place before a click, so the table does not
            # move when a record shows.
            if (length(row) != 1L || is.na(row) || row < 1L || !is.data.frame(raw) || row > nrow(raw)) {
                return(shiny::div(class = "preview-record is-empty", tr("preview_fix_record_empty", lang)))
            }
            values <- vapply(raw[row, , drop = FALSE], function(v) {
                v <- as.character(v)
                if (is.na(v) || !nzchar(trimws(v))) "" else v
            }, character(1))
            shiny::div(
                class = "preview-record",
                if (identical(focus$term, "scientificName")) taxon_clues(row, lang),
                shiny::div(class = "preview-record-title",
                           sprintf(tr("preview_fix_record_title", lang), row)),
                shiny::div(
                    class = "preview-record-grid",
                    lapply(seq_along(values), function(i) {
                        shiny::tagList(
                            shiny::span(class = "preview-record-key", names(values)[i]),
                            shiny::span(class = if (nzchar(values[i])) "preview-record-value" else "preview-record-value is-empty",
                                        if (nzchar(values[i])) values[i] else tr("preview_fix_empty_value", lang))
                        )
                    })
                )
            )
        })

        # A person who does not know the species can still write a higher
        # taxon. The common name and the higher ranks in the record help.
        taxon_clues <- function(row, lang) {
            df <- edited_data_r()
            terms <- intersect(c("vernacularName", "kingdom", "phylum", "class", "order",
                                 "family", "genus"), names(df))
            values <- vapply(terms, function(t) {
                v <- as.character(df[[t]][row])
                if (is.na(v)) "" else trimws(v)
            }, character(1))
            values <- values[nzchar(values)]
            shiny::div(
                class = "preview-taxon-clues",
                shiny::p(class = "preview-taxon-hint", tr("preview_fix_taxon_hint", lang)),
                if (length(values)) {
                    shiny::div(
                        class = "preview-record-grid",
                        lapply(names(values), function(t) shiny::tagList(
                            shiny::span(class = "preview-record-key", t),
                            shiny::span(class = "preview-record-value", values[[t]])
                        ))
                    )
                } else {
                    shiny::p(class = "pf-muted", tr("preview_fix_taxon_none", lang))
                }
            )
        }

        # Store one correction for each of `rows`. A fix for every cell with
        # the same value (row NA) replaces the per-row fixes of that value.
        # The edits of one click share a batch, so Undo removes them together.
        # Returns the rows it reaches.
        add_edit <- function(rows, term, from, to, batch = next_batch()) {
            edits <- edits_rv()
            new <- data.frame(row = as.integer(rows), term = term, from = from, to = to,
                              batch = batch, stringsAsFactors = FALSE)
            if (is.data.frame(edits)) {
                same <- edits$term == term & edits$from == from &
                    (anyNA(rows) | (!is.na(edits$row) & edits$row %in% rows))
                edits <- rbind(edits[!same, , drop = FALSE], new)
            } else {
                edits <- new
            }
            edits_rv(edits)
            p <- shiny::isolate(problems_r())
            if (anyNA(rows)) sum(p$term == term & p$value == from) else length(rows)
        }

        next_batch <- function() {
            edits <- shiny::isolate(edits_rv())
            if (is.data.frame(edits)) max(edits$batch) + 1L else 1L
        }

        save_problem_fix <- function(id, value) {
            p <- problems_r()
            term <- p$term[id]
            # The ids before the repeated ones are replaced: a typed id that
            # another row still repeats would be replaced too.
            taken <- if (term == "occurrenceID") {
                ids <- as.character(corrected_data_r()$occurrenceID)
                ids[-p$row[id]]
            } else {
                character(0)
            }
            parsed <- parse_preview_edit(term, value, taken = taken)
            if (!is.null(parsed$error)) {
                notify_fix(tr(parsed$error, lang_r()), "error")
                refresh_rows()
                return(invisible(NULL))
            }
            all_rows <- isTRUE(p$bulk[id]) && isTRUE(input$same_value %||% TRUE)
            rows <- if (!all_rows) {
                p$row[id]
            } else if (preview_fix_by_row(p$type[id])) {
                p$row[preview_fix_key(p) == preview_fix_key(p[id, , drop = FALSE])]
            } else {
                NA_integer_
            }
            n <- add_edit(rows, term, p$value[id], parsed$value)
            refresh_rows()
            focus_next_open(id)
            notify_fix(sprintf(tr("preview_fix_saved", lang_r()), n), "message")
        }

        # A fix for every row with the same value leaves its edited copies in
        # the list, so the browser moves to the next open problem below.
        focus_next_open <- function(id) {
            ids <- rows_base_r()
            display <- as.integer(unlist(input$rows_table_rows_all))
            if (length(display) != length(ids)) display <- seq_along(ids)
            shown <- ids[display]
            pos <- next_open_problem(id, shown, is.na(problem_edit_r()[shown]))
            if (is.na(pos)) return(invisible(NULL))
            p <- problems_r()
            session$sendCustomMessage(ns("fix_next"), list(
                pos = pos - 1L, row = p$row[shown[pos]], term = p$term[shown[pos]]
            ))
        }

        shiny::observeEvent(input$rows_table_cell_edit, {
            info <- input$rows_table_cell_edit
            ids <- rows_base_r()
            pos <- suppressWarnings(as.integer(info$row))
            if (!identical(as.integer(info$col), 4L) || length(pos) != 1L || is.na(pos) ||
                    pos < 1L || pos > length(ids)) {
                return(invisible(NULL))
            }
            save_problem_fix(ids[pos], info$value)
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$use, {
            id <- suppressWarnings(as.integer(input$use))
            p <- problems_r()
            if (length(id) != 1L || is.na(id) || id > nrow(p) || is.na(p$suggestion[id])) return(invisible(NULL))
            save_problem_fix(id, p$suggestion[id])
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$blank, {
            id <- suppressWarnings(as.integer(input$blank))
            if (length(id) != 1L || is.na(id) || id > nrow(problems_r())) return(invisible(NULL))
            save_problem_fix(id, "")
        }, ignoreInit = TRUE)

        # The fix for the other cell of the row (D07). With the same-value box
        # on, it reaches each open row of the same problem, one row at a time.
        shiny::observeEvent(input$other, {
            id <- suppressWarnings(as.integer(input$other))
            p <- problems_r()
            if (length(id) != 1L || is.na(id) || id > nrow(p)) return(invisible(NULL))
            k <- match(p$type[id], preview_other_fix$type)
            if (is.na(k)) return(invisible(NULL))
            term <- preview_other_fix$term[k]
            rows <- if (isTRUE(input$same_value %||% TRUE)) {
                open <- is.na(problem_edit_r())
                p$row[open & preview_fix_key(p) == preview_fix_key(p[id, , drop = FALSE])]
            } else {
                p$row[id]
            }
            from <- trimws(as.character(full_data_r()[[term]][rows]))
            from[is.na(from)] <- ""
            n <- 0L
            batch <- next_batch()
            for (f in unique(from)) {
                n <- n + add_edit(rows[from == f], term, f, preview_other_fix$to[k], batch)
            }
            refresh_rows()
            focus_next_open(id)
            notify_fix(sprintf(tr("preview_fix_saved", lang_r()), n), "message")
        }, ignoreInit = TRUE)

        shiny::observeEvent(input$undo, {
            id <- suppressWarnings(as.integer(input$undo))
            hit <- problem_edit_r()
            if (length(id) != 1L || is.na(id) || id > length(hit) || is.na(hit[id])) return(invisible(NULL))
            edits <- edits_rv()
            edits <- edits[edits$batch != edits$batch[hit[id]], , drop = FALSE]
            edits_rv(if (nrow(edits)) edits else NULL)
            refresh_rows()
            notify_fix(tr("preview_fix_undone", lang_r()), "message")
        }, ignoreInit = TRUE)

        # --- Exact copies ----------------------------------------------------

        # Each original with its copies under it. Only a copy has a choice.
        output$copies_section <- shiny::renderUI({
            shiny::req(identical(filter_rv(), "copy"))
            cp <- copies_r()
            shiny::req(nrow(cp) > 0L)
            left <- rows_left_out_r()
            lang <- lang_r()
            df <- corrected_data_r()
            cell <- function(term, row) {
                v <- if (term %in% names(df)) as.character(df[[term]][row]) else NA_character_
                if (is.na(v) || !nzchar(trimws(v))) "" else v
            }
            choice <- function(row, out) {
                shiny::tags$span(
                    class = "preview-copy-choice",
                    shiny::tags$button(type = "button", class = paste("preview-copy-set", if (!out) "is-on"),
                                       `data-row` = row, `data-out` = "0", tr("preview_copy_in", lang)),
                    shiny::tags$button(type = "button", class = paste("preview-copy-set", if (out) "is-out"),
                                       `data-row` = row, `data-out` = "1", tr("preview_copy_out", lang))
                )
            }
            line <- function(row, diag, last, original = FALSE) {
                shiny::tags$tr(
                    class = if (original) "is-original",
                    shiny::tags$td(class = "pf-mono", row),
                    shiny::tags$td(diag),
                    shiny::tags$td(class = "pf-taxon", cell("scientificName", row)),
                    shiny::tags$td(class = "pf-mono", cell("eventDate", row)),
                    shiny::tags$td(last)
                )
            }
            body <- lapply(unique(cp$of), function(of) {
                copies <- cp$row[cp$of == of]
                shiny::tagList(
                    line(of, shiny::span(class = "pf-muted", tr("preview_copy_original", lang)),
                         shiny::span(class = "pf-muted", tr("preview_copy_original_stays", lang)),
                         original = TRUE),
                    lapply(copies, function(r) line(
                        r,
                        shiny::span(class = "coord-issue-badge coord-issue-badge-missing",
                                    sprintf(tr("preview_copy_of", lang), of)),
                        choice(r, r %in% left)
                    ))
                )
            })
            all_out <- length(left) == nrow(cp)
            shiny::div(
                class = "preview-fix-section preview-copies",
                shiny::div(
                    class = "preview-copy-box",
                    shiny::p(
                        if (all_out) sprintf(tr("preview_copy_all_out", lang), nrow(cp))
                        else sprintf(tr("preview_copy_open", lang), nrow(cp)),
                        shiny::tags$small(tr(if (all_out) "preview_copy_all_out_sub" else "preview_copy_open_sub", lang))
                    ),
                    shiny::tags$button(
                        type = "button", `data-row` = "all", `data-out` = if (all_out) "0" else "1",
                        class = paste("btn btn-sm preview-copy-set",
                                      if (all_out) "btn-outline-secondary" else "btn-primary"),
                        tr(if (all_out) "preview_fix_undo" else "preview_copy_drop_all", lang)
                    )
                ),
                shiny::div(
                    class = "preview-copy-scroll",
                    shiny::tags$table(
                        class = "preview-copy-table",
                        shiny::tags$thead(shiny::tags$tr(
                            shiny::tags$th(tr("preview_fix_col_row", lang)),
                            shiny::tags$th(tr("preview_fix_col_diag", lang)),
                            shiny::tags$th("scientificName"),
                            shiny::tags$th("eventDate"),
                            shiny::tags$th(tr("preview_fix_col_fix", lang))
                        )),
                        shiny::tags$tbody(body)
                    )
                ),
                shiny::p(class = "pf-muted preview-copy-note", tr("preview_copy_note", lang))
            )
        })

        shiny::observeEvent(input$copy_set, {
            set <- input$copy_set
            cp <- copies_r()
            rows <- if (identical(set$row, "all")) cp$row else {
                intersect(suppressWarnings(as.integer(set$row)), cp$row)
            }
            if (!length(rows)) return(invisible(NULL))
            left <- left_out_rv()
            left_out_rv(if (isTRUE(set$out)) union(left, rows) else setdiff(left, rows))
        }, ignoreInit = TRUE)

        notify_fix <- function(message, type) {
            shiny::showNotification(message, type = type, id = ns("fix_note"),
                                    duration = if (identical(type, "error")) 7 else 4)
        }

        module_result_return(
            new_module_result(preview_data, edited_data_r = edited_data_r, problems_n_r = problems_n_r,
                              rows_left_out_r = rows_left_out_r,
                              preview_changes_r = preview_changes_r),
            c("edited_data_r" = "edited_data_r", "problems_n_r" = "problems_n_r",
              "rows_left_out_r" = "rows_left_out_r",
              "preview_changes_r" = "preview_changes_r"), return_contract
        )
    })
}

#' Count of open problems after the Preview step name in the nav
#'
#' @param n Open problems, or NA before there is data to count
#' @param lang Language code
#' @return A `shiny.tag`, or NULL for NA
#' @noRd
preview_nav_badge <- function(n, lang) {
    if (length(n) != 1L || is.na(n)) {
        return(NULL)
    }
    if (n == 0L) {
        return(shiny::tags$span(
            class = "nav-count is-clear", title = tr("preview_nav_clear_title", lang),
            ph_icon("check")
        ))
    }
    shiny::tags$span(
        class = "nav-count", title = sprintf(tr("preview_nav_count_title", lang), n), n
    )
}

preview_dt_language <- function(lang) {
    list(
        search = tr("preview_datatable_search", lang),
        lengthMenu = tr("preview_datatable_length_menu", lang),
        info = tr("preview_datatable_info", lang),
        emptyTable = tr("preview_datatable_empty", lang),
        zeroRecords = tr("preview_datatable_zero_records", lang),
        paginate = list(
            first = tr("preview_datatable_first", lang),
            last = tr("preview_datatable_last", lang),
            `next` = tr("preview_datatable_next", lang),
            previous = tr("preview_datatable_prev", lang)
        )
    )
}
