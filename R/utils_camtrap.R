# Title: Camtrap ingestion helpers
# Author: Rogerio Nunes Oliveira
#
# Detects three flavors of camera-trap upload and normalizes them so the
# `camtrapdp` package's `read_camtrapdp()` + `write_dwc()` pipeline produces a
# flat Darwin Core Occurrence data.frame for the standard mapping flow:
#   - "datapackage_zip"        : Frictionless Camtrap DP (zip + datapackage.json)
#   - "camtrap_csv_zip"        : Loose Camtrap DP CSVs (deployments + observations
#                                + optional media), no descriptor; we synthesize one
#   - "wildlife_insights_zip"  : Wildlife Insights export; columns are renamed
#                                to Camtrap DP shape, then synthesized descriptor
#
# `camtrapdp` is a Suggests dependency; all entry points check at runtime.

# --- Source detection ---------------------------------------------------

detect_camtrap_source <- function(path) {
    if (!is.character(path) || length(path) != 1L || !file.exists(path)) {
        return(NA_character_)
    }
    listing <- tryCatch(
        utils::unzip(path, list = TRUE),
        error = function(e) NULL,
        warning = function(w) NULL
    )
    if (!is.data.frame(listing) || nrow(listing) == 0L) {
        return(NA_character_)
    }
    base_names <- tolower(basename(as.character(listing$Name)))
    if ("datapackage.json" %in% base_names) {
        return("datapackage_zip")
    }
    has_deployments <- "deployments.csv" %in% base_names
    has_observations <- "observations.csv" %in% base_names
    if (has_deployments && has_observations) {
        return("camtrap_csv_zip")
    }
    has_projects <- "projects.csv" %in% base_names
    has_images <- any(grepl("^images.*\\.csv$", base_names))
    if (has_deployments && has_projects && has_images) {
        return("wildlife_insights_zip")
    }
    NA_character_
}

# Back-compat shim: any of the three sources is "valid camtrap input".
is_camtrap_dp_zip <- function(path) {
    !is.na(detect_camtrap_source(path))
}

# --- Optional package guard ---------------------------------------------

require_camtrapdp <- function(lang = "en") {
    if (!requireNamespace("camtrapdp", quietly = TRUE)) {
        stop(tr("err_camtrap_pkg_missing", lang), call. = FALSE)
    }
    invisible(TRUE)
}

# --- Wildlife Insights → Camtrap DP normalizer --------------------------

WI_REQUIRED_DEP_COLS <- c(
    "deployment_id", "latitude", "longitude", "start_date", "end_date"
)
WI_REQUIRED_IMG_COLS <- c("deployment_id", "image_id", "timestamp")

wi_read_csv <- function(path) {
    utils::read.csv(
        path,
        stringsAsFactors = FALSE,
        na.strings = c("", "NA"),
        check.names = FALSE,
        encoding = "UTF-8"
    )
}

# Parse WI timestamps ("YYYY-MM-DD HH:MM:SS", "YYYY-MM-DD", etc.) into ISO 8601
# UTC strings. Returns NA for unparseable values without warning.
wi_parse_timestamp <- function(x) {
    if (length(x) == 0L) return(character(0))
    x <- as.character(x)
    out <- rep(NA_character_, length(x))
    fmts <- c("%Y-%m-%d %H:%M:%S", "%Y-%m-%dT%H:%M:%S",
              "%Y-%m-%d %H:%M", "%Y-%m-%d")
    for (f in fmts) {
        idx <- which(is.na(out) & !is.na(x) & nzchar(x))
        if (length(idx) == 0L) next
        parsed <- suppressWarnings(as.POSIXct(x[idx], format = f, tz = "UTC"))
        ok <- !is.na(parsed)
        out[idx[ok]] <- format(parsed[ok], "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    }
    out
}

wi_derive_observation_type <- function(is_blank, class, order, family,
                                       genus, species, common_name) {
    n <- length(is_blank)
    out <- character(n)
    blank_mask <- !is.na(is_blank) & (
        is_blank %in% c(1L, "1", "true", "TRUE", TRUE)
    )
    out[blank_mask] <- "blank"
    human_mask <- out == "" & !is.na(genus) & genus == "Homo"
    out[human_mask] <- "human"
    vehicle_mask <- out == "" & (
        (!is.na(class) & class == "Vehicle") |
        (!is.na(common_name) & grepl("[Vv]ehicle", common_name))
    )
    out[vehicle_mask] <- "vehicle"
    taxonomy_blank <-
        (is.na(class) | class == "") &
        (is.na(order) | order == "") &
        (is.na(family) | family == "") &
        (is.na(genus) | genus == "") &
        (is.na(species) | species == "")
    out[out == "" & taxonomy_blank] <- "unknown"
    out[out == ""] <- "animal"
    out
}

wi_build_scientific_name <- function(genus, species, family, order, class) {
    n <- length(genus)
    out <- rep(NA_character_, n)
    has_g <- !is.na(genus) & genus != ""
    has_s <- !is.na(species) & species != ""
    out[has_g & has_s] <- paste(genus[has_g & has_s], species[has_g & has_s])
    fill <- is.na(out) & has_g
    out[fill] <- genus[fill]
    fill <- is.na(out) & !is.na(family) & family != ""
    out[fill] <- family[fill]
    fill <- is.na(out) & !is.na(order) & order != ""
    out[fill] <- order[fill]
    fill <- is.na(out) & !is.na(class) & class != ""
    out[fill] <- class[fill]
    out
}

# Reads WI CSVs from `input_dir`, writes deployments/media/observations CSVs
# in Camtrap DP shape under `<input_dir>/_camtrap_normalized`, returns the
# normalized directory.
wi_to_camtrap_csv <- function(input_dir, lang = "en") {
    dep_paths <- list.files(input_dir, pattern = "^deployments\\.csv$",
                            recursive = TRUE, full.names = TRUE,
                            ignore.case = TRUE)
    cam_paths <- list.files(input_dir, pattern = "^cameras\\.csv$",
                            recursive = TRUE, full.names = TRUE,
                            ignore.case = TRUE)
    img_paths <- list.files(input_dir, pattern = "^images.*\\.csv$",
                            recursive = TRUE, full.names = TRUE,
                            ignore.case = TRUE)

    if (length(dep_paths) == 0L || length(img_paths) == 0L) {
        stop(tr("err_camtrap_wi_columns_missing", lang), call. = FALSE)
    }
    wi_dep <- wi_read_csv(dep_paths[1])
    wi_img <- wi_read_csv(img_paths[1])
    wi_cam <- if (length(cam_paths) > 0L) wi_read_csv(cam_paths[1]) else NULL

    missing_dep <- setdiff(WI_REQUIRED_DEP_COLS, names(wi_dep))
    missing_img <- setdiff(WI_REQUIRED_IMG_COLS, names(wi_img))
    if (length(missing_dep) > 0L || length(missing_img) > 0L) {
        stop(tr("err_camtrap_wi_columns_missing", lang), call. = FALSE)
    }

    out_dir <- file.path(input_dir, "_camtrap_normalized")
    if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

    # deployments.csv ----------------------------------------------------
    cam_lookup <- character(0)
    if (!is.null(wi_cam) && all(c("camera_id", "model") %in% names(wi_cam))) {
        make <- if ("make" %in% names(wi_cam)) wi_cam$make else rep("", nrow(wi_cam))
        make[is.na(make)] <- ""
        model <- wi_cam$model
        model[is.na(model)] <- ""
        cam_lookup <- stats::setNames(
            trimws(paste(make, model)),
            as.character(wi_cam$camera_id)
        )
    }
    pick <- function(df, name, default = NA) {
        if (name %in% names(df)) df[[name]] else rep(default, nrow(df))
    }
    n_dep <- nrow(wi_dep)
    dep <- data.frame(
        deploymentID = as.character(wi_dep$deployment_id),
        locationID = rep(NA_character_, n_dep),
        locationName = pick(wi_dep, "placename", NA_character_),
        latitude = suppressWarnings(as.numeric(wi_dep$latitude)),
        longitude = suppressWarnings(as.numeric(wi_dep$longitude)),
        coordinateUncertainty = rep(NA_real_, n_dep),
        deploymentStart = wi_parse_timestamp(wi_dep$start_date),
        deploymentEnd = wi_parse_timestamp(wi_dep$end_date),
        setupBy = pick(wi_dep, "recorded_by", NA_character_),
        cameraID = as.character(pick(wi_dep, "camera_id", NA)),
        cameraModel = unname(cam_lookup[as.character(pick(wi_dep, "camera_id", NA))]),
        cameraDelay = suppressWarnings(as.integer(pick(wi_dep, "quiet_period", NA))),
        cameraHeight = rep(NA_real_, n_dep),
        cameraDepth = rep(NA_real_, n_dep),
        cameraTilt = rep(NA_integer_, n_dep),
        cameraHeading = rep(NA_integer_, n_dep),
        detectionDistance = rep(NA_real_, n_dep),
        timestampIssues = rep(FALSE, n_dep),
        baitUse = rep(NA_character_, n_dep),
        featureType = pick(wi_dep, "feature_type", NA_character_),
        habitat = pick(wi_dep, "feature_type", NA_character_),
        deploymentGroups = pick(wi_dep, "subproject_name", NA_character_),
        deploymentTags = rep(NA_character_, n_dep),
        deploymentComments = pick(wi_dep, "remarks", NA_character_),
        stringsAsFactors = FALSE
    )
    utils::write.csv(dep, file.path(out_dir, "deployments.csv"),
                     row.names = FALSE, na = "", fileEncoding = "UTF-8")

    # media.csv ----------------------------------------------------------
    # WI permite múltiplas linhas por image_id (mesma imagem com várias
    # identificações). A spec Camtrap DP exige mediaID único, então
    # deduplicamos pela primeira ocorrência de cada image_id.
    wi_img_media <- wi_img[!duplicated(wi_img$image_id), , drop = FALSE]
    highlighted_media <- if ("highlighted" %in% names(wi_img_media)) {
        wi_img_media$highlighted
    } else {
        rep(FALSE, nrow(wi_img_media))
    }
    fav <- tolower(as.character(highlighted_media)) %in% c("true", "1", "t")
    n_media <- nrow(wi_img_media)
    pick_media <- function(name, default = NA) {
        if (name %in% names(wi_img_media)) wi_img_media[[name]] else rep(default, n_media)
    }
    media <- data.frame(
        mediaID = as.character(wi_img_media$image_id),
        deploymentID = as.character(wi_img_media$deployment_id),
        captureMethod = rep("activityDetection", n_media),
        timestamp = wi_parse_timestamp(wi_img_media$timestamp),
        filePath = pick_media("location", NA_character_),
        filePublic = rep(TRUE, n_media),
        fileName = pick_media("filename", NA_character_),
        fileMediatype = rep("image/jpeg", n_media),
        exifData = rep(NA_character_, n_media),
        favorite = fav,
        mediaComments = rep(NA_character_, n_media),
        stringsAsFactors = FALSE
    )
    utils::write.csv(media, file.path(out_dir, "media.csv"),
                     row.names = FALSE, na = "", fileEncoding = "UTF-8")

    # observations.csv ---------------------------------------------------
    n_img <- nrow(wi_img)
    obs_type <- wi_derive_observation_type(
        is_blank = pick(wi_img, "is_blank"),
        class = pick(wi_img, "class"),
        order = pick(wi_img, "order"),
        family = pick(wi_img, "family"),
        genus = pick(wi_img, "genus"),
        species = pick(wi_img, "species"),
        common_name = pick(wi_img, "common_name")
    )
    sci_name <- wi_build_scientific_name(
        genus = pick(wi_img, "genus"),
        species = pick(wi_img, "species"),
        family = pick(wi_img, "family"),
        order = pick(wi_img, "order"),
        class = pick(wi_img, "class")
    )
    cv_conf <- suppressWarnings(as.numeric(pick(wi_img, "cv_confidence")))
    if (any(!is.na(cv_conf)) && max(cv_conf, na.rm = TRUE) > 1) {
        cv_conf <- cv_conf / 100
    }
    method <- ifelse(
        !is.na(pick(wi_img, "identified_by")) &
            pick(wi_img, "identified_by") == "Computer Vision",
        "machine", "human"
    )
    ts_iso <- wi_parse_timestamp(wi_img$timestamp)
    # observationID precisa ser único por linha. Para imagens com múltiplas
    # identificações WI, sufixamos seq dentro do mesmo image_id: img-1, img-2.
    image_id_chr <- as.character(wi_img$image_id)
    within_image_seq <- stats::ave(seq_along(image_id_chr), image_id_chr, FUN = seq_along)
    observation_id <- paste0(image_id_chr, "-obs-", within_image_seq)
    obs <- data.frame(
        observationID = observation_id,
        deploymentID = as.character(wi_img$deployment_id),
        mediaID = image_id_chr,
        # eventID = image_id (cada imagem é um evento de detecção). Linhas com
        # múltiplas identificações na mesma imagem compartilham eventID.
        eventID = image_id_chr,
        eventStart = ts_iso,
        eventEnd = ts_iso,
        observationLevel = rep("media", n_img),
        observationType = obs_type,
        cameraSetupType = rep(NA_character_, n_img),
        scientificName = sci_name,
        count = suppressWarnings(as.integer(pick(wi_img, "number_of_objects", 1L))),
        lifeStage = tolower(as.character(pick(wi_img, "age", NA))),
        sex = tolower(as.character(pick(wi_img, "sex", NA))),
        behavior = pick(wi_img, "behavior", NA_character_),
        individualID = pick(wi_img, "individual_id", NA_character_),
        individualPositionRadius = rep(NA_real_, n_img),
        individualPositionAngle = rep(NA_real_, n_img),
        individualSpeed = rep(NA_real_, n_img),
        bboxX = rep(NA_real_, n_img),
        bboxY = rep(NA_real_, n_img),
        bboxWidth = rep(NA_real_, n_img),
        bboxHeight = rep(NA_real_, n_img),
        classificationMethod = method,
        classifiedBy = pick(wi_img, "identified_by", NA_character_),
        classificationTimestamp = rep(NA_character_, n_img),
        classificationProbability = cv_conf,
        observationTags = rep(NA_character_, n_img),
        observationComments = pick(wi_img, "individual_animal_notes", NA_character_),
        stringsAsFactors = FALSE
    )
    utils::write.csv(obs, file.path(out_dir, "observations.csv"),
                     row.names = FALSE, na = "", fileEncoding = "UTF-8")

    invisible(out_dir)
}

# --- Synthetic Frictionless descriptor ----------------------------------

# Writes a minimal datapackage.json into `dir` so camtrapdp::read_camtrapdp()
# can parse a loose-CSV bundle. Targets Camtrap DP 1.0.2 (latest supported per
# the camtrapdp PDF page 17). Resources reference whichever of
# deployments.csv / media.csv / observations.csv exist in `dir`.
synthesize_camtrap_descriptor <- function(dir, lang = "en") {
    csvs <- tolower(list.files(dir, pattern = "\\.csv$", full.names = FALSE,
                               recursive = FALSE, ignore.case = TRUE))
    resource_files <- list(
        deployments = "deployments.csv",
        media = "media.csv",
        observations = "observations.csv"
    )
    resources <- lapply(names(resource_files), function(rname) {
        fname <- resource_files[[rname]]
        if (!fname %in% csvs) return(NULL)
        list(
            name = rname,
            path = fname,
            profile = "tabular-data-resource",
            format = "csv",
            mediatype = "text/csv",
            encoding = "utf-8",
            schema = sprintf(
                "https://raw.githubusercontent.com/tdwg/camtrap-dp/1.0.2/%s-table-schema.json",
                rname
            )
        )
    })
    resources <- Filter(Negate(is.null), resources)
    if (length(resources) == 0L) {
        stop(tr("err_camtrap_invalid_zip", lang), call. = FALSE)
    }
    descriptor <- list(
        profile = "https://raw.githubusercontent.com/tdwg/camtrap-dp/1.0.2/camtrap-dp-profile.json",
        name = paste0("saira-ingest-",
                      format(Sys.time(), "%Y%m%d%H%M%S", tz = "UTC")),
        id = paste0("urn:uuid:", ids::random_id(bytes = 16)),
        title = "Saira-generated Camtrap DP descriptor",
        created = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        version = "1.0",
        resources = resources
    )
    out_path <- file.path(dir, "datapackage.json")
    jsonlite::write_json(descriptor, out_path,
                         auto_unbox = TRUE, pretty = TRUE)
    invisible(out_path)
}

# --- Root discovery after unzip -----------------------------------------

find_csv_root <- function(dest, signature_predicate) {
    dep_files <- list.files(dest, pattern = "^deployments\\.csv$",
                            recursive = TRUE, full.names = TRUE,
                            ignore.case = TRUE)
    for (f in dep_files) {
        d <- dirname(f)
        siblings <- tolower(list.files(d))
        if (signature_predicate(siblings)) return(d)
    }
    NA_character_
}

# --- Read + dispatch ----------------------------------------------------

read_camtrap_dp_zip <- function(path, lang = "en") {
    require_camtrapdp(lang)
    source <- detect_camtrap_source(path)
    if (is.na(source)) {
        stop(tr("err_camtrap_invalid_zip", lang), call. = FALSE)
    }

    dest <- tempfile("camtrapdp_")
    dir.create(dest)
    utils::unzip(path, exdir = dest)

    if (source == "datapackage_zip") {
        descriptor <- list.files(
            dest, pattern = "^datapackage\\.json$",
            recursive = TRUE, full.names = TRUE
        )
        if (length(descriptor) == 0L) {
            stop(tr("err_camtrap_invalid_zip", lang), call. = FALSE)
        }
        pkg <- camtrapdp::read_camtrapdp(descriptor[1])
        attr(pkg, "saira_camtrap_source") <- source
        return(pkg)
    }

    if (source == "wildlife_insights_zip") {
        wi_root <- find_csv_root(dest, function(siblings) {
            "projects.csv" %in% siblings &&
                any(grepl("^images.*\\.csv$", siblings))
        })
        if (is.na(wi_root)) {
            stop(tr("err_camtrap_wi_columns_missing", lang), call. = FALSE)
        }
        norm_dir <- wi_to_camtrap_csv(wi_root, lang = lang)
        synthesize_camtrap_descriptor(norm_dir, lang = lang)
        pkg <- camtrapdp::read_camtrapdp(file.path(norm_dir, "datapackage.json"))
        # camtrapdp::write_dwc() filtra observationLevel == gbifIngestion$observationLevel
        # (default "event"). Como WI sintetiza só linhas media-level, declaramos o nível
        # explicitamente para que write_dwc() exporte essas linhas como ocorrências.
        pkg$gbifIngestion$observationLevel <- "media"
        attr(pkg, "saira_camtrap_source") <- source
        return(pkg)
    }

    # camtrap_csv_zip
    csv_root <- find_csv_root(dest, function(siblings) {
        "observations.csv" %in% siblings
    })
    if (is.na(csv_root)) {
        stop(tr("err_camtrap_invalid_zip", lang), call. = FALSE)
    }
    synthesize_camtrap_descriptor(csv_root, lang = lang)
    pkg <- camtrapdp::read_camtrapdp(file.path(csv_root, "datapackage.json"))
    attr(pkg, "saira_camtrap_source") <- source
    pkg
}

# --- Final conversion (unchanged) ---------------------------------------

convert_camtrap_to_dwc_occurrence <- function(x, lang = "en") {
    require_camtrapdp(lang)
    out_dir <- tempfile("camtrap_dwc_")
    dir.create(out_dir)
    result <- camtrapdp::write_dwc(x, directory = out_dir)
    occ <- if (!is.null(result[["occurrence"]])) {
        result[["occurrence"]]
    } else if (length(result) > 0L) {
        result[[1]]
    } else {
        NULL
    }
    if (!is.data.frame(occ) || !"scientificName" %in% names(occ)) {
        stop(tr("err_camtrap_invalid_zip", lang), call. = FALSE)
    }
    if (nrow(occ) == 0L) {
        stop(tr("err_camtrap_empty_occurrence", lang), call. = FALSE)
    }
    df <- as.data.frame(occ, stringsAsFactors = FALSE)
    src <- attr(x, "saira_camtrap_source")
    if (!is.null(src)) attr(df, "saira_camtrap_source") <- src
    df
}
