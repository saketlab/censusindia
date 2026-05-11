.geometry_cache <- new.env(parent = emptyenv())

#' Clear geometry cache
#'
#' @return Invisible NULL
#' @export
#' @examples
#' \dontrun{
#' clear_geometry_cache()
#' }
clear_geometry_cache <- function() {
  rm(list = ls(envir = .geometry_cache), envir = .geometry_cache)
  invisible(NULL)
}

#' @noRd
get_cached_geometry <- function(year, geography) {
  cache_key <- paste0(year, "_", geography)

  if (exists(cache_key, envir = .geometry_cache)) {
    return(get(cache_key, envir = .geometry_cache))
  }

  filename <- sprintf(
    "india-census-%d-%s.geojson", year,
    if (geography == "state") "states" else "districts"
  )
  geojson_path <- system.file("extdata", filename, package = "censusindia")

  if (geojson_path == "") {
    return(NULL)
  }

  shapes <- sf::st_read(geojson_path, quiet = TRUE)
  assign(cache_key, shapes, envir = .geometry_cache)
  shapes
}

#' @noRd
add_geometry <- function(data, year, geography) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required for geometry support.")
  }

  if (!geography %in% c("state", "district")) {
    cli::cli_warn("Geometry not available for {.val {geography}} level")
    return(data)
  }

  shapes <- get_cached_geometry(year, geography)

  if (is.null(shapes)) {
    available_years <- c(1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011)
    closest_year <- available_years[which.min(abs(available_years - year))]
    shapes <- get_cached_geometry(closest_year, geography)

    if (!is.null(shapes)) {
      cli::cli_warn(c(
        "Exact boundaries for {.val {year}} not available.",
        "i" = "Using {.val {closest_year}} boundaries instead."
      ))
    } else {
      cli::cli_warn("No geographic boundaries available for {.val {geography}} level")
      return(data)
    }
  }

  if (geography == "state") {
    join_state_geometry(data, shapes)
  } else if (all(c("state_name_harmonized", "district_name") %in% names(shapes))) {
    join_districts_geometry(data, shapes)
  } else {
    cli::cli_warn("Shapefile missing required columns for district join")
    data
  }
}

#' @noRd
join_state_geometry <- function(data, shapes) {
  if ("state_name_harmonized" %in% names(data) &&
    "state_name_harmonized" %in% names(shapes)) {
    result <- dplyr::left_join(
      data,
      shapes |> dplyr::select(state_name_harmonized, geometry),
      by = "state_name_harmonized"
    )
  } else {
    shapes_df <- shapes |>
      dplyr::mutate(join_key = normalize_name(state_name))
    data_col <- intersect(c("state_name", "state", "name"), names(data))[1]
    data_df <- data |>
      dplyr::mutate(join_key = normalize_name(.data[[data_col]]))

    result <- dplyr::left_join(
      data_df,
      shapes_df |> dplyr::select(join_key, geometry),
      by = "join_key"
    )

    unmatched <- is.na(sf::st_dimension(result$geometry)) |
      vapply(result$geometry, sf::st_is_empty, logical(1))

    if (any(unmatched)) {
      result <- fuzzy_join_geometry(result, shapes_df, unmatched, "join_key")
    }
    result <- result |> dplyr::select(-join_key)
  }

  sf::st_as_sf(result)
}

#' @noRd
join_districts_geometry <- function(data, shapes) {
  if ("state_name_harmonized" %in% names(data) &&
    "state_name_harmonized" %in% names(shapes)) {
    shapes_df <- shapes |>
      dplyr::mutate(district_key = normalize_name(district_name))

    district_col <- intersect(c("district", "name", "area_name"), names(data))[1]
    data_df <- data |>
      dplyr::mutate(district_key = normalize_name(gsub(" District$", "", .data[[district_col]])))

    result <- dplyr::left_join(
      data_df,
      shapes_df |> dplyr::select(state_name_harmonized, district_key, geometry),
      by = c("state_name_harmonized", "district_key")
    )

    unmatched <- is.na(sf::st_dimension(result$geometry)) |
      vapply(result$geometry, sf::st_is_empty, logical(1))

    if (any(unmatched)) {
      result <- fuzzy_join_districts_harmonized(result, shapes_df, unmatched)
    }

    result <- result |> dplyr::select(-district_key)
  } else {
    shapes_df <- shapes |>
      dplyr::mutate(
        state_key = normalize_name(state_name),
        district_key = normalize_name(district_name)
      )

    state_col <- intersect(c("state_name", "state"), names(data))[1]
    district_col <- intersect(c("district", "name"), names(data))[1]

    if (is.null(state_col) || is.null(district_col)) {
      cli::cli_warn("Could not determine state/district columns for geometry join")
      return(data)
    }

    data_df <- data |>
      dplyr::mutate(
        state_key = normalize_name(.data[[state_col]]),
        district_key = normalize_name(.data[[district_col]])
      )

    result <- dplyr::left_join(
      data_df,
      shapes_df |> dplyr::select(state_key, district_key, geometry),
      by = c("state_key", "district_key")
    )

    unmatched <- is.na(sf::st_dimension(result$geometry)) |
      vapply(result$geometry, sf::st_is_empty, logical(1))

    if (any(unmatched)) {
      result <- fuzzy_join_districts(result, shapes_df, unmatched)
    }

    result <- result |> dplyr::select(-state_key, -district_key)
  }

  sf::st_as_sf(result)
}

#' @noRd
fuzzy_join_districts_harmonized <- function(result, shapes_df, unmatched) {
  for (i in which(unmatched)) {
    candidates <- shapes_df |>
      dplyr::filter(state_name_harmonized == result$state_name_harmonized[i])
    if (nrow(candidates) == 0) next

    data_name <- result$district_key[i]

    contains_match <- which(
      sapply(candidates$district_key, function(cn) grepl(cn, data_name, fixed = TRUE)) |
        sapply(candidates$district_key, function(cn) grepl(data_name, cn, fixed = TRUE))
    )
    if (length(contains_match) == 1) {
      result$geometry[i] <- candidates$geometry[contains_match]
      next
    }

    exact_match <- which(tolower(candidates$district_key) == tolower(data_name))
    if (length(exact_match) == 1) {
      result$geometry[i] <- candidates$geometry[exact_match]
      next
    }

    distances <- utils::adist(data_name, candidates$district_key, ignore.case = TRUE)[1, ]
    best_idx <- which.min(distances)

    if (distances[best_idx] <= max(3, nchar(data_name) * 0.3)) {
      result$geometry[i] <- candidates$geometry[best_idx]
    }
  }
  result
}

#' @noRd
fuzzy_join_districts <- function(result, shapes_df, unmatched) {
  for (i in which(unmatched)) {
    candidates <- shapes_df |> dplyr::filter(state_key == result$state_key[i])
    if (nrow(candidates) == 0) next

    distances <- utils::adist(result$district_key[i], candidates$district_key)[1, ]
    best_idx <- which.min(distances)

    if (distances[best_idx] <= max(3, nchar(result$district_key[i]) * 0.3)) {
      result$geometry[i] <- candidates$geometry[best_idx]
    }
  }
  result
}

#' @noRd
fuzzy_join_geometry <- function(result, shapes_df, unmatched, key_col) {
  for (i in which(unmatched)) {
    distances <- utils::adist(result[[key_col]][i], shapes_df[[key_col]])[1, ]
    best_idx <- which.min(distances)

    if (distances[best_idx] <= max(3, nchar(result[[key_col]][i]) * 0.3)) {
      result$geometry[i] <- shapes_df$geometry[best_idx]
    }
  }
  result
}

#' @noRd
normalize_name <- function(x) {
  x <- tolower(x)
  x <- stringr::str_squish(x)
  x <- stringr::str_replace_all(x, "twenty four", "24")
  x <- stringr::str_replace_all(x, "twenty-four", "24")
  x <- stringr::str_replace_all(x, "[^a-z0-9 ]", "")
  stringr::str_squish(x)
}

#' Attach geographic boundaries to census data
#'
#' Adds geometry for mapping. Auto-detects state or district level from
#' available columns.
#'
#' @param data A data frame containing census data with state/district names.
#' @param year Census year for boundaries. Available: 1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011.
#' @param geography Geographic level: "state" or "district". If NULL (default),
#'   auto-detects based on available columns.
#'
#' @return An sf object with geometry attached.
#'
#' @examples
#' \dontrun{
#' library(dplyr)
#' data(census_2011_pca)
#'
#' # Attach district boundaries
#' census_2011_pca |>
#'   mutate(st_pct = 100 * st_population / population_total) |>
#'   attach_geometry(2011)
#' }
#'
#' @export
attach_geometry <- function(data, year, geography = NULL) {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required for geometry support.")
  }

  if (is.null(geography)) {
    if ("geography" %in% names(data)) {
      geography <- unique(data$geography)[1]
    } else if (any(c("district", "district_code", "name") %in% names(data))) {
      geography <- "district"
    } else {
      geography <- "state"
    }
  }

  add_geometry(data, year, geography)
}

#' Get census boundaries
#'
#' State or district boundaries for a given census year.
#'
#' @param year Census year. Available: 1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011.
#' @param geography Geographic level: "state" or "district".
#' @return An sf object containing the geographic boundaries with harmonized state names.
#'
#' @examples
#' \dontrun{
#' boundaries <- get_census_boundaries(1971, "district")
#' ggplot2::ggplot(boundaries) +
#'   ggplot2::geom_sf()
#' }
#'
#' @export
get_census_boundaries <- function(year, geography = c("state", "district")) {
  geography <- match.arg(geography)

  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required for geometry support.")
  }

  shapes <- get_cached_geometry(year, geography)

  if (is.null(shapes)) {
    cli::cli_abort(c(
      "Boundaries not available for year {.val {year}}",
      "i" = "Available years: 1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011"
    ))
  }

  shapes
}
