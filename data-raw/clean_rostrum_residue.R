# One-off cleanup of the local Rostrum alias store. Not package code and not
# run by anything automatically: invoke it by hand.
#
# Removes two kinds of residue documented in ADR-115 and LESSONS.md:
#   1. Aliases written by the test suite before tests/testthat/setup.R isolated
#      SAIRA_DATA_DIR (user_id like "test_isolation_%"), plus their events.
#   2. A hand-picked list of wrong personal aliases left behind by cycling a
#      mapping card through candidate columns, back when every selection was
#      learned immediately.
#
# Prints what it would do and exits. Pass apply = TRUE to write, which always
# takes a VACUUM INTO backup first.
#
# Usage:
#   Rscript -e "source('data-raw/clean_rostrum_residue.R'); clean_rostrum_residue()"
#   Rscript -e "source('data-raw/clean_rostrum_residue.R'); clean_rostrum_residue(apply = TRUE)"

# Wrong pairs to drop. Each of these columns also has a CORRECT alias that must
# survive (especie -> scientificName, class -> class, datasetname -> datasetName,
# road id -> locationID, bibliographiccitation -> bibliographicCitation), so the
# delete has to match on the pair, never on the column alone.
.rostrum_wrong_pairs <- data.frame(
    col_name_norm = c(
        "especie", "id", "1", "class",
        "datasetname", "road id", "bibliographiccitation"
    ),
    dwc_term = c(
        "habitat", "basisOfRecord", "basisOfRecord", "basisOfRecord",
        "basisOfRecord", "basisOfRecord", "basisOfRecord"
    ),
    stringsAsFactors = FALSE
)

clean_rostrum_residue <- function(db_path = NULL, apply = FALSE) {
    if (is.null(db_path)) {
        data_dir <- Sys.getenv("SAIRA_DATA_DIR", unset = "")
        if (!nzchar(data_dir)) {
            data_dir <- tools::R_user_dir("saira", "data")
        }
        db_path <- file.path(data_dir, "rostrum.sqlite")
    }
    if (!file.exists(db_path)) {
        stop("No database at ", db_path)
    }

    conn <- DBI::dbConnect(RSQLite::SQLite(), dbname = db_path)
    on.exit(try(DBI::dbDisconnect(conn), silent = TRUE), add = TRUE)

    total <- DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM rostrum_aliases")$n[[1]]

    test_rows <- DBI::dbGetQuery(
        conn,
        "SELECT alias_id, col_name_norm, dwc_term, user_id
           FROM rostrum_aliases
          WHERE user_id LIKE 'test_isolation_%'"
    )

    wrong_rows <- DBI::dbGetQuery(
        conn,
        paste(
            "SELECT alias_id, col_name_norm, dwc_term, user_id, created_at",
            "FROM rostrum_aliases",
            "WHERE", paste(
                rep("(col_name_norm = ? AND dwc_term = ?)",
                    nrow(.rostrum_wrong_pairs)),
                collapse = " OR "
            )
        ),
        params = as.list(as.vector(t(as.matrix(.rostrum_wrong_pairs))))
    )

    doomed <- unique(c(test_rows$alias_id, wrong_rows$alias_id))
    events_n <- if (length(doomed) == 0L) {
        0L
    } else {
        DBI::dbGetQuery(
            conn,
            sprintf(
                "SELECT COUNT(*) AS n FROM rostrum_alias_events WHERE alias_id IN (%s)",
                paste(rep("?", length(doomed)), collapse = ",")
            ),
            params = as.list(doomed)
        )$n[[1]]
    }

    cat("Database:      ", db_path, "\n", sep = "")
    cat("Aliases now:   ", total, "\n", sep = "")
    cat("Test residue:  ", nrow(test_rows), " aliases\n", sep = "")
    cat("Wrong pairs:   ", nrow(wrong_rows), " aliases\n", sep = "")
    cat("Events to drop:", events_n, "\n", sep = "")
    cat("Aliases after: ", total - length(doomed), "\n\n", sep = "")

    if (nrow(wrong_rows) > 0L) {
        cat("The personal aliases below will be deleted:\n")
        print(wrong_rows[, c("col_name_norm", "dwc_term", "created_at")],
              row.names = FALSE)
        cat("\n")
    }

    if (!isTRUE(apply)) {
        cat("Dry run. Re-run with apply = TRUE to write.\n")
        return(invisible(list(test = test_rows, wrong = wrong_rows)))
    }

    backup <- paste0(db_path, ".backup-", format(Sys.time(), "%Y%m%dT%H%M%S"))
    DBI::dbExecute(conn, "VACUUM INTO ?", params = list(backup))
    cat("Backup written to ", backup, "\n", sep = "")

    if (length(doomed) > 0L) {
        placeholders <- paste(rep("?", length(doomed)), collapse = ",")
        DBI::dbExecute(conn, "BEGIN IMMEDIATE")
        committed <- FALSE
        on.exit({
            if (!committed) try(DBI::dbExecute(conn, "ROLLBACK"), silent = TRUE)
        }, add = TRUE)

        DBI::dbExecute(
            conn,
            sprintf("DELETE FROM rostrum_alias_events WHERE alias_id IN (%s)", placeholders),
            params = as.list(doomed)
        )
        DBI::dbExecute(
            conn,
            sprintf("DELETE FROM rostrum_aliases WHERE alias_id IN (%s)", placeholders),
            params = as.list(doomed)
        )
        # Events whose alias was removed by some earlier operation.
        DBI::dbExecute(
            conn,
            "DELETE FROM rostrum_alias_events
              WHERE alias_id NOT IN (SELECT alias_id FROM rostrum_aliases)"
        )
        DBI::dbExecute(conn, "COMMIT")
        committed <- TRUE
    }

    DBI::dbExecute(conn, "VACUUM")

    cat("Aliases left:  ",
        DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM rostrum_aliases")$n[[1]],
        "\n", sep = "")
    cat("Events left:   ",
        DBI::dbGetQuery(conn, "SELECT COUNT(*) AS n FROM rostrum_alias_events")$n[[1]],
        "\n", sep = "")

    invisible(list(test = test_rows, wrong = wrong_rows))
}
