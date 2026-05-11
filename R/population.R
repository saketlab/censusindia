#' Get population projections
#'
#' MOHFW population projections (2011-2036) at state or district level,
#' based on the 2011 Census. District projections are available using
#' either Census 2011 boundaries (640 districts, 5-year intervals) or
#' current LGD boundaries (785 districts, annual).
#'
#' @param year Integer or integer vector of projection years. If NULL
#'   (default), returns all available years.
#' @param geography Geographic level: `"state"` or `"district"`.
#' @param state Optional. Filter to specific state(s) by name or
#'   abbreviation (e.g., `"Maharashtra"` or `"MH"`).
#' @param boundary For district geography, which boundary system:
#'   `"census2011"` (default, 640 districts) or `"lgd"` (785 districts).
#'   Ignored for state geography.
#' @param geometry If `TRUE`, attaches geographic boundaries (Census 2011).
#'   Only works with `boundary = "census2011"` for district level.
#'
#' @return A tibble (or sf object if `geometry = TRUE`) with columns:
#'   `year`, `state_name_harmonized`, `males`, `females`, `population`,
#'   and `district` for district-level data.
#'
#' @details
#' State-level data covers 2011-2036 for 38 entries (36 states/UTs plus
#' India total plus Ladakh). Values are in absolute numbers.
#'
#' The source data rounds Persons, Male, and Female independently (in
#' thousands), so `population` may differ from `males + females` by up
#' to 1000 at the state level.
#'
#' District-level Census 2011 data has projections at 5-year intervals
#' (2011, 2016, 2021, 2026, 2031). LGD district data has annual
#' projections from 2012 to 2031.
#'
#' Telangana and Ladakh are included as separate entries even though
#' they did not exist as states at the time of the 2011 Census.
#'
#' @examples
#' # State-level projections for 2021
#' get_population(2021, "state")
#'
#' # District-level for Kerala
#' get_population(2021, "district", state = "Kerala")
#'
#' # LGD boundary districts
#' get_population(2021, "district", boundary = "lgd")
#'
#' @export
get_population <- function(year = NULL,
                           geography = c("state", "district"),
                           state = NULL,
                           boundary = c("census2011", "lgd"),
                           geometry = FALSE) {
  geography <- match.arg(geography)
  boundary <- match.arg(boundary)

  if (geography == "state") {
    data <- censusindia::population_projections_state
  } else if (boundary == "lgd") {
    data <- censusindia::population_projections_district_lgd
  } else {
    data <- censusindia::population_projections_district
  }

  if (!is.null(year)) {
    data <- data |> dplyr::filter(.data$year %in% .env$year)
  }

  if (!is.null(state)) {
    data <- filter_population_by_state(data, state)
  }

  if (geometry) {
    if (geography == "state") {
      data <- add_geometry(data, 2011, "state")
    } else if (boundary == "census2011") {
      data <- add_geometry(data, 2011, "district")
    } else {
      cli::cli_warn(c(
        "Geometry attachment not supported for LGD boundaries.",
        "i" = "Use {.code boundary = \"census2011\"} for geometry support."
      ))
    }
  }

  data
}

#' @noRd
filter_population_by_state <- function(data, state) {
  state_lookup <- censusindia::india_states

  state_match <- if (toupper(state) %in% state_lookup$state_abbr) {
    state_lookup$state_name_harmonized[state_lookup$state_abbr == toupper(state)]
  } else {
    # Try harmonized name match
    hit <- state_lookup$state_name_harmonized[
      tolower(state_lookup$state_name_harmonized) == tolower(state) |
        tolower(state_lookup$state_name) == tolower(state)
    ]
    if (length(hit) > 0) hit[1] else state
  }

  data |>
    dplyr::filter(
      tolower(.data$state_name_harmonized) == tolower(state_match)
    )
}
