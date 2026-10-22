# Named internal contracts, with opt-in lists for exported module consumers.
new_module_result <- function(report_r, ...) {
    fields <- c(list(report_r = report_r), list(...))
    valid <- vapply(fields, shiny::is.reactive, logical(1))
    if (!all(valid)) stop("Module result fields must be reactive: ",
                          paste(names(fields)[!valid], collapse = ", "), call. = FALSE)
    fields
}

module_result_return <- function(result, legacy_attributes, return_contract) {
    return_contract <- match.arg(return_contract, c("legacy", "list"))
    if (identical(return_contract, "list")) return(result)
    legacy <- result$report_r
    for (name in names(legacy_attributes)) attr(legacy, name) <- result[[legacy_attributes[[name]]]]
    legacy
}

optional_reactive_value <- function(value_r, default = NULL) {
    if (is.null(value_r)) return(default)
    if (!shiny::is.reactive(value_r)) stop("Expected an optional reactive.", call. = FALSE)
    value_r()
}
