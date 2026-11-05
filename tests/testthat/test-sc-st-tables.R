test_that("both the long form and the short code are available", {
  expect_setequal(
    unique(census_2011_sc_st$category),
    c("Scheduled Caste", "Scheduled Tribe")
  )
  expect_setequal(unique(census_2011_sc_st$category_code), c("SC", "ST"))
  expect_equal(
    census_2011_sc_st$category_code == "SC",
    census_2011_sc_st$category == "Scheduled Caste"
  )
  # category holds full names, so "SC" needs category_code
  expect_equal(nrow(dplyr::filter(census_2011_sc_st, .data$category == "SC")), 0)
  expect_equal(nrow(dplyr::filter(census_2011_sc_st, .data$category_code == "SC")), 582)
})

test_that("census_sc_st accepts either spelling in any case", {
  n_sc <- 582
  n_st <- 13446
  for (x in c("SC", "sc", "Scheduled Caste", "scheduled castes", "SCHEDULED CASTE")) {
    expect_equal(nrow(census_sc_st(x)), n_sc, label = x)
  }
  for (x in c("ST", "st", "Scheduled Tribe", "scheduled tribes")) {
    expect_equal(nrow(census_sc_st(x)), n_st, label = x)
  }
  expect_equal(nrow(census_sc_st()), n_sc + n_st)
  expect_equal(nrow(census_sc_st(c("SC", "ST"))), n_sc + n_st)
  # a vector of mixed spellings resolves to one code
  expect_equal(nrow(census_sc_st(c("SC", "Scheduled Caste"))), n_sc)
})

test_that("census_sc_st rejects an unknown category and filters by state", {
  expect_error(census_sc_st("OBC"), "Unknown categor")
  expect_error(census_sc_st("General"))
  mh <- census_sc_st("ST", state = "Maharashtra")
  expect_gt(nrow(mh), 0)
  expect_true(all(mh$state_name_harmonized == "Maharashtra"))
  expect_equal(nrow(census_sc_st("ST", state = "MH")), nrow(mh))
})

test_that("Scheduled Castes are an aggregate, not individual castes", {
  sc <- dplyr::filter(census_2011_sc_st, .data$category == "Scheduled Caste")
  expect_equal(unique(sc$caste_tribe_name), "All Scheduled Castes")
  expect_equal(nrow(sc), 582)
})

test_that("tribes is sc_st's ST rows minus the Generic Tribes residual", {
  st <- dplyr::filter(census_2011_sc_st, .data$category == "Scheduled Tribe")
  generic <- dplyr::filter(st, .data$caste_tribe_name == "Generic Tribes etc.")

  expect_equal(nrow(generic), 585)
  expect_equal(sum(generic$population), 2804148)
  expect_equal(nrow(st) - nrow(generic), nrow(census_2011_tribes))
  expect_equal(
    sum(st$population) - sum(generic$population),
    sum(census_2011_tribes$population)
  )
  expect_equal(sum(census_2011_tribes$population), 103409280)
})

test_that("tribe_name is the harmonised head of tribe_name_original", {
  # "Chero (in the districts of ...)" -> "Chero": qualifier dropped, first synonym kept
  head_of <- function(x) {
    x <- gsub("\\*+", "", x)
    x <- sub("\\s*\\(.*$", "", x)
    gsub("[^a-z0-9]", "", tolower(trimws(sub(",.*$", "", x))))
  }
  tr <- census_2011_tribes
  expect_equal(head_of(tr$tribe_name), head_of(tr$tribe_name_original))
  expect_equal(dplyr::n_distinct(tr$tribe_name), 481)
  expect_gt(dplyr::n_distinct(tr$tribe_name_original), dplyr::n_distinct(tr$tribe_name))
})

test_that("A-11 reconciles to the PCA once Naga's constituents are not counted twice", {
  st <- dplyr::filter(census_2011_sc_st, .data$category == "Scheduled Tribe")
  pca <- sum(census_2011_pca$st_population)
  expect_equal(pca, 104545716)
  expect_equal(sum(st$population[is.na(st$parent_tribe)]), pca)
  # summing every row double-counts the 1,667,712 people in Naga's constituents
  expect_equal(sum(st$population) - pca, sum(st$population[!is.na(st$parent_tribe)]))
  expect_equal(sum(st$population[!is.na(st$parent_tribe)]), 1667712)
  expect_true(all(st$parent_tribe %in% c(NA, "Naga")))
})

test_that("tribe_name carries no (ST) marker", {
  expect_false(any(grepl("\\((ST|St)\\)", census_2011_tribes$tribe_name)))
  expect_equal(
    census_2011_tribes$tribe_name[census_2011_tribes$tribe_name_original == "Naga (ST)"][1],
    "Naga (unspecified)"
  )
  expect_equal(sum(!is.na(census_2011_tribes$parent_tribe)), 193)
})

test_that("district_total_population is the PCA district population (issue #4)", {
  pca <- dplyr::filter(census_2011_pca, .data$geography == "district")
  for (d in list(census_2011_sc_st, census_2011_tribes)) {
    j <- dplyr::inner_join(
      dplyr::distinct(d, .data$state_name_harmonized, .data$district, .data$district_total_population),
      pca,
      by = c("state_name_harmonized", "district")
    )
    expect_equal(j$district_total_population, j$population)
    expect_equal(d$percent, round(100 * d$population / d$district_total_population, 2))
  }
  bastar <- dplyr::filter(census_2011_sc_st, .data$district == "Bastar", .data$category_code == "SC")
  expect_equal(bastar$percent, 2.69)
})

test_that("A-10 SC totals equal the PCA SC count in every district", {
  sc <- dplyr::inner_join(
    dplyr::filter(census_2011_sc_st, .data$category_code == "SC"),
    dplyr::select(census_2011_pca, "state_name_harmonized", "district", "sc_population"),
    by = c("state_name_harmonized", "district")
  )
  expect_equal(nrow(sc), 582)
  expect_equal(sc$population, sc$sc_population)
})
