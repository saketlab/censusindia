# R/schema.R canonicalize(); conversion is in test-legacy-schema.R

canonicalize <- censusindia:::canonicalize
id_cols <- censusindia:::.id_cols

test_that("canonicalize() turns zero and '000' codes into NA integers", {
  out <- canonicalize(data.frame(
    geography = "district", state_code = c("00", "32"),
    district_code = c("000", "012"), population = 1:2
  ))
  expect_identical(out$state_code, c(NA, 32L))
  expect_identical(out$district_code, c(NA, 12L))
})

test_that("canonicalize() fills state_code from india_states and keeps one present", {
  out <- canonicalize(data.frame(geography = "state", state_name_harmonized = c("Kerala", "Bihar"), population = 1:2))
  ref <- censusindia::india_states
  expect_identical(out$state_code, ref$state_code[match(c("Kerala", "Bihar"), ref$state_name_harmonized)])
  kept <- canonicalize(data.frame(geography = "state", state_name_harmonized = "Kerala", state_code = 99L, population = 1))
  expect_identical(kept$state_code, 99L)
})

test_that("canonicalize() adds year and geography when given, and normalizes geography", {
  out <- canonicalize(data.frame(state_name_harmonized = "Kerala", population = 1), year = 2011, geography = "State")
  expect_identical(out$year, 2011L)
  expect_identical(out$geography, "state")
  expect_identical(
    canonicalize(data.frame(geography = c("Sub-District", "UA"), population = 1:2))$geography,
    c("subdistrict", "urban_agglomeration")
  )
  expect_error(canonicalize(data.frame(population = 1)), "geography")
  expect_error(canonicalize(data.frame(geography = "tehsil", population = 1)))
})

test_that("canonicalize() orders ids first, stores counts as doubles, returns a tibble", {
  out <- canonicalize(data.frame(
    population = 1L, language_group = 2L, district = "Idukki",
    geography = "district", year = 2011L
  ))
  expect_identical(names(out)[1:3], c("year", "geography", "district"))
  expect_type(out$population, "double")
  expect_type(out$language_group, "integer")
  expect_s3_class(out, "tbl_df")
})

test_that("canonicalize() preserves sf geometry and its column", {
  skip_if_not_installed("sf")
  x <- sf::st_sf(
    geography = "state", state_name_harmonized = "Kerala", population = 1,
    geom = sf::st_sfc(sf::st_point(c(76, 10)), crs = 4326)
  )
  out <- canonicalize(x)
  expect_s3_class(out, "sf")
  expect_identical(attr(out, "sf_column"), "geom")
  expect_identical(names(out)[ncol(out)], "geom")
  expect_equal(unname(sf::st_coordinates(out)[1, 1:2]), c(76, 10))
})

test_that("shipped tables carry no retired column names", {
  for (nm in utils::data(package = "censusindia")$results[, "Item"]) {
    d <- getExportedValue("censusindia", nm)
    expect_false(any(RETIRED_COLS %in% names(d)), info = nm)
  }
})
