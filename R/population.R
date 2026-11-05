#' Get population projections
#'
#' Queries Ministry of Health and Family Welfare (MoHFW) population projections
#' (2011-2036, Census 2011 base) at state or district level. District
#' projections are available on two boundary sets: Census 2011 districts (640
#' districts at 5-year intervals) and Local Government Directory (LGD) districts
#' (783 districts, annual).
#'
#' @param year Integer or integer vector of projection years, or `NULL`
#'   (default) for all published years in the table.
#' @param geography Geographic level: `"state"` or `"district"`.
#' @param state Optional state filter: one or more canonical state names or
#'   two-letter codes (e.g., `"Maharashtra"` or `"MH"`).
#' @param boundary District boundary system: `"census2011"` (default, 640
#'   districts) or `"lgd"` (783 districts). Ignored when `geography = "state"`.
#' @param geometry If `TRUE`, attaches Census 2011 boundaries and returns an
#'   `sf` object. At district level, supported only when
#'   `boundary = "census2011"`.
#' @param by_age If `TRUE`, returns age-stratified rows. State projections use
#'   5-year age bands from `"0-4"` to `"80+"`; district projections use single
#'   years for ages 0-14 and 5-year bands from `"15-19"` to `"80+"`. See
#'   [population_projections_state_age], [population_projections_district_age()],
#'   and [population_projections_district_lgd_age()]. State age projections
#'   cover 23 major states, `"India"`, and `"North East States Excluding Assam"`;
#'   requesting other states with `by_age = TRUE` raises an error.
#'
#' @return A tibble (or an `sf` object if `geometry = TRUE`) with columns
#'   `year`, `geography`, `state_code`, `state_name_harmonized`, `district`
#'   (district level only), `age_group` (when `by_age = TRUE`), `males`,
#'   `females`, `population`, and `estimate`. `geography` is `"india"` on
#'   national rows. All counts are in persons. `estimate` is `"published"` for
#'   years printed in the MoHFW/IIPS tables, `"interpolated"` for years between
#'   printed years, and `"extrapolated"` for years after the last printed year.
#'
#' @details
#' State projections cover 2011-2036 across 39 entries: 28 states, the 9 union
#' territories printed by MoHFW (including separate `"Dadra & Nagar Haveli"` and
#' `"Daman & Diu"` rows), the merged `"Dadra & Nagar Haveli and Daman & Diu"` UT
#' (the sum of the two), and `"India"`. To sum across states without
#' double-counting, exclude `"India"` and either the merged UT or the two
#' constituent UTs; see [population_projections_state].
#'
#' Because the state report rounds Persons, Male, and Female independently to
#' the nearest thousand, `population` and `males + females` can differ by up to
#' 1,000 at state level (2,000 for the summed UT).
#'
#' Census 2011 district projections are published at 5-year intervals (2011,
#' 2016, 2021, 2026, 2031); LGD district projections are annual from 2012 to
#' 2031.
#'
#' When a requested `year` is between published table years, `get_population()`
#' interpolates `males`, `females`, and `population` independently using
#' geometric (exponential) growth between the two nearest published years:
#'
#' \deqn{P_t = P_1 (P_2 / P_1)^{(t - t_1) / (t_2 - t_1)}}
#'
#' Because each series is interpolated independently, summed district estimates
#' need not equal the interpolated state estimate.
#'
#' Years after the last published year are extrapolated using the final
#' interval's growth rate for up to five years (to 2041 for states, 2036 for
#' districts). Years before the start of the table or more than five years past
#' the end raise an error.
#'
#' Telangana and Ladakh are reported as separate entries even though both were
#' created after the 2011 Census.
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
    data <- if (by_age) population_projections_district_lgd_age() else censusindia::population_projections_district_lgd
  } else {
    data <- if (by_age) population_projections_district_age() else censusindia::population_projections_district
  }

  if (!is.null(state)) {
    data <- filter_by_state(data, state)
  }

  data$estimate <- "published"
  if (!is.null(year)) {
    if (!length(year) || !rlang::is_integerish(year, finite = TRUE)) {
      cli::cli_abort("{.arg year} must be whole-number years.")
    }
    year <- unique(as.integer(year))
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
