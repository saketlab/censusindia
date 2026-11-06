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
add_village_geometry <- function(data, year) {
  if (!"town_village_code" %in% names(data)) {
    cli::cli_abort("{.arg data} has no {.field town_village_code} column.")
  }
  shapes <- get_census_boundaries(
    year, "village",
    state = unique(data$state_name_harmonized)
  )
  out <- dplyr::left_join(
    data, shapes[c("town_village_code", "geometry")],
    by = "town_village_code"
  )
  sf::st_as_sf(out)
}

#' @noRd
finish_geometry <- function(out, year, unmatched) {
  out <- report_join_quality(out, unmatched)
  # the map functions read this to pick the outline drawn underneath
  attr(out, "census_boundary_year") <- year
  out
}

#' @noRd
add_geometry <- function(data, year, geography, unmatched = "warn") {
  if (geography %in% c("village", "town")) {
    return(finish_geometry(add_village_geometry(data, year), year, unmatched))
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

  finish_geometry(out, year, unmatched)
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
#' Joins state, district or village boundary polygons to a census data frame for
#' maps.
#' When `geography` is `NULL`, the geographic level is inferred from the columns
#' of `data`.
#'
#' @param data A data frame of census data with state names and, for
#'   districts, district names. `state_name_harmonized` and `district` join
#'   exactly. Other name columns use fuzzy matching as a fallback. Villages and
#'   towns join by `town_village_code`.
#' @param year Census year of the boundaries. Available: 1941, 1951, 1961, 1971,
#'   1981, 1991, 2001, 2011.
#' @param geography Geographic level: `"state"`, `"district"` or `"village"`. If `NULL`
#'   (default), inferred from the columns of `data`.
#' @param unmatched Action when rows get no geometry or when two distinct units
#'   claim the same polygon: `"warn"` (default), `"error"`, or `"ignore"`.
#'   Fuzzy matching uses substrings and edit distance as a fallback. Thus,
#'   without this check, a district with no true polygon can silently get the
#'   shape of a neighbor.
#'
#' @return An `sf` object with geometry attached.
#'
#' @details
#' The package downloads boundary files on first use and keeps them in a local
#' cache. Refer to [census_cache_dir()].
#'
#' @examplesIf interactive()
#' # Attach district boundaries
#' census_2011_pca |>
#'   dplyr::mutate(st_pct = share(st_population, population)) |>
#'   attach_geometry(2011)
#'
#' @export
attach_geometry <- function(data, year, geography = NULL,
                            unmatched = c("warn", "error", "ignore")) {
  unmatched <- match.arg(unmatched)
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
#' Retrieve state, district, village or town boundary polygons for a census
#' year.
#'
#' Use `geography = "village"` only with `year = 2011`. You must give `state`.
#' The result has villages and towns of the 2011 Census, with their census
#' codes. Areas with no census code, for example forests, are not in the result.
#'
#' Most large city corporations have no polygon. Coverage of the population is
#' complete in Haryana and partial in Maharashtra. The Delhi file does not agree
#' with the census. Do not use it.
#'
#' The state files use the current states. Thus, `"Andhra Pradesh"` also gets
#' Telangana, and `"Jammu & Kashmir"` also gets Ladakh. `"Daman & Diu"` and
#' `"Dadra & Nagar Haveli"` share one file. The `state_name_harmonized` column
#' gives the state in the 2011 Census.
#'
#' @param year Census year. Available: 1941, 1951, 1961, 1971, 1981, 1991, 2001,
#'   2011.
#' @param geography Geographic level: `"state"`, `"district"` or `"village"`.
#' @param state One or more state names or two-letter codes. Necessary for
#'   `geography = "village"`. Optional at the other levels.
#' @return An `sf` object. At state and district level, the columns are `year`,
#'   `geography`, `state_code`, `state_name_harmonized`, `state_name`, `district`
#'   (district level only), `id`, and `geometry`. At village level, the columns
#'   are `year`, `geography` (`"village"` or `"town"`), `state_code`,
#'   `state_name_harmonized`, `district_code`, `subdistrict_code`,
#'   `town_village_code`, `name`, and `geometry`.
#'
#' @details
#' The package downloads boundary files on first use and keeps them in a local
#' cache. Refer to [census_cache_dir()].
#'
#' @examplesIf interactive()
#' boundaries <- get_census_boundaries(1971, "district")
#' ggplot2::ggplot(boundaries) +
#'   ggplot2::geom_sf()
#'
#' @export
get_census_boundaries <- function(year, geography = c("state", "district", "village"),
                                  state = NULL) {
  geography <- match.arg(geography)

  if (length(year) != 1L || is.na(year) || !year %in% BOUNDARY_YEARS) {
    cli::cli_abort(c(
      "Boundaries not available for year {.val {year}}",
      "i" = "Available years: {BOUNDARY_YEARS}"
    ))
  }
  if (geography == "village") {
    return(get_village_geometry(year, state))
  }
  shapes <- get_cached_geometry(year, geography)
  if (is.null(state)) shapes else filter_by_state(shapes, state)
}

#' @noRd
state_slug <- function(state) gsub("[^a-z]+", "-", gsub("&", "and", tolower(state)))

#' 2011 Census states of the files named for current states
#' @noRd
village_file_parents <- function() {
  moved <- .state_succession[.state_succession$created > 2011L, ]
  stats::setNames(
    c(as.list(moved$parent), list(c("Dadra & Nagar Haveli", "Daman & Diu"))),
    state_slug(c(moved$state, .merged_ut))
  )
}

#' @noRd
village_file_states <- function(file) {
  slug <- sub("[.]geojson$", "", file)
  parents <- village_file_parents()[[slug]]
  if (!is.null(parents)) {
    return(parents)
  }
  states <- censusindia::india_states$state_name_harmonized
  states[state_slug(states) == slug]
}

#' @noRd
village_files <- function(state) {
  state <- resolve_states(state)
  parents <- village_file_parents()
  merged <- parents[[state_slug(.merged_ut)]]
  extra <- names(Filter(function(p) any(p %in% state), parents))
  paste0(unique(c(state_slug(setdiff(state, merged)), extra)), ".geojson")
}

#' @noRd
get_village_geometry <- function(year, state) {
  if (year != 2011L) {
    cli::cli_abort("Village boundaries are available for 2011 only.")
  }
  if (is.null(state)) {
    cli::cli_abort(c(
      "{.arg state} is necessary with {.code geography = \"village\"}.",
      "i" = "Each state is a separate download."
    ))
  }
  files <- village_files(state)
  parts <- lapply(files, function(file) {
    rlang::env_cache(.session_cache, paste0("village_", file), read_village_file(file))
  })
  dplyr::bind_rows(parts)
}

#' @noRd
read_village_file <- function(file) {
  shapes <- sf::st_read(village_file(file), quiet = TRUE)["village_code"]
  shapes$town_village_code <- suppressWarnings(as.integer(shapes$village_code))
  # drops polygons with a code from an unrelated state
  codes <- census_2011_demographics() |>
    dplyr::filter(
      .data$geography %in% c("village", "town"),
      .data$state_name_harmonized %in% village_file_states(file)
    ) |>
    dplyr::distinct(.data$town_village_code, .keep_all = TRUE)
  cols <- c(
    "year", "geography", "state_code", "state_name_harmonized", "district_code",
    "subdistrict_code", "town_village_code", "name"
  )
  shapes <- dplyr::inner_join(shapes, codes[cols], by = "town_village_code")
  # a village in parts has one row for each part
  dedupe_shapes(repair_geometry(shapes[cols]), "town_village_code")
}
