pca_key <- function() {
  censusindia::census_2011_pca |>
    dplyr::transmute(
      state_code = sprintf("%02d", .data$state_code),
      district_code = sprintf("%03d", .data$district_code),
      district_name = .data$name,
      population = .data$population_total
    )
}

test_that("district language speakers do not exceed district population", {
  spk <- censusindia::census_2011_district_languages |>
    dplyr::group_by(.data$state_code, .data$district_code) |>
    dplyr::summarise(s = sum(.data$total_speakers), .groups = "drop") |>
    dplyr::inner_join(pca_key(), by = c("state_code", "district_code"))

  expect_equal(nrow(spk), 640)
  # a double-counted source would exceed population
  expect_true(all(spk$s <= spk$population))
  expect_gt(stats::median(spk$s / spk$population), 0.99)
})

test_that("subdistricts reconstruct their district exactly", {
  skip_if_no_remote()
  sub <- census_2011_subdistrict_languages() |>
    dplyr::group_by(.data$state_code, .data$district_code, .data$language_name) |>
    dplyr::summarise(s = sum(.data$total_speakers), .groups = "drop")
  dis <- censusindia::census_2011_district_languages |>
    dplyr::select("state_code", "district_code", "language_name", d = "total_speakers")

  j <- dplyr::inner_join(sub, dis,
    by = c("state_code", "district_code", "language_name")
  )
  expect_equal(nrow(j), nrow(dis))
  expect_equal(j$s, j$d)
})

test_that("the halving invariant the rebuild relies on holds in the source", {
  skip_if_no_remote()
  # subdistricts partition their district, so the district is half the group sum
  by_lang <- census_2011_mother_tongue() |>
    dplyr::filter(.data$district_code != "000", .data$language_level == "L1") |>
    dplyr::group_by(.data$state_code, .data$district_code, .data$language_code) |>
    dplyr::summarise(s = sum(.data$total_persons), .groups = "drop")

  expect_true(all(by_lang$s %% 2 == 0))

  halved <- by_lang |>
    dplyr::group_by(.data$state_code, .data$district_code) |>
    dplyr::summarise(half = sum(.data$s) / 2, .groups = "drop") |>
    dplyr::inner_join(pca_key(), by = c("state_code", "district_code"))

  expect_equal(nrow(halved), 640)
  expect_equal(halved$half, halved$population)
  expect_equal(sum(halved$half), 1210854977)
})

test_that("district names are authoritative and complete", {
  ld <- censusindia::census_2011_linguistic_diversity
  expect_equal(nrow(ld), 640)
  expect_false(anyNA(ld$district_name))

  expect_equal(
    ld$district_name[ld$state_code == "09" & ld$district_code == "171"],
    "Chitrakoot"
  )
  expect_setequal(ld$district_name, censusindia::census_2011_pca$name)
})

test_that("diversity metrics are well formed", {
  ld <- censusindia::census_2011_linguistic_diversity
  expect_true(all(ld$dominant_share > 0 & ld$dominant_share <= 1))
  expect_true(all(ld$effective_languages >= 1))
  expect_true(all(ld$effective_languages <= ld$n_languages))
  # effective_languages is 2^H
  expect_equal(ld$effective_languages, 2^ld$shannon_entropy)
})

test_that("coverage reports the share the metrics are computed from", {
  ld <- censusindia::census_2011_linguistic_diversity
  expect_true(all(ld$coverage > 0 & ld$coverage <= 1))

  spk <- ld |>
    dplyr::select("state_code", "district_code", "total_speakers", "coverage") |>
    dplyr::inner_join(pca_key(), by = c("state_code", "district_code"))
  expect_equal(spk$coverage, spk$total_speakers / spk$population)

  # C-16 lumps northeast languages into residuals; Zunheboto would rank first
  zun <- ld[ld$district_name == "Zunheboto", ]
  expect_lt(zun$coverage, 0.05)
})

test_that("census_languages returns the level it is asked for", {
  skip_if_no_remote()
  d <- census_languages("district")
  s <- census_languages("subdistrict")

  expect_equal(nrow(dplyr::distinct(d, .data$state_code, .data$district_code)), 640)
  expect_true("district_name" %in% names(d))
  expect_true("area_name" %in% names(s))
  expect_gt(nrow(s), nrow(d))

  expect_error(census_languages("village"))
})

test_that("census_languages filters by language_group", {
  g <- census_languages("district", language_group = 1)
  expect_true(all(g$language_group == 1))
  expect_lt(nrow(g), nrow(census_languages("district")))
})
