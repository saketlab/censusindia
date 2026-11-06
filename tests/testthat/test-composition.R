tribes <- function() composition_matrix(census_2011_tribes, "tribe_name_original", "population")

test_that("diversity measures have their known values", {
  p <- c(0.5, 0.25, 0.25)
  expect_equal(shannon_entropy(p), 1.5)
  expect_equal(effective_number(rep(0.25, 4)), 4)
  expect_equal(effective_number(c(1, 0)), 1)
  expect_equal(herfindahl_index(p), 0.375)
  expect_equal(greenberg_index(p), 0.625)
  expect_equal(gini_coefficient(c(1, 1, 1)), 0)
  expect_equal(gini_coefficient(c(0, 0, 0, 1)), 0.75)
})

test_that("composition_matrix gives proportions by district", {
  d <- data.frame(
    state_name_harmonized = c("A", "A", "A"), district = c("x", "x", "y"),
    item = c("p", "q", "p"), n = c(1, 3, 2), total = c(8, 8, 2)
  )
  expect_equal(unname(composition_matrix(d, "item", "n")["A|x", ]), c(0.25, 0.75))
  expect_equal(unname(composition_matrix(d, "item", "n", "total")["A|x", ]), c(0.125, 0.375))
  expect_equal(unname(composition_matrix(d, "item", "n")["A|y", ]), c(1, 0))
})

test_that("composition distances have their known values", {
  x <- rbind(a = c(1, 0, 0), b = c(0.5, 0.5, 0), c = c(0, 0, 1))
  expect_equal(as.matrix(composition_distance(x, "jaccard"))["a", "b"], 0.5)
  expect_equal(as.matrix(composition_distance(x, "jaccard"))["a", "c"], 1)
  expect_equal(as.matrix(composition_distance(x, "bray_curtis"))["a", "b"], 0.5)
  expect_equal(as.matrix(composition_distance(x, "hellinger"))["a", "c"], sqrt(2))
  expect_equal(as.matrix(composition_distance(x, "tfidf"))["a", "c"], 1)
})

test_that("composition_clusters returns one row per district for each method", {
  m <- tribes()[1:40, ]
  m <- m[, colSums(m) > 0]
  for (method in c("hellinger", "tfidf", "jaccard", "bray_curtis", "pca")) {
    cl <- composition_clusters(m, 4, method)
    expect_equal(nrow(cl), 40)
    expect_equal(nlevels(cl$cluster), 4)
    expect_named(cl, c("state_name_harmonized", "district", "cluster"))
  }
})

test_that("pca helpers keep the districts and the total variance", {
  m <- tribes()[1:40, ]
  pca <- composition_pca(m)
  expect_equal(max(pca_variance(pca)$cumulative), 1)
  expect_equal(nrow(pca_scores(pca)), 40)
  expect_true(all(pca_scores(pca)$state_name_harmonized %in% census_2011_tribes$state_name_harmonized))
})

test_that("adjusted_rand_index ignores label names", {
  expect_equal(adjusted_rand_index(c(1, 1, 2, 2), c("b", "b", "a", "a")), 1)
  expect_lt(adjusted_rand_index(c(1, 1, 2, 2), c(1, 2, 1, 2)), 0.1)
})

test_that("language_diversity covers all districts", {
  skip_if_no_remote()
  d <- language_diversity("L1")
  expect_equal(nrow(d), nrow(census_2011_pca))
  expect_true(all(d$effective_languages >= 1))
})
