pca_key <- function() {
  dplyr::select(censusindia::census_2011_pca, "state_code", "district_code", "district", "population")
}

total <- function(d) d[d$sector == "total", ]

test_that("district language speakers do not exceed district population", {
  spk <- total(censusindia::census_2011_district_languages) |>
    dplyr::group_by(.data$state_code, .data$district_code) |>
    dplyr::summarise(s = sum(.data$speakers), .groups = "drop") |>
    dplyr::inner_join(pca_key(), by = c("state_code", "district_code"))

  expect_equal(nrow(spk), 640)
  # a double-counted source would exceed population
  expect_true(all(spk$s <= spk$population))
  expect_gt(stats::median(spk$s / spk$population), 0.99)
})

test_that("subdistricts reconstruct their district exactly", {
  skip_if_no_remote()
  sub <- total(census_2011_subdistrict_languages()) |>
    dplyr::group_by(.data$state_code, .data$district_code, .data$language_name) |>
    dplyr::summarise(s = sum(.data$speakers), .groups = "drop")
  dis <- total(censusindia::census_2011_district_languages) |>
    dplyr::select("state_code", "district_code", "language_name", d = "speakers")

  j <- dplyr::inner_join(sub, dis,
    by = c("state_code", "district_code", "language_name")
  )
  expect_equal(nrow(j), nrow(dis))
  expect_equal(j$s, j$d)
})

test_that("mother tongue levels: each district equals its subdistricts and the PCA", {
  skip_if_no_remote()
  l1 <- total(census_2011_mother_tongue())
  l1 <- l1[l1$language_level == "L1", ]
  by_level <- function(g) {
    l1[l1$geography == g, ] |>
      dplyr::group_by(.data$state_code, .data$district_code) |>
      dplyr::summarise(s = sum(.data$speakers), n = dplyr::n_distinct(.data$subdistrict), .groups = "drop")
  }
  d <- dplyr::inner_join(by_level("district"), pca_key(), by = c("state_code", "district_code"))
  s <- by_level("subdistrict")

  expect_equal(nrow(d), 640)
  expect_equal(d$s, d$population)
  expect_equal(s$s, d$s[match(paste(s$state_code, s$district_code), paste(d$state_code, d$district_code))])
  expect_false(anyNA(l1$district[l1$geography != "state"]))

  m <- census_2011_mother_tongue()
  sub <- unique(m[m$geography == "subdistrict", c("state_code", "district_code", "subdistrict")])
  expect_equal(nrow(sub), 5988)
  # source defect: Kalapipal's L1 row holds the Hindi speakers of five Shajapur tehsils
  expect_equal(sum(s$n), 5983)
  shaj <- m[m$sector == "total" & m$geography == "subdistrict" & m$district_code == 436, ]
  stub <- c("Agar", "Shajapur", "Gulana", "Moman Badodiya", "Shujalpur")
  expect_true(all(table(shaj$subdistrict)[stub] == 1))
  kal <- shaj$speakers[shaj$subdistrict == "Kalapipal" & shaj$language_level == "L1"]
  expect_equal(kal, sum(shaj$speakers[shaj$subdistrict %in% c(stub, "Kalapipal") & shaj$language_level == "L2"]))
})

test_that("district names are authoritative and complete", {
  ld <- censusindia::census_2011_linguistic_diversity
  expect_equal(nrow(ld), 640)
  expect_false(anyNA(ld$district))

  expect_equal(ld$district[ld$state_code == 9 & ld$district_code == 171], "Chitrakoot")
  expect_setequal(ld$district, censusindia::census_2011_pca$district)
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
    dplyr::select("state_code", "district_code", "speakers", "coverage") |>
    dplyr::inner_join(pca_key(), by = c("state_code", "district_code"))
  expect_equal(spk$coverage, spk$speakers / spk$population)

  # C-16 lumps northeast languages into residuals; Zunheboto would rank first
  zun <- ld[ld$district == "Zunheboto", ]
  expect_lt(zun$coverage, 0.05)
})

test_that("census_languages returns the level it is asked for", {
  skip_if_no_remote()
  d <- census_languages("district")
  s <- census_languages("subdistrict")

  expect_equal(nrow(dplyr::distinct(d, .data$state_code, .data$district_code)), 640)
  expect_true("district" %in% names(d))
  expect_true(all(c("district_code", "subdistrict") %in% names(s)))
  expect_equal(unique(c(d$sector, s$sector)), "total")
  expect_gt(nrow(s), nrow(d))

  expect_error(census_languages("village"))
})

test_that("census_languages filters by language_group", {
  g <- census_languages("district", language_group = 1)
  expect_true(all(g$language_group == 1))
  expect_lt(nrow(g), nrow(census_languages("district")))
})
