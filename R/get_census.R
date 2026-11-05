#' Get India census data
#'
#' Queries Census of India data at state, district, or subdistrict level.
#'
#' @param year Census year. One of: 1901, 1911, 1921, 1931, 1941, 1951, 1961,
#'   1971, 1981, 1991, 2001, 2011.
#' @param geography Geographic level: `"state"`, `"district"`, or `"subdistrict"`.
#'   Not all geographies are available for every census year; see
#'   [list_census_geographies()].
#' @param variables Character vector of variable names to return, or `NULL`
#'   (default) for all variables available at that year and geography. See
#'   [list_census_variables()].
#' @param state Optional state filter: one or more canonical state names or
#'   two-letter codes (e.g., `"Maharashtra"` or `"MH"`).
#' @param geometry If `TRUE`, attaches census boundaries and returns an `sf`
#'   object. Available for `"state"` and `"district"`.
#' @param sector Sector filter: `"total"` (default), `"rural"`, or `"urban"`.
#'   Rural and urban splits are available in `get_census()` for 1971 and 1981
#'   only; passing `"rural"` or `"urban"` for other years raises an error.
#'
#' @return A tibble (or an `sf` object when `geometry = TRUE`). Every year
#'   begins with the same identifier columns: `year`, `geography`, `sector`,
#'   `state_code`, `state_name_harmonized`, `state_name`, followed by
#'   `district_code`, `district`, and `subdistrict` where applicable. State
#'   frames carry no district columns. `sector` is `"total"` for years without a
#'   rural/urban split. For 1961, only literacy rates (`literacy_rate`,
#'   `literacy_rate_male`, `literacy_rate_female`) are available, not population
#'   counts.
#'
#' @examples
#' get_census(2011, "state")
#' get_census(1971, "district", state = "Maharashtra")
#' get_census(1971, "state", sector = "rural")
#' get_census(1961, "state", variables = "literacy_rate")
#' @examplesIf interactive()
#' get_census(1981, "district", variables = c("population", "literacy_rate"), geometry = TRUE)
#'
#' @export
get_census <- function(year,
                       geography = c("state", "district", "subdistrict"),
                       variables = NULL,
                       state = NULL,
                       geometry = FALSE,
                       sector = c("total", "rural", "urban")) {
  geography <- match.arg(geography)
  sector <- match.arg(sector)

  valid_years <- c(1901, 1911, 1921, 1931, 1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011)
  if (length(year) != 1L || is.na(year) || !year %in% valid_years) {
    cli::cli_abort("Year must be one of: {.val {valid_years}}")
  }
  if (sector != "total" && !year %in% c(1971, 1981)) {
    cli::cli_abort(c(
      "{.arg sector} {.val {sector}} is not available for {year}.",
      "i" = "Rural and urban figures exist for 1971 and 1981 only."
    ))
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
  if (geometry) {
    if (!geography %in% c("state", "district")) {
      cli::cli_abort(c(
        "{.arg geometry} is only available for state and district level.",
        "i" = "No boundary file exists for {.val {geography}}."
      ))
    }
    data <- add_geometry(data, year, geography)
  }

  data
}

#' @noRd
get_census_data_for_year <- function(year, geography, sector) {
  data <- if (year == 2011 && geography == "subdistrict") {
    censusindia::census_subdistricts_2011
  } else if (year %in% c(2001L, 2011L)) {
    # the time series omits Sikkim, Mizoram and Daman & Diu; the PCA is complete
    census_from_pca(year, geography)
  } else {
    switch(as.character(year),
      "1961" = censusindia::census_1961_literacy,
      "1971" = censusindia::census_1971,
      "1981" = censusindia::census_1981,
      censusindia::census_population_time_series |> dplyr::filter(.data$year == .env$year)
    )
  }
  data <- at_level(data, geography, sector)
  # name labels units below subdistrict; a state frame has no district to name
  data$name <- NULL
  lower <- intersect(c("district_code", "district", "subdistrict_code", "subdistrict"), names(data))
  data <- data[setdiff(names(data), lower[vapply(data[lower], \(v) all(is.na(v)), logical(1))])]
  if (!"sector" %in% names(data)) data$sector <- "total"
  canonicalize(data)
}

#' Builds a get_census() frame from the Primary Census Abstract.
#'
#' Keeps the indicators of the abstract, so `variables =` can get literacy and
#' worker counts. Adds the districts to make the state frame. Copies
#' `variation_*` from the time series when that year has it.
#' @noRd
census_from_pca <- function(year, geography) {
  out <- if (year == 2001L) censusindia::census_2001_pca else censusindia::census_2011_pca
  keys <- c("state_name_harmonized", "district")

  if (geography == "state") {
    num <- .count_cols(out)
    out <- out |>
      dplyr::group_by(.data$year, .data$state_code, .data$state_name_harmonized, .data$state_name) |>
      dplyr::summarise(dplyr::across(dplyr::all_of(num), \(x) sum(x, na.rm = TRUE)), .groups = "drop") |>
      dplyr::mutate(geography = "state")
    keys <- "state_name_harmonized"
  }

  ts <- censusindia::census_population_time_series |>
    dplyr::filter(.data$year == .env$year, .data$geography == .env$geography) |>
    dplyr::select(dplyr::all_of(c(keys, "variation_absolute", "variation_percent")))
  dplyr::left_join(out, ts, by = keys)
}

#' Finds the canonical state for each state name or two-letter code.
#'
#' Accepts a vector. A value that is not a code or a canonical name, but occurs
#' verbatim in `present`, passes through unchanged. Historical spellings
#' ("MYSORE") and aggregate rows ("India") operate correctly. All other values
#' give an error. A
#' resolved state with no rows in `present` gives an error. The error lists the
#' states that have rows.
#' @noRd
resolve_states <- function(state, present = character(0)) {
  lookup <- censusindia::india_states
  key <- tolower(trimws(as.character(state)))
  present_key <- tolower(trimws(present))

  out <- vapply(key, function(k) {
    if (k == "india") {
      return("India")
    }
    # Ladakh postdates the 2011 state list; projections have it
    if (k %in% c("la", "ladakh")) {
      return("Ladakh")
    }
    i <- which(tolower(lookup$state_abbr) == k)
    if (length(i)) {
      return(lookup$state_name_harmonized[i[1]])
    }
    i <- which(tolower(lookup$state_name_harmonized) == k | tolower(lookup$state_name) == k)
    if (length(i)) {
      return(lookup$state_name_harmonized[i[1]])
    }
    if (k %in% present_key) {
      return(NA_character_)
    }
    ""
  }, character(1), USE.NAMES = FALSE)

  bad <- state[!is.na(out) & out == ""]
  if (length(bad)) {
    cli::cli_abort(c(
      "Unknown state{?s}: {.val {bad}}.",
      "i" = "Use a canonical name or two-letter code from {.fn list_states}.",
      "i" = "Remove {.arg state} to get every state."
    ))
  }
  absent <- out[!is.na(out) & !tolower(out) %in% present_key]
  if (length(present) && length(absent)) {
    # prefer "Andhra Pradesh" over "ANDHRA PRADESH"
    shown <- unique(present)
    shown <- shown[order(shown == toupper(shown))]
    shown <- sort(shown[!duplicated(tolower(shown))])
    ne <- list_states(region = "Northeast")$state_name_harmonized
    cli::cli_abort(c(
      "No rows for {.val {absent}} in this table.",
      "i" = if (any(absent %in% ne) && "north east states excluding assam" %in% present_key) {
        "North-East states other than Assam are one row: {.val North East States Excluding Assam}."
      },
      "i" = "States in this table: {.val {shown}}.",
      "i" = "Remove {.arg state} to get every state."
    ))
  }
  # NA: matched the data verbatim, so keep the caller's spelling
  ifelse(is.na(out), state, out)
}

#' @noRd
filter_by_state <- function(data, state) {
  cols <- intersect(names(data), c("state_name_harmonized", "state_name"))
  if (!length(cols)) {
    cli::cli_abort("Cannot filter by state: no state column found")
  }
  present <- unique(unlist(lapply(data[cols], as.character), use.names = FALSE))
  wanted <- resolve_states(state, present = present[!is.na(present)])
  hit <- Reduce(`|`, lapply(cols, function(cl) {
    tolower(as.character(data[[cl]])) %in% tolower(wanted)
  }))
  data[hit & !is.na(hit), , drop = FALSE]
}

#' @noRd
select_variables <- function(data, variables) {
  ids <- intersect(.id_cols, names(data))
  # variable = c(numerator, denominator, function)
  derived <- list(
    literacy_rate = list("literate", "population", share),
    sex_ratio = list("females", "males", sex_ratio),
    sc_percent = list("sc_population", "population", share),
    st_percent = list("st_population", "population", share)
  )
  derivable <- names(derived)[vapply(derived, function(p) all(c(p[[1]], p[[2]]) %in% names(data)), logical(1))]
  # a table storing a rate directly (1961 literacy) keeps its stored value
  computed <- setdiff(variables, names(data))

  missing <- setdiff(computed, derivable)
  if (length(missing)) {
    cli::cli_abort(c(
      "Variable{?s} {.val {missing}} not available for this year and geography.",
      "i" = "Available here: {.val {union(setdiff(names(data), ids), derivable)}}."
    ))
  }

  for (v in computed) {
    p <- derived[[v]]
    data[[v]] <- p[[3]](data[[p[[1]]]], data[[p[[2]]]])
  }
  data[unique(c(ids, variables))]
}
