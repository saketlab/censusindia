test_that("village_files uses the file of each 2011 state", {
  files <- censusindia:::village_files
  expect_equal(files("Kerala"), "kerala.geojson")
  expect_equal(files("KL"), "kerala.geojson")
  expect_setequal(files("Andhra Pradesh"), c("andhra-pradesh.geojson", "telangana.geojson"))
  expect_setequal(files("Jammu & Kashmir"), c("jammu-and-kashmir.geojson", "ladakh.geojson"))
  expect_equal(
    files(c("Daman & Diu", "Dadra & Nagar Haveli")),
    "dadra-and-nagar-haveli-and-daman-and-diu.geojson"
  )
})

test_that("a village file keeps only the census states that it covers", {
  states <- censusindia:::village_file_states
  expect_equal(states("kerala.geojson"), "Kerala")
  expect_equal(states("telangana.geojson"), "Andhra Pradesh")
  expect_equal(states("ladakh.geojson"), "Jammu & Kashmir")
  expect_length(states("dadra-and-nagar-haveli-and-daman-and-diu.geojson"), 2)
})

test_that("each state in india_states has a pinned village file", {
  m <- censusindia:::census_manifest("manifest-villages.csv")
  expect_equal(nrow(m), 36)
  expect_true(all(grepl("^[0-9a-f]{32}$", m$md5)))
  expect_true(all(unlist(lapply(india_states$state_name_harmonized, censusindia:::village_files)) %in% m$file))
})

test_that("village boundaries need 2011 and a state", {
  expect_error(get_census_boundaries(2001, "village", state = "Kerala"), "2011 only")
  expect_error(get_census_boundaries(2011, "village"), "necessary")
  expect_error(get_census_boundaries(2011, "village", state = "India"), "manifest")
})

test_that("Kerala villages join to the census by code", {
  skip_if_no_remote()
  shapes <- get_census_boundaries(2011, "village", state = "Kerala")
  expect_false(anyDuplicated(shapes$town_village_code) > 0)
  expect_true(all(sf::st_is_valid(shapes)))
  expect_equal(sum(shapes$geography == "village"), 1018)
  expect_equal(unique(shapes$state_name_harmonized), "Kerala")

  villages <- census_2011_demographics() |>
    at_level("village", sector = "rural") |>
    dplyr::filter(state_name_harmonized == "Kerala")
  joined <- attach_geometry(villages, 2011, geography = "village")
  expect_s3_class(joined, "sf")
  expect_equal(sum(sf::st_is_empty(joined$geometry)), 0)
})
