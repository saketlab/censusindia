# data-raw/legacy.R on hand-made frames; data-raw is absent from the built package

legacy <- test_path("..", "..", "data-raw", "legacy.R")
skip_if_not(file.exists(legacy), "data-raw is not in the built package")
source(legacy, local = TRUE)
id_cols <- censusindia:::.id_cols

test_that("legacy_names() maps the NEWS migration table's old names", {
  old_new <- c(
    district_name = "district", area_name = "name", state = "state_name",
    level = "geography",
    population_total = "population", population_male = "males",
    population_female = "females", total_persons = "population",
    total_males = "males", total_females = "females"
  )
  expect_identical(legacy_names(names(old_new)), unname(old_new))
})

test_that("legacy_names() drops _total from indicators", {
  expect_identical(
    legacy_names(c("literate_total", "workers_total", "main_workers_total", "males_total", "females_total")),
    c("literate", "workers", "main_workers", "males", "females")
  )
})

test_that("legacy_names() maps SC/ST totals and sexes onto sc_population", {
  expect_identical(
    legacy_names(c("sc_total", "st_total", "sc_male", "st_female")),
    c("sc_population", "st_population", "sc_population_male", "st_population_female")
  )
})

test_that("legacy_names() maps 1981 persons/males/females suffixes", {
  expect_identical(
    legacy_names(c("literate_persons", "literate_males", "literate_females")),
    c("literate", "literate_male", "literate_female")
  )
})

test_that("legacy_names() maps marg_ to marginal_", {
  expect_identical(
    legacy_names(c("marg_workers", "marg_workers_male")),
    c("marginal_workers", "marginal_workers_male")
  )
})

test_that("legacy_names() maps speakers, percentage and 1961 literacy", {
  expect_identical(
    legacy_names(c("total_speakers", "male_speakers", "female_speakers", "percentage")),
    c("speakers", "speakers_male", "speakers_female", "percent")
  )
  expect_identical(
    legacy_names(c("literacy_total", "literacy_male", "literacy_female")),
    c("literacy_rate", "literacy_rate_male", "literacy_rate_female")
  )
})

test_that("legacy_names() moves sector prefixes to suffixes", {
  expect_identical(
    legacy_names(c("rural_males", "urban_population", "persons_rural")),
    c("males_rural", "population_urban", "population_rural")
  )
})

test_that("legacy_names() leaves canonical names alone", {
  canon <- c(
    id_cols, "population", "males", "females", "literate_male", "speakers",
    "sc_population", "literacy_rate", "marginal_workers", "percent"
  )
  expect_identical(legacy_names(canon), canon)
})

test_that("legacy_names() is idempotent on every shipped table's columns", {
  sets <- utils::data(package = "censusindia")$results[, "Item"]
  for (nm in sets) {
    cols <- names(getExportedValue("censusindia", nm))
    if (nm %in% censusindia:::.not_geographic) next
    expect_identical(legacy_names(cols), cols, info = nm)
  }
})

test_that("to_schema() renames level to geography", {
  out <- to_schema(data.frame(level = c("STATE", "District"), population = 1:2))
  expect_identical(out$geography, c("state", "district"))
  expect_false("level" %in% names(out))
})

test_that("to_schema() pivots sector-suffixed columns into rows", {
  x <- data.frame(
    state_name_harmonized = "Kerala", population = 10,
    population_rural = 6, population_urban = 4, area_km2 = 5
  )
  out <- to_schema(x)
  expect_equal(nrow(out), 3)
  expect_identical(out$sector, c("total", "rural", "urban"))
  expect_identical(out$population, c(10, 6, 4))
  expect_false(any(grepl("_(rural|urban)$", names(out))))
})

test_that("values with no per-sector source are NA on rural and urban rows", {
  x <- data.frame(
    state_name_harmonized = "Kerala", speakers = 10, speakers_rural = 7,
    speakers_urban = 3, speakers_male = 6
  )
  out <- to_schema(x)
  expect_identical(out$speakers_male, c(6, NA, NA))
  expect_identical(out$speakers, c(10, 7, 3))
})

test_that("a rural column with no urban partner is left alone", {
  out <- to_schema(data.frame(state_name_harmonized = "Kerala", population = 1, households_rural = 1))
  expect_equal(nrow(out), 1)
  expect_true("households_rural" %in% names(out))
})

test_that("to_schema() turns name into district on a state/district table", {
  x <- data.frame(
    geography = c("state", "district"), state_name_harmonized = "Kerala",
    name = c("Kerala", "Idukki"), population = 1:2
  )
  out <- to_schema(x)
  expect_false("name" %in% names(out))
  expect_identical(out$district, c(NA, "Idukki"))
})

test_that("to_schema() turns name into subdistrict on a subdistrict table", {
  x <- data.frame(geography = "subdistrict", district = "Idukki", name = "Thodupuzha", population = 1)
  out <- to_schema(x)
  expect_identical(out$subdistrict, "Thodupuzha")
  expect_false("name" %in% names(out))
})

test_that("to_schema() keeps name on a table reaching villages", {
  x <- data.frame(
    geography = c("state", "district", "village"), state_name_harmonized = "Kerala",
    name = c("Kerala", "Idukki", "Kumily"), population = 1:3
  )
  out <- to_schema(x)
  expect_identical(out$name, c("Kerala", "Idukki", "Kumily"))
  expect_identical(utils::tail(names(out)[names(out) %in% id_cols], 1), "name")
})

test_that("to_schema() blanks district on india and state rows", {
  x <- data.frame(
    geography = c("india", "state", "district"),
    state_name_harmonized = c("India", "Kerala", "Kerala"),
    district = c("India", "Kerala", "Idukki"), population = 1:3
  )
  expect_identical(to_schema(x)$district, c(NA, NA, "Idukki"))
})

test_that("to_schema() infers geography from codes and the India row", {
  x <- data.frame(
    state_name_harmonized = c("India", "Kerala", "Kerala", "Kerala"),
    district_code = c(0, 0, 12, 12), subdistrict_code = c(0, 0, 0, 5),
    population = 1:4
  )
  expect_identical(to_schema(x)$geography, c("india", "state", "district", "subdistrict"))
})

test_that("to_schema() uses the geography argument when there is no column", {
  out <- to_schema(data.frame(state_name_harmonized = "Kerala", population = 1), geography = "district")
  expect_identical(out$geography, "district")
})

test_that("to_schema() drops the 1981 source keys", {
  out <- to_schema(data.frame(geo_id = 1, entity_id = 2, state_name_harmonized = "Kerala", population = 1))
  expect_false(any(c("geo_id", "entity_id") %in% names(out)))
})

test_that("to_schema() is idempotent on hand-made frames", {
  frames <- list(
    data.frame(state_name_harmonized = "Kerala", population_total = 10, population_rural = 6, population_urban = 4),
    data.frame(
      level = c("State", "District"), state = "KERALA", state_name_harmonized = "Kerala",
      name = c("Kerala", "Idukki"), district_code = c("000", "12"), total_persons = 1:2
    ),
    data.frame(geography = c("district", "village"), name = c("Idukki", "Kumily"), population = 1:2),
    data.frame(geography = "ua", area_name = "Kochi UA", marg_workers = 3L)
  )
  for (i in seq_along(frames)) {
    once <- to_schema(frames[[i]], year = 2011)
    expect_identical(to_schema(once), once, info = i)
    expect_identical(to_schema(once, year = 2011), once, info = i)
  }
})

test_that("to_schema() errors on an unknown geography", {
  expect_error(to_schema(data.frame(geography = "tehsil", population = 1)))
})

test_that("infer_geography() defaults to state without codes", {
  expect_identical(infer_geography(data.frame(population = 1:2)), c("state", "state"))
})
