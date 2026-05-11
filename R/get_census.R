#' Get India census data
#'
#' Census data for India at state, district, or subdistrict level.
#'
#' @param year Census year. One of: 1901, 1911, 1921, 1931, 1941, 1951, 1961,
#'   1971, 1981, 1991, 2001, 2011.
#' @param geography Geographic level: "state", "district", or "subdistrict".
#'   Not all geographies are available for all years.
#' @param variables Character vector of variables to retrieve. Use
#'   [list_census_variables()] to see available variables. If NULL (default),
#'   returns all available variables for the specified year and geography.
#' @param state Optional. Filter to specific state(s). Can be state name or
#'   abbreviation (e.g., "Maharashtra" or "MH").
#' @param geometry If TRUE, returns an sf object with geographic boundaries.
#' @param sector For 1971/1981, filter to "total", "rural", or "urban".
#'
#' @return A tibble (or sf object if geometry = TRUE).
#'
#' @examples
#' get_census(2011, "state")
#' get_census(1971, "district", state = "Maharashtra")
#' get_census(1981, "district", variables = c("population", "literacy_rate"), geometry = TRUE)
#'
#' @export
get_census <- function(year,
                       geography = c("state", "district", "subdistrict"),
                       variables = NULL,
                       state = NULL,
                       geometry = FALSE,
                       sector = "total") {
  geography <- match.arg(geography)

  valid_years <- c(1901, 1911, 1921, 1931, 1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011)
  if (!year %in% valid_years) {
    cli::cli_abort("Year must be one of: {.val {valid_years}}")
  }

  data <- get_census_data_for_year(year, geography, sector)

  if (is.null(data) || nrow(data) == 0) {
    cli::cli_abort(c(
      "No data available for year {.val {year}} at geography {.val {geography}}",
      "i" = "Use {.fn list_census_geographies} to see available combinations."
    ))
  }

  if (!is.null(state)) data <- filter_by_state(data, state)
  if (!is.null(variables)) data <- select_variables(data, variables)
  if (geometry) data <- add_geometry(data, year, geography)

  data
}

#' @noRd
get_census_data_for_year <- function(year, geography, sector) {
  if (year == 2011 && geography == "subdistrict") {
    return(censusindia::census_subdistricts_2011)
  }

  if (year == 1981) {
    data <- censusindia::census_1981 |>
      dplyr::filter(.data$sector == .env$sector)

    if (geography == "state") {
      data <- data |> dplyr::filter(.data$level == "state")
    } else if (geography == "district") {
      data <- data |> dplyr::filter(.data$level == "district")
    }

    return(data |>
      dplyr::rename(population = total_persons, males = total_males, females = total_females))
  }

  if (year == 1971) {
    data <- censusindia::census_1971 |>
      dplyr::filter(.data$geography == .env$geography)

    suffix <- if (sector == "rural") "_rural" else if (sector == "urban") "_urban" else "_total"
    return(data |>
      dplyr::rename(
        population = !!paste0("population", suffix),
        males = !!paste0("males", suffix),
        females = !!paste0("females", suffix),
        sc_population = !!paste0("sc_population", suffix),
        st_population = !!paste0("st_population", suffix)
      ))
  }

  if (year == 1961) {
    if (geography != "district") {
      cli::cli_abort("1961 data only available at district level for literacy")
    }
    return(censusindia::census_1961_literacy)
  }

  censusindia::census_population_time_series |>
    dplyr::filter(.data$year == .env$year, .data$geography == .env$geography)
}

#' @noRd
filter_by_state <- function(data, state) {
  state_lookup <- censusindia::india_states

  state_match <- if (toupper(state) %in% state_lookup$state_abbr) {
    state_lookup$state_name[state_lookup$state_abbr == toupper(state)]
  } else {
    state
  }

  state_col <- intersect(names(data), c("state", "state_name"))[1]
  if (is.na(state_col)) {
    cli::cli_abort("Cannot filter by state: no state column found")
  }

  data |>
    dplyr::filter(
      tolower(.data[[state_col]]) == tolower(state_match) |
        grepl(tolower(state_match), tolower(.data[[state_col]]))
    )
}

#' @noRd
select_variables <- function(data, variables) {
  id_cols <- intersect(
    c(
      "year", "geography", "state", "state_name", "district", "subdistrict",
      "name", "state_code", "district_code", "geo_id", "geo_name", "level"
    ),
    names(data)
  )

  var_mapping <- list(
    population = c("population", "total_persons"),
    males = c("males", "total_males", "male_count"),
    females = c("females", "total_females", "female_count"),
    literacy_rate = c("literacy_total", "literate_persons"),
    literacy_male = c("literacy_male", "literate_males"),
    literacy_female = c("literacy_female", "literate_females"),
    sc_population = c("sc_population", "sc_population_total"),
    st_population = c("st_population", "st_population_total"),
    households = c("households", "hhld_count"),
    area_km2 = c("area_km2", "area_sqkm")
  )

  selected_cols <- vapply(variables, function(v) {
    if (v %in% names(var_mapping)) {
      matching <- intersect(var_mapping[[v]], names(data))
      if (length(matching) > 0) {
        return(matching[1])
      }
    }
    if (v %in% names(data)) {
      return(v)
    }
    NA_character_
  }, character(1))

  data |> dplyr::select(dplyr::all_of(unique(c(id_cols, stats::na.omit(selected_cols)))))
}
