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
                       sector = c("total", "rural", "urban")) {
  geography <- match.arg(geography)
  sector <- match.arg(sector)

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
  if (year == 2011 && geography == "subdistrict") {
    return(censusindia::census_subdistricts_2011)
  }

  # census_population_time_series omits Sikkim, Mizoram and Daman & Diu in every
  # year, so routing 2001 and 2011 through it returned 626 districts and
  # 1,208,903,947 people for 2011 against the true 640 and 1,210,854,977. Both
  # years have a complete Primary Census Abstract; use it.
  if (year %in% c(2001L, 2011L) && geography %in% c("state", "district")) {
    return(census_from_pca(year, geography))
  }

  if (year == 1981) {
    data <- censusindia::census_1981 |>
      dplyr::filter(.data$sector == .env$sector)

    if (!geography %in% c("state", "district")) {
      cli::cli_abort("1981 data is available at state and district level only.")
    }
    data <- data |> dplyr::filter(.data$level == .env$geography)

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

#' Build a get_census() frame from the Primary Census Abstract.
#'
#' Renames onto the population/males/females contract the rest of get_census()
#' returns, keeps the abstract's extra indicators so `variables =` can reach
#' literacy and worker counts, and carries `variation_*` across from the time
#' series where that year has it.
#' @noRd
census_from_pca <- function(year, geography) {
  pca <- if (year == 2001L) censusindia::census_2001_pca else censusindia::census_2011_pca

  out <- pca |>
    dplyr::rename(
      population = "population_total",
      males = "population_male",
      females = "population_female"
    ) |>
    dplyr::mutate(year = as.integer(year), geography = "district")

  if (geography == "state") {
    num <- names(out)[vapply(out, is.numeric, logical(1))]
    num <- setdiff(num, c("year", "state_code", "district_code"))
    out <- out |>
      dplyr::group_by(.data$state_code, .data$state_name, .data$state_name_harmonized) |>
      dplyr::summarise(dplyr::across(dplyr::all_of(num), \(x) sum(x, na.rm = TRUE)),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        year = as.integer(year), geography = "state",
        name = .data$state_name_harmonized
      )
  }

  ts <- censusindia::census_population_time_series |>
    dplyr::filter(.data$year == .env$year, .data$geography == .env$geography) |>
    dplyr::select(dplyr::any_of(c(
      "state_name_harmonized", "name", "variation_absolute", "variation_percent"
    )))

  if (all(c("variation_absolute", "state_name_harmonized", "name") %in% names(ts))) {
    out <- dplyr::left_join(out, ts, by = c("state_name_harmonized", "name"))
  }
  out
}

#' Resolve state names or two-letter codes against the canonical list.
#'
#' Accepts a vector. Anything that is neither a code nor a canonical name, but
#' does appear verbatim in `present`, is passed through so historical spellings
#' ("MYSORE") and aggregate rows ("India") still work. Everything else is an
#' error: the old substring fallback quietly turned `state = "Pradesh"` into
#' five states' worth of rows.
#' @noRd
resolve_states <- function(state, present = character(0)) {
  lookup <- censusindia::india_states
  key <- tolower(trimws(as.character(state)))
  present_key <- tolower(trimws(present))

  out <- vapply(key, function(k) {
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
      "i" = "Use a canonical name or two-letter code from {.fn list_states}."
    ))
  }
  # NA marks "matched the data verbatim"; keep the caller's original spelling.
  ifelse(is.na(out), state, out)
}

#' @noRd
filter_by_state <- function(data, state) {
  state_col <- intersect(
    names(data), c("state_name_harmonized", "state", "state_name")
  )[1]
  if (is.na(state_col)) {
    cli::cli_abort("Cannot filter by state: no state column found")
  }

  wanted <- resolve_states(state, present = unique(as.character(data[[state_col]])))
  cols <- intersect(names(data), c("state_name_harmonized", "state", "state_name"))
  hit <- Reduce(`|`, lapply(cols, function(cl) {
    tolower(as.character(data[[cl]])) %in% tolower(wanted)
  }))
  data[hit & !is.na(hit), , drop = FALSE]
}

#' @noRd
select_variables <- function(data, variables) {
  id_cols <- intersect(
    c(
      "year", "geography", "state", "state_name", "state_name_harmonized",
      "district", "subdistrict", "name", "state_code", "district_code",
      "geo_id", "geo_name", "level"
    ),
    names(data)
  )

  var_mapping <- list(
    population = c("population", "total_persons", "population_total"),
    males = c("males", "total_males", "male_count", "population_male"),
    females = c("females", "total_females", "female_count", "population_female"),
    literate = c("literate_total", "literacy_total", "literate_persons"),
    literate_male = c("literate_male", "literacy_male", "literate_males"),
    literate_female = c("literate_female", "literacy_female", "literate_females"),
    sc_population = c("sc_population", "sc_population_total", "sc_total"),
    st_population = c("st_population", "st_population_total", "st_total"),
    workers = c("workers_total", "total_workers_total"),
    main_workers = c("main_workers", "main_workers_total"),
    marginal_workers = c("marginal_workers", "marginal_workers_total"),
    non_workers = c("non_workers", "non_workers_total"),
    households = c("households", "hhld_count"),
    area_km2 = c("area_km2", "area_sqkm")
  )

  # Rates are derived, never aliased.
  derived <- list(
    literacy_rate = c("literate", "population"),
    sex_ratio = c("females", "males"),
    sc_percent = c("sc_population", "population"),
    st_percent = c("st_population", "population")
  )

  resolve <- function(v) {
    if (v %in% names(var_mapping)) {
      m <- intersect(var_mapping[[v]], names(data))
      if (length(m)) {
        return(m[1])
      }
    }
    if (v %in% names(data)) {
      return(v)
    }
    NA_character_
  }

  needed <- unlist(lapply(variables, function(v) {
    if (v %in% names(derived)) derived[[v]] else v
  }))
  resolved <- vapply(needed, resolve, character(1))

  if (anyNA(resolved)) {
    missing <- unique(needed[is.na(resolved)])
    available <- setdiff(names(var_mapping)[
      vapply(names(var_mapping), function(v) !is.na(resolve(v)), logical(1))
    ], character(0))
    cli::cli_abort(c(
      "Variable{?s} {.val {missing}} not available for this year and geography.",
      "i" = "Available here: {.val {available}}."
    ))
  }

  out <- data |>
    dplyr::select(dplyr::all_of(unique(c(id_cols, unname(resolved)))))

  for (v in intersect(variables, names(derived))) {
    parts <- vapply(derived[[v]], resolve, character(1))
    out[[v]] <- if (v == "sex_ratio") {
      1000 * out[[parts[1]]] / out[[parts[2]]]
    } else {
      100 * out[[parts[1]]] / out[[parts[2]]]
    }
  }

  plain <- setdiff(variables, names(derived))
  for (v in plain) {
    src <- resolve(v)
    if (!identical(src, v) && src %in% names(out) && !v %in% id_cols) {
      names(out)[names(out) == src] <- v
    }
  }

  out |> dplyr::select(dplyr::all_of(unique(c(id_cols, variables))))
}
