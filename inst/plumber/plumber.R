# censusindia Plumber API
# Launch with: censusindia::serve()

#* @apiTitle Census India API
#* @apiDescription Query Census of India population and demographic data by year, geography, state, and variable. Requests with `geometry=true` return GeoJSON. Every endpoint returns at most 10,000 rows (100 GeoJSON features) per request; page with `limit` and `offset`, and read the total from the `X-Total-Count` header.
#* @apiVersion 0.1.0

# "a, b,,c" -> c("a", "b", "c"); empty -> NULL
csv <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  x <- trimws(strsplit(x, ",", fixed = TRUE)[[1]])
  x <- x[nzchar(x)]
  if (length(x)) x else NULL
}

`%||%` <- rlang::`%||%`

flag <- function(x) {
  x <- tolower(trimws(x %||% ""))
  if (x %in% c("true", "t", "1", "yes")) {
    return(TRUE)
  }
  if (x %in% c("", "false", "f", "0", "no")) {
    return(FALSE)
  }
  rlang::abort(sprintf("Expected true or false, got \"%s\".", x))
}

word <- function(x) tolower(trimws(x))

# "2011", "2015,2016", "2015:2020" or "2020:2015" -> integers; empty -> NULL
as_whole <- function(x, name = "year", lo = -Inf, hi = Inf) {
  x <- csv(as.character(x %||% ""))
  if (is.null(x)) {
    return(NULL)
  }
  x <- unlist(lapply(x, function(v) {
    b <- suppressWarnings(as.numeric(strsplit(v, ":", fixed = TRUE)[[1]]))
    # ponytail: ranges capped at 1000 values so "1:1e9" cannot exhaust memory
    ok <- length(b) == 2L && all(is.finite(b)) && abs(b[2] - b[1]) <= 1000
    if (ok) as.character(seq(b[1], b[2])) else v
  }))
  n <- suppressWarnings(as.numeric(x))
  if (!rlang::is_integerish(n, finite = TRUE) || any(n < lo | n > hi)) {
    range <- if (is.finite(hi)) sprintf(" from %s to %s", lo, hi) else ""
    rlang::abort(sprintf("`%s` must be whole numbers%s, got \"%s\".", name, range, paste(x, collapse = ",")))
  }
  as.integer(n)
}

# routes whose package function takes a single census year
one_year <- function(x) {
  y <- as_whole(x)
  if (length(y) > 1L) rlang::abort(sprintf("`year` takes one census year, got %d.", length(y)))
  y
}

DATASETS <- utils::data(package = "censusindia")$results[, c("Item", "Title")]

# `X-Client` wins (MCP wrappers should send `X-Client: mcp/<name>`), else the
# first User-Agent pattern that matches.
CLIENT_PATTERNS <- c(
  mcp = "mcp",
  ai_agent = "claude|anthropic|openai|chatgpt|gptbot|perplexity|gemini",
  curl = "^curl/",
  wget = "wget",
  python = "python|httpx|aiohttp|urllib",
  r = "httr|r-curl|^R \\(|libcurl",
  node = "node|undici|axios",
  browser = "mozilla"
)

classify_client <- function(req) {
  explicit <- req$HTTP_X_CLIENT
  if (!is.null(explicit) && nzchar(explicit)) {
    return(substr(explicit, 1, 64))
  }
  ua <- req$HTTP_USER_AGENT
  if (is.null(ua) || !nzchar(ua)) {
    return("unknown")
  }
  hit <- names(CLIENT_PATTERNS)[vapply(CLIENT_PATTERNS, grepl, TRUE, ua, ignore.case = TRUE)]
  if (length(hit)) hit[1] else "other"
}

# One JSON line per request on stdout, which systemd sends to the journal.
log_request <- function(req, res) {
  # nginx sets X-Real-IP itself; X-Forwarded-For starts with whatever the client sent
  ip <- req$HTTP_X_REAL_IP %||% req$HTTP_X_FORWARDED_FOR %||% req$REMOTE_ADDR %||% ""
  cat(jsonlite::toJSON(list(
    ts = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3%z"),
    method = req$REQUEST_METHOD,
    path = req$PATH_INFO,
    query = sub("^\\?", "", req$QUERY_STRING %||% ""),
    status = res$status,
    ms = round(as.numeric(Sys.time() - req$.start, units = "secs") * 1000),
    client = classify_client(req),
    user_agent = req$HTTP_USER_AGENT %||% "",
    ip = trimws(sub(",.*", "", ip))
  ), auto_unbox = TRUE), "\n", sep = "")
}

# A query name missing from the route's @param lines is a 400.
reject_unknown_params <- function(pr) {
  function(req, res) {
    # read per request: endpoints below the @plumber block are not parsed yet
    ep <- Find(function(e) e$matchesPath(req$PATH_INFO), pr$endpoints[["__no-preempt__"]])
    if (is.null(ep)) {
      return(plumber::forward())
    }
    known <- c(names(ep$params), "limit", "offset")
    bad <- setdiff(names(req$argsQuery), known)
    if (!length(bad)) {
      return(plumber::forward())
    }
    res$status <- 400L
    list(error = sprintf(
      "Unknown parameter%s: %s. Known parameters: %s.",
      if (length(bad) > 1) "s" else "", paste(bad, collapse = ", "), paste(known, collapse = ", ")
    ))
  }
}

#* @plumber
function(pr) {
  pr <- plumber::pr_set_serializer(pr, plumber::serializer_json(auto_unbox = TRUE, na = "null"))
  pr <- plumber::pr_filter(pr, "params", reject_unknown_params(pr))
  plumber::pr_hooks(pr, list(
    preroute = function(req) req$.start <- Sys.time(),
    postserialize = function(req, res) {
      tryCatch(log_request(req, res), error = function(e) NULL)
    }
  ))
}

# cli_abort() and match.arg() errors are bad input (400), a failed download
# is 503, anything else is a bug (500).
status_for <- function(e) {
  if (inherits(e, "censusindia_download_error")) {
    return(503L)
  }
  call <- conditionCall(e)
  if (inherits(e, "rlang_error") ||
    (is.call(call) && identical(call[[1]], quote(match.arg)))) {
    return(400L)
  }
  500L
}

# One page per response bounds the body the single R process builds.
# District polygons are large, so features get a smaller page than rows.
# ponytail: offset paging reruns the query per page; cache if clients walk big tables.
MAX_ROWS <- 10000L
MAX_FEATURES <- 100L

paginate <- function(x, req, res) {
  q <- req$argsQuery
  cap <- if (inherits(x, "sf")) MAX_FEATURES else MAX_ROWS
  # clients send limit=0 for a full table; read it as the maximum
  if (identical(trimws(q$limit %||% ""), "0")) q$limit <- NULL
  limit <- as_whole(q$limit, "limit", 1, cap)[1] %||% cap
  offset <- as_whole(q$offset, "offset", 0, .Machine$integer.max)[1] %||% 0L
  total <- nrow(x)
  res$setHeader("X-Total-Count", as.character(total))
  res$setHeader("X-Offset", as.character(offset))
  res$setHeader("X-Limit", as.character(limit))
  x[seq_len(max(0L, min(limit, total - offset))) + offset, , drop = FALSE]
}

# sf results go out as a GeoJSON FeatureCollection, everything else as rows.
respond <- function(req, res, expr) {
  # cli otherwise wraps mid-name
  op <- options(cli.width = 10000L)
  on.exit(options(op), add = TRUE)
  x <- tryCatch(paginate(expr, req, res), error = identity)
  if (inherits(x, "error")) {
    res$status <- status_for(x)
    return(list(error = cli::ansi_strip(conditionMessage(x))))
  }
  if ("state_name_harmonized" %in% names(x)) x$state <- x$state_name_harmonized
  if ("district_name" %in% names(x) && !"district" %in% names(x)) x$district <- x$district_name
  if (!inherits(x, "sf")) {
    return(as.data.frame(x))
  }

  tmp <- tempfile(fileext = ".geojson")
  on.exit(unlink(tmp), add = TRUE)
  sf::st_write(x, tmp, layer = "censusindia", driver = "GeoJSON", quiet = TRUE)
  res$setHeader("Content-Type", "application/geo+json")
  res$body <- readChar(tmp, file.size(tmp), useBytes = TRUE)
  res
}

#* Health check
#* @get /health
function() {
  list(
    status = "ok",
    package = "censusindia",
    version = as.character(utils::packageVersion("censusindia"))
  )
}

#* List available states
#* @get /states
function(req, res) {
  respond(req, res, list_states())
}

#* List available census year and geography combinations
#* @get /geographies
function(req, res) {
  respond(req, res, list_census_geographies())
}

#* List available variables
#* @param year Optional census year to filter on
#* @param geography Optional geography to filter on (state, district, subdistrict)
#* @param category Optional category filter
#* @get /variables
function(year = "", geography = "", category = "", req, res) {
  respond(req, res, list_census_variables(
    year = as_whole(year),
    geography = csv(geography),
    category = csv(category)
  ))
}

#* Search census variables by keyword
#* @param pattern Keyword or regex to match in variable names/labels
#* @get /search
function(pattern = "", req, res) {
  respond(req, res, if (nzchar(trimws(pattern))) {
    search_census_variables(pattern)
  } else {
    list_census_variables()
  })
}

#* Query census data
#* @param year Census year. One of 1901, 1911, 1921, 1931, 1941, 1951, 1961, 1971, 1981, 1991, 2001, 2011.
#* @param geography Geography level: state, district, or subdistrict.
#* @param state Comma-separated state names or two-letter codes. Census tables have no India row; omit to get every state.
#* @param variables Comma-separated variable names to return.
#* @param sector total, rural or urban. Rural and urban exist for 1971 and 1981 only; other years are a 400.
#* @param geometry Return a GeoJSON FeatureCollection with boundaries.
#* @get /query
function(year = 2011, geography = "state", state = "", variables = "",
         sector = "total", geometry = FALSE, req, res) {
  respond(req, res, {
    x <- get_census(
      year = one_year(year),
      geography = word(geography),
      variables = csv(variables),
      state = csv(state),
      geometry = flag(geometry),
      sector = word(sector)
    )
    # district rows hold the name in name; the other APIs call it district
    if (identical(word(geography), "district")) x$district <- x$name
    x
  })
}

#* Query population projections
#* @param year Projection year or years (comma-separated, or a range such as 2021:2026). Years between projections are interpolated, years up to five past the last table year extrapolated; the `estimate` column says which.
#* @param geography Geography level: state or district.
#* @param state Comma-separated state names or two-letter codes.
#* @param boundary District boundary system: census2011 or lgd.
#* @param by_age Return age-stratified rows. States by age cover 23 major states, India and "North East States Excluding Assam"; others are a 400.
#* @param geometry Return a GeoJSON FeatureCollection with boundaries.
#* @get /population
function(year = "", geography = "state", state = "", boundary = "census2011",
         by_age = FALSE, geometry = FALSE, req, res) {
  respond(req, res, get_population(
    year = as_whole(year),
    geography = word(geography),
    state = csv(state),
    boundary = word(boundary),
    geometry = flag(geometry),
    by_age = flag(by_age)
  ))
}

#* Census boundaries as GeoJSON
#* @param year Boundary vintage: 1941, 1951, 1961, 1971, 1981, 1991, 2001 or 2011.
#* @param geography state or district.
#* @get /boundaries
function(year = 2011, geography = "state", req, res) {
  respond(req, res, get_census_boundaries(one_year(year), word(geography)))
}

#* Census 2011 languages spoken, one row per language per area
#* @param level district or subdistrict.
#* @param language_group Comma-separated codes from the `language_group` column.
#* @get /languages
function(level = "district", language_group = "", req, res) {
  respond(req, res, census_languages(word(level), csv(language_group)))
}

#* Census 2011 Scheduled Caste and Scheduled Tribe populations
#* @param category SC, ST, or a full category name.
#* @param state Comma-separated state names or two-letter codes.
#* @get /sc-st
function(category = "", state = "", req, res) {
  respond(req, res, census_sc_st(csv(category), csv(state)))
}

#* Shipped datasets that can be fetched whole with /dataset/<name>
#* @get /datasets
function(req, res) {
  respond(req, res, DATASETS)
}

#* One shipped dataset, e.g. census_1931_castes or census_2011_tribes. Counts are persons.
#* @param name Dataset name from /datasets.
#* @param state Comma-separated state names or two-letter codes, for tables with a state column.
#* @get /dataset/<name>
function(name, state = "", req, res) {
  if (!name %in% DATASETS[, "Item"]) {
    res$status <- 404L
    return(list(error = sprintf("Unknown dataset \"%s\". See /datasets.", name)))
  }
  respond(req, res, {
    d <- getExportedValue("censusindia", name)
    # serve persons like every other table
    if (name == "population_projections_state_age") d <- state_age_persons()
    state <- csv(state)
    if (is.null(state)) d else filter_by_state(d, state)
  })
}
