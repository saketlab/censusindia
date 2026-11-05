# One column schema for every table the package ships, downloads or returns.
# Id columns first in .id_cols order; counts are population/males/females or
# <x>/<x>_male/<x>_female; sector is a row; codes are integers, counts doubles.
# data-raw/legacy.R converts source formats at build time, so canonicalize() only reorders.

#' @noRd
.id_cols <- c(
  "year", "geography", "sector",
  "state_code", "state_name_harmonized", "state_name",
  "district_code", "district", "subdistrict_code", "subdistrict",
  "town_village_code", "ward_code", "name"
)

.count_cols <- function(x) setdiff(names(x)[vapply(x, is.numeric, logical(1))], .id_cols)

#' @noRd
.geographies <- c(
  "india", "state", "district", "subdistrict", "town", "village", "ward",
  "urban_agglomeration"
)

# below the named levels; tables reaching them keep name for the unit
.unit_geographies <- c("town", "village", "ward", "urban_agglomeration")

# shipped tables with no state or district units
.not_geographic <- c("census_variables", "india_states", "census_1931_castes", "census_1931_exterior_castes")

# integer columns counting categories (people counts are doubles)
.integer_values <- c("language_group", "n_languages", "rank", "id")

#' Put a frame in schema order and types
#'
#' Idempotent: a table already on the schema comes back unchanged.
#'
#' @param x A data frame with schema column names.
#' @param year Census year, added when `x` has no `year` column.
#' @param geography Geography, added when `x` has no `geography` column.
#' @noRd
canonicalize <- function(x, year = NULL, geography = NULL) {
  geom <- if (inherits(x, "sf")) attr(x, "sf_column") else NULL
  x <- normalize_codes(tibble::as_tibble(x))

  if ("state_name_harmonized" %in% names(x)) {
    # every table that carries codes uses the 2011 census code of the harmonized state
    ref <- censusindia::india_states
    code <- ref$state_code[match(x$state_name_harmonized, ref$state_name_harmonized)]
    x$state_code <- if ("state_code" %in% names(x)) dplyr::coalesce(x$state_code, code) else code
  }

  if (!"year" %in% names(x) && !is.null(year)) x$year <- year
  if ("year" %in% names(x)) x$year <- as.integer(x$year)

  if (!"geography" %in% names(x)) {
    if (is.null(geography)) cli::cli_abort("{.arg x} has no {.field geography} column; pass {.arg geography}.")
    x$geography <- geography
  }
  x$geography <- normalize_geography(x$geography)
  stopifnot(all(x$geography %in% .geographies))

  ids <- intersect(.id_cols, names(x))
  for (v in setdiff(names(x), c(ids, geom, .integer_values))) {
    if (is.integer(x[[v]])) x[[v]] <- as.double(x[[v]])
  }
  x <- x[c(ids, setdiff(names(x), c(ids, geom)), geom)]
  if (!is.null(geom)) x <- sf::st_as_sf(x, sf_column_name = geom)
  x
}

#' Codes as integers, with NA where the unit has none (0, "000").
#' @noRd
normalize_codes <- function(x) {
  for (v in intersect(grep("_code$", .id_cols, value = TRUE), names(x))) {
    code <- suppressWarnings(as.integer(x[[v]]))
    code[!is.na(code) & code == 0L] <- NA_integer_
    x[[v]] <- code
  }
  x
}

#' "Sub-district" -> "subdistrict", "UA" -> "urban_agglomeration".
#' @noRd
normalize_geography <- function(x) {
  x <- tolower(gsub("[- ]", "", x))
  x[x == "ua"] <- "urban_agglomeration"
  x
}
