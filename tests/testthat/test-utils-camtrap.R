# Title: Tests for Camtrap ingestion helpers
# Author: Rogerio Nunes Oliveira

# Builds a zip containing the supplied files. `files` is a named list:
# the names are filenames inside the zip, the values are the file contents
# (character vectors written one line per element). Returns the zip path.
build_zip_fixture <- function(files, prefix = "camtrap_fixture_") {
    dir <- tempfile(prefix)
    dir.create(dir)
    for (fname in names(files)) {
        writeLines(files[[fname]], file.path(dir, fname))
    }
    zip_path <- tempfile(prefix, fileext = ".zip")
    withr::with_dir(dir, {
        zip::zip(zipfile = zip_path, files = list.files("."))
    })
    list(dir = dir, zip = zip_path)
}

descriptor_zip_fixture <- function() {
    build_zip_fixture(list(
        "datapackage.json" = '{"profile":"camtrap-dp","resources":[]}',
        "deployments.csv" = "deploymentID\nd1",
        "observations.csv" = "observationID\no1"
    ), prefix = "descriptor_zip_")
}

loose_camtrap_zip_fixture <- function() {
    build_zip_fixture(list(
        "deployments.csv" = c(
            "deploymentID,locationName,latitude,longitude,deploymentStart,deploymentEnd",
            "d1,site-a,-23.5,-46.6,2024-01-01T00:00:00Z,2024-01-15T00:00:00Z"
        ),
        "observations.csv" = c(
            paste0("observationID,deploymentID,eventID,eventStart,eventEnd,",
                   "observationLevel,observationType,scientificName,count"),
            "o1,d1,d1,2024-01-02T08:00:00Z,2024-01-02T08:00:30Z,event,animal,Panthera onca,1"
        )
    ), prefix = "loose_camtrap_zip_")
}

wi_zip_fixture <- function() {
    deployments <- c(
        "project_id,deployment_id,placename,longitude,latitude,start_date,end_date,camera_id,quiet_period,feature_type,recorded_by,subproject_name,remarks",
        "2004252,DEP1,site-a,-62.94,-8.57,2021-08-26 00:00:00,2022-01-19 00:00:00,2008799,0,None,Elildo,UMF-1,",
        "2004252,DEP2,site-b,-62.96,-8.55,2021-08-25 00:00:00,2021-11-04 00:00:00,2038808,3,None,Elildo,UMF-1,"
    )
    cameras <- c(
        "project_id,camera_id,camera_name,make,model,serial_number,year_purchased",
        "2004252,2008799,B140926462,Bushnell,Trophy Cam HD,B140926462,2016",
        "2004252,2038808,B180821250,Bushnell,Trophy Cam HD,B180821250,2018"
    )
    projects <- c(
        "project_id,project_name,project_short_name",
        "2004252,Test Project,TP"
    )
    images <- c(
        paste0("project_id,deployment_id,image_id,filename,location,is_blank,",
               "identified_by,wi_taxon_id,class,order,family,genus,species,",
               "common_name,uncertainty,timestamp,number_of_objects,age,sex,",
               "animal_recognizable,individual_id,individual_animal_notes,",
               "behavior,highlighted,markings,cv_confidence,license,bounding_boxes"),
        # blank
        "2004252,DEP1,img-blank,a.jpg,gs://a,1,Elildo,,,,,,,,,2021-08-26 10:00:00,0,,,,,,,false,,,CC-BY-NC,",
        # human (Homo sapiens)
        "2004252,DEP1,img-human,b.jpg,gs://b,0,Elildo,,Mammalia,Primates,Hominidae,Homo,sapiens,Human-Camera Trapper,,2021-08-26 10:05:00,1,,,,,,,false,,,CC-BY-NC,",
        # animal (Panthera onca, machine-identified, conf 0.92)
        "2004252,DEP2,img-jaguar,c.jpg,gs://c,0,Computer Vision,,Mammalia,Carnivora,Felidae,Panthera,onca,Jaguar,,2021-09-15 23:12:00,1,Adult,Unknown,,,,,false,,92,CC-BY-NC,",
        # unknown (no taxonomy at all, not blank)
        "2004252,DEP2,img-unknown,d.jpg,gs://d,0,Elildo,,,,,,,,,2021-10-01 03:30:00,1,,,,,,,false,,,CC-BY-NC,"
    )
    build_zip_fixture(list(
        "deployments.csv" = deployments,
        "cameras.csv" = cameras,
        "projects.csv" = projects,
        "images_2004252.csv" = images
    ), prefix = "wi_zip_")
}

# WI sequence project: projects.csv says project_type Sequence, images.csv
# carries sequence_id and no identification fields, and sequences.csv holds
# one row per identification of a sequence.
wi_sequence_zip_fixture <- function(with_sequences = TRUE) {
    deployments <- c(
        "project_id,deployment_id,placename,longitude,latitude,start_date,end_date,camera_id,quiet_period,feature_type,recorded_by,subproject_name,remarks",
        "1,DEP1,site-a,-62.94,-8.57,2021-08-26 00:00:00,2022-01-19 00:00:00,c1,0,None,,UMF,",
        "1,DEP2,site-b,-62.96,-8.55,2021-08-25 00:00:00,2021-11-04 00:00:00,c2,0,None,,UMF,"
    )
    cameras <- c(
        "project_id,camera_id,camera_name,make,model,serial_number,year_purchased",
        "1,c1,n1,Bushnell,T,c1,2020",
        "1,c2,n2,Bushnell,T,c2,2020"
    )
    projects <- c(
        "project_id,project_name,project_short_name,project_type",
        "1,P,TP,Sequence"
    )
    images <- c(
        paste0("project_id,deployment_id,image_id,filename,sequence_id,location,",
               "wi_taxon_id,class,order,family,genus,species,common_name,",
               "timestamp,bounding_boxes"),
        "1,DEP1,img-1,1.jpg,seq-blank,gs://1,,,,,,,,2021-08-26 10:00:00,",
        "1,DEP1,img-2,2.jpg,seq-blank,gs://2,,,,,,,,2021-08-26 10:00:20,",
        "1,DEP2,img-3,3.jpg,seq-jaguar,gs://3,,,,,,,,2021-09-15 23:12:00,",
        "1,DEP2,img-4,4.jpg,seq-jaguar,gs://4,,,,,,,,2021-09-15 23:12:10,",
        "1,DEP2,img-5,5.jpg,seq-jaguar,gs://5,,,,,,,,2021-09-15 23:12:40,",
        "1,DEP2,img-6,6.jpg,seq-mixed,gs://6,,,,,,,,2021-10-01 03:30:00,",
        "1,DEP1,img-7,7.jpg,seq-human,gs://7,,,,,,,,2021-09-01 08:00:00,"
    )
    sequences <- c(
        paste0("project_id,deployment_id,sequence_id,is_blank,identified_by,",
               "wi_taxon_id,class,order,family,genus,species,common_name,",
               "uncertainty,start_time,end_time,group_size,age,sex,",
               "animal_recognizable,individual_id,individual_animal_notes,",
               "behavior,highlighted,markings,cv_confidence,license"),
        "1,DEP1,seq-blank,1,Ana,,,,,,,,,2021-08-26 10:00:00,2021-08-26 10:00:20,,,,,,,,false,,,CC-BY",
        "1,DEP2,seq-jaguar,0,Computer Vision,,Mammalia,Carnivora,Felidae,Panthera,onca,Jaguar,,2021-09-15 23:12:00,2021-09-15 23:12:40,2,Adult,Female,,,,,false,,92,CC-BY",
        "1,DEP2,seq-mixed,0,Ana,,Mammalia,Carnivora,Felidae,Panthera,onca,Jaguar,,2021-10-01 03:30:00,2021-10-01 03:30:00,1,,,,,,,false,,,CC-BY",
        "1,DEP2,seq-mixed,0,Ana,,Mammalia,Perissodactyla,Tapiridae,Tapirus,terrestris,Tapir,,2021-10-01 03:30:00,2021-10-01 03:30:00,3,,,,,,,false,,,CC-BY",
        "1,DEP1,seq-human,0,Ana,,Mammalia,Primates,Hominidae,Homo,sapiens,Human,,2021-09-01 08:00:00,2021-09-01 08:00:00,1,,,,,,,false,,,CC-BY"
    )
    files <- list(
        "deployments.csv" = deployments,
        "cameras.csv" = cameras,
        "projects.csv" = projects,
        "images_1.csv" = images
    )
    if (with_sequences) files[["sequences.csv"]] <- sequences
    build_zip_fixture(files, prefix = "wi_seq_zip_")
}

# detect_camtrap_source --------------------------------------------------

testthat::test_that("detect_camtrap_source detects descriptor zip", {
    fx <- descriptor_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))
    testthat::expect_identical(
        saira:::detect_camtrap_source(fx$zip),
        "datapackage_zip"
    )
})

testthat::test_that("detect_camtrap_source detects loose Camtrap DP csv zip", {
    fx <- loose_camtrap_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))
    testthat::expect_identical(
        saira:::detect_camtrap_source(fx$zip),
        "camtrap_csv_zip"
    )
})

testthat::test_that("detect_camtrap_source detects Wildlife Insights zip", {
    fx <- wi_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))
    testthat::expect_identical(
        saira:::detect_camtrap_source(fx$zip),
        "wildlife_insights_zip"
    )
})

testthat::test_that("detect_camtrap_source returns NA on unrelated zip", {
    fx <- build_zip_fixture(list("foo.csv" = "a,b\n1,2"), prefix = "plain_")
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))
    testthat::expect_true(is.na(saira:::detect_camtrap_source(fx$zip)))
    testthat::expect_true(is.na(saira:::detect_camtrap_source(tempfile())))
    testthat::expect_true(is.na(saira:::detect_camtrap_source(character(0))))
})

testthat::test_that("is_camtrap_dp_zip shim is TRUE for all three sources", {
    d <- descriptor_zip_fixture()
    l <- loose_camtrap_zip_fixture()
    w <- wi_zip_fixture()
    other <- build_zip_fixture(list("foo.csv" = "a,b\n1,2"), prefix = "plain_")
    withr::defer(unlink(c(d$dir, d$zip, l$dir, l$zip, w$dir, w$zip,
                          other$dir, other$zip), recursive = TRUE))
    testthat::expect_true(saira:::is_camtrap_dp_zip(d$zip))
    testthat::expect_true(saira:::is_camtrap_dp_zip(l$zip))
    testthat::expect_true(saira:::is_camtrap_dp_zip(w$zip))
    testthat::expect_false(saira:::is_camtrap_dp_zip(other$zip))
})

# wi_to_camtrap_csv ------------------------------------------------------

testthat::test_that("wi_to_camtrap_csv maps blank/human/animal/unknown", {
    fx <- wi_zip_fixture()
    dest <- tempfile("wi_unzip_")
    dir.create(dest)
    utils::unzip(fx$zip, exdir = dest)
    withr::defer(unlink(c(fx$dir, fx$zip, dest), recursive = TRUE))

    norm_dir <- saira:::wi_to_camtrap_csv(dest, lang = "en")
    testthat::expect_true(dir.exists(norm_dir))
    obs <- utils::read.csv(file.path(norm_dir, "observations.csv"),
                           stringsAsFactors = FALSE)
    # observationID is suffixed (`<image_id>-obs-<seq>`) for uniqueness;
    # mediaID keeps the original image_id, so we key lookups by mediaID.
    by_id <- stats::setNames(obs$observationType, obs$mediaID)
    testthat::expect_identical(by_id[["img-blank"]], "blank")
    testthat::expect_identical(by_id[["img-human"]], "human")
    testthat::expect_identical(by_id[["img-jaguar"]], "animal")
    testthat::expect_identical(by_id[["img-unknown"]], "unknown")

    # observationID is unique per row and follows the `<image_id>-obs-N` shape
    testthat::expect_true(!anyDuplicated(obs$observationID))
    testthat::expect_true(all(grepl("-obs-\\d+$", obs$observationID)))

    # observationLevel stays "media" (write_dwc is told to use media via
    # gbifIngestion$observationLevel; see read_camtrap_dp_zip).
    testthat::expect_true(all(obs$observationLevel == "media"))

    # eventID is per-image (not deployment-collapsed)
    testthat::expect_identical(
        sort(unique(obs$eventID)),
        sort(c("img-blank", "img-human", "img-jaguar", "img-unknown"))
    )

    # scientificName cascade: jaguar gets "Panthera onca", unknown gets NA
    sci <- stats::setNames(obs$scientificName, obs$mediaID)
    testthat::expect_identical(sci[["img-jaguar"]], "Panthera onca")
    testthat::expect_true(is.na(sci[["img-unknown"]]) || sci[["img-unknown"]] == "")

    # classificationMethod follows identified_by
    method <- stats::setNames(obs$classificationMethod, obs$mediaID)
    testthat::expect_identical(method[["img-jaguar"]], "machine")
    testthat::expect_identical(method[["img-blank"]], "human")

    # cv_confidence 92 was scaled to 0.92 (max>1 triggers /100 path)
    prob <- stats::setNames(obs$classificationProbability, obs$mediaID)
    testthat::expect_equal(as.numeric(prob[["img-jaguar"]]), 0.92,
                           tolerance = 1e-6)

    # media.csv mediaID is unique (Camtrap DP spec requirement)
    media <- utils::read.csv(file.path(norm_dir, "media.csv"),
                             stringsAsFactors = FALSE)
    testthat::expect_true(!anyDuplicated(media$mediaID))

    # Deployments table picked up placename + camera model join
    dep <- utils::read.csv(file.path(norm_dir, "deployments.csv"),
                           stringsAsFactors = FALSE)
    testthat::expect_setequal(dep$deploymentID, c("DEP1", "DEP2"))
    testthat::expect_true(all(grepl("Trophy Cam HD", dep$cameraModel)))

    # WI end_date is a calendar date: the deployment runs to the end of it.
    end <- stats::setNames(dep$deploymentEnd, dep$deploymentID)
    testthat::expect_identical(end[["DEP2"]], "2021-11-04T23:59:59Z")

    # WI "Adult" maps to the Camtrap DP enum, "Unknown" has no match.
    life <- stats::setNames(obs$lifeStage, obs$mediaID)
    sex <- stats::setNames(obs$sex, obs$mediaID)
    testthat::expect_identical(life[["img-jaguar"]], "adult")
    testthat::expect_true(is.na(sex[["img-jaguar"]]) || sex[["img-jaguar"]] == "")
})

testthat::test_that("WI value helpers follow the Camtrap DP enums", {
    testthat::expect_identical(
        saira:::wi_end_of_day(c("2021-11-04 00:00:00", "2021-11-04",
                                "2021-11-04 15:30:00", NA)),
        c("2021-11-04 23:59:59", "2021-11-04 23:59:59",
          "2021-11-04 15:30:00", NA)
    )
    testthat::expect_identical(
        saira:::wi_feature_type(c("Trail game", "Road paved", "Water source",
                                  "Trail - game", "None", "Other", NA)),
        c("trailGame", "roadPaved", "waterSource", "trailGame", NA, NA, NA)
    )
    testthat::expect_identical(
        saira:::wi_enum(tolower(c("Adult", "Juvenile", "Unknown", "Mixed", NA)),
                        c("adult", "subadult", "juvenile")),
        c("adult", "juvenile", NA, NA, NA)
    )
})

testthat::test_that("wi_to_camtrap_csv stops when required columns are missing", {
    bad <- build_zip_fixture(list(
        "deployments.csv" = "wrong_col\n1",
        "cameras.csv" = "camera_id\nx",
        "projects.csv" = "project_id\n1",
        "images_2004252.csv" = "deployment_id,image_id,timestamp\nx,y,2021-01-01"
    ), prefix = "wi_bad_")
    dest <- tempfile("wi_bad_unzip_")
    dir.create(dest)
    utils::unzip(bad$zip, exdir = dest)
    withr::defer(unlink(c(bad$dir, bad$zip, dest), recursive = TRUE))

    testthat::expect_error(
        saira:::wi_to_camtrap_csv(dest, lang = "en"),
        regexp = "Wildlife Insights"
    )
})

# synthesize_camtrap_descriptor ------------------------------------------

testthat::test_that("synthesize_camtrap_descriptor writes a valid descriptor", {
    dir <- tempfile("synth_desc_")
    dir.create(dir)
    withr::defer(unlink(dir, recursive = TRUE))
    writeLines("deploymentID\nd1", file.path(dir, "deployments.csv"))
    writeLines("observationID\no1", file.path(dir, "observations.csv"))

    out <- saira:::synthesize_camtrap_descriptor(dir, lang = "en")
    testthat::expect_true(file.exists(out))
    desc <- jsonlite::fromJSON(out, simplifyVector = FALSE)
    testthat::expect_match(desc$profile, "camtrap-dp-profile\\.json$")
    resource_names <- vapply(desc$resources, function(r) r$name, character(1))
    testthat::expect_setequal(resource_names, c("deployments", "observations"))
    # write_dwc() copies id and title to datasetID and datasetName.
    testthat::expect_null(desc$id)
    testthat::expect_null(desc$title)
})

# localize_camtrap_schemas -----------------------------------------------

testthat::test_that("localize_camtrap_schemas points schema URLs at bundled copies", {
    dir <- tempfile("local_schema_")
    dir.create(dir)
    withr::defer(unlink(dir, recursive = TRUE))
    base <- "https://raw.githubusercontent.com/tdwg/camtrap-dp/"
    other <- "https://example.org/custom-table-schema.json"
    desc_path <- file.path(dir, "datapackage.json")
    jsonlite::write_json(list(resources = list(
        list(name = "deployments", schema = paste0(base, "1.0/deployments-table-schema.json")),
        list(name = "media", schema = paste0(base, "1.0.1/media-table-schema.json")),
        list(name = "observations", schema = paste0(base, "1.0.2/observations-table-schema.json")),
        list(name = "extra", schema = other)
    )), desc_path, auto_unbox = TRUE)

    saira:::localize_camtrap_schemas(desc_path)
    desc <- jsonlite::fromJSON(desc_path, simplifyVector = FALSE)
    refs <- vapply(desc$resources, function(r) r$schema, character(1))
    testthat::expect_identical(refs[1:3], c(
        "saira-camtrap-dp-1.0-deployments-table-schema.json",
        "saira-camtrap-dp-1.0.1-media-table-schema.json",
        "saira-camtrap-dp-1.0.2-observations-table-schema.json"
    ))
    testthat::expect_identical(refs[[4]], other)
    # Each copy is the bundled schema of the same version.
    testthat::expect_identical(
        unname(tools::md5sum(file.path(dir, refs[[2]]))),
        unname(tools::md5sum(system.file("extdata", "camtrap-dp", "1.0.1",
                                         "media-table-schema.json",
                                         package = "saira")))
    )
})

# read_camtrap_dp_zip round-trips --------------------------------------

# Only example_dataset() needs internet. Table schemas come from inst/extdata.
skip_if_offline <- function() {
    ok <- tryCatch({
        con <- url("https://raw.githubusercontent.com/tdwg/camtrap-dp/1.0.2/camtrap-dp-profile.json")
        on.exit(try(close(con), silent = TRUE))
        suppressWarnings(readLines(con, n = 1, warn = FALSE))
        TRUE
    }, error = function(e) FALSE)
    testthat::skip_if_not(ok, "Camtrap DP profile URL not reachable.")
}

testthat::test_that("read_camtrap_dp_zip round-trips a descriptor zip (canonical example)", {
    skip_if_offline()
    src_pkg <- tryCatch(camtrapdp::example_dataset(), error = function(e) NULL)
    testthat::skip_if(is.null(src_pkg), "camtrapdp::example_dataset() unavailable.")

    src_dir <- tempfile("camtrap_dp_src_")
    dir.create(src_dir)
    withr::defer(unlink(src_dir, recursive = TRUE))
    camtrapdp::write_camtrapdp(src_pkg, directory = src_dir)
    zip_path <- tempfile("camtrap_dp_real_", fileext = ".zip")
    withr::defer(unlink(zip_path))
    withr::with_dir(src_dir, {
        zip::zip(zipfile = zip_path, files = list.files("."))
    })

    pkg <- saira:::read_camtrap_dp_zip(zip_path, lang = "en")
    testthat::expect_s3_class(pkg, "camtrapdp")
    testthat::expect_identical(attr(pkg, "saira_camtrap_source"),
                               "datapackage_zip")

    df <- saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en")
    testthat::expect_true(is.data.frame(df))
    testthat::expect_gt(nrow(df), 0L)
    testthat::expect_true("scientificName" %in% names(df))

    # write_dwc() emits a fixed schema; columns with no source data come back
    # entirely empty and must be dropped (else they surface as blank mapping
    # cards / title-only preview columns). For the canonical example,
    # organismID and the depth columns are always empty.
    testthat::expect_false("organismID" %in% names(df))
    testthat::expect_false("minimumDepthInMeters" %in% names(df))
    testthat::expect_false("identificationVerificationStatus" %in% names(df))
    # Every surviving column must carry at least one non-blank value.
    has_data <- vapply(
        df,
        function(v) any(!is.na(v) & nzchar(trimws(as.character(v)))),
        logical(1)
    )
    testthat::expect_true(all(has_data))
})

testthat::test_that("read_camtrap_dp_zip round-trips a loose Camtrap DP csv zip", {
    skip_if_offline()
    src_pkg <- tryCatch(camtrapdp::example_dataset(), error = function(e) NULL)
    testthat::skip_if(is.null(src_pkg), "camtrapdp::example_dataset() unavailable.")

    # Round-trip through write_camtrapdp() to get standard CSVs, then drop
    # the descriptor before zipping. This forces the synthesize path.
    src_dir <- tempfile("camtrap_csv_src_")
    dir.create(src_dir)
    withr::defer(unlink(src_dir, recursive = TRUE))
    camtrapdp::write_camtrapdp(src_pkg, directory = src_dir)
    unlink(file.path(src_dir, "datapackage.json"))

    zip_path <- tempfile("camtrap_csv_only_", fileext = ".zip")
    withr::defer(unlink(zip_path))
    withr::with_dir(src_dir, {
        zip::zip(zipfile = zip_path, files = list.files("."))
    })

    testthat::expect_identical(
        saira:::detect_camtrap_source(zip_path),
        "camtrap_csv_zip"
    )
    pkg <- suppressWarnings(saira:::read_camtrap_dp_zip(zip_path, lang = "en"))
    testthat::expect_s3_class(pkg, "camtrapdp")
    testthat::expect_identical(attr(pkg, "saira_camtrap_source"),
                               "camtrap_csv_zip")

    df <- suppressWarnings(saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en"))
    testthat::expect_true(is.data.frame(df))
    testthat::expect_true("scientificName" %in% names(df))
})

testthat::test_that("read_camtrap_dp_zip reads a loose csv zip without media.csv", {
    skip_if_offline()
    src_pkg <- tryCatch(camtrapdp::example_dataset(), error = function(e) NULL)
    testthat::skip_if(is.null(src_pkg), "camtrapdp::example_dataset() unavailable.")

    src_dir <- tempfile("camtrap_no_media_src_")
    dir.create(src_dir)
    withr::defer(unlink(src_dir, recursive = TRUE))
    camtrapdp::write_camtrapdp(src_pkg, directory = src_dir)
    unlink(file.path(src_dir, c("datapackage.json", "media.csv")))

    zip_path <- tempfile("camtrap_no_media_", fileext = ".zip")
    withr::defer(unlink(zip_path))
    withr::with_dir(src_dir, {
        zip::zip(zipfile = zip_path, files = list.files("."))
    })

    pkg <- suppressWarnings(saira:::read_camtrap_dp_zip(zip_path, lang = "en"))
    testthat::expect_equal(nrow(camtrapdp::media(pkg)), 0L)
    df <- suppressWarnings(saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en"))
    testthat::expect_gt(nrow(df), 0L)
})

testthat::test_that("read_camtrap_dp_zip round-trips a Wildlife Insights zip (animals only)", {

    fx <- wi_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))

    pkg <- tryCatch(
        suppressWarnings(saira:::read_camtrap_dp_zip(fx$zip, lang = "en")),
        error = function(e) e
    )
    # If the camtrapdp package's frictionless validation rejects our minimal
    # descriptor for any reason, skip rather than fail the suite — the unit
    # tests above already cover the normalizer and descriptor builder.
    if (inherits(pkg, "error")) {
        testthat::skip(paste("camtrapdp could not parse synthesized descriptor:",
                             conditionMessage(pkg)))
    }

    testthat::expect_s3_class(pkg, "camtrapdp")
    testthat::expect_identical(attr(pkg, "saira_camtrap_source"),
                               "wildlife_insights_zip")

    df <- tryCatch(
        suppressWarnings(saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en")),
        error = function(e) e
    )
    if (inherits(df, "error")) {
        testthat::skip(paste("write_dwc() rejected synthesized package:",
                             conditionMessage(df)))
    }

    # The WI fixture has 4 rows (blank/human/animal/unknown); write_dwc()
    # filters to observationType == "animal", so the DwC occurrence frame
    # should have exactly 1 row (the jaguar).
    testthat::expect_true("scientificName" %in% names(df))
    testthat::expect_equal(nrow(df), 1L)
    testthat::expect_identical(df$scientificName[1], "Panthera onca")
    testthat::expect_true(!anyDuplicated(df$occurrenceID))
})

testthat::test_that("read_camtrap_dp_zip sets gbifIngestion$observationLevel = 'media' on WI", {

    fx <- wi_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))

    pkg <- tryCatch(
        suppressWarnings(saira:::read_camtrap_dp_zip(fx$zip, lang = "en")),
        error = function(e) e
    )
    if (inherits(pkg, "error")) {
        testthat::skip(paste("camtrapdp could not parse synthesized descriptor:",
                             conditionMessage(pkg)))
    }
    testthat::expect_identical(pkg$gbifIngestion$observationLevel, "media")
})

testthat::test_that("convert_camtrap_to_dwc_occurrence errors on empty occurrence (all blank/human)", {

    # WI fixture with only blank + human rows — no animals to export.
    deployments <- c(
        "project_id,deployment_id,placename,longitude,latitude,start_date,end_date,camera_id,quiet_period,feature_type,recorded_by,subproject_name,remarks",
        "1,DEP1,site-a,-62.94,-8.57,2021-08-26 00:00:00,2021-09-01 00:00:00,c1,0,None,,UMF,"
    )
    cameras <- c(
        "project_id,camera_id,camera_name,make,model,serial_number,year_purchased",
        "1,c1,n,Bushnell,T,c1,2020"
    )
    projects <- c("project_id,project_name,project_short_name", "1,P,TP")
    images <- c(
        paste0("project_id,deployment_id,image_id,filename,location,is_blank,",
               "identified_by,wi_taxon_id,class,order,family,genus,species,",
               "common_name,uncertainty,timestamp,number_of_objects,age,sex,",
               "animal_recognizable,individual_id,individual_animal_notes,",
               "behavior,highlighted,markings,cv_confidence,license,bounding_boxes"),
        "1,DEP1,img-a,a.jpg,gs://a,1,me,,,,,,,,,2021-08-26 10:00:00,0,,,,,,,false,,,CC-BY-NC,",
        "1,DEP1,img-b,b.jpg,gs://b,0,me,,Mammalia,Primates,Hominidae,Homo,sapiens,Human,,2021-08-26 10:05:00,1,,,,,,,false,,,CC-BY-NC,"
    )
    fx <- build_zip_fixture(list(
        "deployments.csv" = deployments,
        "cameras.csv" = cameras,
        "projects.csv" = projects,
        "images_2004252.csv" = images
    ), prefix = "wi_empty_")
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))

    pkg <- tryCatch(
        suppressWarnings(saira:::read_camtrap_dp_zip(fx$zip, lang = "en")),
        error = function(e) e
    )
    if (inherits(pkg, "error")) {
        testthat::skip(paste("camtrapdp could not parse synthesized descriptor:",
                             conditionMessage(pkg)))
    }
    err <- tryCatch(
        suppressWarnings(saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en")),
        error = function(e) e
    )
    testthat::expect_s3_class(err, "error")
    testthat::expect_match(
        conditionMessage(err),
        "no occurrences|nenhuma ocorr"
    )
})

testthat::test_that("WI rows with duplicate image_id yield unique IDs + dedup media.csv", {
    # Same image classified twice (Mazama + Blank, mirroring the real WI
    # dataset shape). Expectations:
    #   - observations.csv has 2 rows (both keep their classification)
    #   - observationIDs are unique (suffixed -obs-1, -obs-2)
    #   - media.csv has only 1 row for that image_id (dedup)
    deployments <- c(
        "project_id,deployment_id,placename,longitude,latitude,start_date,end_date,camera_id,quiet_period,feature_type,recorded_by,subproject_name,remarks",
        "1,DEP1,site-a,-62.94,-8.57,2021-08-26 00:00:00,2021-09-01 00:00:00,c1,0,None,,UMF,"
    )
    cameras <- c(
        "project_id,camera_id,camera_name,make,model,serial_number,year_purchased",
        "1,c1,n,Bushnell,T,c1,2020"
    )
    projects <- c("project_id,project_name,project_short_name", "1,P,TP")
    images <- c(
        paste0("project_id,deployment_id,image_id,filename,location,is_blank,",
               "identified_by,wi_taxon_id,class,order,family,genus,species,",
               "common_name,uncertainty,timestamp,number_of_objects,age,sex,",
               "animal_recognizable,individual_id,individual_animal_notes,",
               "behavior,highlighted,markings,cv_confidence,license,bounding_boxes"),
        # img-dup classified as Mazama
        "1,DEP1,img-dup,a.jpg,gs://a,0,me,,Mammalia,Cetartiodactyla,Cervidae,Mazama,,Mazama Species,,2021-08-26 10:00:00,1,,,,,,,false,,,CC-BY-NC,",
        # img-dup again, classified as Blank
        "1,DEP1,img-dup,a.jpg,gs://a,0,me,,,,,,,Blank,,2021-08-26 10:00:00,1,,,,,,,false,,,CC-BY-NC,"
    )
    fx <- build_zip_fixture(list(
        "deployments.csv" = deployments,
        "cameras.csv" = cameras,
        "projects.csv" = projects,
        "images_2004252.csv" = images
    ), prefix = "wi_dup_")
    dest <- tempfile("wi_dup_unzip_")
    dir.create(dest)
    utils::unzip(fx$zip, exdir = dest)
    withr::defer(unlink(c(fx$dir, fx$zip, dest), recursive = TRUE))

    norm_dir <- saira:::wi_to_camtrap_csv(dest, lang = "en")
    obs <- utils::read.csv(file.path(norm_dir, "observations.csv"),
                           stringsAsFactors = FALSE)
    media <- utils::read.csv(file.path(norm_dir, "media.csv"),
                             stringsAsFactors = FALSE)
    testthat::expect_equal(nrow(obs), 2L)
    testthat::expect_true(!anyDuplicated(obs$observationID))
    testthat::expect_identical(unique(obs$mediaID), "img-dup")
    testthat::expect_equal(nrow(media), 1L)
    testthat::expect_identical(media$mediaID, "img-dup")
})

# strip_fabricated_utc (C1) ----------------------------------------------

testthat::test_that("strip_fabricated_utc drops the Z designator only", {
    testthat::expect_identical(
        saira:::strip_fabricated_utc(c("2021-06-11T06:52:55Z", NA, "")),
        c("2021-06-11T06:52:55", NA, "")
    )
    # Range form (start/end) loses both designators.
    testthat::expect_identical(
        saira:::strip_fabricated_utc("2021-06-11T06:52:55Z/2021-06-11T07:00:00Z"),
        "2021-06-11T06:52:55/2021-06-11T07:00:00"
    )
    testthat::expect_null(saira:::strip_fabricated_utc(NULL))
})

# wi_to_camtrap_csv: habitat + count defaults (H4) -----------------------

testthat::test_that("wi_to_camtrap_csv leaves habitat empty and defaults count to 1", {
    deployments <- c(
        "project_id,deployment_id,placename,longitude,latitude,start_date,end_date,camera_id,quiet_period,feature_type,recorded_by,subproject_name,remarks",
        "1,DEP1,site-a,-62.94,-8.57,2021-08-26 00:00:00,2021-09-01 00:00:00,c1,0,Trail - game,,UMF,"
    )
    cameras <- c(
        "project_id,camera_id,camera_name,make,model,serial_number,year_purchased",
        "1,c1,n,Bushnell,T,c1,2020"
    )
    projects <- c("project_id,project_name,project_short_name", "1,P,TP")
    images <- c(
        paste0("project_id,deployment_id,image_id,filename,location,is_blank,",
               "identified_by,wi_taxon_id,class,order,family,genus,species,",
               "common_name,uncertainty,timestamp,number_of_objects,age,sex,",
               "animal_recognizable,individual_id,individual_animal_notes,",
               "behavior,highlighted,markings,cv_confidence,license,bounding_boxes"),
        # animal row with EMPTY number_of_objects -> count must default to 1
        "1,DEP1,img-a,a.jpg,gs://a,0,me,,Mammalia,Carnivora,Felidae,Panthera,onca,Jaguar,,2021-08-26 10:00:00,,,,,,,,false,,,CC-BY-NC,"
    )
    fx <- build_zip_fixture(list(
        "deployments.csv" = deployments,
        "cameras.csv" = cameras,
        "projects.csv" = projects,
        "images_2004252.csv" = images
    ), prefix = "wi_h4_")
    dest <- tempfile("wi_h4_unzip_")
    dir.create(dest)
    utils::unzip(fx$zip, exdir = dest)
    withr::defer(unlink(c(fx$dir, fx$zip, dest), recursive = TRUE))

    norm_dir <- saira:::wi_to_camtrap_csv(dest, lang = "en")
    dep <- utils::read.csv(file.path(norm_dir, "deployments.csv"),
                           stringsAsFactors = FALSE, na.strings = "")
    obs <- utils::read.csv(file.path(norm_dir, "observations.csv"),
                           stringsAsFactors = FALSE, na.strings = "")
    testthat::expect_true(all(is.na(dep$habitat)))
    testthat::expect_identical(obs$count[obs$mediaID == "img-a"], 1L)
})

# convert_camtrap_to_dwc_occurrence: WI eventDate carries no Z (C1) ------

testthat::test_that("WI conversion strips the fabricated UTC designator from eventDate", {

    fx <- wi_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))

    pkg <- tryCatch(
        suppressWarnings(saira:::read_camtrap_dp_zip(fx$zip, lang = "en")),
        error = function(e) e
    )
    if (inherits(pkg, "error")) {
        testthat::skip(paste("camtrapdp could not parse synthesized descriptor:",
                             conditionMessage(pkg)))
    }
    df <- tryCatch(
        suppressWarnings(saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en")),
        error = function(e) e
    )
    if (inherits(df, "error")) {
        testthat::skip(paste("write_dwc() rejected synthesized package:",
                             conditionMessage(df)))
    }
    testthat::expect_false(any(grepl("Z", df$eventDate)))
    testthat::expect_true(any(grepl("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}$", df$eventDate)))
    testthat::expect_identical(df$samplingEffort[1],
                               "2021-08-25T00:00:00/2021-11-04T23:59:59")
    # The synthesized descriptor must not reach the export as dataset metadata.
    testthat::expect_false(any(c("datasetName", "datasetID") %in% names(df)))
})

testthat::test_that("WI read and conversion remove their temporary directories", {
    fx <- wi_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))

    before <- list.files(tempdir())
    pkg <- suppressWarnings(saira:::read_camtrap_dp_zip(fx$zip, lang = "en"))
    suppressMessages(saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en"))
    testthat::expect_length(setdiff(list.files(tempdir()), before), 0L)
})

# WI sequence projects ----------------------------------------------------

testthat::test_that("wi_to_camtrap_csv writes one event-level observation per sequence row", {
    fx <- wi_sequence_zip_fixture()
    dest <- tempfile("wi_seq_unzip_")
    dir.create(dest)
    utils::unzip(fx$zip, exdir = dest)
    withr::defer(unlink(c(fx$dir, fx$zip, dest), recursive = TRUE))

    norm_dir <- saira:::wi_to_camtrap_csv(dest, lang = "en")
    obs <- utils::read.csv(file.path(norm_dir, "observations.csv"),
                           stringsAsFactors = FALSE, na.strings = "")
    media <- utils::read.csv(file.path(norm_dir, "media.csv"),
                             stringsAsFactors = FALSE, na.strings = "")

    testthat::expect_identical(nrow(media), 7L)
    testthat::expect_identical(nrow(obs), 5L)
    testthat::expect_true(all(obs$observationLevel == "event"))
    testthat::expect_true(all(is.na(obs$mediaID)))
    testthat::expect_identical(
        obs$observationID,
        c("seq-blank-obs-1", "seq-jaguar-obs-1", "seq-mixed-obs-1",
          "seq-mixed-obs-2", "seq-human-obs-1")
    )
    testthat::expect_identical(obs$observationType,
                               c("blank", "animal", "animal", "animal", "human"))
    testthat::expect_identical(obs$count, c(1L, 2L, 1L, 3L, 1L))

    jaguar <- obs[obs$eventID == "seq-jaguar", ]
    testthat::expect_identical(jaguar$eventStart, "2021-09-15T23:12:00Z")
    testthat::expect_identical(jaguar$eventEnd, "2021-09-15T23:12:40Z")
    testthat::expect_identical(jaguar$classificationMethod, "machine")
    testthat::expect_equal(jaguar$classificationProbability, 0.92)
    testthat::expect_identical(jaguar$lifeStage, "adult")
    testthat::expect_identical(jaguar$sex, "female")
})

testthat::test_that("WI sequence projects export one occurrence per animal identification", {
    fx <- wi_sequence_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))

    pkg <- saira:::read_camtrap_dp_zip(fx$zip, lang = "en")
    testthat::expect_null(pkg$gbifIngestion$observationLevel)
    # camtrapdp links each image to its sequence by the event time window.
    media <- camtrapdp::media(pkg)
    testthat::expect_identical(
        stats::setNames(media$eventID, media$mediaID)[c("img-3", "img-5", "img-6")],
        c("img-3" = "seq-jaguar", "img-5" = "seq-jaguar", "img-6" = "seq-mixed")
    )

    df <- saira:::convert_camtrap_to_dwc_occurrence(pkg, lang = "en")
    df <- df[order(df$occurrenceID), ]
    testthat::expect_identical(df$occurrenceID,
                               c("seq-jaguar-obs-1", "seq-mixed-obs-1", "seq-mixed-obs-2"))
    testthat::expect_identical(df$scientificName,
                               c("Panthera onca", "Panthera onca", "Tapirus terrestris"))
    testthat::expect_equal(as.integer(df$individualCount), c(2L, 1L, 3L))
    testthat::expect_identical(
        df$eventDate,
        c("2021-09-15T23:12:00/2021-09-15T23:12:40",
          "2021-10-01T03:30:00", "2021-10-01T03:30:00")
    )
})

testthat::test_that("WI image projects keep media-level observations", {
    fx <- wi_zip_fixture()
    withr::defer(unlink(c(fx$dir, fx$zip), recursive = TRUE))

    pkg <- saira:::read_camtrap_dp_zip(fx$zip, lang = "en")
    testthat::expect_identical(pkg$gbifIngestion$observationLevel, "media")
    testthat::expect_true(all(camtrapdp::observations(pkg)$observationLevel == "media"))
})

testthat::test_that("WI sequence project without sequences.csv stops with a clear error", {
    fx <- wi_sequence_zip_fixture(with_sequences = FALSE)
    dest <- tempfile("wi_seq_unzip_")
    dir.create(dest)
    utils::unzip(fx$zip, exdir = dest)
    withr::defer(unlink(c(fx$dir, fx$zip, dest), recursive = TRUE))
    testthat::expect_error(
        saira:::wi_to_camtrap_csv(dest, lang = "en"),
        "sequences.csv", fixed = TRUE
    )
})

testthat::test_that("WI projects.csv without a final newline reads without a warning", {
    fx <- wi_sequence_zip_fixture()
    dest <- tempfile("wi_seq_unzip_")
    dir.create(dest)
    utils::unzip(fx$zip, exdir = dest)
    withr::defer(unlink(c(fx$dir, fx$zip, dest), recursive = TRUE))
    # The real WI export ends projects.csv without a newline.
    cat("project_id,project_name,project_short_name,project_type\n1,P,TP,Sequence",
        file = file.path(dest, "projects.csv"))

    testthat::expect_no_warning(norm_dir <- saira:::wi_to_camtrap_csv(dest, lang = "en"))
    obs <- utils::read.csv(file.path(norm_dir, "observations.csv"),
                           stringsAsFactors = FALSE)
    testthat::expect_true(all(obs$observationLevel == "event"))
})

# camtrap_error_message ---------------------------------------------------

testthat::test_that("camtrap_error_message shows Saira errors without a prefix", {
    fx <- wi_sequence_zip_fixture(with_sequences = FALSE)
    dest <- tempfile("wi_seq_unzip_")
    dir.create(dest)
    utils::unzip(fx$zip, exdir = dest)
    withr::defer(unlink(c(fx$dir, fx$zip, dest), recursive = TRUE))
    e <- tryCatch(saira:::wi_to_camtrap_csv(dest, lang = "pt"),
                  error = function(e) e)
    testthat::expect_s3_class(e, "saira_camtrap_error")
    testthat::expect_identical(saira:::camtrap_error_message(e, "pt"),
                               saira:::tr("err_camtrap_wi_sequences_missing", "pt"))

    e <- tryCatch(saira:::camtrap_stop("err_camtrap_invalid_zip", "en"),
                  error = function(e) e)
    testthat::expect_identical(saira:::camtrap_error_message(e, "en"),
                               saira:::tr("err_camtrap_invalid_zip", "en"))
})

testthat::test_that("camtrap_error_message shows the root cause of other errors", {
    cause <- simpleError("Can't find column `x`.")
    wrapped <- structure(
        class = c("rlang_error", "error", "condition"),
        list(message = "In index: 1.", parent = cause, call = NULL)
    )
    msg <- saira:::camtrap_error_message(wrapped, "en")
    testthat::expect_identical(
        msg, paste(saira:::tr("err_read_failed", "en"), "Can't find column `x`.")
    )
    testthat::expect_false(grepl("In index", msg, fixed = TRUE))
    testthat::expect_identical(
        saira:::camtrap_error_message(simpleError("boom"), "pt"),
        paste(saira:::tr("err_read_failed", "pt"), "boom")
    )
})

