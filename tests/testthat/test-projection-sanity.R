# If one fails, assume the numbers are wrong before changing a threshold.

state <- function(s, y, x = population_projections_state) {
  x$population[x$state_name_harmonized == s & x$year == y]
}
urban <- function(s, y) state(s, y, population_projections_state_urban)
rise <- function(s, from = 2011, to = 2036) state(s, to) - state(s, from)
sex_ratio_of <- function(s, y) {
  r <- population_projections_state[population_projections_state$state_name_harmonized == s & population_projections_state$year == y, ]
  sex_ratio(r$females, r$males)
}
states_only <- function(x) {
  x[x$geography == "state" & x$state_name_harmonized != censusindia:::.merged_ut, ]
}

# the full table is slow; build it once
.pp <- new.env()
pp <- function() {
  skip_if_no_remote()
  if (is.null(.pp$all)) .pp$all <- suppressMessages(population_projections())
  .pp$all
}
level <- function(g, s = "total", y = NULL) {
  x <- at_level(pp(), g, s)
  if (is.null(y)) x else x[x$year %in% y, ]
}
share_of_urban <- function(y, g) {
  u <- sum(level(g, "urban", y)$population)
  u / (u + sum(level(g, "rural", y)$population))
}

# What the report says --------------------------------------------------

test_that("India's size and growth are the report's", {
  expect_equal(state("India", 2011), 1210855000, tolerance = 1e-5) # Census 2011
  expect_equal(rise("India") / 1e7, 31.1, tolerance = 0.005)
  expect_equal(100 * rise("India") / state("India", 2011), 25.7, tolerance = 0.002)
  expect_equal(100 * ((state("India", 2036) / state("India", 2011))^(1 / 25) - 1), 1.0, tolerance = 0.1)
  expect_equal(state("India", 2011) / 3287263, 368, tolerance = 0.002)
  expect_equal(state("India", 2036) / 3287263, 463, tolerance = 0.002)
})

test_that("sex ratios are the report's", {
  expect_equal(sex_ratio_of("India", 2011), 943, tolerance = 0.002)
  expect_equal(sex_ratio_of("India", 2036), 952, tolerance = 0.002)
  expect_equal(sex_ratio_of("Delhi", 2036), 899, tolerance = 0.002)
  expect_equal(sex_ratio_of("Gujarat", 2036), 900, tolerance = 0.002)
  expect_equal(sex_ratio_of("Haryana", 2036), 908, tolerance = 0.002)
})

test_that("state growth agrees with the report's tables", {
  pct <- function(s) 100 * rise(s) / state(s, 2011)
  # Table 8, which the report's text contradicts
  expect_equal(round(pct("Himachal Pradesh"), 1), 13.4)
  expect_equal(round(pct("Delhi"), 1), 58.4)
  expect_equal(round(pct("Maharashtra"), 1), 21.7)
  # where text and tables agree
  expect_equal(round(pct("Tamil Nadu")), 8)
  for (s in c("Punjab", "Karnataka", "Odisha", "Telangana", "West Bengal")) {
    expect_true(pct(s) >= 10 && pct(s) <= 20, label = s)
  }
  for (s in c("Gujarat", "Rajasthan", "Madhya Pradesh", "Bihar", "Delhi")) {
    expect_gt(pct(s), 30, label = s)
  }
  expect_identical(
    names(which.min(vapply(c("Tamil Nadu", "Kerala", "Andhra Pradesh", "West Bengal"), pct, numeric(1)))),
    "Tamil Nadu"
  )
})

test_that("each state's part of national growth is the report's", {
  part <- function(s) 100 * sum(vapply(s, rise, numeric(1))) / rise("India")
  expect_equal(round(part("Uttar Pradesh")), 19)
  expect_equal(round(part("Rajasthan"), 1), 7.2, tolerance = 0.02)
  expect_equal(round(part("Gujarat"), 1), 6.8, tolerance = 0.02)
  expect_equal(round(part("Haryana"), 1), 3.0, tolerance = 0.04)
  expect_equal(round(part("Delhi"), 1), 3.2, tolerance = 0.04)
  five <- c("Bihar", "Uttar Pradesh", "Maharashtra", "West Bengal", "Madhya Pradesh")
  expect_equal(sum(vapply(five, rise, numeric(1))) / 1e7, 17, tolerance = 0.04)
  south <- c("Andhra Pradesh", "Karnataka", "Kerala", "Telangana", "Tamil Nadu")
  expect_equal(sum(vapply(south, rise, numeric(1))) / 1e7, 2.9, tolerance = 0.03)
})

test_that("urbanisation is the report's", {
  rise_urban <- urban("India", 2036) - urban("India", 2011)
  expect_equal(rise_urban / 1e7, 21.8, tolerance = 0.005)
  # Tables 8 and 9, which the report's text contradicts
  expect_equal(round(100 * rise_urban / rise("India"), 1), 69.8)
  expect_equal(round(100 * urban("India", 2011) / state("India", 2011), 1), 31.1)
  expect_equal(round(100 * urban("India", 2036) / state("India", 2036), 1), 39.1)
  expect_equal(100 * urban("Himachal Pradesh", 2036) / state("Himachal Pradesh", 2036), 10.5, tolerance = 0.02)
  for (s in c("Delhi", "Chandigarh", "Lakshadweep")) {
    expect_equal(urban(s, 2036) / state(s, 2036), 1, label = s)
  }
})

# State tables: internal sense -------------------------------------------------------

both <- list(urban = population_projections_state_urban, rural = population_projections_state_rural)

test_that("state sector tables are complete, whole and non-negative", {
  for (n in names(both)) {
    d <- both[[n]]
    expect_equal(nrow(d), 38 * 26, label = n)
    expect_true(all(table(d$state_name_harmonized) == 26), label = n)
    expect_setequal(d$year, 2011:2036)
    expect_false(anyNA(d[c("males", "females", "population")]), label = n)
    expect_true(all(d$population %% 1000 == 0), label = n)
    expect_true(all(d$population >= 0 & d$males >= 0 & d$females >= 0), label = n)
    expect_identical(unique(d$sector), n)
  }
})

test_that("urban and rural add to the total in every state and year", {
  j <- merge(both$urban, both$rural, by = c("year", "state_name_harmonized"), suffixes = c("_u", "_r"))
  j <- merge(j, population_projections_state, by = c("year", "state_name_harmonized"))
  expect_equal(nrow(j), 38 * 26)
  expect_equal(j$population_u + j$population_r, j$population)
})

test_that("the urban share lies in [0, 100] and rises in India", {
  j <- merge(both$urban, population_projections_state, by = c("year", "state_name_harmonized"))
  share <- j$population.x / j$population.y
  expect_true(all(share >= 0 & share <= 1))
  i <- j[j$state_name_harmonized == "India", ]
  i <- i[order(i$year), ]
  expect_true(all(diff(i$population.x / i$population.y) > 0))
})

test_that("no state's urban population ever falls", {
  u <- both$urban[order(both$urban$state_name_harmonized, both$urban$year), ]
  step <- stats::ave(u$population, u$state_name_harmonized, FUN = function(x) c(0, diff(x)))
  expect_true(all(step >= 0))
})

# projected by extending growth rates in steps
mathematical_method <- c(
  "Andaman & Nicobar Islands", "Chandigarh", "Dadra & Nagar Haveli", "Daman & Diu", "Goa",
  "Lakshadweep", "Puducherry", censusindia:::.merged_ut
)

test_that("annual series are smooth, which a misread digit would break", {
  for (d in list(population_projections_state, both$urban)) {
    d <- d[d$population > 1e6 & !d$state_name_harmonized %in% mathematical_method, ]
    d <- d[order(d$state_name_harmonized, d$year), ]
    growth <- stats::ave(log(d$population), d$state_name_harmonized, FUN = function(x) c(NA, diff(x)))
    jump <- stats::ave(growth, d$state_name_harmonized, FUN = function(x) c(NA, diff(x)))
    expect_lt(max(abs(growth), na.rm = TRUE), 0.08)
    expect_lt(max(abs(jump), na.rm = TRUE), 0.01)
  }
})

test_that("states add to India in each sector and year", {
  for (d in list(population_projections_state, both$urban, both$rural)) {
    s <- tapply(states_only(d)$population, states_only(d)$year, sum)
    i <- d[d$state_name_harmonized == "India", ]
    gap <- abs(s[as.character(i$year)] - i$population) / i$population
    expect_lt(max(gap), 0.0005)
  }
})

test_that("Telangana's known gap is the only urban-Census difference, and stays pinned", {
  expect_equal(urban("Telangana", 2011), 13731000)
  expect_equal(urban("Andhra Pradesh", 2011) + urban("Telangana", 2011) - 28219075, 121925)
  expect_equal(sum(states_only(both$urban[both$urban$year == 2011, ])$population) - urban("India", 2011), 120000)
})

test_that("the small UTs' extreme growth is the report's, and is known", {
  expect_equal(round(100 * rise("Daman & Diu") / state("Daman & Diu", 2011)), 710)
  expect_equal(round(100 * rise("Dadra & Nagar Haveli") / state("Dadra & Nagar Haveli", 2011)), 395)
  others <- setdiff(unique(population_projections_state$state_name_harmonized), mathematical_method)
  fast <- vapply(others, function(s) rise(s) / state(s, 2011), numeric(1))
  expect_lt(max(fast), 0.6)
})

test_that("big states keep their order", {
  top <- function(y) {
    d <- states_only(population_projections_state)
    d <- d[d$year == y, ]
    d$state_name_harmonized[which.max(d$population)]
  }
  for (y in c(2011, 2021, 2036)) expect_identical(top(y), "Uttar Pradesh")
  expect_gt(state("Bihar", 2036), state("West Bengal", 2036))
})

# Districts against states -----------------------------------------------------------

test_that("IIPS districts stay close to their state totals", {
  d <- population_projections_district
  s <- stats::aggregate(population ~ year + state_name_harmonized, d, sum)
  j <- merge(s, population_projections_state, by = c("year", "state_name_harmonized"))
  expect_gte(length(unique(j$state_name_harmonized)), 36)
  expect_lt(max(abs(j$population.x / j$population.y - 1)), 0.02)
})

test_that("district projections start from the 2011 Census", {
  d <- population_projections_district[population_projections_district$year == 2011, ]
  expect_equal(sum(d$population), 1210854977, tolerance = 1e-5)
  j <- merge(d, census_2011_pca, by = c("state_name_harmonized", "district"), suffixes = c("", ".c"))
  expect_gt(nrow(j), 600)
  # Lakshadweep is printed in thousands
  expect_lt(max(abs(j$population / j$population.c - 1)), 0.01)
})

test_that("district growth and sex ratios are plausible", {
  d <- population_projections_district
  a <- d[d$year == 2011, ]
  b <- d[d$year == 2031, ]
  j <- merge(a, b, by = c("state_name_harmonized", "district"), suffixes = c("_11", "_31"))
  expect_equal(nrow(j), 640)
  rate <- (j$population_31 / j$population_11)^(1 / 20) - 1
  expect_gt(stats::median(rate), 0.005)
  expect_lt(stats::median(rate), 0.015)
  expect_gt(mean(rate > -0.01 & rate < 0.04), 0.98)
  # male and female growth rates diverge in these units
  ok <- d[!d$state_name_harmonized %in% mathematical_method, ]
  sr <- sex_ratio(ok$females, ok$males)
  expect_true(all(sr > 600 & sr < 1350))
  expect_lt(stats::quantile(abs(sex_ratio(j$females_31, j$males_31) - sex_ratio(j$females_11, j$males_11)), 0.95), 60)
  expect_gt(stats::cor(j$population_11, j$population_31, method = "spearman"), 0.97)
})

# Below district -------------------------------------------------------------------

test_that("the full table has clean rows", {
  x <- pp()
  expect_false(anyNA(x$population))
  expect_false(anyNA(x$males))
  expect_true(all(x$population >= 0 & x$males >= 0 & x$females >= 0))
  expect_true(all(x$population == round(x$population)))
  expect_setequal(x$geography, c("india", "state", "district", "subdistrict", "village"))
  key <- c("year", "geography", "sector", "state_name_harmonized", "district", "subdistrict", "town_village_code")
  expect_equal(nrow(dplyr::distinct(x[key])), nrow(x))
  local <- x[x$geography %in% c("district", "subdistrict", "village"), ]
  expect_equal(local$population, local$males + local$females)
})

test_that("each level has the right number of units", {
  n <- function(g, s) nrow(level(g, s, 2031))
  expect_equal(n("district", "total"), 640)
  expect_equal(n("subdistrict", "total"), 5988)
  expect_equal(n("village", "rural"), 640949)
  expect_equal(n("state", "total"), 37)
  expect_equal(nrow(level("village", "total", 2031)), 0)
  expect_equal(nrow(level("village", "urban", 2031)), 0)
})

test_that("rural and urban add to the total in every unit and year", {
  for (g in c("district", "subdistrict")) {
    key <- c("year", "state_name_harmonized", "district", if (g == "subdistrict") "subdistrict")
    r <- level(g, "rural")[c(key, "population")]
    u <- level(g, "urban")[c(key, "population")]
    t <- level(g, "total")[c(key, "population")]
    j <- merge(merge(r, u, by = key, suffixes = c(".r", ".u")), t, by = key)
    expect_equal(nrow(j), nrow(t), label = g)
    expect_equal(j$population.r + j$population.u, j$population, label = g)
  }
})

test_that("every level gives about the same national totals", {
  for (y in c(2011, 2021, 2031)) {
    for (s in c("total", "rural", "urban")) {
      ref <- sum(level("state", s, y)$population)
      for (g in c("district", "subdistrict", if (s == "rural") "village")) {
        expect_lt(abs(sum(level(g, s, y)$population) / ref - 1), 0.005, label = paste(y, s, g))
      }
    }
  }
})

test_that("in 2011 every level returns the Census", {
  census <- census_2011_demographics()
  expect_equal(sum(level("district", "total", 2011)$population), 1210854977, tolerance = 1e-6)
  a <- level("subdistrict", "total", 2011)
  expect_equal(sum(a$population), sum(census_subdistricts_2011$population), tolerance = 1e-6)
  v <- level("village", "rural", 2011)
  c11 <- at_level(census, "village", "rural")
  j <- merge(v, c11, by = "town_village_code", suffixes = c("", ".c"))
  j <- j[j$name == j$name.c, ]
  expect_gt(stats::cor(j$population, j$population.c), 0.999)
  # villages move only by the small urban-target adjustment
  big <- j[j$population.c > 1000, ]
  expect_lt(stats::quantile(abs(big$population / big$population.c - 1), 0.99), 0.02)
})

test_that("rural and urban districts in 2011 match the Census split", {
  d <- census_2011_demographics()
  pca <- census_2011_pca
  u <- at_level(d, "district", "urban")
  u$district <- pca$district[match(u$district_code, pca$district_code)]
  x <- level("district", "urban", 2011)
  j <- merge(x, u, by = "district", suffixes = c("", ".c"))
  j <- j[j$state_name_harmonized != "Telangana" & j$state_name_harmonized == j$state_name_harmonized.c, ]
  expect_gt(nrow(j), 550)
  big <- j[j$population.c > 1e5, ]
  expect_lt(max(abs(big$population / big$population.c - 1)), 0.03)
})

test_that("urbanisation rises at every level", {
  for (g in c("district", "subdistrict")) {
    shares <- vapply(c(2011, 2021, 2031), share_of_urban, numeric(1), g = g)
    expect_true(all(diff(shares) > 0), label = g)
  }
  expect_equal(share_of_urban(2011, "district"), 0.3114, tolerance = 0.005)
  expect_equal(share_of_urban(2031, "district"), 0.375, tolerance = 0.03)
})

test_that("wholly urban districts stay urban", {
  rural <- level("district", "rural")
  for (d in c("Mumbai", "Kolkata", "Chennai", "Hyderabad", "Mumbai Suburban")) {
    x <- rural[rural$district == d, ]
    expect_equal(nrow(x), 5, label = d)
    expect_true(all(x$population == 0), label = d)
  }
})

test_that("wholly rural units stay rural", {
  b <- censusindia:::subdistrict_base("urban_rural")
  rural_only <- b[b$urban_males + b$urban_females == 0, ]
  expect_gt(nrow(rural_only), 1000)
  u <- level("subdistrict", "urban", 2031)
  j <- merge(rural_only, u, by = c("state_name_harmonized", "district", "subdistrict"))
  expect_equal(nrow(j), nrow(rural_only))
  expect_true(all(j$population == 0))
})

test_that("constant shares give every subdistrict its district's growth", {
  x <- level("subdistrict", "total")
  a <- x[x$year == 2011, ]
  b <- x[x$year == 2031, ]
  j <- merge(a, b, by = c("state_name_harmonized", "district", "subdistrict"), suffixes = c("_a", "_b"))
  j <- j[j$population_a > 10000, ]
  g <- j$population_b / j$population_a
  spread <- stats::ave(g, j$state_name_harmonized, j$district, FUN = function(v) max(v) - min(v))
  # males and females can grow at different rates
  expect_lt(stats::quantile(spread, 0.99), 0.05)
})

test_that("subdistricts keep their rank", {
  x <- level("subdistrict", "total")
  j <- merge(x[x$year == 2011, ], x[x$year == 2031, ],
    by = c("state_name_harmonized", "district", "subdistrict")
  )
  expect_gt(stats::cor(j$population.x, j$population.y, method = "spearman"), 0.97)
  expect_lt(max(j$population.y), 2e7)
})

test_that("no village or subdistrict is larger than its parent", {
  sd <- level("subdistrict", "total", 2031)
  d <- level("district", "total", 2031)
  j <- merge(sd, d, by = c("state_name_harmonized", "district"), suffixes = c("", ".d"))
  expect_true(all(j$population <= j$population.d + 5))
  v <- level("village", "rural", 2031)
  r <- level("subdistrict", "rural", 2031)
  i <- match(
    paste(v$state_name_harmonized, v$district, v$subdistrict),
    paste(r$state_name_harmonized, r$district, r$subdistrict)
  )
  expect_false(anyNA(i))
  expect_true(all(v$population <= r$population[i] + 5))
  expect_lt(max(v$population), 2e5)
})

test_that("villages add to their subdistrict's rural rows everywhere", {
  v <- level("village", "rural", 2031)
  r <- level("subdistrict", "rural", 2031)
  s <- v |>
    dplyr::group_by(state_name_harmonized, district, subdistrict) |>
    dplyr::summarise(villages = sum(population), n = dplyr::n(), .groups = "drop")
  j <- merge(r, s, by = c("state_name_harmonized", "district", "subdistrict"))
  expect_true(all(abs(j$population - j$villages) <= j$n + 2))
})

test_that("sex ratios below district stay plausible", {
  x <- level("subdistrict", "total", 2031)
  x <- x[x$population > 10000, ]
  sr <- sex_ratio(x$females, x$males)
  expect_gt(stats::quantile(sr, 0.01), 700)
  expect_lt(stats::quantile(sr, 0.99), 1250)
  expect_equal(stats::median(sr), 950, tolerance = 0.05)
})

# Same answer however you ask --------------------------------------------------------

test_that("a state filter returns exactly the rows of the full table", {
  x <- pp()
  for (s in c("Kerala", "Telangana", "Delhi", "Ladakh")) {
    a <- suppressMessages(population_projections(state = s))
    b <- x[x$state_name_harmonized == s, ]
    expect_equal(nrow(a), nrow(b), label = s)
    expect_equal(sum(a$population), sum(b$population), label = s)
  }
})

test_that("year, sector and geography filters return the rows of the full table", {
  x <- pp()
  a <- population_projections("district", "rural", 2021)
  b <- level("district", "rural", 2021)
  key <- c("state_name_harmonized", "district")
  j <- merge(a, b, by = key, suffixes = c("", ".b"))
  expect_equal(nrow(j), 640)
  expect_equal(j$population, j$population.b)
  v <- population_projections("village", "rural", 2021, state = "GA")
  w <- x[x$geography == "village" & x$year == 2021 & x$state_name_harmonized == "Goa", ]
  expect_equal(sum(v$population), sum(w$population))
})

test_that("population_projections() and get_population() agree", {
  x <- population_projections("district", "total", 2021)
  expect_equal(sum(x$population), sum(get_population(2021, "district")$population))
  skip_if_no_remote()
  a <- population_projections("subdistrict", "total", 2021, state = "KL", method = "urban_rural")
  b <- get_population(2021, "subdistrict", state = "KL", method = "urban_rural")
  expect_equal(sort(a$population), sort(b$population))
})

test_that("an interpolated year lies between its neighbours at every level", {
  skip_if_no_remote()
  x <- suppressMessages(population_projections(c("district", "subdistrict"), "total", c(2021, 2023, 2026), state = "UP"))
  key <- c("geography", "district", "subdistrict")
  mid <- x[x$year == 2023, ]
  lo <- x[x$year == 2021, ]
  hi <- x[x$year == 2026, ]
  j <- merge(merge(mid, lo, by = key, suffixes = c("", ".lo")), hi, by = key, suffixes = c("", ".hi"))
  expect_equal(nrow(j), nrow(mid))
  low <- pmin(j$population.lo, j$population.hi) - 2
  high <- pmax(j$population.lo, j$population.hi) + 2
  expect_true(all(j$population >= low & j$population <= high))
  expect_identical(unique(mid$estimate), "interpolated")
})

test_that("estimate labels say what is printed and what is derived", {
  x <- pp()
  x <- x[x$year == 2021, ]
  label <- function(g, s) unique(x$estimate[x$geography == g & x$sector == s])
  expect_identical(label("state", "total"), "published")
  expect_identical(label("state", "urban"), "published")
  expect_identical(label("state", "rural"), "derived")
  expect_identical(label("district", "total"), "published")
  expect_identical(label("district", "urban"), "derived")
  expect_identical(label("subdistrict", "total"), "derived")
  expect_identical(label("village", "rural"), "derived")
})

# The back-test behind the default ---------------------------------------------------------

test_that("the back-test behind the default method still holds", {
  script <- test_path("..", "..", "data-raw", "backtest-2001-2011.R")
  skip_if_not(file.exists(script), "data-raw is not in the built package")
  skip_if_no_remote()
  source(script, local = TRUE)
  j <- backtest_subdistrict_methods()
  expect_equal(nrow(j), 106)
  expect_equal(length(unique(j$state_name_harmonized)), 10)
  expect_equal(100 * mean(j$error_constant_share), 7.0, tolerance = 0.01)
  expect_equal(100 * mean(j$error_urban_rural), 8.9, tolerance = 0.01)
})
