district_gap <- function(x, year) {
  d <- dplyr::filter(population_projections_district, year == .env$year)
  s <- x |>
    dplyr::group_by(state_name_harmonized, district) |>
    dplyr::summarise(males = sum(males), females = sum(females), n = dplyr::n(), .groups = "drop")
  j <- dplyr::full_join(s, d, by = c("state_name_harmonized", "district"), suffix = c("", ".d"))
  expect_false(anyNA(j$n))
  expect_false(anyNA(j$males.d))
  # each subdistrict rounds on its own
  expect_true(all(abs(j$males - j$males.d) <= j$n))
  expect_true(all(abs(j$females - j$females.d) <= j$n))
}

test_that("constant shares cover every district and add to it", {
  x <- get_population(2031, "subdistrict")
  expect_equal(nrow(x), nrow(census_subdistricts_2011))
  district_gap(x, 2031)
  expect_identical(unique(x$geography), "subdistrict")
  expect_identical(unique(x$estimate), "derived")
  expect_equal(x$population, x$males + x$females)
})

test_that("a constant share is the 2011 share of the district, by sex", {
  b <- dplyr::filter(census_subdistricts_2011, district == "Pune", state_name_harmonized == "Maharashtra")
  d <- dplyr::filter(population_projections_district, district == "Pune", year == 2031)
  x <- get_population(2031, "subdistrict", state = "MH") |> dplyr::filter(district == "Pune")
  x <- x[match(b$subdistrict, x$subdistrict), ]
  expect_equal(x$males, round(d$males * b$males / sum(b$males)))
  expect_equal(x$females, round(d$females * b$females / sum(b$females)))
})

test_that("Telangana and Ladakh subdistricts are found under the projection states", {
  expect_setequal(
    get_population(2021, "subdistrict", state = "Telangana")$district,
    c(
      "Adilabad", "Hyderabad", "Karimnagar", "Khammam", "Mahbubnagar", "Medak",
      "Nalgonda", "Nizamabad", "Rangareddy", "Warangal"
    )
  )
  expect_setequal(get_population(2021, "subdistrict", state = "Ladakh")$district, c("Kargil", "Leh (Ladakh)"))
})

test_that("interpolated years keep their label", {
  x <- suppressMessages(get_population(2023, "subdistrict", state = "Goa"))
  expect_identical(unique(x$estimate), "interpolated")
})

test_that("unsupported subdistrict options and misplaced method are errors", {
  expect_error(get_population(2021, "subdistrict", boundary = "lgd"), "Census 2011")
  expect_error(get_population(2021, "subdistrict", by_age = TRUE), "Census 2011")
  expect_error(get_population(2021, "subdistrict", geometry = TRUE), "Census 2011")
  expect_error(get_population(2021, "district", method = "urban_rural"), "subdistrict")
})

test_that("urban and rural weights add to the district and start from 2011", {
  skip_if_no_remote()
  x <- get_population(c(2011, 2031), "subdistrict", method = "urban_rural")
  y <- get_population(2011, "subdistrict")
  expect_false(anyNA(x$population))
  expect_true(all(x$population >= 0))
  district_gap(x[x$year == 2031, ], 2031)
  key <- c("state_name_harmonized", "district", "subdistrict")
  a <- dplyr::inner_join(x[x$year == 2011, ], y, by = key)
  expect_equal(nrow(a), nrow(y))
  expect_equal(a$population.x, a$population.y)
})

test_that("states whose urban figure reaches the total keep constant shares", {
  skip_if_no_remote()
  for (s in c("Lakshadweep", "Delhi", "Chandigarh")) {
    u <- get_population(2031, "subdistrict", state = s, method = "urban_rural")
    expect_equal(u$population, get_population(2031, "subdistrict", state = s)$population, info = s)
  }
  expect_true(all(get_population(2031, "subdistrict", method = "urban_rural")$population > 0))
})

test_that("a more urban subdistrict outgrows a more rural one in its district", {
  skip_if_no_remote()
  x <- get_population(c(2011, 2031), "subdistrict", state = "MH", method = "urban_rural") |>
    dplyr::filter(district == "Pune")
  g <- function(s) {
    p <- x$population[x$subdistrict == s]
    p[2] / p[1]
  }
  expect_gt(g("Pune City"), g("Velhe"))
})

test_that("urban table holds the printed values, including its awkward pages", {
  u <- population_projections_state_urban
  printed <- function(s, y) u$population[u$state_name_harmonized == s & u$year == y]
  expect_equal(printed("Odisha", 2011), 7004000) # columns off the row baseline
  expect_equal(printed("Odisha", 2036), 10434000)
  expect_equal(printed("Telangana", 2014), 14849000)
  expect_equal(printed("Lakshadweep", 2011), 50000) # columns not in the usual state order
  expect_equal(printed("Puducherry", 2011), 853000)
  expect_equal(printed("Dadra & Nagar Haveli", 2011), 161000)
  expect_equal(nrow(u), 38 * 26)
  expect_true(all(abs(u$population - u$males - u$females) <= 1000))
})

test_that("urban 2011 rows agree with the Census", {
  skip_if_no_remote()
  census <- at_level(census_2011_demographics(), "state", "urban")
  u <- dplyr::filter(population_projections_state_urban, year == 2011) |>
    dplyr::inner_join(census, by = "state_name_harmonized", suffix = c("", ".c")) |>
    dplyr::filter(!state_name_harmonized %in% c("Andhra Pradesh", "Jammu & Kashmir"))
  expect_equal(nrow(u), 33)
  expect_true(all(abs(u$population - u$population.c) <= 1000))
})

# population_projections() -----------------------------------------------------

test_that("rural is total minus urban, and never negative", {
  r <- population_projections_state_rural
  u <- population_projections_state_urban
  t <- population_projections_state
  j <- dplyr::inner_join(r, u, by = c("year", "state_name_harmonized"), suffix = c("", ".u")) |>
    dplyr::inner_join(t, by = c("year", "state_name_harmonized"), suffix = c("", ".t"))
  expect_equal(nrow(j), 38 * 26)
  expect_equal(j$population, pmax(j$population.t - j$population.u, 0))
  capped <- c("Delhi", "Chandigarh", "Lakshadweep")
  ok <- j[!j$state_name_harmonized %in% capped, ]
  expect_equal(ok$males, ok$males.t - ok$males.u)
  expect_equal(ok$females, ok$females.t - ok$females.u)
  expect_equal(r$population[r$state_name_harmonized == "Delhi" & r$year == 2036], 0)
})

test_that("state rows return the three source tables", {
  x <- population_projections(geography = "state", state = "Kerala", year = 2031)
  expect_setequal(x$sector, c("total", "rural", "urban"))
  for (s in c("rural", "urban")) {
    d <- getExportedValue("censusindia", paste0("population_projections_state_", s))
    want <- d$population[d$state_name_harmonized == "Kerala" & d$year == 2031]
    expect_equal(x$population[x$sector == s], want)
  }
  expect_identical(x$estimate[x$sector == "rural"], "derived")
  expect_identical(x$estimate[x$sector == "urban"], "published")
})

test_that("narrowing works without any download", {
  x <- population_projections(geography = "state", sector = "rural")
  expect_identical(unique(x$sector), "rural")
  expect_identical(unique(x$geography), "state")
  expect_equal(sort(unique(x$year)), 2011:2036)
  expect_false("India" %in% x$state_name_harmonized)
  expect_identical(
    population_projections(geography = "india", sector = "total", year = 2021)$population,
    get_population(2021, state = "India")$population
  )
  d <- population_projections(geography = "district", sector = "total", state = "KL", year = 2021)
  expect_equal(d$population, get_population(2021, "district", state = "KL")$population)
  s <- population_projections(geography = "subdistrict", sector = "total", state = "KL", year = 2021)
  expect_equal(sum(s$population), sum(get_population(2021, "subdistrict", state = "KL")$population))
})

test_that("states add to India, without the merged UT counted twice", {
  x <- population_projections(geography = c("india", "state"), sector = "total", year = 2021)
  expect_false(censusindia:::.merged_ut %in% x$state_name_harmonized)
  expect_lt(abs(sum(x$population[x$geography == "state"]) - x$population[x$geography == "india"]), 40000)
})

test_that("levels with no data and bad input explain themselves", {
  expect_error(population_projections("block"), "gram panchayat")
  expect_error(population_projections("gram panchayat"), "gram panchayat")
  expect_error(population_projections("town"), "No projections")
  expect_error(population_projections("planet"), "must be from")
  expect_error(population_projections(sector = "suburban"), "must be from")
  expect_error(population_projections("village", sector = "urban"), "Villages are rural")
  expect_error(population_projections("india", state = "Kerala"), "national rows")
  expect_error(population_projections("state", state = "Atlantis"), "Unknown state")
  expect_equal(
    nrow(population_projections("tehsil", "total", state = "GA", year = 2021)),
    nrow(population_projections("sub-district", "total", state = "GA", year = 2021))
  )
})

test_that("in 2011 the rural and urban rows are the Census counts", {
  skip_if_no_remote()
  x <- population_projections("district", "urban", year = 2011)
  d <- at_level(census_2011_demographics(), "district", "urban")
  expect_equal(sum(x$population), sum(d$population), tolerance = 1e-3)
})

test_that("rural and urban rows add up across levels, under both methods", {
  skip_if_no_remote()
  for (m in c("constant_share", "urban_rural")) {
    x <- population_projections(c("state", "district", "subdistrict"), c("rural", "urban"), 2031, method = m)
    x <- x[!x$state_name_harmonized %in% c("Delhi", "Chandigarh", "Lakshadweep"), ]
    sum_of <- function(g, ...) {
      x[x$geography == g, ] |>
        dplyr::group_by(sector, ...) |>
        dplyr::summarise(p = sum(population), n = dplyr::n(), .groups = "drop")
    }
    s <- dplyr::inner_join(sum_of("district", state_name_harmonized), sum_of("state", state_name_harmonized),
      by = c("sector", "state_name_harmonized"), suffix = c("", ".s")
    )
    u <- s[s$sector == "urban", ]
    expect_true(all(abs(u$p - u$p.s) <= 2 * u$n), info = m)
    d <- dplyr::inner_join(
      sum_of("subdistrict", state_name_harmonized, district),
      sum_of("district", state_name_harmonized, district),
      by = c("sector", "state_name_harmonized", "district"), suffix = c("", ".d")
    )
    expect_gt(nrow(d), 1200)
    # under constant shares a district's urban figure can outgrow its urban subdistricts
    off <- mean(abs(d$p - d$p.d) > 4 * d$n)
    if (m == "urban_rural") expect_equal(off, 0) else expect_lt(off, 0.05)
  }
})

test_that("rake_urban() hits the target and respects each unit's limits", {
  rake <- censusindia:::rake_urban
  x <- rake(c(100, 100), c(1, 3), c(3, 1), 120)
  expect_equal(sum(x), 120, tolerance = 1e-6)
  expect_true(all(x >= 0 & x <= 100))
  expect_gt(x[2], x[1])
  expect_equal(rake(c(100, 100), c(1, 0), c(1, 1), 150), c(100, 0)) # no urban weight stays rural
  expect_equal(rake(c(100, 100), c(1, 1), c(0, 1), 10), c(100, 0)) # no rural weight stays urban
  expect_equal(rake(c(100, 100), c(1, 1), c(1, 3), NA), c(50, 25))
})

test_that("villages carry their name and code", {
  skip_if_no_remote()
  v <- population_projections("village", "rural", 2031, state = "GA")
  expect_false(anyNA(v$name))
  expect_false(anyNA(v$town_village_code))
})

test_that("Telangana and Ladakh villages reach their projection states", {
  skip_if_no_remote()
  expect_gt(nrow(population_projections("village", "rural", 2031, state = "Telangana")), 9000)
  expect_gt(nrow(population_projections("village", "rural", 2031, state = "Ladakh")), 200)
})

test_that("a district the projections do not know is an error, not a dropped row", {
  x <- data.frame(state_name_harmonized = "Kerala", district = "Atlantis")
  expect_error(censusindia:::projection_names(x), "Atlantis")
  y <- data.frame(state_name_harmonized = "West Bengal", district = "North Twenty Four Parganas")
  expect_identical(censusindia:::projection_names(y)$district, "North Twenty-Four Parganas")
})
