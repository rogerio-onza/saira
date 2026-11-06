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

# Reads each optional source once. NULL is an absent source and gives its
# default. A req() stop means "not ready" and also gives the default. Any other
# error is a decision that exists but failed: the source name and message go to
# `failed`, so the caller can block instead of reading it as "no decision".
capture_sources <- function(sources, defaults = list()) {
    values <- list()
    failed <- character(0)
    for (name in names(sources)) {
        default <- defaults[[name]]
        result <- tryCatch(
            list(value = optional_reactive_value(sources[[name]], default)),
            shiny.silent.error = function(e) list(value = default),
            error = function(e) list(value = default, error = conditionMessage(e))
        )
        values[name] <- list(result$value)
        if (!is.null(result$error)) {
            failed[[name]] <- result$error
            warning("[export] Could not read ", name, ": ", result$error, call. = FALSE)
        }
    }
    list(values = values, failed = failed)
}
