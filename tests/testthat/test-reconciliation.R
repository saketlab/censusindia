sum_by <- function(x, by, col = "population") tapply(x[[col]], do.call(paste, unname(x[by])), sum)

expect_states_match <- function(di, st) {
  expect_false(anyNA(di$population))
  expect_false(anyNA(st$population))
  d <- sum_by(di, "state_name_harmonized")
  expect_equal(d[st$state_name_harmonized], st$population, ignore_attr = TRUE)
}

test_that("2011 district sums equal each state's own figure", {
  skip_if_no_remote()
  st <- at_level(census_2011_demographics(), "state")
  st$population <- st$population_total
  di <- get_census(2011, "district")
  expect_setequal(st$state_name_harmonized, di$state_name_harmonized)
  expect_equal(nrow(st), 35)
  expect_states_match(di, st)
})

test_that("2001 district sums equal the time series state figures", {
  ts <- census_population_time_series
  # 2001 PCA excludes the Mao-Maram, Paomata and Purul subdivisions
  st <- ts[ts$year == 2001 & ts$geography == "state" & ts$state_name_harmonized != "Manipur", ]
  expect_states_match(get_census(2001, "district"), st)
})

test_that("2011 subdistrict sums equal each district's PCA total", {
  s <- get_census(2011, "subdistrict")
  di <- get_census(2011, "district")
  key <- paste(di$state_name_harmonized, di$name)
  for (v in c("population", "males", "females")) {
    expect_false(anyNA(s[[v]]))
    d <- sum_by(s, c("state_name_harmonized", "district"), v)
    expect_setequal(names(d), key)
    expect_equal(d[key], di[[v]], ignore_attr = TRUE)
  }
})

test_that("projection district sums are within 2 percent of each state", {
  pd <- population_projections_district
  ps <- population_projections_state
  expect_false(anyNA(pd$population))
  expect_false(anyNA(ps$population))
  # district projections are 5-yearly
  ps <- ps[ps$year %in% pd$year & ps$state_name_harmonized != "India", ]
  d <- sum_by(pd, c("state_name_harmonized", "year"))
  key <- paste(ps$state_name_harmonized, ps$year)
  expect_setequal(names(d), key)
  expect_true(all(abs(d[key] / ps$population - 1) < 0.02))
})
