# Execute with the bundled Rscript and --library=<bundled library path>.
arg <- grep("^--file=", commandArgs(), value = TRUE)
source(file.path(dirname(normalizePath(sub("^--file=", "", arg))), "common.R"))
library <- desktop_arg("library")
if (is.null(library) || !dir.exists(library)) stop("Pass --library=<bundled R library>.")
.libPaths(c(normalizePath(library, winslash = "/"), .Library), include.site = FALSE)
private <- tempfile("saira-desktop-smoke-")
dir.create(private)
Sys.setenv(SAIRA_DATA_DIR = private, R_USER_DATA_DIR = private, R_USER_CACHE_DIR = private)
options(shiny.launch.browser = FALSE)
imports <- strsplit(packageDescription("saira", fields = "Imports"), ",")[[1L]]
imports <- trimws(sub(" *\\(.*$", "", imports))
for (package in imports) {
    if (!requireNamespace(package, quietly = TRUE)) stop("Could not load: ", package)
    location <- normalizePath(find.package(package), winslash = "/")
    if (!startsWith(tolower(location), paste0(tolower(normalizePath(library, winslash = "/")), "/"))) {
        stop("An app dependency came from outside the bundle: ", location)
    }
}
message("All direct dependencies loaded from the bundled library.")

point <- sf::st_sfc(sf::st_point(c(-47, -15)), crs = 4326)
stopifnot(all(is.finite(sf::st_coordinates(sf::st_transform(point, 31983)))))
stopifnot(terra::nrow(terra::vect(point)) == 1L)
connection <- DBI::dbConnect(RSQLite::SQLite(), tempfile(fileext = ".sqlite"))
DBI::dbWriteTable(connection, "probe", data.frame(value = "Sa\u00edra"))
stopifnot(identical(DBI::dbReadTable(connection, "probe")$value, "Sa\u00edra"))
DBI::dbDisconnect(connection)

records <- data.frame(
    occurrenceID = c("desktop-smoke-01", "desktop-smoke-02"),
    scientificName = c("Panthera onca", "Tapirus terrestris"),
    basisOfRecord = "HumanObservation",
    decimalLatitude = c("-15", "-14"),
    decimalLongitude = c("-47", "-48"),
    country = "Brazil", eventDate = "2026-01-01",
    stringsAsFactors = FALSE
)
csv <- file.path(private, "records.csv")
readr::write_csv(records, csv)
loaded <- saira::read_biodiversity_csv(csv)
stopifnot(is.data.frame(loaded), nrow(loaded) == 2L)
coordinates <- saira::validate_coords_cc_df(records,
    "decimalLatitude", "decimalLongitude", "country", seas_scale = 10L)
stopifnot(is.data.frame(coordinates), nrow(coordinates) == nrow(records))

xlsx <- file.path(private, "records.xlsx")
saira::write_xlsx_text_only(records, xlsx)
stopifnot(nrow(readxl::read_xlsx(xlsx)) == nrow(records))
archive <- file.path(private, "records.zip")
saira::build_dwca_bundle(records, archive)
stopifnot(all(c("occurrence.txt", "meta.xml", "eml.xml") %in% zip::zip_list(archive)$filename))
stopifnot(inherits(saira::run_app(), "shiny.appobj"))
message("PASS: native libraries, CSV, coordinates, XLSX, DwC-A and Shiny app construction.")

# The Flora/Fauna BR update starts a callr worker with the same library paths
# (ADR-177). The shell sets R_LIBS_USER so that a plain Rscript loads saira
# from the bundle too.
bundle <- paste0(tolower(normalizePath(library, winslash = "/")), "/")
Sys.setenv(R_LIBS_USER = normalizePath(library, winslash = "/"))
worker <- callr::r_bg(function() { Sys.sleep(5); normalizePath(find.package("saira"), winslash = "/") },
    libpath = .libPaths(), package = TRUE, user_profile = FALSE, stdout = NULL, stderr = NULL,
    supervise = TRUE)
# A listening socket outside the loopback opens the Windows firewall prompt.
listen <- system2("powershell", c("-NoProfile", "-Command", shQuote(sprintf(paste0(
    "$l = @(Get-NetTCPConnection -State Listen -ErrorAction Stop); ",
    "$r = @($l | Where-Object { $_.OwningProcess -in @(%d, %d) -and ",
    "$_.LocalAddress -notin @('127.0.0.1', '::1') }); ",
    "Write-Output \"$($l.Count) $($r.Count)\""), Sys.getpid(), worker$get_pid()), type = "cmd")),
    stdout = TRUE)
counts <- as.integer(strsplit(trimws(tail(listen, 1L)), " ")[[1]])
stopifnot(length(counts) == 2L, counts[[1]] > 0L, counts[[2]] == 0L)
worker$wait(60000)
stopifnot(startsWith(tolower(worker$get_result()), bundle))
rscript <- file.path(R.home("bin"), "Rscript")
plain <- system2(rscript, c("--vanilla", "-e",
    shQuote("cat(normalizePath(find.package('saira'), winslash = '/'))")), stdout = TRUE)
stopifnot(startsWith(tolower(plain), bundle))

# #219 to #221: the offline Flora/Fauna BR pass suggests the catalog name for a typo.
names <- data.frame(query_name = c("Euterpe edulis", "Euterpe eduls", "Panthera onca"))
state <- saira:::init_taxadb_run_state(names, providers = c("florabr", "faunabr"))
while (!saira:::is_taxadb_run_done(state)) state <- saira:::next_taxadb_run_step(state)
report <- saira:::finalize_taxadb_run(state)$report
row <- report[report$query_name == "Euterpe eduls", , drop = FALSE]
stopifnot(nrow(row) == 1L, identical(row$suggestedName, "Euterpe edulis"),
    identical(report$validation_status[report$query_name == "Panthera onca"], "accepted"))
message("PASS: R workers load the bundle without a public socket, and the offline names check suggests Euterpe edulis.")
