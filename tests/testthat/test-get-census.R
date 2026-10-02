test_that("2001 and 2011 return the full district set", {
  d11 <- get_census(2011, "district")
  expect_equal(nrow(d11), 640)
  expect_equal(sum(d11$population), 1210854977)

  d01 <- get_census(2001, "district")
  expect_equal(nrow(d01), 593)
  expect_equal(sum(d01$population), 1028610328)

  for (s in c("Sikkim", "Mizoram", "Daman & Diu")) {
    expect_true(s %in% d11$state_name_harmonized)
  }
})

test_that("state totals match district totals for 2001 and 2011", {
  for (y in c(2001, 2011)) {
    st <- get_census(y, "state")
    di <- get_census(y, "district")
    expect_equal(sum(st$population), sum(di$population))
    expect_equal(nrow(st), 35)
  }
})

test_that("year and geography are validated", {
  expect_error(get_census(1905, "state"), "Year")
  expect_error(get_census(2011, "planet"))
  # 1961 is district only
  expect_error(get_census(1961, "state"))
  expect_error(get_census(1981, "subdistrict"))
})

test_that("every advertised year/geography combination works", {
  g <- list_census_geographies()
  for (i in seq_len(nrow(g))) {
    expect_no_error(get_census(g$year[i], g$geography[i]))
  }
})

test_that("sector is validated rather than silently ignored", {
  expect_error(get_census(1971, "state", sector = "bogus"))
  expect_error(get_census(2011, "state", sector = "bogus"))
  expect_no_error(get_census(1981, "state", sector = "urban"))
})

test_that("state filtering accepts vectors and codes", {
  expect_equal(nrow(get_census(2011, "district", state = c("Punjab", "Haryana"))), 41)
  expect_equal(nrow(get_census(2011, "district", state = "Punjab")), 20)
  expect_equal(
    nrow(get_census(2011, "district", state = "PB")),
    nrow(get_census(2011, "district", state = "Punjab"))
  )
})

test_that("a partial state name is rejected, not substring matched", {
  expect_error(get_census(2011, "district", state = "Pradesh"), "Unknown state")
  expect_error(get_census(2011, "district", state = "Atlantis"), "Unknown state")
})

test_that("unavailable variables error instead of vanishing", {
  expect_error(get_census(1901, "state", variables = c("population", "cultivators")))
  expect_no_error(get_census(2011, "district", variables = c("workers", "main_workers")))
})

test_that("literacy_rate is a rate, not a count", {
  d <- get_census(2011, "state", variables = c("population", "literacy_rate"))
  expect_true("literacy_rate" %in% names(d))
  expect_true(all(d$literacy_rate > 0 & d$literacy_rate < 100))
})

test_that("geometry = TRUE either returns sf or says why not", {
  skip_if_no_remote()
  skip_if_not_installed("sf")
  expect_s3_class(
    suppressWarnings(get_census(2011, "district", geometry = TRUE)), "sf"
  )
  expect_error(get_census(2011, "subdistrict", geometry = TRUE))
})

test_that("attaching geometry never changes the row count", {
  skip_if_no_remote()
  skip_if_not_installed("sf")
  for (y in c(1991, 2001, 2011)) {
    d <- get_census(y, "district")
    g <- suppressWarnings(
      attach_geometry(d, y, geography = "district", unmatched = "ignore")
    )
    expect_equal(nrow(g), nrow(d))
  }
})
