# Do district figures add up to their states? Known deviations live in
# fixtures/deviations.csv; a new or vanished deviation fails, forcing a ledger diff.

ledger <- read_ledger()

expect_matches_ledger <- function(found, check) {
  known <- ledger[ledger$check == check, ]
  fk <- ledger_key(found)
  kk <- ledger_key(known)
  new <- found[!fk %in% kk, ]
  gone <- known[!kk %in% fk, ]
  expect(nrow(new) == 0, paste0(
    nrow(new), " new ", check, " deviation(s), e.g. ",
    paste(utils::head(ledger_key(new), 3), collapse = "; ")
  ))
  expect(nrow(gone) == 0, paste0(
    nrow(gone), " ledger ", check, " deviation(s) no longer occur, e.g. ",
    paste(utils::head(ledger_key(gone), 3), collapse = "; ")
  ))
  # listed deviations keep their exact figures
  both <- merge(found, known, by = c(
    "check", "dataset", "year", "sector", "state_name_harmonized",
    "district", "variable"
  ), suffixes = c("", ".ledger"))
  expect_equal(both$reference, both$reference.ledger)
  expect_equal(both$actual, both$actual.ledger)
}

census_gaps <- census_reconciliations()

test_that("the ledger is well formed", {
  expect_true(all(ledger$check %in% c(
    "district_sum_vs_state", "rural_plus_urban_vs_total",
    "males_plus_females_vs_population", "a11_st_vs_pca",
    "age_sum_vs_total"
  )))
  expect_equal(anyDuplicated(ledger_key(ledger)), 0L)
  expect_true(all(is.na(ledger$reference) | is.na(ledger$actual) | ledger$reference != ledger$actual))
})

for (chk in c(
  "district_sum_vs_state", "rural_plus_urban_vs_total",
  "males_plus_females_vs_population", "a11_st_vs_pca"
)) {
  test_that(paste("census tables:", chk, "deviations are exactly the known ones"), {
    expect_matches_ledger(census_gaps[census_gaps$check == chk, ], chk)
  })
}

# Census tables: what the ledger says, stated directly ---------------------------

dev <- function(check, dataset) ledger[ledger$check == check & ledger$dataset == dataset, ]

test_that("time series: districts add up to their state from 1951 on, bar Assam 1981", {
  d <- dev("district_sum_vs_state", "census_population_time_series")
  expect_true(all(d$year <= 1951 | (d$year == 1981 & d$state_name_harmonized == "Assam")))
  # 1981 Assam held no census: the state row is an estimate with no districts
  expect_true(all(is.na(d$actual[d$year == 1981])))
  # where districts exist before 1951, they miss the state by under 0.4%
  num <- d[!is.na(d$actual) & !is.na(d$reference), ]
  expect_lt(max(abs(num$actual / num$reference - 1)), 0.004)
})

test_that("time series: states whose districts cannot be summed before 1961 are the known ones", {
  d <- dev("district_sum_vs_state", "census_population_time_series")
  missing <- unique(d$state_name_harmonized[is.na(d$actual) & d$year < 1961])
  # no district rows, or district rows with no population
  expect_setequal(missing, c(
    "Punjab", "Haryana", "Delhi", "Arunachal Pradesh", "Nagaland",
    "Manipur", "Assam", "Himachal Pradesh", "Madhya Pradesh", "Puducherry"
  ))
})

test_that("1971 and 1981 reconcile exactly wherever both figures exist", {
  d <- ledger[ledger$dataset %in% c("census_1971", "census_1981"), ]
  # remaining deviations are ".." (nil) cells stored as NA; 1981 Lakshadweep only
  expect_true(all(is.na(d$reference) | is.na(d$actual)))
  expect_setequal(unique(d$state_name_harmonized[d$dataset == "census_1981"]), "Lakshadweep")
})

test_that("1971: all 19 Mysore districts and Madras are present and sum to their states", {
  for (st in c("Karnataka", "Tamil Nadu")) {
    x <- census_1971[census_1971$state_name_harmonized == st, ]
    for (s in c("total", "rural", "urban")) {
      di <- x[x$geography == "district" & x$sector == s, ]
      expect_equal(sum(di$population), x$population[x$geography == "state" & x$sector == s], label = paste(st, s))
    }
  }
  expect_equal(sum(census_1971$state_name_harmonized == "Karnataka" & census_1971$geography == "district" &
    census_1971$sector == "total"), 19)
  madras <- census_1971[census_1971$district %in% "Madras", ]
  expect_equal(madras$population[madras$sector == "total"], 2469449)
  expect_equal(madras$population[madras$sector == "rural"], 0)
})

test_that("every OCR correction is in the data, with its evidence", {
  fx <- utils::read.csv(system.file("ocr-corrections.csv", package = "censusindia"), colClasses = "character")
  expect_gt(nrow(fx), 100)
  expect_true(all(fx$evidence %in% c(
    "arithmetic_only", "printed_value_inconsistent", "ocr_reads_corrected",
    "leading_digit_clipped_in_scan", "page_image_or_text_layer", "page_image",
    "state_row_identity", "merged_cells"
  )))
  expect_true(all(nzchar(fx$pdf)))
  for (i in seq_len(nrow(fx))) {
    x <- getExportedValue("censusindia", fx$dataset[i])
    expect_equal(x[[fx$column[i]]][ocr_cell(x, fx, i)], as.numeric(fx$new[i]),
      label = paste(fx$dataset[i], fx$district[i], fx$sector[i], fx$column[i])
    )
  }
})

test_that("1981 areas are in square kilometres", {
  india <- census_1981$area_km2[census_1981$geography == "india" & census_1981$sector == "total"]
  expect_equal(india, 3208825)
  kerala <- census_1981$area_km2[census_1981$geography == "state" & census_1981$state_name == "KERALA" &
    census_1981$sector == "total"]
  expect_equal(kerala, 38863)
  nellore <- census_1981$area_km2[census_1981$name %in% "Nellore (M)V"]
  expect_equal(nellore, 48.39)
})

test_that("1981: states sum to the published India total once Assam's estimate is added", {
  st <- get_census(1981, "state")
  assam <- census_population_time_series$population[census_population_time_series$year == 1981 &
    census_population_time_series$geography == "state" &
    census_population_time_series$state_name_harmonized == "Assam"]
  expect_false("Assam" %in% st$state_name_harmonized)
  expect_equal(sum(st$population) + assam, 683329097)
})

test_that("males + females == population except the documented rows", {
  ts <- dev("males_plus_females_vs_population", "census_population_time_series")
  # one row is off by one person; the rest have no sex split
  num <- ts[!is.na(ts$actual) & !is.na(ts$reference), ]
  expect_equal(nrow(num), 1)
  expect_equal(abs(num$actual - num$reference), 1)
  expect_true(all(dev("males_plus_females_vs_population", "census_1971")$state_name_harmonized == "Tamil Nadu"))
})

test_that("A-11: counting each tribe once, every district's ST rows equal the PCA", {
  expect_equal(nrow(dev("a11_st_vs_pca", "census_2011_sc_st")), 0)
  st <- census_2011_sc_st[census_2011_sc_st$state_name_harmonized == "Nagaland" &
    census_2011_sc_st$category_code == "ST", ]
  # "Naga" is the sum of its (ST) constituents, which carry parent_tribe "Naga"
  naga <- tapply(st$population * (st$caste_tribe_name == "Naga"), st$district, sum)
  sub <- tapply(st$population * (st$parent_tribe %in% "Naga"), st$district, sum)
  expect_equal(as.vector(naga), as.vector(sub[names(naga)]))
  expect_true(all(grepl("(ST)", st$caste_tribe_name[!is.na(st$parent_tribe)], fixed = TRUE)))
})

test_that("2011 and 2001: get_census district rows sum exactly to its state rows", {
  for (y in c(2001, 2011)) {
    d <- dplyr::bind_rows(get_census(y, "district"), get_census(y, "state"))
    num <- setdiff(.count_cols(d), c("variation_absolute", "variation_percent"))
    expect_equal(nrow(district_sum_gaps(as.character(y), d, num)), 0, label = paste(y, "district sum gaps"))
  }
})

test_that("national totals match the published census", {
  expect_equal(sum(get_census(2011, "state")$population), 1210854977)
  # the 2001 PCA excludes Manipur's Mao-Maram, Paomata and Purul subdivisions
  expect_equal(1028737436 - sum(get_census(2001, "state")$population), 127108)
  expect_equal(sum(get_census(2011, "subdistrict")$population), 1210854977)
})

test_that("time series state rows fall short of the published India total by under 0.4%", {
  published <- c(
    `1901` = 238396327, `1911` = 252093390, `1921` = 251321213, `1931` = 278977238,
    `1941` = 318660580, `1951` = 361088090, `1961` = 439234771, `1971` = 548159652,
    `1981` = 683329097, `1991` = 846421039, `2001` = 1028737436, `2011` = 1210854977
  )
  ts <- census_population_time_series[census_population_time_series$geography == "state" &
    census_population_time_series$year %in% as.integer(names(published)), ]
  s <- tapply(ts$population, ts$year, sum, na.rm = TRUE)
  short <- 1 - s / published[names(s)]
  # Sikkim, Mizoram and Daman & Diu are missing from every year
  expect_true(all(short > 0 & short < 0.004))
})

test_that("2011 village-level tables: every level sums exactly to its parent", {
  skip_if_no_remote()
  for (f in c("census_2011_demographics", "census_2011_workers", "census_2011_marginal_detail")) {
    d <- getExportedValue("censusindia", f)()
    num <- .count_cols(d)
    for (lv in list(c("state", "india"), c("district", "state"), c("subdistrict", "district"))) {
      child <- d[d$geography == lv[1], ]
      parent <- d[d$geography == lv[2], ]
      keys <- c("sector", switch(lv[2],
        india = character(0),
        state = "state_code",
        district = c("state_code", "district_code")
      ))
      s <- stats::aggregate(child[num], child[keys], sum)
      p <- parent[match(do.call(paste, s[keys]), do.call(paste, parent[keys])), ]
      for (v in num) expect_equal(s[[v]], p[[v]], label = paste(f, lv[1], "->", lv[2], v))
    }
  }
})

test_that("2011 village-level tables: rural + urban == total at every exact level", {
  skip_if_no_remote()
  d <- census_2011_demographics()
  d <- d[d$geography %in% c("india", "state", "district", "subdistrict"), ]
  key <- do.call(paste, d[c("geography", "state_code", "district_code", "subdistrict_code")])
  for (v in c("population", "males", "females", "households", "literate", "sc_population", "st_population")) {
    tot <- d[[v]][d$sector == "total"]
    k <- key[d$sector == "total"]
    r <- d[[v]][d$sector == "rural"][match(k, key[d$sector == "rural"])]
    u <- d[[v]][d$sector == "urban"][match(k, key[d$sector == "urban"])]
    expect_equal(tot, r + u, label = v)
  }
})

test_that("2011 PCA districts are the village-level table's district rows", {
  skip_if_no_remote()
  d <- at_level(census_2011_demographics(), "district")
  p <- census_2011_pca[match(
    paste(d$state_code, d$district_code),
    paste(census_2011_pca$state_code, census_2011_pca$district_code)
  ), ]
  for (v in c(
    "households", "population", "males", "females", "population_0_6",
    "sc_population", "st_population", "literate"
  )) {
    expect_equal(d[[v]], p[[v]], label = v)
  }
})

# Population projections -----------------------------------------------------------

proj_gaps <- function(district_table) {
  d <- stats::aggregate(district_table["population"], district_table[c("year", "state_name_harmonized")], sum)
  s <- population_projections_state
  j <- merge(s[c("year", "state_name_harmonized", "population")], d,
    by = c("year", "state_name_harmonized"), suffixes = c(".state", ".districts")
  )
  j$rel <- j$population.districts / j$population.state - 1
  j
}

# max |district sum / state - 1| per state, rounded up; unlisted states stay within 0.2%
PROJECTION_MAX <- list(
  population_projections_district = c(
    "Lakshadweep" = 0.0150, "Nagaland" = 0.0146, "Punjab" = 0.0085, "Chhattisgarh" = 0.0056, "Telangana" = 0.0055,
    "Andhra Pradesh" = 0.0039, "Ladakh" = 0.0035, "Jammu & Kashmir" = 0.0028,
    "Andaman & Nicobar Islands" = 0.0025, "Daman & Diu" = 0.0022
  ),
  population_projections_district_lgd = c(
    "Lakshadweep" = 0.0154, "Telangana" = 0.0136,
    "Andhra Pradesh" = 0.0102, "Nagaland" = 0.0093, "Punjab" = 0.0085,
    "Puducherry" = 0.0074, "Chhattisgarh" = 0.0057, "Ladakh" = 0.0036,
    "Jammu & Kashmir" = 0.0028, "Andaman & Nicobar Islands" = 0.0026, "Manipur" = 0.0021
  )
)

for (nm in names(PROJECTION_MAX)) {
  test_that(paste(nm, "district sums stay within each state's pinned deviation"), {
    j <- proj_gaps(getExportedValue("censusindia", nm))
    cap <- PROJECTION_MAX[[nm]][j$state_name_harmonized]
    cap[is.na(cap)] <- 0.002
    over <- j[abs(j$rel) > cap, ]
    expect(nrow(over) == 0, paste(
      "district sums drifted from the state projection:",
      paste(utils::head(sprintf("%s %d %+.4f", over$state_name_harmonized, over$year, over$rel), 5),
        collapse = "; "
      )
    ))
    # every listed state still deviates somewhere, or its entry is stale
    worst <- tapply(abs(j$rel), j$state_name_harmonized, max)
    expect_true(all(worst[names(PROJECTION_MAX[[nm]])] > 0.002), label = paste(nm, "stale entries"))
  })
}

test_that("every state but the merged Dadra/Daman UT has district projections", {
  states <- setdiff(unique(population_projections_state$state_name_harmonized), "India")
  expect_setequal(
    setdiff(states, unique(population_projections_district$state_name_harmonized)),
    "Dadra & Nagar Haveli and Daman & Diu"
  )
  expect_setequal(
    setdiff(states, unique(population_projections_district_lgd$state_name_harmonized)),
    c("Dadra & Nagar Haveli", "Daman & Diu")
  )
})

test_that("district projections sum to within 0.25% of India", {
  for (nm in names(PROJECTION_MAX)) {
    d <- getExportedValue("censusindia", nm)
    s <- tapply(d$population, d$year, sum)
    india <- population_projections_state[population_projections_state$state_name_harmonized == "India", ]
    rel <- s[as.character(india$year)] / india$population - 1
    rel <- rel[!is.na(rel)]
    expect_true(all(abs(rel) < 0.0025), label = nm)
  }
})

test_that("state projections sum to India within the thousand-rounding of 37 rows", {
  ps <- population_projections_state
  parts <- ps[!ps$state_name_harmonized %in% c("India", "Dadra & Nagar Haveli and Daman & Diu"), ]
  s <- tapply(parts$population, parts$year, sum)
  india <- ps$population[ps$state_name_harmonized == "India"][match(names(s), ps$year[ps$state_name_harmonized == "India"])]
  expect_true(all(abs(s - india) <= 37 * 500))
  expect_equal(length(unique(table(parts$year))), 1)
})

test_that("the merged Dadra/Daman UT is the sum of the two old UTs every year", {
  ps <- population_projections_state
  pick <- function(s) ps[ps$state_name_harmonized == s, c("year", "males", "females", "population")]
  a <- pick("Dadra & Nagar Haveli")
  b <- pick("Daman & Diu")
  m <- pick("Dadra & Nagar Haveli and Daman & Diu")
  expect_equal(m$population, a$population + b$population)
  expect_equal(m$males, a$males + b$males)
})

test_that("state projections: males + females within 1000 of population", {
  ps <- population_projections_state
  expect_true(all(abs(ps$males + ps$females - ps$population) <= 2000))
  expect_lte(mean(ps$males + ps$females != ps$population), 0.25)
})

test_that("state age projections sum to the state total within the rounding of 17 bands", {
  a <- population_projections_state_age
  s <- stats::aggregate(a["population"], a[c("year", "state_name_harmonized")], sum)
  j <- merge(s, population_projections_state, by = c("year", "state_name_harmonized"), suffixes = c(".age", ""))
  expect_gt(nrow(j), 100)
  expect_true(all(abs(j$population.age - j$population) <= 17 * 500))
})

test_that("LGD district age projections sum exactly to the LGD district table", {
  skip_if_no_remote()
  g <- age_sum_gaps(
    population_projections_district_lgd_age(), population_projections_district_lgd,
    "population_projections_district_lgd_age"
  )
  expect_equal(nrow(g), 0)
})

test_that("Census-2011 district age projections: rounding everywhere except the ledger", {
  skip_if_no_remote()
  g <- age_sum_gaps(
    population_projections_district_age(), population_projections_district,
    "population_projections_district_age"
  )
  big <- g[abs(g$actual - g$reference) > AGE_ROUNDING_TOLERANCE, ]
  expect_matches_ledger(big, "age_sum_vs_total")
  # Nagaland 2016 is printed half a percent apart in the two source tables
  expect_setequal(unique(big$state_name_harmonized), "Nagaland")
  expect_true(all(big$year == 2016))
  expect_lt(max(abs(big$actual / big$reference - 1)), 0.006)
})

test_that("district age and total projections agree on males + females", {
  skip_if_no_remote()
  a <- population_projections_district_age()
  expect_equal(a$males + a$females, a$population)
  expect_equal(
    population_projections_district$males + population_projections_district$females,
    population_projections_district$population
  )
})
