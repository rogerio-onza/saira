# Mapping commands with explicit mutation and browser synchronization ports.
# No database, Shiny inputs or grid state is reachable through this interface.
new_mapping_commands <- function(write_selection, write_meta, add_terms,
                                  begin_restore, end_restore, sync_selection,
                                  write_fixed, sync_fixed) {
    select <- function(term, value, update_input = TRUE) {
        selected <- sanitize_map_selection(term, value)
        write_selection(term, selected)
        sync_selection(term, selected, update_input)
        invisible(selected)
    }
    manual_meta <- function(term, has_value = TRUE) {
        write_meta(term, build_manual_meta(previous_meta = NULL, has_value = has_value))
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
        select = select, manual_meta = manual_meta,
        fixed_value = fixed_value, restore = restore
    )
}
