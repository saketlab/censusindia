# inst/provenance.csv records each dataset's source, build scripts and test.
# A .rda changed without make -C data-raw provenance fails here.

prov <- utils::read.csv(system.file("provenance.csv", package = "censusindia"),
  colClasses = "character"
)
shipped <- utils::data(package = "censusindia")$results[, "Item"]
dataset <- function(n) getExportedValue("censusindia", n)

test_that("every shipped and remote dataset has a provenance row with a source", {
  remote <- sub(
    "[.](rds|geojson[.]gz)$", "",
    utils::read.csv(system.file("manifest.csv", package = "censusindia"))$file
  )
  expect_setequal(prov$dataset, c(shipped, remote))
  expect_false(anyDuplicated(prov$dataset) > 0)
  expect_true(all(nzchar(prov$source)))
})

test_that("each shipped dataset matches its recorded content hash", {
  for (n in shipped) {
    expect_equal(content_md5(dataset(n)), prov$content_md5[prov$dataset == n],
      label = paste(n, "(rebuilt without `make -C data-raw provenance`?)")
    )
  }
})

test_that("named build scripts and verifying tests exist", {
  scripts <- unlist(strsplit(prov$build_script[nzchar(prov$build_script)], " ", fixed = TRUE))
  tests <- prov$verified_by[nzchar(prov$verified_by)]
  expect_true(all(file.exists(test_path(tests))), info = paste(tests, collapse = " "))
  data_raw <- test_path("..", "..", "data-raw")
  skip_if_not(dir.exists(data_raw), "data-raw is not in the built package")
  expect_true(all(file.exists(file.path(data_raw, scripts))),
    info = paste(setdiff(scripts, list.files(data_raw)), collapse = " ")
  )
})

# Generic invariants over every shipped table ------------------------------------

# Source spellings kept on purpose; see data-raw/harmonize-state-names.R.
STATE_EXCEPTIONS <- c(
  "India", "Ladakh", "Telangana",
  "UNION TERRITORIES AND OTHER AREAS", "Goa, Daman & Diu",
  "Dadra & Nagar Haveli and Daman & Diu", "North East States Excluding Assam"
)

test_that("state_name_harmonized is canonical in every table", {
  ok <- c(india_states$state_name_harmonized, STATE_EXCEPTIONS)
  for (n in shipped) {
    d <- dataset(n)
    if (!"state_name_harmonized" %in% names(d)) next
    expect_equal(setdiff(stats::na.omit(unique(d$state_name_harmonized)), ok),
      character(0),
      label = n
    )
  }
})

test_that("percent and rate columns lie in [0, 100], shares in [0, 1], no duplicate rows", {
  for (n in shipped) {
    d <- dataset(n)
    if (!is.data.frame(d)) next
    expect_equal(anyDuplicated(d), 0L, label = n)
    in_range <- function(pattern, hi) {
      for (v in grep(pattern, names(d), value = TRUE)) {
        if (is.numeric(d[[v]])) expect_true(all(d[[v]] >= 0 & d[[v]] <= hi, na.rm = TRUE), label = paste(n, v))
      }
    }
    in_range("^percent$|_rate($|_)", 100)
    in_range("_share$|^coverage$", 1)
  }
})

test_that("2011 district tables use census_2011_pca district spellings", {
  for (n in c(
    "census_2011_sc_st", "census_2011_tribes",
    "census_2011_district_languages", "census_2011_linguistic_diversity"
  )) {
    keys <- unique(dataset(n)[c("state_name_harmonized", "district")])
    off <- dplyr::anti_join(keys, census_2011_pca, by = c("state_name_harmonized", "district"))
    expect_equal(nrow(off), 0, label = n)
  }
})

# One column schema (R/schema.R) ---------------------------------------------------

expect_canonical <- function(d, label) {
  d <- sf::st_drop_geometry(d)
  expect_identical(canonicalize(d), d, label = label)
  ids <- intersect(.id_cols, names(d))
  expect_equal(names(d)[seq_along(ids)], ids, label = paste(label, "id columns first, in order"))
  expect_true(all(d$geography %in% .geographies), label = label)
  for (v in intersect(c("year", grep("_code$", ids, value = TRUE)), names(d))) {
    expect_type(d[[v]], "integer")
    if (v != "year") expect_false(any(d[[v]] == 0L, na.rm = TRUE), label = paste(label, v))
  }
}

test_that("every shipped table is on the package schema", {
  for (n in setdiff(shipped, .not_geographic)) expect_canonical(dataset(n), n)
})

test_that("downloaded tables and boundaries load on the package schema", {
  skip_if_no_remote()
  for (f in c(
    "census_2011_demographics", "census_2011_workers", "census_2011_marginal_detail",
    "census_2011_mother_tongue", "census_2011_subdistrict_languages",
    "population_projections_district_age", "population_projections_district_lgd_age"
  )) {
    expect_canonical(getExportedValue("censusindia", f)(), f)
  }
  for (g in c("state", "district")) expect_canonical(get_census_boundaries(2011, g), g)
})

test_that("get_census() returns the same id columns for every year at a level", {
  g <- list_census_geographies()
  for (geo in c("state", "district")) {
    ids <- lapply(g$year[g$geography == geo], function(y) {
      d <- get_census(y, geo)
      expect_canonical(d, paste(y, geo))
      setdiff(intersect(.id_cols, names(d)), "district_code") # 1971/1981 publish no codes
    })
    expect_true(all(vapply(ids, identical, TRUE, ids[[1]])), label = geo)
  }
})
