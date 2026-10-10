religions <- c("hindu", "muslim", "sikh", "jain", "buddhist", "christian", "tribal", "parsi", "jew")

test_that("census_1931_castes religion columns sum to total", {
  x <- census_1931_castes
  expect_equal(anyDuplicated(x[c("province", "rank")]), 0)
  split <- rowSums(!is.na(x[religions])) > 0
  expect_equal(unique(x$province[!split]), "Ajmer-Merwara")
  expect_true(all(is.na(x$total[!split])))
  expect_equal(unname(rowSums(x[split, religions], na.rm = TRUE)), x$total[split])
  expect_false(anyNA(x$notes[which(x$total != x$total_ranked_list)]))
})

test_that("census_1931_castes reproduces the codebook totals", {
  x <- census_1931_castes
  expect_equal(length(unique(x$province)), 24)
  expect_equal(sum(x$total, na.rm = TRUE), 330778420)
  expect_equal(sum(x$total_ranked_list, na.rm = TRUE), 331222004)
  # Source_Notes revisions
  bihar <- x[x$province == "Bihar & Orissa" & x$caste == "Caste Unspecified", ]
  expect_equal(bihar$total, 4500008)
  expect_equal(sum(x$total[x$province == "Delhi"]), 636110)
})

test_that("census_1931_exterior_castes sums to the printed appendix total", {
  x <- census_1931_exterior_castes
  expect_false(anyNA(x$population))
  expect_equal(sum(x$population), 50195770)
  by_section <- tapply(x$population, x$section, sum)
  expect_equal(as.vector(by_section[c("Madras", "United Provinces", "Bengal")]), c(7299400, 11531145, 6930631))
})
