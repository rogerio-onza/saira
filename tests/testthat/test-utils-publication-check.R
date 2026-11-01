test_that("publication_portal reads the portal from the dataset key", {
    expect_equal(publication_portal("eca6ce5b-72ce-4ce3-b96f-c6ed82eebcc9"), "gbif")
    expect_equal(publication_portal("dr1451"), "sibbr")
    expect_error(publication_portal("Neotropical Carnivores"), "GBIF dataset key")
    expect_error(publication_portal(c("dr1", "dr2")), "GBIF dataset key")
})

test_that("read_archive_occurrence_ids reads a Saira bundle, zipped or unzipped", {
    df <- data.frame(
        occurrenceID = c("a-1", "b,2", "c-3"),
        scientificName = c("Puma concolor", "Leopardus wiedii", "Nasua nasua")
    )
    zip_path <- tempfile(fileext = ".zip")
    build_dwca_bundle(df, zip_path)
    expect_equal(read_archive_occurrence_ids(zip_path), c("a-1", "b,2", "c-3"))

    dir <- tempfile("unzipped_")
    zip::unzip(zip_path, exdir = dir)
    expect_equal(read_archive_occurrence_ids(dir), c("a-1", "b,2", "c-3"))
})

test_that("read_archive_occurrence_ids follows meta.xml in an IPT archive", {
    # The IPT writes tabs, no quotes, and an <id> column apart from the
    # occurrenceID field. A quote inside a value is plain text there.
    dir <- tempfile("ipt_")
    dir.create(dir)
    writeLines(c(
        '<archive xmlns="http://rs.tdwg.org/dwc/text/" metadata="eml.xml">',
        '  <core encoding="UTF-8" fieldsTerminatedBy="\\t" linesTerminatedBy="\\n"',
        '        fieldsEnclosedBy="" ignoreHeaderLines="1"',
        '        rowType="http://rs.tdwg.org/dwc/terms/Occurrence">',
        "    <files><location>occurrence.txt</location></files>",
        '    <id index="0" />',
        '    <field index="1" term="http://rs.tdwg.org/dwc/terms/locality"/>',
        '    <field index="2" term="http://rs.tdwg.org/dwc/terms/occurrenceID"/>',
        "  </core>",
        "</archive>"
    ), file.path(dir, "meta.xml"))
    writeLines(c(
        "id\tlocality\toccurrenceID",
        "1\tSerra \"do\" Mar\tocc-1",
        "2\t\tocc-2"
    ), file.path(dir, "occurrence.txt"))

    expect_equal(read_archive_occurrence_ids(dir), c("occ-1", "occ-2"))
})

test_that("read_archive_occurrence_ids stops without meta.xml", {
    dir <- tempfile("bare_")
    dir.create(dir)
    writeLines("occurrenceID\nocc-1", file.path(dir, "occurrence.txt"))
    expect_error(read_archive_occurrence_ids(dir), "no meta.xml")
    expect_error(read_archive_occurrence_ids(file.path(dir, "nope.zip")), "not found")
})

test_that("check_publication lists the IDs that did not arrive and the extra ones", {
    zip_path <- tempfile(fileext = ".zip")
    build_dwca_bundle(
        data.frame(occurrenceID = c("occ-1", "occ-2", "occ-3", ""), scientificName = "x"),
        zip_path
    )
    testthat::local_mocked_bindings(
        published_occurrence_ids = function(portal, dataset) {
            structure(c("occ-1", "occ-3", "occ-9"), count = 4L)
        }
    )

    res <- check_publication(zip_path, "dr1451")

    expect_equal(res$portal, "sibbr")
    expect_equal(res$sent, 4L)
    expect_equal(res$published, 4L)
    expect_equal(res$missing, "occ-2")
    expect_equal(res$unexpected, "occ-9")
})

test_that("published_occurrence_ids reads facet pages until a short page", {
    offsets <- integer(0)
    testthat::local_mocked_bindings(
        publication_id_page = function(portal, dataset, offset) {
            offsets <<- c(offsets, offset)
            n <- if (offset == 0L) PUBLICATION_PAGE_SIZE else 2L
            list(count = PUBLICATION_PAGE_SIZE + 2L,
                 ids = paste0("occ-", offset + seq_len(n)))
        }
    )

    ids <- published_occurrence_ids("gbif", "eca6ce5b-72ce-4ce3-b96f-c6ed82eebcc9")

    expect_equal(offsets, c(0L, PUBLICATION_PAGE_SIZE))
    expect_length(ids, PUBLICATION_PAGE_SIZE + 2L)
    expect_equal(attr(ids, "count"), PUBLICATION_PAGE_SIZE + 2L)
})
