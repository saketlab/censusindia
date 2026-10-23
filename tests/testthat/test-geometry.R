BOUNDARY_YEARS <- censusindia:::BOUNDARY_YEARS

skip_no_sf <- function() {
  skip_if_not_installed("sf")
  skip_if_no_remote()
}

test_that("every boundary year reaches India's full northern extent", {
  skip_no_sf()
  for (y in BOUNDARY_YEARS) {
    ymax <- sf::st_bbox(get_census_boundaries(y, "state"))[["ymax"]]
    expect_gt(ymax, 37.0)
  }
})

test_that("get_census_boundaries returns sf for both geographies", {
  skip_no_sf()
  s <- get_census_boundaries(2011, "state")
  d <- get_census_boundaries(2011, "district")
  expect_s3_class(s, "sf")
  expect_s3_class(d, "sf")
  expect_gt(nrow(d), nrow(s))
  expect_false(any(sf::st_is_empty(s$geometry)))
})

test_that("get_census_boundaries rejects a year with no boundary file", {
  skip_no_sf()
  expect_error(get_census_boundaries(1901, "state"))
  expect_error(get_census_boundaries(2036, "state"))
})

test_that("attach_geometry never multiplies rows", {
  skip_no_sf()
  d <- get_census(2011, "district")
  g <- suppressWarnings(attach_geometry(d, 2011, geography = "district"))
  expect_equal(nrow(g), nrow(d))
  expect_s3_class(g, "sf")
})

test_that("attach_geometry resolves every 2011 PCA district", {
  skip_no_sf()
  g <- suppressWarnings(
    attach_geometry(censusindia::census_2011_pca, 2011, geography = "district")
  )
  expect_equal(nrow(g), 640)
  expect_equal(sum(sf::st_is_empty(g$geometry)), 0)
})

test_that("successor states inherit their parent's polygon at earlier vintages", {
  skip_no_sf()
  # Telangana (2014) and Ladakh (2019) postdate every boundary file
  d <- data.frame(
    state_name_harmonized = c("Telangana", "Ladakh", "Kerala"),
    value = c(1, 2, 3),
    stringsAsFactors = FALSE
  )
  g <- suppressWarnings(attach_geometry(d, 2011, geography = "state"))
  expect_equal(nrow(g), 3)
  expect_equal(sum(sf::st_is_empty(g$geometry)), 0)
  ymax <- sf::st_bbox(g)[["ymax"]]
  expect_gt(ymax, 37.0)
})

test_that("projections attached to 2011 boundaries keep the full extent", {
  skip_no_sf()
  p <- get_population(2031, geography = "state")
  g <- suppressWarnings(attach_geometry(p, 2011, geography = "state"))
  matched <- g[!sf::st_is_empty(g$geometry), ]
  expect_gt(sf::st_bbox(matched)[["ymax"]], 37.0)
})

test_that("the geometry cache is a cache and clears", {
  skip_no_sf()
  clear_geometry_cache()
  a <- get_census_boundaries(2011, "state")
  b <- get_census_boundaries(2011, "state")
  expect_identical(a, b)
  expect_silent(clear_geometry_cache())
  expect_equal(nrow(get_census_boundaries(2011, "state")), nrow(a))
})

test_that("census_base_layer returns something ggplot can draw", {
  skip_no_sf()
  skip_if_not_installed("ggplot2")
  lay <- census_base_layer(2011)
  p <- ggplot2::ggplot() + lay
  expect_s3_class(p, "ggplot")
  expect_silent(invisible(ggplot2::ggplot_build(p)))
})
