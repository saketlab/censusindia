# Contracts of the exported accessors.

id_prefix <- c("year", "geography", "sector", "state_code", "state_name_harmonized", "state_name")

# get_census() -----------------------------------------------------------

test_that("every advertised year and geography returns rows of that year and geography", {
  g <- list_census_geographies()
  for (i in seq_len(nrow(g))) {
    d <- get_census(g$year[i], g$geography[i])
    info <- paste(g$year[i], g$geography[i])
    expect_gt(nrow(d), 0)
    expect_true(all(d$year == g$year[i]), info = info)
    expect_true(all(d$geography == g$geography[i]), info = info)
  }
})

test_that("every year starts with the same identifier columns", {
  g <- list_census_geographies()
  for (i in seq_len(nrow(g))) {
    d <- get_census(g$year[i], g$geography[i])
    expect_identical(names(d)[1:6], id_prefix, info = paste(g$year[i], g$geography[i]))
  }
})

test_that("state frames carry no district columns", {
  for (y in c(1901, 1961, 1971, 1981, 1991, 2001, 2011)) {
    d <- get_census(y, "state")
    expect_false(any(c("district", "district_code", "subdistrict", "name") %in% names(d)), info = y)
  }
})

test_that("district frames carry a district column with no NA names", {
  for (y in c(1901, 1961, 1971, 1981, 1991, 2001, 2011)) {
    d <- get_census(y, "district")
    expect_true("district" %in% names(d), info = y)
    expect_false(anyNA(d$district), info = y)
    expect_false("name" %in% names(d), info = y)
  }
})

test_that("the 2011 subdistrict frame names both district and subdistrict", {
  d <- get_census(2011, "subdistrict")
  expect_equal(nrow(d), 5988)
  expect_true(all(c("district", "subdistrict") %in% names(d)))
  expect_false(anyNA(d$subdistrict))
})

test_that("sector is 'total' for years without a rural/urban split", {
  for (y in c(1901, 1951, 1961, 1991, 2001, 2011)) {
    expect_identical(unique(get_census(y, "state")$sector), "total", info = y)
  }
})

test_that("sector filters 1971 and 1981 and is returned as a column", {
  for (y in c(1971, 1981)) {
    for (s in c("rural", "urban")) {
      d <- get_census(y, "state", sector = s)
      expect_gt(nrow(d), 0)
      expect_identical(unique(d$sector), s, info = paste(y, s))
    }
  }
})

test_that("1971 rural and urban state populations add to the total where all three exist", {
  tot <- get_census(1971, "state")
  rur <- get_census(1971, "state", sector = "rural")
  urb <- get_census(1971, "state", sector = "urban")
  k <- "state_name_harmonized"
  m <- merge(merge(tot[c(k, "population")], rur[c(k, "population")], by = k, suffixes = c("", "_r")),
    urb[c(k, "population")],
    by = k, suffixes = c("", "_u")
  )
  m <- m[stats::complete.cases(m), ]
  expect_gt(nrow(m), 20)
  expect_equal(m$population_r + m$population_u, m$population)
})

test_that("bad year is an error naming the census years", {
  expect_error(get_census(2005, "state"), "Year must be one of")
  expect_error(get_census(2021, "state"), "Year must be one of")
})

test_that("an unknown geography is rejected by match.arg", {
  expect_error(get_census(2011, "village"), "should be one of")
  expect_error(get_census(2011, "district", sector = "suburban"), "should be one of")
})

test_that("a geography with no table for that year is an error", {
  expect_error(get_census(1961, "subdistrict"), "No data available")
  expect_error(get_census(2001, "subdistrict"), "No data available")
})

test_that("rural or urban is an error for years without a split", {
  for (y in c(1901, 1961, 1991, 2001, 2011)) {
    expect_error(get_census(y, "state", sector = "rural"), "1971 and 1981", info = y)
  }
  expect_error(get_census(2011, "district", sector = "urban"), "not available for 2011")
})

test_that("geometry for subdistrict is an error before any download", {
  expect_error(get_census(2011, "subdistrict", geometry = TRUE), "state and district level")
})

test_that("state= accepts canonical names", {
  d <- get_census(2011, "district", state = "Kerala")
  expect_identical(unique(d$state_name_harmonized), "Kerala")
  expect_equal(nrow(d), 14)
})

test_that("state= accepts two-letter codes in any case", {
  a <- get_census(2011, "district", state = "KL")
  b <- get_census(2011, "district", state = "kl")
  c <- get_census(2011, "district", state = "Kl")
  expect_identical(a, b)
  expect_identical(a, c)
  expect_identical(unique(a$state_name_harmonized), "Kerala")
})

test_that("state= takes a vector mixing names and codes", {
  d <- get_census(2011, "state", state = c("mh", "Kerala", "TN"))
  expect_setequal(d$state_name_harmonized, c("Maharashtra", "Kerala", "Tamil Nadu"))
  expect_equal(nrow(d), 3)
})

test_that("state= is case-insensitive on full names", {
  expect_identical(
    get_census(2011, "state", state = "west bengal")$state_name_harmonized,
    "West Bengal"
  )
})

test_that("state= passes through a historical spelling present in the data", {
  d <- get_census(1971, "state", state = "MYSORE")
  expect_equal(nrow(d), 1)
  expect_identical(d$state_name, "MYSORE")
})

test_that("unknown state is an error naming it", {
  expect_error(get_census(2011, "state", state = "Atlantis"), "Unknown state.*Atlantis")
  expect_error(get_census(2011, "state", state = c("Kerala", "Atlantis")), "Atlantis")
})

test_that("'Pradesh' is not substring matched", {
  expect_error(get_census(2011, "state", state = "Pradesh"), "Unknown state")
  expect_error(get_census(2011, "district", state = "Bengal"), "Unknown state")
})

test_that("state = 'India' on a table without a national row is an error", {
  expect_error(get_census(2011, "state", state = "India"), "No rows for")
})

test_that("variables= returns the identifier columns then the requested ones in order", {
  d <- get_census(2011, "district", variables = c("females", "population", "males"))
  ids <- intersect(names(get_census(2011, "district")), censusindia:::.id_cols)
  expect_identical(names(d), c(ids, "females", "population", "males"))
})

test_that("variables= does not change the row count", {
  expect_equal(
    nrow(get_census(2011, "district", variables = "population")),
    nrow(get_census(2011, "district"))
  )
})

test_that("sex_ratio is 1000 * females / males", {
  d <- get_census(2011, "state", variables = c("sex_ratio", "males", "females"))
  expect_equal(d$sex_ratio, 1000 * d$females / d$males)
  kl <- d[d$state_name_harmonized == "Kerala", ]
  expect_gt(kl$sex_ratio, 1000)
})

test_that("literacy_rate is 100 * literate / population for 2011", {
  d <- get_census(2011, "district", variables = c("literacy_rate", "literate", "population"))
  expect_equal(d$literacy_rate, 100 * d$literate / d$population)
  expect_true(all(d$literacy_rate > 0 & d$literacy_rate < 100))
})

test_that("sc_percent and st_percent are shares of population", {
  d <- get_census(2001, "state",
    variables = c("sc_percent", "st_percent", "sc_population", "st_population", "population")
  )
  expect_equal(d$sc_percent, 100 * d$sc_population / d$population)
  expect_equal(d$st_percent, 100 * d$st_population / d$population)
  expect_true(all(d$sc_percent >= 0 & d$sc_percent <= 100, na.rm = TRUE))
})

test_that("1971 derives sc_percent from its own sc_population", {
  d <- get_census(1971, "state", variables = c("sc_percent", "sc_population", "population"))
  expect_equal(d$sc_percent, 100 * d$sc_population / d$population)
})

test_that("1961 literacy_rate is read from the table, not derived", {
  d <- get_census(1961, "state", variables = "literacy_rate")
  raw <- census_1961_literacy[census_1961_literacy$geography == "state", ]
  expect_equal(
    d$literacy_rate[order(d$state_name_harmonized)],
    raw$literacy_rate[order(raw$state_name_harmonized)]
  )
  expect_true(all(d$literacy_rate <= 100, na.rm = TRUE))
})

test_that("1961 has no counts to request", {
  expect_error(get_census(1961, "district", variables = "population"), "not available")
  expect_error(get_census(1961, "district", variables = "literate"), "not available")
})

test_that("an unknown variable error lists what is available", {
  err <- tryCatch(get_census(2011, "district", variables = "nope"), error = identity)
  msg <- conditionMessage(err)
  expect_match(msg, "nope")
  expect_match(msg, "Available here")
  for (v in c("population", "literate", "sex_ratio", "literacy_rate")) expect_match(msg, v)
})

test_that("population_rural is no longer a variable; sector= replaces it", {
  expect_error(get_census(1971, "state", variables = "population_rural"), "not available")
})

test_that("2011 PCA route covers all 640 districts and the full population", {
  d <- get_census(2011, "district")
  expect_equal(nrow(d), 640)
  expect_equal(sum(d$population), 1210854977)
})

# get_population() -------------------------------------------------------

test_that("get_population() returns the requested years with a published estimate", {
  p <- get_population(c(2021, 2026), "state")
  expect_setequal(unique(p$year), c(2021L, 2026L))
  expect_identical(unique(p$estimate), "published")
  expect_type(p$year, "integer")
})

test_that("a year between district table years is interpolated geometrically", {
  p <- suppressMessages(get_population(c(2011, 2013, 2016), "district", state = "Kerala"))
  expect_identical(sort(unique(p$estimate)), c("interpolated", "published"))
  expect_true(all(p$estimate[p$year == 2013] == "interpolated"))
  a <- p[p$year == 2011, ]
  b <- p[p$year == 2016, ]
  m <- p[p$year == 2013, ]
  k <- match(m$district, a$district)
  expect_equal(m$population, round(a$population[k] * (b$population[k] / a$population[k])^(2 / 5)))
})

test_that("estimation announces itself", {
  expect_message(get_population(2013, "district", state = "KL"), "geometric growth")
})

test_that("years past the last table year are extrapolated up to five years", {
  p <- suppressMessages(get_population(2040, "state", state = "KL"))
  expect_identical(p$estimate, "extrapolated")
  expect_equal(nrow(p), 1)
  s <- population_projections_state[population_projections_state$state_name_harmonized == "Kerala", ]
  p35 <- s$population[s$year == 2035]
  p36 <- s$population[s$year == 2036]
  expect_equal(p$population, round(p35 * (p36 / p35)^5))
})

test_that("out-of-range years are errors naming the allowed range", {
  expect_error(get_population(2050), "from 2011 to 2041")
  expect_error(get_population(2005), "from 2011 to 2041")
  expect_error(suppressMessages(get_population(2037, "district")), "from 2011 to 2036")
})

test_that("non-integer years are an error", {
  expect_error(get_population(2011.5), "whole-number")
  expect_error(get_population(NA_real_), "whole-number")
})

test_that("year = NULL returns every table year", {
  expect_setequal(unique(get_population(geography = "district")$year), c(2011, 2016, 2021, 2026, 2031))
})

test_that("state projections have an India row tagged geography 'india'", {
  p <- get_population(2021, "state", state = "India")
  expect_equal(nrow(p), 1)
  expect_identical(p$geography, "india")
})

test_that("LA resolves to Ladakh in the projections", {
  p <- get_population(2021, "state", state = "LA")
  expect_identical(p$state_name_harmonized, "Ladakh")
  expect_identical(get_population(2021, "state", state = "ladakh"), p)
})

test_that("by_age state rows sum to the India total", {
  a <- get_population(2021, "state", by_age = TRUE, state = "India")
  t <- get_population(2021, "state", state = "India")
  expect_equal(nrow(a), 17)
  expect_true("age_group" %in% names(a))
  expect_equal(sum(a$population), t$population, tolerance = 1e-3)
})

test_that("by_age for a state outside the table's coverage points at the North-East row", {
  expect_error(get_population(2021, "state", by_age = TRUE, state = "Sikkim"), "North East States")
})

test_that("boundary = 'lgd' returns annual LGD districts", {
  p <- get_population(2021, "district", boundary = "lgd")
  expect_gt(nrow(p), 700)
  expect_identical(names(p)[1:5], c("year", "geography", "state_code", "state_name_harmonized", "district"))
  expect_setequal(unique(get_population(geography = "district", boundary = "lgd")$year), 2012:2031)
})

test_that("geometry with LGD boundaries warns and returns plain rows", {
  expect_warning(p <- get_population(2021, "district", boundary = "lgd", geometry = TRUE), "LGD")
  expect_false(inherits(p, "sf"))
})

test_that("bad geography or boundary is a match.arg error", {
  expect_error(get_population(2021, "village"), "should be one of")
  expect_error(get_population(2021, "district", boundary = "osm"), "should be one of")
})

# census_languages(), census_sc_st() ------------------------------------

test_that("census_languages() defaults to the total sector at district level", {
  l <- census_languages()
  expect_identical(unique(l$sector), "total")
  expect_identical(unique(l$geography), "district")
  expect_true(all(c("language_name", "language_group", "speakers") %in% names(l)))
})

test_that("census_languages() filters sector, language group, and state", {
  r <- census_languages("district", sector = "rural")
  expect_identical(unique(r$sector), "rural")
  g <- census_languages("district", language_group = 6)
  expect_identical(unique(g$language_group), 6L)
  expect_lt(nrow(g), nrow(census_languages()))
  ga <- census_languages("district", state = "GA")
  expect_identical(unique(ga$state_name_harmonized), "Goa")
  expect_setequal(unique(ga$district), c("North Goa", "South Goa"))
})

test_that("census_languages() rejects an unknown level, sector, or non-integer language_group", {
  expect_error(census_languages("state"), "should be one of")
  expect_error(census_languages(sector = "both"), "should be one of")
  expect_error(census_languages(language_group = "indo-aryan"), "whole-number")
})

test_that("census_sc_st() accepts either spelling in any case", {
  sc <- census_sc_st("SC")
  expect_identical(census_sc_st("sc"), sc)
  expect_identical(census_sc_st("Scheduled Caste"), sc)
  expect_identical(census_sc_st("scheduled castes"), sc)
  expect_identical(unique(sc$category_code), "SC")
  expect_equal(nrow(census_sc_st(c("SC", "ST"))), nrow(census_2011_sc_st))
})

test_that("census_sc_st() SC rows are one aggregate per district", {
  sc <- census_sc_st("SC")
  expect_identical(unique(sc$caste_tribe_name), "All Scheduled Castes")
  expect_false(any(duplicated(sc[c("state_name_harmonized", "district")])))
})

test_that("census_sc_st() rejects unknown categories and states", {
  expect_error(census_sc_st("OBC"), "Unknown category")
  expect_error(census_sc_st(state = "Atlantis"), "Unknown state")
})

test_that("census_sc_st(state=) filters by code", {
  d <- census_sc_st("ST", state = "kl")
  expect_identical(unique(d$state_name_harmonized), "Kerala")
  expect_identical(unique(d$category_code), "ST")
})

# at_level(), census_years() --------------------------------------------

test_that("at_level() returns one geography and one sector", {
  d <- at_level(census_1981, "state")
  expect_identical(unique(d$geography), "state")
  expect_identical(unique(d$sector), "total")
  u <- at_level(census_1981, "state", sector = "urban")
  expect_identical(unique(u$sector), "urban")
  expect_equal(nrow(u), nrow(d))
})

test_that("at_level() accepts the 'sub-district' spelling", {
  x <- data.frame(geography = c("district", "subdistrict", "subdistrict"), population = 1:3)
  expect_equal(nrow(at_level(x, "sub-district")), 2)
  expect_equal(nrow(at_level(x, "Sub District")), 2)
})

test_that("at_level() without a sector column filters only geography", {
  x <- data.frame(geography = c("state", "district"), population = 1:2)
  expect_equal(at_level(x, "state")$population, 1L)
})

test_that("at_level() rejects unknown levels and frames without geography", {
  expect_error(at_level(census_1981, "planet"), "must be one of")
  expect_error(at_level(data.frame(x = 1), "state"), "no .*geography")
})

test_that("census_years() keeps the twelve census years only", {
  d <- census_years(census_population_time_series)
  expect_setequal(unique(d$year), seq(1901, 2011, by = 10))
  expect_false(any(c(1900, 1948, 2021) %in% d$year))
  expect_error(census_years(data.frame(x = 1)), "no .*year")
})

# metadata helpers ------------------------------------------------------

test_that("list_states() filters by region, including multiple regions", {
  s <- list_states(region = "South")
  expect_true(all(s$region == "South"))
  expect_true(all(c("Kerala", "Tamil Nadu", "Karnataka") %in% s$state_name_harmonized))
  si <- list_states(region = c("South", "Islands"))
  expect_setequal(unique(si$region), c("South", "Islands"))
  expect_equal(nrow(list_states()), 36)
  expect_equal(nrow(list_states(region = "Nowhere")), 0)
})

test_that("list_states() regions partition the state list", {
  all <- list_states()
  n <- sum(vapply(unique(all$region), function(r) nrow(list_states(region = r)), integer(1)))
  expect_equal(n, nrow(all))
  expect_false(any(duplicated(all$state_abbr)))
})

test_that("search_census_variables() matches names and labels case-insensitively", {
  h <- search_census_variables("LITER")
  expect_true(all(c("literate", "literacy_rate") %in% h$variable))
  expect_true(all(grepl("liter", h$variable, ignore.case = TRUE) | grepl("liter", h$label, ignore.case = TRUE)))
  expect_equal(nrow(search_census_variables("zzzqqq")), 0)
})

test_that("list_census_variables() filters agree with census_variables rows, including multiple years", {
  v <- list_census_variables(year = 1981, geography = "district", category = "literacy")
  ref <- census_variables[census_variables$geography == "district" &
    census_variables$category == "literacy" &
    vapply(strsplit(census_variables$years, ","), function(y) "1981" %in% y, logical(1)), ]
  expect_setequal(v$variable, ref$variable)
  expect_gt(nrow(v), 0)

  v_multi <- list_census_variables(year = c(1961, 1971), geography = "state")
  v_1961 <- list_census_variables(year = 1961, geography = "state")
  v_1971 <- list_census_variables(year = 1971, geography = "state")
  expect_setequal(v_multi$variable, union(v_1961$variable, v_1971$variable))
})

test_that("list_census_variables() has one row per variable and geography", {
  v <- list_census_variables()
  expect_identical(v, census_variables)
  expect_false(any(duplicated(v[c("variable", "geography")])))
  expect_true(all(v$geography %in% c("state", "district", "subdistrict")))
})

test_that("each listed variable resolves through get_census() at a listed year", {
  v <- list_census_variables(year = 2011, geography = "state")
  d <- get_census(2011, "state", variables = v$variable)
  expect_true(all(v$variable %in% names(d)))
})

test_that("1961 lists only literacy rates", {
  v <- list_census_variables(year = 1961, geography = "district")
  expect_true(all(grepl("^literacy_rate", v$variable)))
})

test_that("sex_ratio() and share() compute per-1000 and percent", {
  expect_equal(sex_ratio(c(940, 1084), c(1000, 1000)), c(940, 1084))
  expect_equal(sex_ratio(1, 2), 500)
  expect_equal(share(c(1, 3), c(4, 4)), c(25, 75))
  expect_true(is.nan(share(0, 0)))
  expect_equal(sex_ratio(5, 0), Inf)
})
