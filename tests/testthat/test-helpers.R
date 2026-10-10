test_that("sex_ratio is females per 1000 males", {
  expect_equal(sex_ratio(940, 1000), 940)
  expect_equal(sex_ratio(500, 500), 1000)
  expect_equal(sex_ratio(c(940, 1084), c(1000, 1000)), c(940, 1084))
  expect_true(is.nan(sex_ratio(0, 0)))
  expect_identical(sex_ratio(NA_real_, 1000), NA_real_)
})

test_that("sex_ratio reproduces the published 2011 national figure", {
  p <- censusindia::census_2011_pca
  expect_equal(
    round(sex_ratio(sum(p$population_female), sum(p$population_male))),
    943
  )
})

test_that("share is a percentage", {
  expect_equal(share(25, 100), 25)
  expect_equal(share(1, 3), 100 / 3)
  expect_equal(share(c(1, 2), c(4, 4)), c(25, 50))
})

test_that("get_palette returns hex ramps", {
  p <- get_palette("blue_red")
  expect_type(p, "character")
  expect_gt(length(p), 2)
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", p)))
})

test_that("get_palette reverse flips the ramp", {
  expect_equal(get_palette("blues", reverse = TRUE), rev(get_palette("blues")))
})

test_that("blue_red and red_blue are mirrors", {
  expect_equal(get_palette("blue_red"), rev(get_palette("red_blue")))
})

test_that("get_palette rejects an unknown name", {
  expect_error(get_palette("chartreuse"))
})

test_that("themes are ggplot theme objects", {
  skip_if_not_installed("ggplot2")
  expect_s3_class(theme_census(), "theme")
  expect_s3_class(theme_census_map(), "theme")
  expect_s3_class(theme_census(base_size = 14), "theme")
})
