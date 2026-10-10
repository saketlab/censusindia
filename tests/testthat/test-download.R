test_that("every remote file has a pinned checksum", {
  ns <- asNamespace("censusindia")
  m <- ns$census_manifest()
  boundaries <- ns$boundary_file(rep(ns$BOUNDARY_YEARS, each = 2), c("district", "state"))
  expect_setequal(grep("geojson", m$file, value = TRUE), boundaries)
  tables <- c(
    "census_2011_demographics", "census_2011_workers", "census_2011_marginal_detail",
    "census_2011_mother_tongue", "census_2011_subdistrict_languages",
    "population_projections_district_age", "population_projections_district_lgd_age"
  )
  expect_setequal(sub("[.]rds$", "", grep("[.]rds$", m$file, value = TRUE)), tables)
  expect_false(anyDuplicated(m$file) > 0)
  expect_true(all(grepl("^[0-9a-f]{32}$", m$md5)))
  expect_true(all(grepl("^v[0-9]+$", m$version)))
})

test_that("a file downloads once, verifies, and is then read from the cache", {
  skip_if_no_remote()
  dir <- tempfile("censusindia-cache")
  op <- options(censusindia.cache_dir = dir)
  on.exit(options(op), add = TRUE)
  on.exit(unlink(dir, recursive = TRUE), add = TRUE)

  file <- "india-census-1941-states.geojson.gz"
  expect_message(path <- censusindia:::census_file(file), "Downloading")
  expect_true(startsWith(path, census_cache_dir()))
  m <- censusindia:::census_manifest()
  expect_equal(unname(tools::md5sum(path)), m$md5[m$file == file])
  expect_silent(censusindia:::census_file(file))

  clear_census_cache()
  expect_false(dir.exists(census_cache_dir()))
})
