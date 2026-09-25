# censusindia Plumber API
# Launch with: censusindia::serve()

library(censusindia)

#* @apiTitle Census India API
#* @apiDescription Query Census of India population and demographic data by year, geography, state, and variable.
#* @apiVersion 0.1.0

#* Health check
#* @get /health
#* @serializer unboxedJSON
function() {
  list(
    status = "ok",
    package = "censusindia",
    version = as.character(utils::packageVersion("censusindia"))
  )
}

#* List available states
#* @get /states
#* @serializer json
function() {
  as.data.frame(list_states())
}

#* List available census geographies
#* @get /geographies
#* @serializer json
function() {
  as.data.frame(list_census_geographies())
}

#* List available variables
#* @param year Optional census year to filter on
#* @param geography Optional geography to filter on (state, district, subdistrict)
#* @param category Optional category filter
#* @get /variables
#* @serializer json
function(year = NULL, geography = NULL, category = NULL) {
  if (!is.null(year) && nzchar(trimws(year))) year <- as.integer(year)
  if (!is.null(geography) && !nzchar(trimws(geography))) geography <- NULL
  if (!is.null(category) && !nzchar(trimws(category))) category <- NULL

  as.data.frame(list_census_variables(year = year, geography = geography, category = category))
}

#* Search census variables by keyword
#* @param pattern Keyword or regex to match in variable names/labels
#* @get /search
#* @serializer json
function(pattern = "") {
  if (!nzchar(trimws(pattern))) {
    return(as.data.frame(list_census_variables()))
  }
  as.data.frame(search_census_variables(pattern))
}

#* Query census data
#* @param year Census year. One of 1901, 1911, 1921, 1931, 1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011.
#* @param geography Geography level: state, district, or subdistrict.
#* @param state Comma-separated state names or two-letter codes.
#* @param variables Comma-separated variable names to return.
#* @param sector For 1971/1981 only: total, rural, urban.
#* @param geometry Logical; attach geographic boundaries when available.
#* @get /query
#* @serializer json
function(year = 2011, geography = "state", state = "", variables = "", sector = "total", geometry = FALSE, res) {
  year <- suppressWarnings(as.integer(year))
  geography <- tolower(trimws(geography))
  sector <- tolower(trimws(sector))
  geometry <- isTRUE(as.logical(geometry))

  valid_years <- c(1901L, 1911L, 1921L, 1931L, 1941L, 1951L, 1961L, 1971L, 1981L, 1991L, 2001L, 2011L)
  if (!year %in% valid_years) {
    res$status <- 400L
    return(list(error = paste("Invalid year. Must be one of:", paste(valid_years, collapse = ", "))))
  }

  if (!(geography %in% c("state", "district", "subdistrict"))) {
    res$status <- 400L
    return(list(error = "Invalid geography. Must be one of: state, district, subdistrict."))
  }

  if (sector %in% c("rural", "urban", "total")) {
    sector <- sector
  } else {
    res$status <- 400L
    return(list(error = "Invalid sector. Must be one of: total, rural, urban."))
  }

  selected_state <- NULL
  if (nzchar(trimws(state))) {
    selected_state <- trimws(strsplit(state, ",", fixed = TRUE)[[1]])
    selected_state <- selected_state[nzchar(selected_state)]
  }

  selected_vars <- NULL
  if (nzchar(trimws(variables))) {
    selected_vars <- trimws(strsplit(variables, ",", fixed = TRUE)[[1]])
    selected_vars <- selected_vars[nzchar(selected_vars)]
  }

  tryCatch(
    {
      result <- get_census(
        year = year,
        geography = geography,
        variables = selected_vars,
        state = selected_state,
        geometry = geometry,
        sector = sector
      )
      as.data.frame(result)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Query population projections
#* @param year Projection year or years (comma-separated).
#* @param geography Geography level: state or district.
#* @param state Comma-separated state names or two-letter codes.
#* @param boundary District boundary system: census2011 or lgd.
#* @param by_age Return age-stratified rows.
#* @param geometry Attach geometry when available.
#* @get /population
#* @serializer json
function(year = NULL, geography = "state", state = "", boundary = "census2011", by_age = FALSE, geometry = FALSE, res) {
  geography <- tolower(trimws(geography))
  boundary <- tolower(trimws(boundary))
  by_age <- isTRUE(as.logical(by_age))
  geometry <- isTRUE(as.logical(geometry))

  if (!(geography %in% c("state", "district"))) {
    res$status <- 400L
    return(list(error = "Invalid geography. Must be one of: state, district."))
  }

  if (!(boundary %in% c("census2011", "lgd"))) {
    res$status <- 400L
    return(list(error = "Invalid boundary. Must be one of: census2011, lgd."))
  }

  selected_year <- NULL
  if (!is.null(year) && nzchar(trimws(year))) {
    selected_year <- as.integer(strsplit(trimws(year), ",", fixed = TRUE)[[1]])
  }

  selected_state <- NULL
  if (nzchar(trimws(state))) {
    selected_state <- trimws(strsplit(state, ",", fixed = TRUE)[[1]])
    selected_state <- selected_state[nzchar(selected_state)]
  }

  tryCatch(
    {
      result <- get_population(
        year = selected_year,
        geography = geography,
        state = selected_state,
        boundary = boundary,
        geometry = geometry,
        by_age = by_age
      )
      as.data.frame(result)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}
