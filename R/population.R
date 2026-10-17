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
#' @param by_age If `TRUE`, returns one row per age group. States
#'   come in 5-year bands from "0-4" to "80+"; districts in single years of
#'   age 0-14, then 5-year bands 15-19 through 80+. See
#'   [population_projections_state_age], [population_projections_district_age()]
#'   and [population_projections_district_lgd_age()]. State coverage by age is
#'   23 major states plus an "India" row and one North-East aggregate row,
#'   "North East States Excluding Assam"; any other state is an error.
#'
#' @return A tibble (or sf object if `geometry = TRUE`) with columns:
#'   `year`, `state_name_harmonized`, `males`, `females`, `population`,
#'   `estimate`, `district` for district-level data, and `age_group` if
#'   `by_age = TRUE`. `estimate` is `"published"` for a year printed in the
#'   MOHFW tables, `"interpolated"` or `"extrapolated"` otherwise.
#'
#' @details
#' State-level data covers 2011-2036 and has 39 entries: 28 states, the 9
#' UTs that MOHFW gives, the merged "Dadra & Nagar Haveli and Daman & Diu",
#' and "India". MOHFW gives "Dadra & Nagar Haveli" and "Daman & Diu" as two
#' UTs. This package adds the merged UT as the sum of the two. To get the sum
#' of the states, remove "India" and one of the two Dadra/Daman forms. Refer
#' to [population_projections_state]. Values are numbers of persons. This is
#' also true for the state rows by age, but
#' [population_projections_state_age] stores them in thousands.
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
#' Years after the last table year extrapolate with the last interval's rate,
#' up to five years out: 2041 for states, 2036 for districts. Years before 2011
#' or past that limit are an error.
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
    data <- if (by_age) state_age_persons() else censusindia::population_projections_state
  } else if (boundary == "lgd") {
    data <- if (by_age) population_projections_district_lgd_age() else censusindia::population_projections_district_lgd
  } else {
    data <- if (by_age) population_projections_district_age() else censusindia::population_projections_district
  }

  if (!is.null(state)) {
    data <- filter_population_by_state(data, state)
  }

  data$estimate <- "published"
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
  keys <- setdiff(names(data), c("year", "estimate", values))

  lo <- min(known)
  hi <- max(known) + 5L
  out_of_range <- years < lo | years > hi
  if (any(out_of_range)) {
    cli::cli_abort(c(
      "{.arg year} must be from {lo} to {hi} for this table, got {.val {years[out_of_range]}}.",
      "i" = "MOHFW publishes up to {max(known)}; later years are extrapolated, five years at most."
    ))
  }

  # all.inside extrapolates with the end interval's rate
  # ponytail: one-interval rate is noisy far out; use a longer baseline if that matters
  idx <- findInterval(years, known, all.inside = TRUE)
  extrap <- years > max(known)
  cli::cli_inform(c(
    "i" = "Not in the MOHFW tables, estimated by geometric growth: {.val {years}}.",
    "!" = if (any(extrap)) "Extrapolated beyond {max(known)}: {.val {years[extrap]}}."
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
    m$estimate <- if (extrap[j]) "extrapolated" else "interpolated"
    m[names(data)]
  })
  dplyr::bind_rows(rows)
}

#' population_projections_state_age in persons; Table 18 is stored in thousands
#' @noRd
state_age_persons <- function() {
  d <- censusindia::population_projections_state_age
  d[c("males", "females", "population")] <- d[c("males", "females", "population")] * 1000
  d
}
