pop_cols <- c("population", "males", "females")

test_that("census_subdistricts_2011 covers every 2011 subdistrict", {
  s <- census_subdistricts_2011
  expect_equal(nrow(s), 5988)
  expect_false(anyNA(s[c(pop_cols, "households")]))
})

test_that("census_subdistricts_2011 matches census_2011_demographics", {
  skip_if_no_remote()
  d <- at_level(census_2011_demographics(), "sub-district")
  s <- census_subdistricts_2011
  expect_setequal(
    paste(s$state_name_harmonized, s$population, s$males, s$females),
    paste(d$state_name_harmonized, d$population_total, d$population_male, d$population_female)
  )
})

test_that("census_1971 empty sectors are 0 and only Madras stays NA", {
  x <- census_1971
  cols <- paste0(rep(pop_cols, each = 3), c("_total", "_rural", "_urban"))
  na <- x[!stats::complete.cases(x[cols]), ]
  expect_equal(na$name, "Madras")
  bombay <- x[x$name == "Greater Bombay", ]
  expect_equal(bombay$population_rural, 0)
  ok <- x[x$name != "Madras", ]
  for (v in pop_cols) {
    expect_equal(ok[[paste0(v, "_rural")]] + ok[[paste0(v, "_urban")]], ok[[paste0(v, "_total")]])
  }
})

test_that("census_1981 empty district sectors are 0", {
  x <- census_1981
  pick <- function(d, s) with(at_level(x, "district", s), total_persons[district == d])
  expect_equal(pick("Greater Bombay", "rural"), 0)
  expect_equal(pick("Madras", "rural"), 0)
  expect_equal(pick("Nicobars", "urban"), 0)
  expect_equal(pick("Phek", "urban"), 0)
  # 3 town and 4 urban-agglomeration rows have no figure
  expect_equal(sum(is.na(x$total_persons)), 7)
})

test_that("projection tables have no NA population", {
  for (x in list(
    population_projections_state, population_projections_state_age,
    population_projections_district, population_projections_district_lgd
  )) {
    expect_false(anyNA(x[pop_cols]))
  }
})

test_that("Moga and Tapi 2022-2026 totals equal the printed All ages", {
  # IIPS report, All ages rows of the 2022-2026 blocks: Moga p.132, Tapi p.1034
  printed <- data.frame(
    district = rep(c("Moga", "Tapi"), each = 5), year = rep(2022:2026, 2),
    males = c(571471, 574892, 578312, 581733, 585153, 473385, 479337, 485288, 491240, 497191),
    females = c(511475, 515004, 518532, 522061, 525589, 469619, 475129, 480639, 486135, 491645)
  )
  lgd <- merge(printed, population_projections_district_lgd, by = c("district", "year"))
  expect_equal(nrow(lgd), 10)
  expect_equal(lgd$males.y, lgd$males.x)
  expect_equal(lgd$females.y, lgd$females.x)
})

test_that("district age tables have no NA and Theni reproduces Table 8", {
  skip_if_no_remote()
  age <- population_projections_district_age()
  expect_false(anyNA(age[pop_cols]))
  expect_false(anyNA(population_projections_district_lgd_age()[pop_cols]))
  theni <- age[age$district == "Theni", ]
  tot <- stats::aggregate(cbind(males, females) ~ year, theni, sum)
  t8 <- population_projections_district[population_projections_district$district == "Theni", ]
  both <- merge(tot, t8, by = "year")
  expect_setequal(both$year, c(2016, 2021, 2026, 2031))
  tol <- 0.5 * length(unique(age$age_group)) # rounding
  expect_true(all(abs(both$males.x - both$males.y) <= tol))
  expect_true(all(abs(both$females.x - both$females.y) <= tol))

  # the PDF prints Madurai's numbers under Theni from 2017
  madurai <- age[age$district == "Madurai", ]
  m <- merge(theni, madurai, by = c("age_group", "year"))
  expect_false(any(m$year > 2016 & m$males.x == m$males.y & m$females.x == m$females.y))

  moga80 <- age[age$district == "Moga" & age$age_group == "80+", ]
  moga80 <- moga80[order(moga80$year), ]
  expect_true(all(diff(moga80$males) > 0))
})
