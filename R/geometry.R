BOUNDARY_YEARS <- c(1941L, 1951L, 1961L, 1971L, 1981L, 1991L, 2001L, 2011L)

nearest_boundary_year <- function(year) BOUNDARY_YEARS[which.min(abs(BOUNDARY_YEARS - year))]

boundary_file <- function(year, geography) {
  sprintf("india-census-%d-%s.geojson.gz", year, ifelse(geography == "state", "states", "districts"))
}

.session_cache <- new.env(parent = emptyenv())

#' Clear geometry cache
#'
#' Evicts cached boundary geometries and downloaded tables from session memory.
#'
#' @return Invisible `NULL`.
#' @export
#' @seealso [clear_census_cache()] deletes the downloaded files from disk.
#' @examples
#' clear_geometry_cache()
clear_geometry_cache <- function() {
  rm(list = ls(envir = .session_cache), envir = .session_cache)
  invisible(NULL)
}

#' Repair self-intersecting boundary polygons.
#'
#' The source polygons for 1941 Madras, 1961 Punjab and 2001 Tamil Nadu are
#' not valid. st_area, st_centroid, st_union and st_intersects give an error on
#' them. st_make_valid repairs the first two. Tamil Nadu is valid in the plane
#' but not on the sphere, so it needs s2_rebuild.
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
  rlang::env_cache(.session_cache, paste0(year, "_", geography), {
    path <- census_file(boundary_file(year, geography))
    shapes <- sf::st_read(paste0("/vsigzip/", path), quiet = TRUE)
    shapes$id <- as.integer(shapes$id)
    names(shapes)[names(shapes) == "district_name"] <- "district"
    shapes <- canonicalize(repair_geometry(shapes), year = as.integer(year), geography = geography)
    relabel_boundaries(shapes, year, geography)
  })
}

# polygons the upstream file names "Unknown", identified by centroid, area and adjacency
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
  if (!"district" %in% names(shapes)) {
    return(shapes)
  }
  r <- .boundary_relabels[
    .boundary_relabels$year == year & .boundary_relabels$geography == geography, ,
    drop = FALSE
  ]
  for (i in seq_len(nrow(r))) {
    hit <- which(
      shapes$state_name_harmonized == r$state_name_harmonized[i] &
        shapes$district == r$from[i]
    )
    if (length(hit) == 1) shapes$district[hit] <- r$to[i]
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

  closest_year <- nearest_boundary_year(year)
  if (closest_year != year) {
    cli::cli_warn(c(
      "Exact boundaries for {.val {year}} not available.",
      "i" = "Using {.val {closest_year}} boundaries instead."
    ))
  }
  shapes <- get_cached_geometry(closest_year, geography)

  out <- if (geography == "state") {
    join_state_geometry(data, shapes, year)
  } else if (all(c("state_name_harmonized", "district") %in% names(shapes))) {
    join_districts_geometry(data, shapes, year)
  } else {
    cli::cli_warn("Shapefile missing required columns for district join")
    return(data)
  }

  out <- report_join_quality(out, unmatched)
  # plot_map() reads this to pick the outline drawn underneath
  attr(out, "census_boundary_year") <- year
  out
}

#' Reports rows with no geometry, and polygons that more than one row claims.
#'
#' The fallback match on substrings and edit distance can give one polygon to
#' two rows.
#' @noRd
report_join_quality <- function(out, unmatched = c("warn", "error", "ignore")) {
  unmatched <- match.arg(unmatched)
  if (unmatched == "ignore" || !inherits(out, "sf")) {
    return(out)
  }

  empty <- sf::st_is_empty(sf::st_geometry(out))
  # first label column with values; a state frame can carry an empty district column
  label <- intersect(c("district", "name", "area_name", "state_name_harmonized"), names(out))
  label <- label[!vapply(label, function(v) all(is.na(out[[v]])), logical(1))][1]
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
    state_col <- intersect(c("state_name_harmonized", "state_name", "state"), names(out))[1]
    unit_id <- if (!is.na(state_col) && !is.na(label)) {
      paste(out[[state_col]][drawn], out[[label]][drawn], sep = "\r")
    } else {
      named(drawn)
    }
    drawn <- drawn[!duplicated(unit_id)]
  }
  if (length(drawn) > 1) {
    key <- vapply(sf::st_as_binary(sf::st_geometry(out)[drawn]), rlang::hash, character(1))
    dup <- unique(key[duplicated(key)])
    if (length(dup)) {
      who <- vapply(dup, function(w) {
        paste(named(drawn[key == w]), collapse = " + ")
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

#' States that came after a boundary vintage, and the parent state of each.
#' Without this table, their districts match nothing in an older boundary file
#' and are absent from the map.
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

#' Gives the parent state in `year` for each successor state.
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
      sf::st_is_empty(result$geometry)

    if (any(unmatched)) {
      result <- fuzzy_join_geometry(result, shapes_df, unmatched, "join_key")
    }
    result <- result |> dplyr::select(-join_key)
  }

  sf::st_as_sf(result)
}

#' Combines the boundary rows with the same join key into one multipolygon.
#'
#' The 1991 file has two rows each for Firozabad, Pondicherry and Andaman &
#' Nicobar. A left join on duplicate keys adds rows. Each of the two rows is a
#' real part of the district, so the function keeps the two parts in one
#' multipolygon.
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
      dplyr::mutate(district_key = normalize_name(.data$district)) |>
      dedupe_shapes(c("state_name_harmonized", "district_key"))

    district_col <- intersect(c("district", "district_name", "name", "area_name"), names(data))[1]
    if (is.na(district_col)) {
      cli::cli_abort("No district name column in {.arg data}; expected {.field district}.")
    }
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
      sf::st_is_empty(result$geometry)

    if (any(unmatched)) {
      result <- fuzzy_join_districts_harmonized(result, shapes_df, unmatched)
    }

    result <- result |> dplyr::select(-district_key, -".match_state")
  } else {
    shapes_df <- shapes |>
      dplyr::mutate(
        state_key = normalize_name(state_name),
        district_key = normalize_name(.data$district)
      ) |>
      dedupe_shapes(c("state_key", "district_key"))

    state_col <- intersect(c("state_name", "state"), names(data))[1]
    district_col <- intersect(c("district", "district_name", "name"), names(data))[1]

    if (is.na(state_col) || is.na(district_col)) {
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
      sf::st_is_empty(result$geometry)

    if (any(unmatched)) {
      result <- fuzzy_join_districts(result, shapes_df, unmatched)
    }

    result <- result |> dplyr::select(-state_key, -district_key)
  }

  sf::st_as_sf(result)
}

#' @noRd
fuzzy_join_districts_harmonized <- function(result, shapes_df, unmatched) {
  state <- if (".match_state" %in% names(result)) result$.match_state else result$state_name_harmonized
  pick <- function(i) {
    cand <- which(shapes_df$state_name_harmonized == state[i])
    if (!length(cand)) {
      return(NA_integer_)
    }
    data_name <- result$district_key[i]
    keys <- shapes_df$district_key[cand]
    contains <- which(vapply(keys, function(cn) {
      grepl(cn, data_name, fixed = TRUE) ||
        grepl(data_name, cn, fixed = TRUE)
    }, logical(1)))
    if (length(contains) == 1) {
      return(cand[contains])
    }
    exact <- which(tolower(keys) == tolower(data_name))
    if (length(exact) == 1) {
      return(cand[exact])
    }
    d <- utils::adist(data_name, keys, ignore.case = TRUE)[1, ]
    if (min(d) <= max(3, nchar(data_name) * 0.3)) cand[which.min(d)] else NA_integer_
  }
  assign_matches(result, shapes_df, which(unmatched), pick)
}

#' @noRd
fuzzy_join_districts <- function(result, shapes_df, unmatched) {
  pick <- function(i) {
    cand <- which(shapes_df$state_key == result$state_key[i])
    if (!length(cand)) {
      return(NA_integer_)
    }
    d <- utils::adist(result$district_key[i], shapes_df$district_key[cand])[1, ]
    if (min(d) <= max(3, nchar(result$district_key[i]) * 0.3)) cand[which.min(d)] else NA_integer_
  }
  assign_matches(result, shapes_df, which(unmatched), pick)
}

#' @noRd
fuzzy_join_geometry <- function(result, shapes_df, unmatched, key_col) {
  pick <- function(i) {
    d <- utils::adist(result[[key_col]][i], shapes_df[[key_col]])[1, ]
    if (min(d) <= max(3, nchar(result[[key_col]][i]) * 0.3)) which.min(d) else NA_integer_
  }
  assign_matches(result, shapes_df, which(unmatched), pick)
}

# one sfc assignment; per-row [<-.sfc recomputes the column bbox each time
#' @noRd
assign_matches <- function(result, shapes_df, rows, pick) {
  src <- vapply(rows, pick, integer(1))
  hit <- !is.na(src)
  if (any(hit)) result$geometry[rows[hit]] <- shapes_df$geometry[src[hit]]
  result
}

#' @noRd
normalize_name <- function(x) {
  x <- tolower(x)
  x <- stringr::str_squish(x)
  x <- stringr::str_replace_all(x, "twenty four", "24")
  x <- stringr::str_replace_all(x, "twenty-four", "24")
  # spell out "&" before punctuation goes, so "lahul & spiti" matches "lahul and spiti"
  x <- stringr::str_replace_all(x, "&", " and ")
  x <- stringr::str_replace_all(x, "[^a-z0-9 ]", "")
  stringr::str_squish(x)
}

#' Attach geographic boundaries to census data
#'
#' Joins state or district boundary polygons to a census data frame for mapping.
#' When `geography` is `NULL`, the geographic level is inferred from the columns
#' of `data`.
#'
#' @param data A data frame of census data with state names and, for
#'   districts, district names. `state_name_harmonized` and `district` join
#'   exactly; other name columns fall back to fuzzy matching.
#' @param year Census year of the boundaries. Available: 1941, 1951, 1961, 1971,
#'   1981, 1991, 2001, 2011.
#' @param geography Geographic level: `"state"` or `"district"`. If `NULL`
#'   (default), inferred from the columns of `data`.
#' @param unmatched Action when rows get no geometry or when two distinct units
#'   claim the same polygon: `"warn"` (default), `"error"`, or `"ignore"`.
#'   Because fuzzy matching uses substrings and edit distance as a fallback, a
#'   district whose true polygon is missing can otherwise be assigned a neighbor's
#'   shape silently.
#'
#' @return An `sf` object with geometry attached.
#'
#' Boundary files are downloaded on first use and cached locally; see
#' [census_cache_dir()].
#'
#' @examplesIf interactive()
#' # Attach district boundaries
#' census_2011_pca |>
#'   dplyr::mutate(st_pct = 100 * st_population / population) |>
#'   attach_geometry(2011)
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
      g <- intersect(unique(data$geography), c("district", "state"))
      geography <- if (length(g)) g[1] else unique(data$geography)[1]
    } else if (any(c("district", "district_name", "district_code", "name") %in% names(data))) {
      geography <- "district"
    } else {
      geography <- "state"
    }
  }

  add_geometry(data, year, geography, unmatched)
}

#' Get census boundaries
#'
#' Retrieve state or district boundary polygons for a census year.
#'
#' @param year Census year. Available: 1941, 1951, 1961, 1971, 1981, 1991, 2001,
#'   2011.
#' @param geography Geographic level: `"state"` or `"district"`.
#' @return An `sf` object with columns `year`, `geography`, `state_code`,
#'   `state_name_harmonized`, `state_name`, `district` (district level only),
#'   `id`, and `geometry`.
#'
#' Boundary files are downloaded on first use and cached locally; see
#' [census_cache_dir()].
#'
#' @examplesIf interactive()
#' boundaries <- get_census_boundaries(1971, "district")
#' ggplot2::ggplot(boundaries) +
#'   ggplot2::geom_sf()
#'
#' @export
get_census_boundaries <- function(year, geography = c("state", "district")) {
  geography <- match.arg(geography)

  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required for geometry support.")
  }

  if (length(year) != 1L || is.na(year) || !year %in% BOUNDARY_YEARS) {
    cli::cli_abort(c(
      "Boundaries not available for year {.val {year}}",
      "i" = "Available years: {BOUNDARY_YEARS}"
    ))
  }
  get_cached_geometry(year, geography)
}
