#' Language speakers at a chosen geographic level
#'
#' The C-16 mother tongue table ([census_2011_mother_tongue()]) stacks state,
#' district, and subdistrict rows in a single table where subdistricts share
#' their parent district's `district_code`. Summing by `district_code` without
#' filtering `geography` double-counts every speaker. `census_languages()`
#' returns a single geographic level and sector at a time, excluding the
#' `"Others"` residual rows.
#'
#' @param level `"district"` (38,993 rows per sector across 640 districts) or
#'   `"subdistrict"` (144,134 rows per sector across 5,988 subdistricts).
#' @param language_group Optional integer vector of `language_group` codes to
#'   keep, or `NULL` (default) for all groups.
#' @param sector `"total"` (default), `"rural"`, or `"urban"`. Because sector is
#'   stored as rows, summing without filtering `sector` double-counts every
#'   speaker.
#' @param state Optional state filter: one or more canonical state names or
#'   two-letter codes, as in [get_census()].
#'
#' @return A tibble for the requested level and sector, with one row per
#'   language per area. Columns match [census_2011_district_languages] or
#'   [census_2011_subdistrict_languages()].
#' @seealso [census_2011_linguistic_diversity] for district-level diversity
#'   metrics (Shannon entropy, effective number of languages).
#' @examples
#' census_languages("district") |> head()
#' @export
census_languages <- function(level = c("district", "subdistrict"),
                             language_group = NULL,
                             sector = c("total", "rural", "urban"),
                             state = NULL) {
  level <- match.arg(level)
  sector <- match.arg(sector)
  d <- if (level == "district") {
    censusindia::census_2011_district_languages
  } else {
    census_2011_subdistrict_languages()
  }
  d <- d[d$sector == sector, , drop = FALSE]
  if (!is.null(language_group)) {
    if (!rlang::is_integerish(language_group, finite = TRUE)) {
      cli::cli_abort("{.arg language_group} must be whole-number codes.")
    }
    language_group <- as.integer(language_group)
    d <- d |> dplyr::filter(.data$language_group %in% .env$language_group)
  }
  if (!is.null(state)) {
    d <- filter_by_state(d, state)
  }
  d
}

#' Filter a stacked census table to one geographic level and sector
#'
#' The village-level 2011 tables ([census_2011_demographics()],
#' [census_2011_workers()], [census_2011_marginal_detail()]) and [census_1981]
#' stack multiple geographic levels (from India down to village or ward) and
#' three sectors (`"total"`, `"rural"`, `"urban"`) in the same table. Summing
#' rows without filtering both `geography` and `sector` counts people multiple
#' times. `at_level()` filters `geography` and, when a `sector` column is
#' present, `sector`.
#'
#' The levels `"india"`, `"state"`, `"district"`, `"subdistrict"`, and
#' `"village"` are additively exact: each level sums to its parent, and
#' `rural + urban == total`.
#'
#' The levels `"town"` and `"ward"` are **not** additive: the Census lists a
#' municipality and the same municipality with its outgrowths as separate town
#' rows (for example, `BBMP (M Corp.)` and `BBMP (M Corp. + OG)` in Bengaluru),
#' and ward rows do not always sum to the parent town row. Use town and ward
#' rows for lookups, not aggregation.
#'
#' @param data A data frame with a `geography` column (e.g., [census_1981] or
#'   one of the village-level 2011 tables).
#' @param level Geographic level, such as `"district"` or `"state"`. Accepts
#'   `"sub-district"` as a synonym for `"subdistrict"`.
#' @param sector `"total"` (default), `"rural"`, or `"urban"`.
#'
#' @return `data` filtered to `level` and `sector`.
#' @examples
#' census_1981 |>
#'   at_level("state") |>
#'   nrow()
#' @export
at_level <- function(data, level = "district", sector = c("total", "rural", "urban")) {
  if (!"geography" %in% names(data)) {
    cli::cli_abort("{.arg data} has no {.field geography} column.")
  }
  sector <- match.arg(sector)
  level <- normalize_geography(level)
  if (length(level) != 1L || is.na(level) || !level %in% .geographies) {
    cli::cli_abort("{.arg level} must be one of {.val {(.geographies)}}.")
  }
  out <- data |> dplyr::filter(.data$geography == .env$level)
  if ("sector" %in% names(data)) {
    out <- out |> dplyr::filter(.data$sector == .env$sector)
  }
  out
}

#' Keep only decennial census years
#'
#' [census_population_time_series] includes non-decennial years (1900, 1910,
#' 1940, 1948, 1950, 1960, 1962, and 2021) alongside the twelve decennial
#' censuses. Computing `lag()` on the unfiltered table silently produces 1-year
#' or 13-year intervals instead of 10-year intervals.
#'
#' @param data A data frame with a `year` column.
#' @return `data` restricted to the twelve decennial census years (1901 to
#'   2011).
#' @examples
#' census_population_time_series |>
#'   census_years() |>
#'   dplyr::distinct(year)
#' @export
census_years <- function(data) {
  if (!"year" %in% names(data)) {
    cli::cli_abort("{.arg data} has no {.field year} column.")
  }
  dplyr::filter(data, .data$year %in% .census_years)
}

#' @noRd
.census_years <- c(
  1901L, 1911L, 1921L, 1931L, 1941L, 1951L,
  1961L, 1971L, 1981L, 1991L, 2001L, 2011L
)

#' Scheduled Caste and Scheduled Tribe rows
#'
#' [census_2011_sc_st] stores full names in `category` (`"Scheduled Caste"`,
#' `"Scheduled Tribe"`) and short codes in `category_code` (`"SC"`, `"ST"`), so
#' `dplyr::filter(category == "SC")` silently returns zero rows.
#' `census_sc_st()` accepts either form, case-insensitively.
#'
#' Individual Scheduled Tribes are listed by name (581 tribes). Scheduled Castes
#' are reported only as a single district aggregate (`"All Scheduled Castes"`,
#' 582 districts).
#'
#' @param category `"SC"`, `"ST"`, `"Scheduled Caste"`, `"Scheduled Tribe"`, or
#'   `NULL` (default) to keep both categories. Case-insensitive; accepts a
#'   vector.
#' @param state Optional state filter: one or more canonical state names or
#'   two-letter codes, as in [get_census()].
#'
#' @return A tibble of [census_2011_sc_st] rows.
#' @seealso [census_2011_tribes] for Scheduled Tribe rows with harmonized names
#'   and without the `"Generic Tribes etc."` residual.
#' @examples
#' nrow(census_sc_st("SC"))
#' nrow(census_sc_st("Scheduled Caste"))
#' @export
census_sc_st <- function(category = NULL, state = NULL) {
  d <- censusindia::census_2011_sc_st

  if (!is.null(category)) {
    d <- d[d$category_code %in% resolve_sc_st_category(category), , drop = FALSE]
  }
  if (!is.null(state)) {
    d <- filter_by_state(d, state)
  }
  d
}

#' Gives the SC or ST code for each form of a category name.
#' @noRd
resolve_sc_st_category <- function(category) {
  key <- gsub("[^a-z]", "", tolower(as.character(category)))
  lookup <- c(
    sc = "SC", scheduledcaste = "SC", scheduledcastes = "SC",
    st = "ST", scheduledtribe = "ST", scheduledtribes = "ST"
  )
  out <- unname(lookup[key])
  bad <- category[is.na(out)]
  if (length(bad)) {
    cli::cli_abort(c(
      "Unknown categor{?y/ies}: {.val {bad}}.",
      "i" = "Use {.val SC} or {.val ST}, or the spelled-out form."
    ))
  }
  unique(out)
}
