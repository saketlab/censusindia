#' Get population projections
#'
#' Gives Ministry of Health and Family Welfare (MoHFW) population projections
#' (2011-2036, Census 2011 base) at state level. It also gives the International
#' Institute for Population Sciences (IIPS) district projections, which use the
#' state projections. This package derives subdistrict figures from the
#' districts. District
#' projections are available on two boundary sets: Census 2011 districts (640
#' districts at 5-year intervals) and Local Government Directory (LGD) districts
#' (783 districts, annual).
#'
#' @param year Integer or integer vector of projection years, or `NULL`
#'   (default) for all published years in the table.
#' @param geography Geographic level: `"state"`, `"district"`, or
#'   `"subdistrict"`. This package derives subdistrict figures. Refer to the
#'   Subdistrict figures section. They cover Census 2011 boundaries and all ages,
#'   without geometry.
#' @param state Optional state filter: one or more canonical state names or
#'   two-letter codes (e.g., `"Maharashtra"` or `"MH"`).
#' @param boundary District boundary system: `"census2011"` (default, 640
#'   districts) or `"lgd"` (783 districts). Ignored when `geography = "state"`.
#' @param geometry If `TRUE`, attaches Census 2011 boundaries and returns an
#'   `sf` object. At district level, supported only when
#'   `boundary = "census2011"`.
#' @param by_age If `TRUE`, returns age-stratified rows. State projections use
#'   5-year age bands from `"0-4"` to `"80+"`. District projections use single
#'   years for ages 0-14 and 5-year bands from `"15-19"` to `"80+"`. See
#'   [population_projections_state_age], [population_projections_district_age()],
#'   and [population_projections_district_lgd_age()]. State age projections
#'   cover 23 major states, `"India"`, and `"North East States Excluding Assam"`.
#'   If you use other states with `by_age = TRUE`, you get an error.
#' @param method How to divide a district among its subdistricts:
#'   `"constant_share"` (default) or `"urban_rural"`. Applies only when
#'   `geography = "subdistrict"`. `"urban_rural"` downloads
#'   [census_2011_demographics()] on first use.
#'
#' @return A tibble (or an `sf` object if `geometry = TRUE`) with columns
#'   `year`, `geography`, `state_code`, `state_name_harmonized`, `district`
#'   (district and subdistrict level), `subdistrict` (subdistrict level only),
#'   `age_group` (when `by_age = TRUE`), `males`,
#'   `females`, `population`, and `estimate`. `geography` is `"india"` on
#'   national rows. All counts are in persons. `estimate` is `"published"` for
#'   years printed in the MoHFW/IIPS tables, `"interpolated"` for years between
#'   printed years, and `"extrapolated"` for years after the last printed year.
#'   Subdistrict rows have `"derived"` in place of `"published"`.
#'
#' @section Subdistrict figures:
#' IIPS projects a district as the state projection times the district's share
#' of the state. The `"constant_share"` method applies the same idea one level
#' down, as IIPS Ratio method 3 does: each subdistrict keeps its 2011 share of
#' its district, for males and females separately. Every subdistrict of a
#' district therefore grows at the district's rate.
#'
#' `"urban_rural"` weights the 2011 urban and rural population of each
#' subdistrict by the growth of its state's urban and rural population. The
#' urban growth comes from [population_projections_state_urban]. The rural
#' growth comes from total minus urban. The method then scales the weights to the
#' district total. Urban subdistricts
#' grow faster than rural ones where the state's urban population does. This
#' method belongs to this package.
#'
#' In Delhi, Chandigarh and Lakshadweep, the projected urban population reaches
#' the state total. Thus, these areas use constant shares with both methods. The
#' `"urban_rural"` method applies the state's rural trend to all rural areas.
#' Thus, Kerala gives extreme results, because the report has a steep decrease in
#' its rural population.
#'
#' Both methods add to the district projection within rounding, and `population`
#' is `males + females`. The package has no 2001 subdistrict data to validate
#' either. `"constant_share"` is the default because it had the lower error for a
#' projection of 2011 districts from 2001, in states with unchanged districts.
#'
#' @details
#' State projections cover 2011-2036 across 39 entries: 28 states, the 9 union
#' territories printed by MoHFW (with separate `"Dadra & Nagar Haveli"` and
#' `"Daman & Diu"` rows), the merged `"Dadra & Nagar Haveli and Daman & Diu"` UT
#' (the sum of the two), and `"India"`. To sum states and count each
#' person once, exclude `"India"` and either the merged UT or the two constituent
#' UTs. Refer to [population_projections_state].
#'
#' The state report rounds Persons, Male, and Female independently to the nearest
#' thousand. Thus, `population` and `males + females` can differ by up to 1,000
#' at state level (2,000 for the summed UT).
#'
#' Census 2011 district projections are published at 5-year intervals (2011,
#' 2016, 2021, 2026, 2031). LGD district projections are annual from 2012 to
#' 2031.
#'
#' When a requested `year` is between published table years, `get_population()`
#' interpolates `males`, `females`, and `population` independently. It uses
#' geometric (exponential) growth between the two nearest published years:
#'
#' \deqn{P_t = P_1 (P_2 / P_1)^{(t - t_1) / (t_2 - t_1)}}
#'
#' Because each series is interpolated independently, summed district estimates
#' need not equal the interpolated state estimate.
#'
#' `get_population()` extrapolates years after the last published year with the
#' growth rate of the final interval, for up to five years (to 2041 for states, 2036 for
#' districts). Years before the start of the table or more than five years past
#' the end raise an error.
#'
#' Telangana and Ladakh are reported as separate entries even though both were
#' created after the 2011 Census.
#'
#' @seealso [population_projections()] for all levels and sectors in one table.
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
#' # Subdistricts: 2011 shares of the district projection
#' get_population(2031, "subdistrict", state = "Kerala")
#'
#' @export
get_population <- function(year = NULL,
                           geography = c("state", "district", "subdistrict"),
                           state = NULL,
                           boundary = c("census2011", "lgd"),
                           geometry = FALSE,
                           by_age = FALSE,
                           method = c("constant_share", "urban_rural")) {
  geography <- match.arg(geography)
  boundary <- match.arg(boundary)
  method <- match.arg(method)
  if (geography == "subdistrict" && (boundary == "lgd" || by_age || geometry)) {
    cli::cli_abort(c(
      "Subdistrict figures have one form: Census 2011 boundaries, all ages, no geometry.",
      "i" = "Remove {.arg boundary}, {.arg by_age} and {.arg geometry}."
    ))
  }
  if (geography != "subdistrict" && method != "constant_share") {
    cli::cli_abort("{.arg method} applies only when {.arg geography} is {.val subdistrict}.")
  }

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

  data <- with_projection_years(data, year)

  if (geography == "subdistrict") {
    data <- project_subdistricts(data, method)
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

#' Label published rows and add any requested years the table lacks.
#' @noRd
with_projection_years <- function(data, year) {
  data$estimate <- "published"
  if (is.null(year)) {
    return(data)
  }
  if (!length(year) || !rlang::is_integerish(year, finite = TRUE)) {
    cli::cli_abort("{.arg year} must be whole-number years.")
  }
  year <- unique(as.integer(year))
  missing_years <- setdiff(year, data$year)
  dplyr::filter(data, .data$year %in% .env$year) |>
    dplyr::bind_rows(
      if (length(missing_years)) estimate_population_years(data, missing_years)
    ) |>
    dplyr::arrange(.data$year)
}

#' @noRd
project_subdistricts <- function(districts, method) {
  out <- merge(districts, subdistrict_base(method),
    by = c("state_name_harmonized", "district"), suffixes = c("", "_2011")
  )
  if (method == "urban_rural") out <- with_growth(out)

  for (v in c("males", "females")) {
    w <- if (method == "urban_rural") {
      sw <- sector_weights(out, v)
      sw$urban + sw$rural
    } else {
      out[[paste0(v, "_2011")]]
    }
    total <- stats::ave(w, out$year, out$state_name_harmonized, out$district, FUN = sum)
    out[[v]] <- round(out[[v]] * w / total)
  }

  out$population <- out$males + out$females
  out$geography <- "subdistrict"
  out <- as_derived(out)
  out <- out[order(out$year, out$state_name_harmonized, out$district, out$subdistrict), ]
  canonicalize(out[c(
    "year", "geography", "state_code", "state_name_harmonized", "district", "subdistrict",
    "males", "females", "population", "estimate"
  )])
}

#' @noRd
as_derived <- function(x) {
  x$estimate[x$estimate == "published"] <- "derived"
  x
}

#' @noRd
subdistrict_base <- function(method) {
  ids <- c("state_name_harmonized", "district", "subdistrict")
  x <- projection_names(censusindia::census_subdistricts_2011[c(ids, "males", "females")])

  if (method == "urban_rural") {
    d <- named_subdistricts()
    for (s in c("urban", "rural")) {
      part <- d[d$sector == s, c(ids, "males", "females")]
      names(part)[4:5] <- paste0(s, "_", c("males", "females"))
      x <- dplyr::left_join(x, part, by = ids)
    }
  }
  x
}

#' the demographics table has codes in place of names
#' @noRd
named_subdistricts <- function() {
  d <- census_2011_demographics()
  d <- d[d$geography == "subdistrict", ]
  pca <- censusindia::census_2011_pca
  d$district <- pca$district[match(d$district_code, pca$district_code)]
  d$subdistrict <- d$name
  projection_names(d)
}

#' Telangana and Ladakh districts sit under their 2011 parents: match by name only
#' @noRd
projection_names <- function(x) {
  ref <- unique(censusindia::population_projections_district[c("state_name_harmonized", "district")])
  key <- function(district) gsub("[^a-z]", "", tolower(district))
  i <- match(
    paste(x$state_name_harmonized, key(x$district)),
    paste(ref$state_name_harmonized, key(ref$district))
  )
  moved <- is.na(i)
  i[moved] <- match(key(x$district[moved]), key(ref$district))
  if (anyNA(i)) {
    cli::cli_abort("No projection for district{?s} {.val {unique(x$district[is.na(i)])}}.")
  }
  x$state_name_harmonized <- ref$state_name_harmonized[i]
  x$district <- ref$district[i]
  x
}

#' urban growth will empty the rural units of these states
#' @noRd
no_rural_states <- function() {
  r <- censusindia::population_projections_state_rural
  unique(r$state_name_harmonized[pmin(r$males, r$females) <= 0])
}

#' relative to 2011, by sex and year
#' @noRd
sector_growth <- function() {
  keys <- c("year", "state_name_harmonized")
  cols <- c(keys, "males", "females")
  out <- merge(
    censusindia::population_projections_state_urban[cols],
    censusindia::population_projections_state_rural[cols],
    by = keys, suffixes = c("_urban", "_rural")
  )
  out <- out[order(out$state_name_harmonized, out$year), ]
  relative <- function(x) x / stats::ave(x, out$state_name_harmonized, FUN = function(s) s[1])
  flat <- out$state_name_harmonized %in% no_rural_states()
  for (v in c("males", "females")) {
    out[[paste0("urban_growth_", v)]] <- ifelse(flat, 1, relative(out[[paste0(v, "_urban")]]))
    out[[paste0("rural_growth_", v)]] <- ifelse(flat, 1, relative(out[[paste0(v, "_rural")]]))
  }
  out[c(keys, grep("_growth_", names(out), value = TRUE))]
}

#' @noRd
with_growth <- function(x) merge(x, sector_growth(), by = c("year", "state_name_harmonized"))

#' @noRd
sector_weights <- function(x, v) {
  list(
    urban = x[[paste0("urban_", v)]] * x[[paste0("urban_growth_", v)]],
    rural = x[[paste0("rural_", v)]] * x[[paste0("rural_growth_", v)]]
  )
}

#' All population projections in one table
#'
#' One long table of projections for India, states, districts, subdistricts and
#' villages, for the total, rural and urban population. With no arguments it
#' returns everything. Use the arguments to narrow it:
#'
#' ```r
#' population_projections(geography = "state", sector = "rural")
#' population_projections(geography = "district", state = "Kerala", year = 2031)
#' ```
#'
#' @param geography Levels to return: any of `"india"`, `"state"`, `"district"`,
#'   `"subdistrict"`, `"village"`, or `NULL` (default) for all. `"tehsil"`,
#'   `"taluka"`, `"taluk"` and `"mandal"` mean `"subdistrict"`. Block, gram
#'   panchayat, town and ward are errors.
#' @param sector Sectors to return: any of `"total"`, `"rural"`, `"urban"`, or
#'   `NULL` (default) for all. Villages are rural, so they appear only with
#'   `"rural"`.
#' @param year Years to return, or `NULL` (default) for the years each level
#'   publishes. India and states have each year from 2011 to 2036. Levels below
#'   state have 2011, 2016, 2021, 2026 and 2031. The function estimates other
#'   years as in [get_population()]. Below state level, these years stop at 2036.
#' @param state Optional state filter: one or more state names or two-letter
#'   codes. `"India"` selects the national rows.
#' @param method How to divide a district among its subdistricts:
#'   `"constant_share"` (default) or `"urban_rural"`. See [get_population()].
#'
#' @return A tibble with columns `year`, `geography`, `sector`, `state_code`,
#'   `state_name_harmonized`, `district`, `subdistrict`, `town_village_code`,
#'   `name` (the village), `males`, `females`, `population`, and `estimate`.
#'   Columns that no selected level uses are left out. Levels and sectors overlap,
#'   so filter `geography` and `sector` before you add rows.
#'
#'   `estimate` is `"published"` for figures printed by MoHFW or IIPS, and
#'   `"derived"` for figures that this package calculates: all rural rows, urban
#'   rows below state level, and all rows below district level.
#'   `"interpolated"` and `"extrapolated"` mark
#'   years that the source table lacks.
#'
#' @section How the figures are made:
#' \describe{
#'   \item{India, state}{[population_projections_state],
#'     [population_projections_state_urban] and
#'     [population_projections_state_rural]. The merged
#'     `"Dadra & Nagar Haveli and Daman & Diu"` row is left out, so states add
#'     to India within rounding.}
#'   \item{District, total}{[population_projections_district].}
#'   \item{Subdistrict, total}{As in `get_population(geography = "subdistrict")`.}
#'   \item{District and subdistrict, rural and urban}{The total of the unit,
#'     split in proportion to its 2011 urban and rural population. The growth of
#'     the urban and rural population of its state weights these two figures.
#'     The function then adjusts the result. Districts add to the urban figure
#'     of the state, and subdistricts add to the figure of their district.
#'     `rural + urban` equals `total` in every unit.}
#'   \item{Village}{Each village keeps its 2011 share of its subdistrict's rural
#'     population, by sex.}
#' }
#'
#' Figures below district level are not validated. Refer to the Subdistrict
#' figures section of [get_population()]. A village estimate is a share of a
#' share, so treat it as an allocation.
#'
#' Rural and urban figures for Delhi, Chandigarh and Lakshadweep keep their 2011
#' split below state level. Thus, they do not add to the state rows of these
#' areas. The report has no rural population in these areas. Use of the state
#' rows will give zero population in their villages.
#'
#' Below state level, totals add to the IIPS districts, which differ slightly
#' from the MoHFW state totals. With `"constant_share"`, the urban rows of a few
#' districts are more than the sum of their subdistricts. The cause is that a
#' subdistrict with no urban population in 2011 stays rural, and the others keep
#' their totals. With `"urban_rural"`, these rows add up.
#'
#' Rural and urban rows below state level, village rows, and subdistrict rows with
#' `"urban_rural"` download [census_2011_demographics()] on first use.
#'
#' @seealso [get_population()] for one level at a time, with age groups, LGD
#'   boundaries and geometry.
#' @examples
#' population_projections(geography = "state", sector = "total", state = "Kerala", year = 2031)
#' @examplesIf interactive()
#' population_projections(geography = "state", sector = "rural")
#' population_projections(geography = "district", state = "Kerala", year = 2031)
#' population_projections(geography = "village", state = "Goa", year = 2031)
#' @export
population_projections <- function(geography = NULL,
                                   sector = NULL,
                                   year = NULL,
                                   state = NULL,
                                   method = c("constant_share", "urban_rural")) {
  everything <- is.null(geography)
  geography <- projection_levels(geography)
  sector <- projection_sectors(sector)
  method <- match.arg(method)
  if (identical(geography, "village") && !"rural" %in% sector) {
    cli::cli_abort(c(
      "Villages are rural, so they have no {.val {sector}} rows.",
      "i" = "Use {.code sector = \"rural\"}."
    ))
  }
  if (everything) {
    cli::cli_inform(c("i" = "Returning every level. Use {.arg geography} to narrow it."), .frequency = "once", .frequency_id = "censusindia_all_levels")
  }

  named <- censusindia::population_projections_state
  named <- unique(named$state_name_harmonized[named$state_name_harmonized != .merged_ut])
  wanted <- if (is.null(state)) named else resolve_states(state, present = named)
  below_state <- setdiff(wanted, "India")

  parts <- list(state_projection_rows(geography, sector, year, wanted))
  if (any(geography %in% c("district", "subdistrict", "village")) && length(below_state)) {
    parts <- c(parts, local_projection_rows(geography, sector, year, below_state, method))
  }
  out <- dplyr::bind_rows(parts)
  if (!nrow(out)) {
    cli::cli_abort(c(
      "No rows for this {.arg geography} and {.arg state}.",
      "i" = "{.val india} has national rows only, so it does not combine with a state."
    ))
  }
  canonicalize(out)
}

.merged_ut <- "Dadra & Nagar Haveli and Daman & Diu"

#' @noRd
projection_levels <- function(geography) {
  levels <- c("india", "state", "district", "subdistrict", "village")
  if (is.null(geography)) {
    return(levels)
  }
  g <- normalize_geography(geography)
  g[g %in% c("tehsil", "tahsil", "taluka", "taluk", "mandal")] <- "subdistrict"
  none <- geography[g %in% c("block", "cdblock", "gp", "grampanchayat", "panchayat", "town", "ward")]
  if (length(none)) {
    cli::cli_abort(c(
      "No projections for {.val {none}}.",
      "i" = "Census 2011 tables here have no block or gram panchayat, and town and ward rows do not add up.",
      "i" = "Use {.val subdistrict} or {.val village}. In some states the subdistrict is the block."
    ))
  }
  bad <- geography[!g %in% levels]
  if (length(bad)) {
    cli::cli_abort("{.arg geography} must be from {.val {levels}}, not {.val {bad}}.")
  }
  levels[levels %in% g]
}

#' @noRd
projection_sectors <- function(sector) {
  sectors <- c("total", "rural", "urban")
  if (is.null(sector)) {
    return(sectors)
  }
  s <- tolower(trimws(sector))
  bad <- sector[!s %in% sectors]
  if (length(bad)) {
    cli::cli_abort("{.arg sector} must be from {.val {sectors}}, not {.val {bad}}.")
  }
  sectors[sectors %in% s]
}

#' @noRd
state_projection_rows <- function(geography, sector, year, wanted) {
  tables <- list(
    total = censusindia::population_projections_state,
    urban = censusindia::population_projections_state_urban,
    rural = censusindia::population_projections_state_rural
  )
  rows <- lapply(sector, function(s) {
    d <- tables[[s]]
    d <- d[d$geography %in% geography & d$state_name_harmonized %in% wanted, ]
    if (!nrow(d)) {
      return(NULL)
    }
    d$sector <- s
    d <- with_projection_years(d, year)
    if (s == "rural") as_derived(d) else d
  })
  dplyr::bind_rows(rows)
}

#' @noRd
local_projection_rows <- function(geography, sector, year, states, method) {
  d <- censusindia::population_projections_district
  d <- with_projection_years(d[d$state_name_harmonized %in% states, ], year)
  split_needed <- any(c("rural", "urban") %in% sector)
  dkeys <- c("state_name_harmonized", "district")
  # lazy arguments: a total-only call does not read the sector bases
  add_sectors <- function(x, ...) {
    if (split_needed) with_sectors(x, ...) else dplyr::mutate(x, sector = "total")
  }

  districts <- add_sectors(
    d, district_sector_base(), dkeys, state_urban_targets(), c("year", "state_name_harmonized")
  )

  out <- list()
  if ("district" %in% geography) out$district <- districts[districts$sector %in% sector, ]
  if (any(c("subdistrict", "village") %in% geography)) {
    s <- add_sectors(
      project_subdistricts(d, method), subdistrict_base("urban_rural"), c(dkeys, "subdistrict"),
      districts[districts$sector == "urban", ], c("year", dkeys)
    )
    if ("subdistrict" %in% geography) out$subdistrict <- s[s$sector %in% sector, ]
    if ("village" %in% geography && "rural" %in% sector) {
      out$village <- project_villages(s[s$sector == "rural", ])
    }
  }
  out
}

#' @noRd
district_sector_base <- function() {
  subdistrict_base("urban_rural") |>
    dplyr::group_by(.data$state_name_harmonized, .data$district) |>
    dplyr::summarise(
      dplyr::across(dplyr::matches("^(urban|rural)_"), sum),
      .groups = "drop"
    )
}

#' NA: these states keep their 2011 split
#' @noRd
state_urban_targets <- function() {
  x <- censusindia::population_projections_state_urban[
    c("year", "state_name_harmonized", "males", "females")
  ]
  x[x$state_name_harmonized %in% no_rural_states(), c("males", "females")] <- NA
  x
}

#' rural is the remainder
#' @noRd
with_sectors <- function(x, base, by, target, within) {
  j <- with_growth(merge(x, base, by = by, suffixes = c("", "_2011")))
  key <- function(d) do.call(paste, c(d[within], sep = "|"))
  group <- key(j)
  goal <- match(group, key(target))
  units <- split(seq_len(nrow(j)), group)

  urban <- rural <- as_derived(j[names(x)])
  for (v in c("males", "females")) {
    w <- sector_weights(j, v)
    part <- numeric(nrow(j))
    for (i in units) {
      part[i] <- rake_urban(j[[v]][i], w$urban[i], w$rural[i], target[[v]][goal[i[1]]])
    }
    urban[[v]] <- round(part)
    rural[[v]] <- j[[v]] - urban[[v]]
  }
  urban$population <- urban$males + urban$females
  rural$population <- rural$males + rural$females
  urban$sector <- "urban"
  rural$sector <- "rural"
  x$sector <- "total"
  dplyr::arrange(dplyr::bind_rows(x, rural, urban), .data$year)
}

#' one factor k on urban weights; units with no urban or rural weight cannot move
#' @noRd
rake_urban <- function(total, u, r, target) {
  part <- function(k) {
    w <- k * u
    p <- total * (w / (w + r))
    p[!(w + r > 0)] <- 0
    p
  }
  if (is.na(target)) {
    return(part(1))
  }
  lowest <- sum(total[u > 0 & r == 0])
  highest <- sum(total[u > 0])
  if (target <= lowest) {
    return(total * (u > 0 & r == 0))
  }
  if (target >= highest) {
    return(total * (u > 0))
  }
  k <- stats::uniroot(function(lk) sum(part(exp(lk))) - target, c(-50, 50), tol = 1e-9)$root
  part(exp(k))
}

#' integer unit numbers: the loop runs over every village each year
#' @noRd
project_villages <- function(rural) {
  ids <- c("state_name_harmonized", "district", "subdistrict")
  key <- function(x) paste(x[[1]], x[[2]], x[[3]], sep = "|")
  code <- function(x) x$district_code * 100000L + x$subdistrict_code
  sd <- named_subdistricts()
  sd <- sd[sd$sector == "total", ]
  rural$unit <- match(key(rural[ids]), key(sd[ids]))

  v <- at_level(census_2011_demographics(), "village", "rural")
  v$unit <- match(code(v), code(sd))
  v <- v[v$unit %in% rural$unit, c("unit", "town_village_code", "name", "males", "females")]
  share_of_unit <- function(x) {
    total <- stats::ave(x, v$unit, FUN = sum)
    ifelse(total > 0, x / total, 0) # an empty subdistrict has no share to give
  }
  male <- share_of_unit(v$males)
  female <- share_of_unit(v$females)
  named <- dplyr::bind_cols(sd[v$unit, ids], v[c("town_village_code", "name")])

  rows <- lapply(split(rural, rural$year), function(r) {
    i <- match(v$unit, r$unit)
    out <- named
    out$year <- r$year[1]
    out$geography <- "village"
    out$sector <- "rural"
    out$state_code <- r$state_code[i]
    out$males <- round(r$males[i] * male)
    out$females <- round(r$females[i] * female)
    out$population <- out$males + out$females
    out$estimate <- r$estimate[i]
    out
  })
  dplyr::bind_rows(rows)
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
      "i" = "The table ends at {max(known)}; later years are extrapolated, five years at most."
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
