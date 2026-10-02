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
#' @param by_age If `TRUE`, returns single years of age 0-14 and 5-year
#'   bands 15-19 through 80+ instead of totals. See
#'   [population_projections_state_age], [population_projections_district_age]
#'   and [population_projections_district_lgd_age]. State coverage by age is
#'   23 major states plus an "India" row and one North-East aggregate row.
#'
#' @return A tibble (or sf object if `geometry = TRUE`) with columns:
#'   `year`, `state_name_harmonized`, `males`, `females`, `population`,
#'   `district` for district-level data, and `age_group` if `by_age = TRUE`.
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
#' A `year` absent from the table is estimated from the two nearest table
#' years by geometric (exponential) growth, applied separately to `males`,
#' `females` and `population`:
#'
#' \deqn{P_t = P_1 (P_2 / P_1)^{(t - t_1) / (t_2 - t_1)}}
#'
#' Estimated districts need not sum exactly to
#' the estimated state.
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
#' # Age-stratified state projections
#' get_population(2021, "state", by_age = TRUE)
#'
#' @export
get_population <- function(year = NULL,
                           geography = c("state", "district"),
                           state = NULL,
                           boundary = c("census2011", "lgd"),
                           geometry = FALSE,
                           by_age = FALSE) {
  geography <- match.arg(geography)
  boundary <- match.arg(boundary)

  if (geography == "state") {
    data <- if (by_age) censusindia::population_projections_state_age else censusindia::population_projections_state
  } else if (boundary == "lgd") {
    data <- if (by_age) censusindia::population_projections_district_lgd_age else censusindia::population_projections_district_lgd
  } else {
    data <- if (by_age) censusindia::population_projections_district_age else censusindia::population_projections_district
  }

  if (!is.null(state)) {
    data <- filter_population_by_state(data, state)
  }

  if (!is.null(year)) {
    if (!rlang::is_integerish(year, finite = TRUE)) {
      cli::cli_abort("{.arg year} must be whole-number years.")
    }
    year <- as.integer(year)
    missing_years <- setdiff(year, data$year)
    data <- dplyr::filter(data, .data$year %in% .env$year) |>
      dplyr::bind_rows(
        if (length(missing_years)) estimate_population_years(data, missing_years)
      ) |>
      dplyr::arrange(.data$year)
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
  wanted <- resolve_states(state, present = unique(data$state_name_harmonized))
  data |>
    dplyr::filter(tolower(.data$state_name_harmonized) %in% tolower(.env$wanted))
}

#' Estimate projection years absent from a table
#' @noRd
estimate_population_years <- function(data, years) {
  known <- sort(unique(data$year))
  values <- c("males", "females", "population")
  keys <- setdiff(names(data), c("year", values))

  # all.inside extrapolates with the end interval's rate
  # ponytail: one-interval rate is noisy far out; use a longer baseline if that matters
  idx <- findInterval(years, known, all.inside = TRUE)
  outside <- years[years < min(known) | years > max(known)]
  cli::cli_inform(c(
    "i" = "Not in the MOHFW tables, estimated by geometric growth: {.val {years}}.",
    "!" = if (length(outside)) "Extrapolated beyond {min(known)}-{max(known)}: {.val {outside}}."
  ))

  rows <- lapply(seq_along(years), function(j) {
    t1 <- known[idx[j]]
    t2 <- known[idx[j] + 1]
    frac <- (years[j] - t1) / (t2 - t1)
    m <- dplyr::inner_join(
      data[data$year == t1, ],
      data[data$year == t2, c(keys, values)],
      by = keys, suffix = c("", ".end")
    )
    for (v in values) {
      p1 <- m[[v]]
      p2 <- m[[paste0(v, ".end")]]
      # growth from zero is undefined unless it stays zero
      m[[v]] <- round(ifelse(p1 > 0, p1 * (p2 / p1)^frac, ifelse(p2 == 0, 0, NA)))
    }
    m$year <- years[j]
    m[names(data)]
  })
  dplyr::bind_rows(rows)
}
