# REST API contract: canonical column names on every route, status codes for
# bad input, paging headers, and /dataset/<name> for every shipped dataset.

skip_if_not_installed("plumber")

expect_canonical <- function(r, info = NULL, allow_name = FALSE) {
  expect_equal(r$status, 200, info = info)
  cols <- names(r$json)
  expect_false(any(RETIRED_COLS %in% cols), info = paste(info, paste(intersect(RETIRED_COLS, cols), collapse = ",")))
  if (!allow_name) expect_false("name" %in% cols, info = info)
}

shipped <- utils::data(package = "censusindia")$results[, "Item"]

test_that("/query returns canonical columns for every advertised year and geography", {
  g <- list_census_geographies()
  for (i in seq_len(nrow(g))) {
    q <- sprintf("year=%d&geography=%s", g$year[i], g$geography[i])
    r <- api_get("/query", q)
    expect_canonical(r, info = q)
    expect_identical(names(r$json)[1:3], c("year", "geography", "sector"), info = q)
  }
})

test_that("/query column order matches get_census()", {
  r <- api_get("/query", "year=1981&geography=district")
  expect_identical(names(r$json), names(get_census(1981, "district")))
})

test_that("/query state frames carry no district column", {
  r <- api_get("/query", "year=2011&geography=state")
  expect_false(any(c("district", "district_code") %in% names(r$json)))
})

test_that("/query variables come back as ids plus the requested names", {
  r <- api_get("/query", "year=2011&geography=state&variables=sex_ratio,population")
  expect_equal(r$status, 200)
  expect_identical(utils::tail(names(r$json), 2), c("sex_ratio", "population"))
  expect_equal(r$json$sex_ratio, 1000 * get_census(2011, "state")$females / get_census(2011, "state")$males, tolerance = 1e-6)
})

test_that("/query state codes are case-insensitive and comma-separated", {
  r <- api_get("/query", "year=2011&geography=state&state=kl,TN")
  expect_setequal(r$json$state_name_harmonized, c("Kerala", "Tamil Nadu"))
})

test_that("/query bad input is a 400 with an error message", {
  qs <- c(
    "year=2005", "year=abc", "year=2001,2011", "geography=village",
    "year=2011&sector=rural", "sector=everywhere", "state=Pradesh",
    "year=2011&variables=nope", "year=2011&geography=subdistrict&geometry=true",
    "geometry=maybe", "year=1961&geography=subdistrict"
  )
  for (q in qs) {
    r <- api_get("/query", q)
    expect_equal(r$status, 400, info = q)
    expect_true(nzchar(r$json$error), info = q)
  }
})

test_that("/query 400 message carries the package's wording", {
  expect_match(api_get("/query", "state=Atlantis")$json$error, "Unknown state")
  expect_match(api_get("/query", "year=2011&variables=nope")$json$error, "Available here")
})

test_that("/population returns canonical columns with an estimate column", {
  for (q in c(
    "year=2021", "year=2021&geography=district", "year=2021&geography=district&boundary=lgd",
    "year=2021&by_age=true&state=India"
  )) {
    r <- api_get("/population", q)
    expect_canonical(r, info = q)
    expect_true("estimate" %in% names(r$json), info = q)
  }
})

test_that("/population interpolates and labels the estimate", {
  r <- suppressMessages(api_get("/population", "year=2013&geography=district&state=KL"))
  expect_equal(r$status, 200)
  expect_identical(unique(r$json$estimate), "interpolated")
})

test_that("/population ranges expand to one row per state per year", {
  r <- api_get("/population", "year=2021:2023&state=KL")
  expect_equal(r$json$year, 2021:2023)
})

test_that("/population bad input is a 400", {
  for (q in c(
    "year=2050", "year=2005", "year=2011.5", "geography=village",
    "by_age=true&state=Sikkim", "state=Atlantis", "by_age=sometimes"
  )) {
    expect_equal(api_get("/population", q)$status, 400, info = q)
  }
})

test_that("/languages returns canonical columns and filters sector", {
  r <- api_get("/languages", "sector=urban&limit=50")
  expect_canonical(r)
  expect_identical(unique(r$json$sector), "urban")
  expect_true(all(c("speakers", "language_name") %in% names(r$json)))
})

test_that("/languages bad level or sector is a 400", {
  expect_equal(api_get("/languages", "level=state")$status, 400)
  expect_equal(api_get("/languages", "sector=both")$status, 400)
})

test_that("/sc-st returns canonical columns with percent", {
  r <- api_get("/sc-st", "category=sc&state=KL")
  expect_canonical(r)
  expect_true("percent" %in% names(r$json))
  expect_false("percentage" %in% names(r$json))
  expect_identical(unique(r$json$category_code), "SC")
})

test_that("/sc-st unknown category is a 400", {
  r <- api_get("/sc-st", "category=OBC")
  expect_equal(r$status, 400)
  expect_match(r$json$error, "Unknown category")
})

test_that("metadata routes return canonical columns", {
  expect_canonical(api_get("/states"))
  expect_true("state_name_harmonized" %in% names(api_get("/states")$json))
  expect_canonical(api_get("/geographies"))
  expect_canonical(api_get("/variables", "year=2011"))
  expect_true("geography" %in% names(api_get("/variables")$json))
})

test_that("/variables filters match list_census_variables()", {
  r <- api_get("/variables", "year=1971&geography=state&category=population")
  ref <- list_census_variables(year = 1971, geography = "state", category = "population")
  expect_setequal(r$json$variable, ref$variable)
})

test_that("/search with an empty pattern returns every variable", {
  expect_equal(nrow(api_get("/search", "pattern=")$json), nrow(census_variables))
})

test_that("/dataset/<name> returns 200 and every row for each shipped dataset", {
  for (nm in shipped) {
    r <- api_get(paste0("/dataset/", nm), "limit=1")
    expect_equal(r$status, 200, info = nm)
    expect_equal(r$headers[["X-Total-Count"]], as.character(nrow(getExportedValue("censusindia", nm))), info = nm)
  }
})

test_that("/dataset/<name> columns are the dataset's own canonical columns", {
  for (nm in shipped) {
    d <- getExportedValue("censusindia", nm)
    r <- api_get(paste0("/dataset/", nm), "limit=5")
    expect_identical(names(r$json), names(d), info = nm)
    # name survives only on tables that reach units below subdistrict
    allow <- "geography" %in% names(d) && any(d$geography %in% censusindia:::.unit_geographies)
    expect_canonical(r, info = nm, allow_name = allow || !"geography" %in% names(d))
  }
})

test_that("/dataset with an unknown name is a 404 pointing at /datasets", {
  r <- api_get("/dataset/census_2021_pca")
  expect_equal(r$status, 404)
  expect_match(r$json$error, "/datasets")
})

test_that("/dataset state filter uses the package resolver", {
  r <- api_get("/dataset/census_2011_pca", "state=kl")
  expect_equal(r$status, 200)
  expect_identical(unique(r$json$state_name_harmonized), "Kerala")
  expect_equal(api_get("/dataset/census_2011_pca", "state=Pradesh")$status, 400)
})

test_that("/datasets lists exactly the shipped datasets", {
  r <- api_get("/datasets")
  expect_setequal(r$json$Item, shipped)
})

test_that("paging headers report total, offset and limit", {
  r <- api_get("/query", "year=2011&geography=district&limit=25&offset=600")
  expect_equal(r$headers[["X-Total-Count"]], "640")
  expect_equal(r$headers[["X-Offset"]], "600")
  expect_equal(r$headers[["X-Limit"]], "25")
  expect_equal(nrow(r$json), 25)
})

test_that("pages walk the table without overlap or gaps", {
  full <- get_census(2011, "district")
  a <- api_get("/query", "year=2011&geography=district&limit=300&offset=0")$json
  b <- api_get("/query", "year=2011&geography=district&limit=300&offset=300")$json
  c <- api_get("/query", "year=2011&geography=district&limit=300&offset=600")$json
  expect_equal(nrow(c), 40)
  expect_identical(c(a$district, b$district, c$district), full$district)
})

test_that("an offset past the end returns an empty page with the total", {
  r <- api_get("/query", "year=2011&geography=state&offset=1000")
  expect_equal(r$status, 200)
  expect_equal(r$headers[["X-Total-Count"]], "35")
  expect_length(r$json, 0)
})

test_that("bad paging parameters are a 400", {
  for (q in c("limit=-1", "limit=10001", "offset=-5", "limit=abc", "limit=1.5")) {
    expect_equal(api_get("/states", q)$status, 400, info = q)
  }
})

test_that("unknown query parameters are a 400 on every route", {
  for (p in c("/query", "/population", "/languages", "/sc-st", "/states", "/dataset/india_states")) {
    r <- api_get(p, "foo=1")
    expect_equal(r$status, 400, info = p)
    expect_match(r$json$error, "Unknown parameter", info = p)
  }
})

test_that("/boundaries returns canonical GeoJSON properties", {
  skip_if_no_remote()
  r <- api_get("/boundaries", "year=2011&geography=state&limit=3")
  expect_equal(r$status, 200)
  expect_equal(r$headers[["Content-Type"]], "application/geo+json")
  g <- jsonlite::fromJSON(r$body)
  props <- names(g$features$properties)
  expect_true("state_name_harmonized" %in% props)
  expect_false(any(RETIRED_COLS %in% props))
})

test_that("/query geometry=true returns GeoJSON with canonical properties", {
  skip_if_no_remote()
  r <- api_get("/query", "year=2011&geography=district&state=KL&geometry=true")
  expect_equal(r$status, 200)
  g <- jsonlite::fromJSON(r$body)
  expect_equal(nrow(g$features$properties), 14)
  expect_true("district" %in% names(g$features$properties))
  expect_false(any(c(RETIRED_COLS, "name") %in% names(g$features$properties)))
})

test_that("/boundaries for a year without a boundary file is a 400", {
  expect_equal(api_get("/boundaries", "year=2021")$status, 400)
  expect_equal(api_get("/boundaries", "geography=village")$status, 400)
})
