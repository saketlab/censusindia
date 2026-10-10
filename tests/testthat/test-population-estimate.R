test_that("a missing year interpolates geometrically and says so", {
  expect_message(
    est <- get_population(2023, "district", state = "Kerala"),
    "estimated"
  )
  p21 <- get_population(2021, "district", state = "Kerala")
  p26 <- get_population(2026, "district", state = "Kerala")
  expect_equal(nrow(est), nrow(p21))
  expect_equal(est$population, round(p21$population * (p26$population / p21$population)^0.4))
  expect_true(all(est$population >= pmin(p21$population, p26$population)))
})

test_that("table years are returned untouched and silently", {
  expect_no_message(x <- get_population(2021, "state"))
  expect_equal(x, dplyr::filter(population_projections_state, year == 2021))
})

test_that("years past the table extrapolate with a warning-level message", {
  expect_message(x <- get_population(2040, "state", state = "India"), "Extrapolated")
  s <- dplyr::filter(population_projections_state, state_name_harmonized == "India")
  p35 <- s$population[s$year == 2035]
  p36 <- s$population[s$year == 2036]
  expect_equal(x$population, round(p36 * (p36 / p35)^4))
})

test_that("mixed table and estimated years come back together", {
  x <- suppressMessages(get_population(c(2021, 2023), "state", by_age = TRUE))
  expect_setequal(unique(x$year), c(2021, 2023))
  expect_type(get_population(2040, "state")$year, "integer") |> suppressMessages()
  expect_error(get_population(2021.5, "state"), "whole-number")
})
