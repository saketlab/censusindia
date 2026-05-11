#' List census variables
#'
#' Available census variables, optionally filtered by year, geography, or category.
#'
#' @param year Filter to variables available for specific census year.
#' @param geography Filter to "state", "district", or "subdistrict".
#' @param category Filter to "population", "literacy", "workers", "sc_st", "housing", "geography", or "change".
#' @return A tibble of available variables.
#'
#' @examples
#' list_census_variables()
#' list_census_variables(year = 1981)
#' list_census_variables(category = "literacy", geography = "district")
#'
#' @export
list_census_variables <- function(year = NULL, geography = NULL, category = NULL) {
  vars <- censusindia::census_variables
  if (!is.null(year)) vars <- vars |> dplyr::filter(grepl(as.character(year), .data$years))
  if (!is.null(geography)) vars <- vars |> dplyr::filter(grepl(geography, .data$geographies))
  if (!is.null(category)) vars <- vars |> dplyr::filter(.data$category == .env$category)
  vars
}

#' List available census geographies
#'
#' Geographic levels available for each census year.
#'
#' @return A tibble showing available year-geography combinations.
#' @examples
#' list_census_geographies()
#' @export
list_census_geographies <- function() {
  tibble::tribble(
    ~year, ~geography, ~dataset,
    1901L, "state", "Population time series",
    1901L, "district", "Population time series",
    1911L, "state", "Population time series",
    1911L, "district", "Population time series",
    1921L, "state", "Population time series",
    1921L, "district", "Population time series",
    1931L, "state", "Population time series",
    1931L, "district", "Population time series",
    1941L, "state", "Population time series",
    1941L, "district", "Population time series",
    1951L, "state", "Population time series",
    1951L, "district", "Population time series",
    1961L, "state", "Population time series",
    1961L, "district", "Population time series + Literacy",
    1971L, "state", "Primary Census Abstract",
    1971L, "district", "Primary Census Abstract",
    1981L, "state", "Primary Census Abstract (detailed)",
    1981L, "district", "Primary Census Abstract (detailed)",
    1991L, "state", "Population time series",
    1991L, "district", "Population time series",
    2001L, "state", "Population time series",
    2001L, "district", "Population time series",
    2011L, "state", "Population time series",
    2011L, "district", "Population time series",
    2011L, "subdistrict", "Subdistrict directory"
  )
}

#' List Indian states
#'
#' States and union territories with codes, abbreviations, and regions.
#'
#' @param region Filter by region: "North", "South", "East", "West", "Central", "Northeast", "Islands".
#' @return A tibble of states with codes, names, abbreviations, and regions.
#'
#' @examples
#' list_states()
#' list_states(region = "South")
#'
#' @export
list_states <- function(region = NULL) {
  states <- censusindia::india_states
  if (!is.null(region)) {
    states <- states |> dplyr::filter(.data$region == .env$region)
  }
  states
}

#' Search census variables
#'
#' Find census variables by keyword in names and labels.
#'
#' @param pattern Character string or regex pattern to search.
#' @return A tibble of matching variables.
#'
#' @examples
#' search_census_variables("population")
#' search_census_variables("worker")
#'
#' @export
search_census_variables <- function(pattern) {
  censusindia::census_variables |>
    dplyr::filter(
      grepl(pattern, variable, ignore.case = TRUE) |
        grepl(pattern, label, ignore.case = TRUE)
    )
}
