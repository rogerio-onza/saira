# Utils export writers

#' Write a data frame to .xlsx with every cell forced to text
#'
#' Excel's auto-detection corrupts ISO dates ("2024-01-15" -> "15/01/2024" in
#' PT-BR locale), large numbers (-> scientific notation), and leading zeros
#' (stripped). To survive double-click open and a re-save, every column is
#' coerced to character before writing via writexl.
#'
#' @param df Data frame to write.
#' @param path Destination .xlsx path.
#' @return Invisibly returns `path`.
#' @export
write_xlsx_text_only <- function(df, path) {
    if (!is.data.frame(df)) {
        stop("write_xlsx_text_only: 'df' must be a data.frame.")
    }

    writexl::write_xlsx(text_only_frame(df), path = path, format_headers = TRUE)
    invisible(path)
}

text_only_frame <- function(df) {
    df_text <- as.data.frame(
        lapply(df, function(col) {
            x <- as.character(col)
            x[is.na(x)] <- ""
            x
        }),
        stringsAsFactors = FALSE,
        check.names = FALSE
    )
    names(df_text) <- names(df)
    df_text
}

#' Write the private real-coordinates file
#'
#' One workbook: the exact points on the first sheet, the notice on the
#' second. The user downloads it apart from the IPT bundle (ADR-163).
#'
#' @param real Data frame of real coordinates (`mask_sensitive_coordinates()$real`).
#' @param notice Character notice text, one line per element.
#' @param path Destination `.xlsx` path.
#' @return Invisibly returns `path`.
#' @noRd
write_sensitive_coords_xlsx <- function(real, notice, path) {
    sheets <- list(
        coordinates = text_only_frame(real),
        README = data.frame(README = enc2utf8(notice), stringsAsFactors = FALSE)
    )
    writexl::write_xlsx(sheets, path = path, format_headers = TRUE)
    invisible(path)
}

#' Assemble a Darwin Core Archive (DwC-A) bundle as a ZIP
#'
#' Lays out the archive with `occurrence.txt`, `meta.xml`, `eml.xml` (and
#' `measurementorfact.txt` when there are measurements) at the ZIP root, plus
#' any provided sibling files (`mapping_guide.txt`, the
#' Excel mirror). The bundle is GBIF/IPT-compatible.
#'
#' @param df Data frame of DwC-ready records (output of
#'   `process_for_export()` or `process_for_export_with_unmapped()`).
#' @param zip_path Destination ZIP path.
#' @param metadata Named list passed to `build_eml_xml()`.
#' @param extras Optional named list mapping in-zip filenames to local file
#'   paths to include as siblings.
#' @param measurements Optional data frame of MeasurementOrFact rows
#'   (`split_measurements()`). When it has rows, the archive gains
#'   `measurementorfact.txt` and `meta.xml` declares it.
#' @return Invisibly returns `zip_path`.
#' @export
build_dwca_bundle <- function(df, zip_path, metadata = list(), extras = list(),
                              measurements = NULL) {
    if (!is.data.frame(df)) stop("build_dwca_bundle: 'df' must be a data.frame.")

    tmpdir <- tempfile("saira_dwca_")
    dir.create(tmpdir, showWarnings = FALSE, recursive = TRUE)
    on.exit(unlink(tmpdir, recursive = TRUE), add = TRUE)

    core_path <- file.path(tmpdir, "occurrence.txt")
    meta_path <- file.path(tmpdir, "meta.xml")
    eml_path  <- file.path(tmpdir, "eml.xml")

    readr::write_csv(df, core_path, na = "")
    writeLines(build_meta_xml(df, core_filename = "occurrence.txt", measurements = measurements),
               meta_path, useBytes = TRUE)
    writeLines(build_eml_xml(df, metadata = metadata),
               eml_path, useBytes = TRUE)

    files <- c(core_path, meta_path, eml_path)
    if (is.data.frame(measurements) && nrow(measurements) > 0L) {
        mof_path <- file.path(tmpdir, MOF_FILENAME)
        readr::write_csv(measurements, mof_path, na = "")
        files <- c(files, mof_path)
    }
    for (nm in names(extras)) {
        src <- extras[[nm]]
        if (length(src) == 1L && file.exists(src)) {
            dst <- file.path(tmpdir, nm)
            file.copy(src, dst, overwrite = TRUE)
            files <- c(files, dst)
        }
    }

    zip::zipr(zipfile = zip_path, files = files)
    invisible(zip_path)
}

