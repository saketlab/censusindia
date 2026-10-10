test_that("variable metadata filters on whole years, not substrings", {
  expect_equal(nrow(list_census_variables(year = 11)), 0)
  expect_gt(nrow(list_census_variables(year = 2011)), 0)
  expect_gt(nrow(list_census_variables(year = 1911)), 0)
  expect_gt(nrow(list_census_variables(geography = "state")), 0)
})

test_that("list_census_geographies advertises only what works", {
  g <- list_census_geographies()
  expect_true(all(c("year", "geography", "dataset") %in% names(g)))
  expect_false(any(g$year == 1961 & g$geography == "state"))
})

test_that("list_states returns the canonical 36", {
  s <- list_states()
  expect_equal(nrow(s), 36)
  expect_true(all(c("state_name", "state_abbr") %in% names(s)))
  expect_gt(nrow(list_states(region = "South")), 0)
})

test_that("search_census_variables finds by substring", {
  expect_gt(nrow(search_census_variables("literacy")), 0)
  expect_equal(nrow(search_census_variables("zzzznotathing")), 0)
})

test_that("census_years keeps only the twelve census years", {
  x <- census_years(census_population_time_series)
  expect_setequal(
    unique(x$year),
    c(1901L, 1911L, 1921L, 1931L, 1941L, 1951L, 1961L, 1971L, 1981L, 1991L, 2001L, 2011L)
  )
  expect_lt(nrow(x), nrow(census_population_time_series))
  expect_error(census_years(data.frame(x = 1)))
})

test_that("at_level slices one level and rejects a missing one", {
  skip_if_no_remote()
  expect_equal(
    nrow(at_level(census_2011_demographics(), "district", "total")), 640
  )
  expect_error(at_level(data.frame(x = 1), "district"))
})

test_that("plot_map accepts fill_var quoted, unquoted, or via a variable", {
  skip_if_no_remote()
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  s <- get_census_boundaries(2011, "state")
  s$value <- seq_len(nrow(s))

  expect_s3_class(plot_map(s, value), "ggplot")
  expect_s3_class(plot_map(s, "value"), "ggplot")
  v <- "value"
  expect_s3_class(plot_map(s, v), "ggplot")
  expect_error(plot_map(s, not_a_column))
})

test_that("every plot_map path draws India's full northern extent", {
  skip_if_no_remote()
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("sf")
  # measure drawn layers; the panel range adds 5% padding
  drawn_ymax <- function(p) {
    max(vapply(p$layers, function(L) {
      d <- L$data
      if (inherits(d, "sf") && nrow(d)) sf::st_bbox(d)[["ymax"]] else -Inf
    }, numeric(1)))
  }
  FULL <- 37.0783

  d <- censusindia::census_2011_pca |>
    attach_geometry(2011, geography = "district", unmatched = "ignore")
  expect_equal(attr(d, "census_boundary_year"), 2011)

  cases <- list(
    "with year column" = plot_map(d, "population_total"),
    "no year column" = plot_map(
      d[, setdiff(names(d), "year")], "population_total",
      show_state_boundaries = TRUE
    ),
    "explicit boundary_year" = plot_map(d, "population_total", boundary_year = 2011),
    "projection, no boundary file for its year" = plot_map(
      get_population(2031, geography = "district") |>
        attach_geometry(2011, geography = "district", unmatched = "ignore"),
      "population"
    )
  )
  for (nm in names(cases)) {
    expect_gte(drawn_ymax(cases[[nm]]), FULL - 1e-3, label = nm)
    expect_gte(length(cases[[nm]]$layers), 2)
  }

  # even a bare sf carrying no census metadata gets the outline
  bare <- sf::st_as_sf(
    data.frame(v = 1:5),
    geometry = sf::st_geometry(get_census_boundaries(2011, "district"))[1:5]
  )
  expect_gte(drawn_ymax(plot_map(bare, "v")), FULL - 1e-3)
})

test_that("the district data really is short without the base layer", {
  skip_if_no_remote()
  skip_if_not_installed("sf")
  d <- censusindia::census_2011_pca |>
    attach_geometry(2011, geography = "district", unmatched = "ignore")
  expect_lt(sf::st_bbox(d)[["ymax"]], 36.1)
  expect_gt(sf::st_bbox(get_census_boundaries(2011, "state"))[["ymax"]], 37.07)
})

test_that("every variable the catalogue advertises actually resolves", {
  v <- census_variables
  for (i in seq_len(nrow(v))) {
    years <- as.integer(strsplit(v$years[i], ",")[[1]])
    geogs <- strsplit(v$geographies[i], ",")[[1]]
    for (y in years) {
      for (g in geogs) {
        if (!nrow(dplyr::filter(list_census_geographies(), .data$year == y, .data$geography == g))) {
          next
        }
        out <- suppressWarnings(get_census(y, g, variables = v$variable[i]))
        expect_true(v$variable[i] %in% names(out))
      }
    }
  }
})

test_that("requested variables come back under their canonical name", {
  d <- get_census(2011, "district", variables = c("workers", "literate"))
  expect_true(all(c("workers", "literate") %in% names(d)))
  expect_false(any(c("workers_total", "literate_total") %in% names(d)))
})
