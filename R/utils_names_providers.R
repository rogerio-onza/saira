# Provider effects. Each query returns one common envelope, independent of the
# round transition logic. Internal contract errors are checked outside I/O catches.
names_provider_adapters <- function() list(
    poll = brprovider_poll_updates,
    load = names_provider_load,
    query = names_provider_query
)

names_provider_load <- function(provider, type) {
    # COL XR is an API: there is nothing to download or load.
    if (!identical(type, "br")) return(list(data = NULL, error = NULL))
    ensured <- tryCatch(brprovider_ensure_data(provider_id = provider, verbose = FALSE),
                         error = function(e) e)
    if (inherits(ensured, "error") || !isTRUE(ensured$ok) || !isTRUE(ensured$available)) {
        message <- if (inherits(ensured, "error")) conditionMessage(ensured) else ensured$error
        if (is.null(message) || !nzchar(message)) message <- "Automatic data bootstrap failed."
        return(list(data = NULL, error = message))
    }
    loaded <- tryCatch(brprovider_load_data(provider), error = function(e) e)
    if (inherits(loaded, "error") || is.null(loaded)) {
        message <- if (inherits(loaded, "error")) conditionMessage(loaded) else "Data load failed."
        return(list(data = NULL, error = message))
    }
    list(data = loaded, error = NULL)
}

names_provider_query <- function(names, provider, type, data = NULL) {
    result <- tryCatch(
        if (identical(type, "br")) query_brprovider(names, provider, data = data)
        else colxr_match_names(names),
        error = function(e) e
    )
    if (inherits(result, "error")) return(list(error = conditionMessage(result)))
    if (!is.data.frame(result) || !all(c("query_name", "validation_status") %in% names(result))) {
        stop("Invalid names provider result: ", provider, call. = FALSE)
    }
    unanswered <- as.character(attr(result, "unanswered") %||% character(0))
    # BR providers short-circuit only on accepted names: synonym, ambiguous
    # and not_found continue to the next provider. A name COL XR does not
    # know stays pending, so it ends as not_found.
    if (identical(type, "br")) {
        shown <- result
        resolved <- result$query_name[result$validation_status %in% "accepted"]
    } else {
        shown <- result[result$validation_status != "not_found", , drop = FALSE]
        resolved <- shown$query_name
    }
    list(results = shown, resolved = unique(as.character(resolved)),
         answered = as.character(result$query_name), unanswered = unanswered, error = NULL)
}
