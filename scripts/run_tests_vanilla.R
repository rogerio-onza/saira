args <- commandArgs(trailingOnly = TRUE)

ensure_pkg <- function(pkg) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
        stop(sprintf("Missing package '%s'. Install it in your global library.", pkg), call. = FALSE)
    }
}

ensure_pkg("devtools")
ensure_pkg("testthat")

devtools::load_all(".", quiet = TRUE)

if (length(args) == 0L) {
    devtools::test()
} else if (length(args) >= 2L && identical(args[[1]], "--file")) {
    testthat::test_file(args[[2]])
} else {
    devtools::test(filter = args[[1]])
}
