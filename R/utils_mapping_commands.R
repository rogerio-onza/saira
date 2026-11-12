# Mapping commands with explicit mutation and browser synchronization ports.
# No database, Shiny inputs or grid state is reachable through this interface.
# Every write of a selection or its meta goes through these commands
# (REF-01). The module keeps the echo guards of the browser inputs.
new_mapping_commands <- function(write_selection, write_meta, add_terms,
                                  begin_restore, end_restore, sync_selection,
                                  write_fixed, sync_fixed,
                                  read_selection = function(term) NULL,
                                  read_meta = function(term) NULL,
                                  write_model = function(values, meta) NULL,
                                  fixed_terms = function() character(0),
                                  in_restore = function() FALSE,
                                  take_programmatic = function(term) FALSE,
                                  selection_changed = function(term, value) NULL) {
    select <- function(term, value, update_input = TRUE) {
        selected <- sanitize_map_selection(term, value)
        write_selection(term, selected)
        sync_selection(term, selected, update_input)
        invisible(selected)
    }
    manual_meta <- function(term, has_value = TRUE) {
        write_meta(term, build_manual_meta(previous_meta = NULL, has_value = has_value))
    }
    # A user edit keeps the history of the previous meta. Code that sets
    # values (restore, auto-map, reset) writes its own meta.
    user_meta <- function(term, has_value) {
        if (isTRUE(in_restore())) {
            return(invisible(NULL))
        }
        write_meta(term, build_manual_meta(previous_meta = read_meta(term), has_value = has_value))
    }
    # The browser reported a value: write it without an update back. A term
    # that code set is not a user edit, so its meta stays.
    select_user <- function(term, value) {
        selected <- sanitize_map_selection(term, value)
        if (identical(read_selection(term) %||% "", selected)) {
            # The echo of a value that code set ends the mark of that set.
            # A kept mark makes the next user pick look like code.
            take_programmatic(term)
            return(invisible(FALSE))
        }
        write_selection(term, selected)
        selection_changed(term, selected)
        # The restore flag is read first and always: the input observer
        # depends on it.
        restoring <- isTRUE(in_restore())
        programmatic <- isTRUE(take_programmatic(term))
        if (!restoring && !programmatic) {
            write_meta(term, build_manual_meta(previous_meta = read_meta(term),
                                               has_value = has_selected_value(selected)))
        }
        invisible(TRUE)
    }
    set_meta <- function(term, meta) {
        write_meta(term, meta)
    }
    replace_meta <- function(meta) {
        write_model(NULL, meta)
    }
    replace_model <- function(values, meta) {
        write_model(values, meta)
    }
    # A term that leaves the page loses its selection and its meta.
    drop_term <- function(term) {
        write_selection(term, NULL)
        write_meta(term, NULL)
    }
    clear_fixed <- function() {
        for (term in fixed_terms()) {
            fixed_value(term, NULL)
        }
    }
    # A new file: no selection, no meta and no fixed value of the old file.
    reset <- function(term_names) {
        write_model(empty_map_values(term_names), empty_map_meta(term_names))
        clear_fixed()
    }
    # A NULL or blank value turns the fixed value off. The state is written
    # first, so a card that is not on the page still gets the change.
    fixed_value <- function(term, value = NULL) {
        value <- trimws(as.character(value %||% ""))
        state <- list(on = nzchar(value), value = value)
        write_fixed(term, state)
        sync_fixed(term, state)
        invisible(state)
    }
    restore <- function(plan) {
        # Catalog terms outside the default set need a card, as in the
        # Add-term flow. Otherwise the value is restored but no card shows it.
        add_terms(detect_extra_dwc_terms(names(plan$map_values)))
        begin_restore()
        on.exit(end_restore(), add = TRUE)
        for (term in names(plan$map_values)) {
            select(term, plan$map_values[[term]])
            manual_meta(term)
        }
    }
    list(
        select = select, select_user = select_user, manual_meta = manual_meta,
        user_meta = user_meta, set_meta = set_meta, replace_meta = replace_meta,
        replace_model = replace_model, drop_term = drop_term,
        fixed_value = fixed_value, clear_fixed = clear_fixed, reset = reset,
        restore = restore
    )
}
