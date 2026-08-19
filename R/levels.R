#' Language speakers at a chosen geographic level
#'
#' The C-16 mother tongue tables stack state, district and subdistrict rows,
#' and a subdistrict carries its parent's `district_code`. Filtering on
#' `district_code != "000"` therefore keeps subdistricts too, and summing the
#' result double counts: 640 districts become 6,231 rows, and district totals
#' inflate by a median factor of two.
#'
#' `area_name` does not separate the two levels either, because in 392 of the
#' 640 districts the headquarters tehsil carries the district's own name.
#' Subdistricts do partition their district, so the district value for any
#' `(district_code, language_code)` is half the group sum. The tables this
#' returns are that split, applied once at build time.
#'
#' @param level `"district"` (38,993 rows, 640 districts) or `"subdistrict"`
#'   (144,134 rows, 5,988 areas).
#' @param language_group Optionally restrict to one language group, as listed in
#'   the `language_group` column. Default `NULL` keeps all.
#'
#' @return A tibble at the requested level, one row per language per area.
#' @seealso [census_2011_linguistic_diversity] for one row per district with
#'   entropy already computed.
#' @examples
#' census_languages("district") |> head()
#' @export
census_languages <- function(level = c("district", "subdistrict"),
                             language_group = NULL) {
  level <- match.arg(level)
  d <- if (level == "district") {
    censusindia::census_2011_district_languages
  } else {
    censusindia::census_2011_subdistrict_languages
  }
  if (!is.null(language_group)) {
    d <- d |> dplyr::filter(.data$language_group %in% .env$language_group)
  }
  d
}

#' Census rows at one geographic level
#'
#' The village-level 2011 tables ([census_2011_demographics],
#' [census_2011_workers], [census_2011_marginal_detail]) stack seven levels from
#' India down to ward, and three sectors. Summing without filtering counts every
#' population several times over.
#'
#' India, state, district, subdistrict and village are exact: each level sums to
#' its parent for every numeric column, and rural + urban sums to total.
#'
#' `"town"` and `"ward"` are not. The census files a municipality and that same
#' municipality plus its outgrowth as separate town rows, so the two overlap.
#' Summing towns to their subdistrict overcounts 325 subdistricts by 73,877,047
#' people in total; Bengaluru's `BBMP (M Corp.)` and `BBMP (M Corp. + OG)` each
#' carry 8,443,675. Ward rows differ from their town by 3,738,272 across 295
#' towns. Treat both as a lookup, not an additive slice.
#'
#' @param data One of the village-level 2011 tables.
#' @param level Geographic level, e.g. `"district"` or `"state"`.
#' @param sector `"total"`, `"rural"` or `"urban"`.
#'
#' @return `data` filtered to that level and sector.
#' @examples
#' census_2011_demographics |>
#'   at_level("district") |>
#'   nrow()
#' @export
at_level <- function(data, level = "district", sector = "total") {
  if (!"level" %in% names(data)) {
    cli::cli_abort("{.arg data} has no {.field level} column.")
  }
  out <- data |> dplyr::filter(.data$level == .env$level)
  if ("sector" %in% names(data)) {
    out <- out |> dplyr::filter(.data$sector == .env$sector)
  }
  out
}

#' Census years only
#'
#' [census_population_time_series] carries rows for 1900, 1910, 1940, 1948,
#' 1950, 1960, 1962 and 2021 alongside the twelve decennial censuses. A
#' `lag()` over the unfiltered table silently produces one- and thirteen-year
#' intervals labelled as decadal.
#'
#' @param data A frame with a `year` column.
#' @return `data` keeping only the twelve census years, 1901 to 2011.
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

#' Scheduled Caste and Scheduled Tribe rows, by either name
#'
#' [census_2011_sc_st] stores `category` as `"Scheduled Caste"` and
#' `"Scheduled Tribe"`. `filter(category == "SC")` therefore matches nothing and
#' raises no error. This accessor takes either spelling, in any case, and the
#' table itself now carries a `category_code` column holding `SC`/`ST` so plain
#' `dplyr::filter()` works both ways too.
#'
#' The two categories are not symmetric. Scheduled Tribes are named, 581 of
#' them. All 582 Scheduled Caste rows carry the single label
#' `"All Scheduled Castes"`, one per district, so `"SC"` returns district
#' aggregates rather than individual castes.
#'
#' @param category `"SC"`, `"ST"`, `"Scheduled Caste"`, `"Scheduled Tribe"`, or
#'   `NULL` (default) to keep both. Case-insensitive; a vector selects several.
#' @param state Optionally restrict to one or more states, by canonical name or
#'   two-letter code, as in [get_census()].
#'
#' @return A tibble of [census_2011_sc_st] rows.
#' @seealso [census_2011_tribes] for the ST rows with names harmonised and the
#'   `"Generic Tribes etc."` residual removed.
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

#' Map either spelling of a category onto its SC/ST code.
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
