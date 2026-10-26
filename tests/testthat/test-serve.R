skip_if_not_installed("plumber")

router <- api_router()

# calls the router in-process, no socket; JSON rows come back as a data frame
# headers go in as Rook names, e.g. HTTP_USER_AGENT = "curl/8.0"
api_get <- function(path, query = "", ...) {
  empty <- list(read = function(...) raw(), rewind = function() NULL)
  out <- capture.output(r <- router$call(list2env(list(
    REQUEST_METHOD = "GET", PATH_INFO = path, QUERY_STRING = query,
    HTTP_HOST = "localhost", rook.input = empty, ...
  ))))
  r$log <- out
  r$json <- if (grepl("json", r$headers[["Content-Type"]])) {
    jsonlite::fromJSON(r$body)
  }
  r
}

test_that("serve() finds the bundled router", {
  expect_s3_class(router, "Plumber")
  expect_identical(census_api, serve)
})

test_that("/health reports the package version", {
  r <- api_get("/health")
  expect_equal(r$status, 200)
  expect_equal(r$json$status, "ok")
  expect_equal(r$json$version, as.character(utils::packageVersion("censusindia")))
})

test_that("metadata endpoints return one row per record", {
  expect_equal(nrow(api_get("/states")$json), nrow(list_states()))
  expect_equal(nrow(api_get("/geographies")$json), nrow(list_census_geographies()))
  expect_equal(
    nrow(api_get("/variables", "year=2011&geography=district")$json),
    nrow(list_census_variables(year = 2011, geography = "district"))
  )
  hits <- api_get("/search", "pattern=liter")$json
  expect_gt(nrow(hits), 0)
  expect_match(hits$variable, "liter")
})

test_that("/query matches get_census()", {
  r <- api_get("/query", "year=2011&geography=district&state=KL,GA&variables=population")
  expect_equal(r$status, 200)
  want <- get_census(2011, "district", "population", state = c("KL", "GA"))
  expect_equal(nrow(r$json), nrow(want))
  expect_equal(sum(r$json$population), sum(want$population))
})

test_that("/query passes sector through for 1971", {
  urban <- api_get("/query", "year=1971&geography=district&state=Kerala&sector=urban")$json
  want <- get_census(1971, "district", state = "Kerala", sector = "urban")
  expect_equal(sort(urban$population), sort(want$population))
})

test_that("bad input is a 400 carrying the package's message", {
  cases <- c(
    "year=2021", "year=abc", "year=2011.5", "state=Pradesh", "variables=foo",
    "geography=village", "sector=suburban",
    "geography=subdistrict&geometry=true"
  )
  errors <- vapply(cases, function(q) {
    r <- api_get("/query", q)
    expect_equal(r$status, 400, info = q)
    expect_length(r$json$error, 1)
    r$json$error
  }, "")
  expect_match(errors[["state=Pradesh"]], "Unknown state")
  expect_equal(api_get("/population", "year=xyz")$status, 400)
  expect_equal(api_get("/population", "boundary=osm")$status, 400)
  expect_equal(api_get("/boundaries", "year=2021")$status, 400)
  expect_equal(api_get("/sc-st", "state=Atlantis")$status, 400)
})

test_that("failed downloads are a 503", {
  status_for <- router$environment$status_for
  e <- tryCatch(
    rlang::abort("offline", class = "censusindia_download_error"),
    error = identity
  )
  expect_equal(status_for(e), 503L)
  expect_equal(status_for(simpleError("bug")), 500L)
})

test_that("unknown routes are a 404", {
  expect_equal(api_get("/nope")$status, 404)
})

test_that("/population returns one row per state and year", {
  r <- api_get("/population", "year=2023,2026&state=KL,TN")
  expect_equal(r$status, 200)
  expect_equal(nrow(r$json), 4)
  expect_setequal(r$json$year, c(2023, 2026))
})

test_that("/sc-st filters like census_sc_st()", {
  r <- api_get("/sc-st", "category=SC&state=GA")
  expect_equal(nrow(r$json), nrow(census_sc_st("SC", "GA")))
})

test_that("missing values serialise as null so every row has every field", {
  r <- api_get("/query", "year=1961&geography=district")
  keys <- lapply(jsonlite::fromJSON(r$body, simplifyVector = FALSE), names)
  expect_true(all(vapply(keys, identical, TRUE, keys[[1]])))
})

test_that("geometry requests return a GeoJSON FeatureCollection", {
  skip_if_no_remote()
  r <- api_get("/query", "year=2011&state=KL&geometry=true")
  expect_equal(r$status, 200)
  expect_equal(r$headers[["Content-Type"]], "application/geo+json")
  gj <- r$json
  expect_equal(gj$type, "FeatureCollection")
  expect_equal(nrow(gj$features), 1)
  expect_equal(gj$features$properties$state_name_harmonized, "Kerala")

  b <- api_get("/boundaries", "year=2011&geography=state")
  expect_equal(b$headers[["Content-Type"]], "application/geo+json")
  expect_gte(nrow(b$json$features), 35)
})

test_that("/variables takes several categories", {
  cats <- unique(list_census_variables()$category)[1:2]
  r <- api_get("/variables", paste0("category=", paste(cats, collapse = ",")))
  expect_equal(nrow(r$json), nrow(list_census_variables(category = cats)))
  expect_setequal(r$json$category, cats)
})

test_that("/dataset serves shipped tables and nothing else", {
  listed <- api_get("/datasets")$json$Item
  expect_true(all(c("census_1931_castes", "census_2011_tribes") %in% listed))

  r <- api_get("/dataset/census_1931_castes")
  expect_equal(r$status, 200)
  expect_equal(nrow(r$json), nrow(census_1931_castes))

  goa <- api_get("/dataset/census_2011_tribes", "state=GA")$json
  expect_gt(nrow(goa), 0)
  expect_setequal(goa$state_name_harmonized, "Goa")

  expect_equal(api_get("/dataset/get_census")$status, 404)
  expect_equal(api_get("/dataset/census_1931_castes", "state=KL")$status, 400)
})

test_that("each request logs one JSON line naming the client", {
  line <- function(...) jsonlite::fromJSON(api_get("/health", ...)$log)

  l <- line(HTTP_USER_AGENT = "curl/8.7.1", HTTP_X_FORWARDED_FOR = "203.0.113.9, 10.0.0.1")
  expect_equal(l$client, "curl")
  expect_equal(l$path, "/health")
  expect_equal(l$status, 200)
  expect_equal(l$ip, "203.0.113.9")
  expect_gte(l$ms, 0)

  expect_equal(line(HTTP_USER_AGENT = "censusindia-mcp/0.1 node")$client, "mcp")
  expect_equal(line(HTTP_USER_AGENT = "curl/8.7.1", HTTP_X_CLIENT = "mcp/claude-desktop")$client, "mcp/claude-desktop")
  expect_equal(line(HTTP_USER_AGENT = "python-requests/2.32")$client, "python")
  expect_equal(line(HTTP_USER_AGENT = "httr2/1.0.0 r-curl/5.2 libcurl/8.4")$client, "r")
  expect_equal(line(HTTP_USER_AGENT = "Mozilla/5.0 (Macintosh)")$client, "browser")
  expect_equal(line()$client, "unknown")

  bad <- jsonlite::fromJSON(api_get("/query", "state=Pradesh")$log)
  expect_equal(bad$status, 400)
  expect_equal(bad$query, "state=Pradesh")
})

test_that("responses are capped at one page and walk with limit/offset", {
  langs <- census_languages("district")
  r <- api_get("/languages")
  expect_equal(r$status, 200)
  expect_equal(nrow(r$json), 10000)
  expect_equal(r$headers[["X-Total-Count"]], as.character(nrow(langs)))
  expect_equal(r$headers[["X-Limit"]], "10000")

  p <- api_get("/languages", "limit=5&offset=10")$json
  expect_equal(p$language_name, langs$language_name[11:15])

  expect_equal(NROW(api_get("/languages", paste0("offset=", nrow(langs)))$json), 0)
  # limit=0 aliases the maximum in all five APIs
  expect_equal(api_get("/languages", "limit=0")$headers[["X-Limit"]], "10000")
  for (q in c("limit=10001", "limit=2.5", "offset=-1", "limit=abc")) {
    expect_equal(api_get("/languages", q)$status, 400, info = q)
  }
})

test_that("a full table of 2011 subdistricts fits in one page", {
  r <- api_get("/query", "year=2011&geography=subdistrict")
  expect_equal(r$headers[["X-Total-Count"]], as.character(nrow(r$json)))
})

test_that("GeoJSON pages by feature, 100 at most", {
  skip_if_no_remote()
  total <- as.character(nrow(get_census_boundaries(2011, "district")))
  full <- api_get("/boundaries", "year=2011&geography=district")
  expect_equal(nrow(full$json$features), 100)
  expect_equal(full$headers[["X-Total-Count"]], total)

  b <- api_get("/boundaries", "year=2011&geography=district&limit=3&offset=2")
  expect_equal(nrow(b$json$features), 3)
  expect_equal(api_get("/boundaries", "year=2011&geography=district&limit=101")$status, 400)
})

test_that("unknown parameters are a 400 naming the known ones", {
  r <- api_get("/states", "foo=1")
  expect_equal(r$status, 400)
  expect_match(r$json$error, "foo.*limit, offset")
  expect_match(api_get("/query", "yaer=2011")$json$error, "year, geography, state")
  expect_equal(api_get("/health", "foo=1")$status, 400)
  expect_equal(api_get("/query", "year=2011&limit=1")$status, 200)
})

test_that("state=India on /query is a 400 telling the client to drop state", {
  r <- api_get("/query", "year=2011&state=India")
  expect_equal(r$status, 400)
  expect_match(r$json$error, "No rows for \"India\"")
  expect_match(r$json$error, "Remove `state`")
  expect_match(api_get("/query", "state=Pradesh")$json$error, "Remove `state`")
})

test_that("rows with a state carry the canonical name as `state`", {
  r <- api_get("/query", "year=1971&state=Karnataka")$json
  expect_equal(unique(r$state), "Karnataka")
  expect_true("state_name_harmonized" %in% names(r))
  p <- api_get("/query", "year=2011&state=GA")$json
  expect_true(all(c("state", "state_name", "state_name_harmonized") %in% names(p)))
  expect_equal(unique(api_get("/population", "year=2026&state=KL")$json$state), "Kerala")
})

test_that("/population by_age answers in persons and rejects uncovered states", {
  kl <- api_get("/population", "year=2026&geography=state&state=Kerala&by_age=true")$json
  expect_gt(kl$males[kl$age_group == "0-4"], 1e6)
  goa <- api_get("/population", "year=2026&geography=state&state=Goa&by_age=true")
  expect_equal(goa$status, 400)
  expect_false(grepl("\n  ", goa$json$error))
})

test_that("/dataset serves the state projections by age in persons", {
  r <- api_get("/dataset/population_projections_state_age", "limit=1")$json
  expect_equal(r$population, population_projections_state_age$population[1] * 1000)
})

test_that("single-year routes reject ranges, and booleans are strict", {
  r <- api_get("/query", "year=2001:2011")
  expect_equal(r$status, 400)
  expect_match(r$json$error, "one census year")
  expect_equal(api_get("/boundaries", "year=2001,2011")$status, 400)
  expect_equal(api_get("/population", "by_age=tru")$status, 400)
  expect_equal(nrow(api_get("/population", "year=2021:2023&state=KL")$json), 3)
})

test_that("district rows carry a district column", {
  r <- api_get("/query", "year=2011&geography=district&state=GA&variables=population")$json
  expect_setequal(r$district, c("North Goa", "South Goa"))
})

test_that("LA resolves to Ladakh and district_name tables also carry district", {
  expect_equal(unique(api_get("/population", "year=2021&state=LA")$json$state), "Ladakh")
  r <- api_get("/sc-st", "category=SC&state=GA")$json
  expect_equal(r$district, r$district_name)
})
