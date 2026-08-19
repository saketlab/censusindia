# Census years with a boundary file in inst/extdata.
BOUNDARY_YEARS <- c(1941L, 1951L, 1961L, 1971L, 1981L, 1991L, 2001L, 2011L)

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

#' Repair self-intersecting boundary polygons.
#'
#' 1941 Madras, 1961 Punjab and 2001 Tamil Nadu are invalid as shipped, and
#' st_area, st_centroid, st_union and st_intersects all throw on them rather
#' than return. st_make_valid fixes the first two. Tamil Nadu is valid in the
#' plane but not on the sphere ("Edge 176 crosses edge 178"), which only
#' s2_rebuild resolves.
#' @noRd
repair_geometry <- function(shapes) {
  bad <- !sf::st_is_valid(sf::st_geometry(shapes))
  if (!any(bad, na.rm = TRUE)) {
    return(shapes)
  }

  shapes <- sf::st_make_valid(shapes)
  bad <- !sf::st_is_valid(sf::st_geometry(shapes))
  if (!any(bad, na.rm = TRUE) || !requireNamespace("s2", quietly = TRUE)) {
    return(shapes)
  }

  g <- sf::st_geometry(shapes)
  fixed <- tryCatch(
    sf::st_as_sfc(
      s2::s2_rebuild(s2::as_s2_geography(sf::st_as_text(g[bad]), check = FALSE)),
      crs = sf::st_crs(g)
    ),
    error = function(e) NULL
  )
  if (!is.null(fixed)) {
    g[bad] <- fixed
    sf::st_geometry(shapes) <- g
  }
  shapes
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
  shapes <- repair_geometry(shapes)
  shapes <- relabel_boundaries(shapes, year, geography)
  assign(cache_key, shapes, envir = .geometry_cache)
  shapes
}

# Districts the upstream shapefile ships as "Unknown", identified by centroid,
# area and adjacency:
#   2001 Gujarat  (70.86 E, 22.43 N, 12,460 km2), adjacent to Amreli/Bhavnagar
#                 -> Rajkot
#   2001 Manipur  (93.55 E, 24.86 N,    877 km2), adjacent to Imphal West,
#                 Senapati, Churachandpur -> Imphal East
# Left unlabelled, "Imphal East *" fell through to edit-distance matching and was
# handed the Imphal West polygon, so two districts drew the same shape.
.boundary_relabels <- data.frame(
  year = c(2001L, 2001L),
  geography = c("district", "district"),
  state_name_harmonized = c("Gujarat", "Manipur"),
  from = c("Unknown", "Unknown"),
  to = c("Rajkot", "Imphal East"),
  stringsAsFactors = FALSE
)

#' @noRd
relabel_boundaries <- function(shapes, year, geography) {
  if (!"district_name" %in% names(shapes)) {
    return(shapes)
  }
  r <- .boundary_relabels[
    .boundary_relabels$year == year & .boundary_relabels$geography == geography, ,
    drop = FALSE
  ]
  for (i in seq_len(nrow(r))) {
    hit <- which(
      shapes$state_name_harmonized == r$state_name_harmonized[i] &
        shapes$district_name == r$from[i]
    )
    if (length(hit) == 1) shapes$district_name[hit] <- r$to[i]
  }
  shapes
}

#' @noRd
add_geometry <- function(data, year, geography, unmatched = "warn") {
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required for geometry support.")
  }

  if (!geography %in% c("state", "district")) {
    cli::cli_warn("Geometry not available for {.val {geography}} level")
    return(data)
  }

  shapes <- get_cached_geometry(year, geography)

  if (is.null(shapes)) {
    closest_year <- BOUNDARY_YEARS[which.min(abs(BOUNDARY_YEARS - year))]
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

  out <- if (geography == "state") {
    join_state_geometry(data, shapes, year)
  } else if (all(c("state_name_harmonized", "district_name") %in% names(shapes))) {
    join_districts_geometry(data, shapes, year)
  } else {
    cli::cli_warn("Shapefile missing required columns for district join")
    return(data)
  }

  out <- report_join_quality(out, unmatched)
  # plot_map() needs the vintage to know which outline belongs underneath;
  # guessing is how the national boundary went missing.
  attr(out, "census_boundary_year") <- year
  out
}

#' Report rows that got no geometry, and polygons claimed more than once.
#'
#' The matcher falls back to substring and edit-distance comparison, neither of
#' which checks whether the polygon it picks is already spoken for. That is how
#' "Imphal East *" was handed the Imphal West shape: two districts, one outline,
#' no complaint. A silently incomplete or double-drawn map is worse than a loud
#' failure.
#' @noRd
report_join_quality <- function(out, unmatched = c("warn", "error", "ignore")) {
  unmatched <- match.arg(unmatched)
  if (unmatched == "ignore" || !inherits(out, "sf")) {
    return(out)
  }

  empty <- sf::st_is_empty(sf::st_geometry(out))
  label <- intersect(c("district", "name", "area_name", "state_name_harmonized"), names(out))[1]
  named <- function(i) {
    if (is.na(label)) paste("row", i) else as.character(out[[label]][i])
  }

  problems <- character(0)
  if (any(empty)) {
    problems <- c(problems, sprintf(
      "%d of %d rows got no geometry: %s.",
      sum(empty), nrow(out), paste(utils::head(named(which(empty)), 5), collapse = ", ")
    ))
  }

  drawn <- which(!empty)
  if (length(drawn) > 1) {
    wkt <- sf::st_as_text(sf::st_geometry(out)[drawn])
    dup <- unique(wkt[duplicated(wkt)])
    if (length(dup)) {
      who <- vapply(dup, function(w) {
        paste(named(drawn[wkt == w]), collapse = " + ")
      }, character(1))
      problems <- c(problems, sprintf(
        "%d polygon(s) claimed by more than one row: %s.",
        length(dup), paste(utils::head(who, 3), collapse = "; ")
      ))
    }
  }

  if (length(problems)) {
    problems <- gsub("{", "{{", problems, fixed = TRUE)
    problems <- gsub("}", "}}", problems, fixed = TRUE)
    msg <- c("Geometry join is incomplete.", stats::setNames(problems, rep("x", length(problems))))
    if (unmatched == "error") {
      cli::cli_abort(c(msg, "i" = "Pass {.code unmatched = \"warn\"} to map anyway."))
    }
    cli::cli_warn(msg)
  }
  out
}

#' States created after a boundary vintage, and the state they were carved
#' from. Without this, their districts match nothing in an older boundary file
#' and drop off the map entirely. Ladakh's absence truncates India's northern
#' extent from 37.1N to 34.9N, and the 2000 trifurcation drops Uttarakhand,
#' Jharkhand and Chhattisgarh from the 1991 map.
#' @noRd
.state_succession <- data.frame(
  state = c(
    "Uttarakhand", "Jharkhand", "Chhattisgarh",
    "Telangana", "Ladakh"
  ),
  parent = c(
    "Uttar Pradesh", "Bihar", "Madhya Pradesh",
    "Andhra Pradesh", "Jammu & Kashmir"
  ),
  created = c(2000L, 2000L, 2000L, 2014L, 2019L),
  stringsAsFactors = FALSE
)

#' Map successor states onto the parent they were part of in `year`.
#' @noRd
remap_successor_states <- function(x, year) {
  if (is.null(year) || is.na(year)) {
    return(x)
  }
  s <- .state_succession[.state_succession$created > year, , drop = FALSE]
  if (!nrow(s)) {
    return(x)
  }
  i <- match(x, s$state)
  ifelse(is.na(i), x, s$parent[i])
}

#' @noRd
join_state_geometry <- function(data, shapes, year = NULL) {
  if ("state_name_harmonized" %in% names(data) &&
    "state_name_harmonized" %in% names(shapes)) {
    result <- data |>
      dplyr::mutate(.match_state = remap_successor_states(.data$state_name_harmonized, .env$year)) |>
      dplyr::left_join(
        shapes |>
          dplyr::select(state_name_harmonized, geometry) |>
          dplyr::rename(.match_state = state_name_harmonized),
        by = ".match_state"
      ) |>
      dplyr::select(-".match_state")
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

#' Collapse boundary rows that share a join key into one multipolygon.
#'
#' The 1991 file lists Firozabad, Pondicherry and Andaman & Nicobar twice. A
#' left join against duplicate keys multiplies rows, so a 626-row frame came
#' back with 627. Both rows are real parts of the district; unioned so
#' neither is lost.
#' @noRd
dedupe_shapes <- function(shapes_df, key_cols) {
  key <- do.call(paste, c(unname(as.list(sf::st_drop_geometry(shapes_df)[key_cols])), sep = "\r"))
  dup <- unique(key[duplicated(key)])
  if (!length(dup)) {
    return(shapes_df)
  }
  keep <- !key %in% dup
  merged <- lapply(dup, function(k) {
    part <- shapes_df[key == k, , drop = FALSE]
    one <- part[1, , drop = FALSE]
    sf::st_geometry(one) <- sf::st_sfc(
      sf::st_union(sf::st_geometry(part)),
      crs = sf::st_crs(part)
    )
    one
  })
  out <- rbind(shapes_df[keep, , drop = FALSE], do.call(rbind, merged))
  out
}

#' @noRd
join_districts_geometry <- function(data, shapes, year = NULL) {
  if ("state_name_harmonized" %in% names(data) &&
    "state_name_harmonized" %in% names(shapes)) {
    shapes_df <- shapes |>
      dplyr::mutate(district_key = normalize_name(district_name)) |>
      dedupe_shapes(c("state_name_harmonized", "district_key"))

    district_col <- intersect(c("district", "name", "area_name"), names(data))[1]
    data_df <- data |>
      dplyr::mutate(
        district_key = normalize_name(gsub(" District$", "", .data[[district_col]])),
        .match_state = remap_successor_states(.data$state_name_harmonized, .env$year)
      )

    result <- dplyr::left_join(
      data_df,
      shapes_df |>
        dplyr::select(state_name_harmonized, district_key, geometry) |>
        dplyr::rename(.match_state = state_name_harmonized),
      by = c(".match_state", "district_key")
    )

    unmatched <- is.na(sf::st_dimension(result$geometry)) |
      vapply(result$geometry, sf::st_is_empty, logical(1))

    if (any(unmatched)) {
      result <- fuzzy_join_districts_harmonized(result, shapes_df, unmatched)
    }

    result <- result |> dplyr::select(-district_key, -".match_state")
  } else {
    shapes_df <- shapes |>
      dplyr::mutate(
        state_key = normalize_name(state_name),
        district_key = normalize_name(district_name)
      ) |>
      dedupe_shapes(c("state_key", "district_key"))

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
    key <- if (".match_state" %in% names(result)) {
      result$.match_state[i]
    } else {
      result$state_name_harmonized[i]
    }
    candidates <- shapes_df |> dplyr::filter(state_name_harmonized == key)
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
  # Sources disagree on "&" vs "and". Stripping the ampersand as punctuation left
  # "lahul spiti" against the shapefile's "lahul and spiti", so Lahul & Spiti got
  # no geometry. Spell it out on both sides before punctuation goes.
  x <- stringr::str_replace_all(x, "&", " and ")
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
#' @param unmatched What to do when rows get no geometry, or when two rows are
#'   given the same polygon: `"warn"` (default), `"error"`, or `"ignore"`.
#'   Name matching falls back to substring and edit distance, so a district can
#'   be handed a wrong-but-similar shape; this is how the check surfaces.
#'
#' @return An sf object with geometry attached.
#'
#' @examples
#' \dontrun{
#' library(dplyr)
#'
#' data(census_2011_pca)
#'
#' # Attach district boundaries
#' census_2011_pca |>
#'   mutate(st_pct = 100 * st_population / population_total) |>
#'   attach_geometry(2011)
#' }
#'
#' @export
attach_geometry <- function(data, year, geography = NULL,
                            unmatched = c("warn", "error", "ignore")) {
  unmatched <- match.arg(unmatched)
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

  add_geometry(data, year, geography, unmatched)
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
