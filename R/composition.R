#' Diversity and concentration measures
#'
#' These measures use a vector of proportions that sum to 1.
#'
#' - `shannon_entropy()` is \eqn{-\sum_i p_i \log_2(p_i)}.
#' - `effective_number()` is \eqn{2^S}, where \eqn{S} is the Shannon entropy.
#'   This is the number of groups of equal size that give the same entropy.
#' - `herfindahl_index()` is the Herfindahl-Hirschman index, \eqn{\sum_i p_i^2}.
#' - `greenberg_index()` is \eqn{1 - \sum_i p_i^2}. This is the probability that
#'   two persons, selected at random, are in different groups.
#'
#' @param p Numeric vector of proportions. Zero proportions have no effect.
#' @return A number.
#' @examples
#' p <- c(0.5, 0.25, 0.25)
#' shannon_entropy(p)
#' effective_number(p)
#' herfindahl_index(p)
#' greenberg_index(p)
#' @export
shannon_entropy <- function(p) {
  # log2, not ln (Grin & Fuerst 2022 use ln), to match the base of 2^entropy.
  -sum(p * log2(p), na.rm = TRUE)
}

#' @rdname shannon_entropy
#' @export
effective_number <- function(p) {
  2^shannon_entropy(p)
}

#' @rdname shannon_entropy
#' @export
herfindahl_index <- function(p) {
  sum(p^2)
}

# Thanks to Shivakumar Jolad for highlighting this measure.
#' @rdname shannon_entropy
#' @export
greenberg_index <- function(p) {
  1 - herfindahl_index(p)
}

#' Gini coefficient
#'
#' Measures inequality. The value is 0 when all values are equal. The value
#' approaches 1 when one unit holds the full total.
#'
#' @param x Numeric vector of values that are not negative.
#' @return A number.
#' @examples
#' gini_coefficient(census_2011_pca$population)
#' @export
gini_coefficient <- function(x) {
  x <- sort(x)
  n <- length(x)
  sum((2 * seq_len(n) - n - 1) * x) / (n^2 * mean(x))
}

#' Language diversity of each 2011 district
#'
#' Calculates diversity measures from the C-16 mother tongue table. The function
#' uses the total sector and does not use the `"Others"` residual rows.
#'
#' [census_2011_linguistic_diversity] gives other measures for each district.
#' Use this function to select the language level and to get the Greenberg
#' index.
#'
#' @param level `"L1"` (scheduled languages) or `"L2"` (mother tongues).
#' @return A tibble with one row for each district. The columns are
#'   `n_languages`, `shannon_entropy`, `effective_languages` and
#'   `greenberg_index`, after the identifier columns.
#' @seealso [shannon_entropy()], [census_languages()].
#' @examplesIf interactive()
#' language_diversity("L1")
#' @export
language_diversity <- function(level = c("L1", "L2")) {
  level <- match.arg(level)
  census_2011_mother_tongue() |>
    at_level("district") |>
    dplyr::filter(.data$language_level == .env$level, !grepl("Others", .data$language_name)) |>
    dplyr::group_by(
      .data$state_code, .data$state_name, .data$state_name_harmonized,
      .data$district_code, .data$district, .data$language_name
    ) |>
    dplyr::summarise(speakers = sum(.data$speakers), .groups = "drop_last") |>
    dplyr::mutate(proportion = .data$speakers / sum(.data$speakers)) |>
    dplyr::summarise(
      n_languages = dplyr::n(),
      shannon_entropy = shannon_entropy(.data$proportion),
      effective_languages = effective_number(.data$proportion),
      greenberg_index = greenberg_index(.data$proportion),
      .groups = "drop"
    )
}

#' Composition of districts as a matrix
#'
#' Makes a matrix with one row for each district and one column for each item,
#' for example each tribe or language. Each cell is a proportion. Use the matrix
#' with [composition_distance()], [composition_clusters()] and
#' [composition_pca()].
#'
#' @param data A data frame in long form, with `state_name_harmonized`,
#'   `district`, and the columns that `item` and `value` name.
#' @param item Name of the column that holds the items.
#' @param value Name of the column that holds the counts.
#' @param total Name of a column that holds the district total. If `NULL`
#'   (default), the function uses the sum of `value` in the district.
#' @return A numeric matrix. The row names identify the state and the district.
#' @examples
#' m <- composition_matrix(census_2011_tribes, "tribe_name_original", "population")
#' dim(m)
#' @export
composition_matrix <- function(data, item, value, total = NULL) {
  unit <- paste(data$state_name_harmonized, data$district, sep = "|")
  m <- tapply(data[[value]], list(unit, data[[item]]), sum, default = 0)
  denominator <- if (is.null(total)) {
    rowSums(m)
  } else {
    tapply(data[[total]], unit, function(v) v[[1]])[rownames(m)]
  }
  m / as.numeric(denominator)
}

#' Distance between district compositions
#'
#' - `"hellinger"` is the Euclidean distance between square roots of
#'   proportions. The majority category has the largest effect.
#' - `"tfidf"` is the cosine distance after TF-IDF weights. Items in many
#'   districts have less effect. Rare items have more effect.
#' - `"jaccard"` uses only the presence or absence of items.
#' - `"bray_curtis"` uses proportions. Only items that are present in a district
#'   have an effect.
#'
#' @param x A matrix from [composition_matrix()].
#' @param method `"hellinger"`, `"tfidf"`, `"jaccard"` or `"bray_curtis"`.
#' @return A `dist` object.
#' @examples
#' m <- composition_matrix(census_2011_tribes, "tribe_name_original", "population")
#' composition_distance(m[1:5, ], "jaccard")
#' @export
composition_distance <- function(x, method = c("hellinger", "tfidf", "jaccard", "bray_curtis")) {
  method <- match.arg(method)
  switch(method,
    hellinger = stats::dist(sqrt(x)),
    jaccard = stats::dist(x > 0, method = "binary"),
    tfidf = tfidf_distance(x),
    bray_curtis = bray_curtis_distance(x)
  )
}

#' @noRd
tfidf_distance <- function(x) {
  weights <- log(nrow(x) / pmax(colSums(x > 0), 1))
  w <- sweep(x, 2, weights, `*`)
  norms <- sqrt(rowSums(w^2))
  norms[norms == 0] <- 1
  similarity <- tcrossprod(w / norms)
  stats::as.dist(1 - pmin(pmax(similarity, -1), 1))
}

#' @noRd
bray_curtis_distance <- function(x) {
  difference <- as.matrix(stats::dist(x, method = "manhattan"))
  total <- outer(rowSums(x), rowSums(x), `+`)
  d <- difference / total
  d[total == 0] <- 1
  stats::as.dist(d)
}

#' Principal components of district compositions
#'
#' `composition_pca()` removes columns with zero variance. It then centers each
#' column and scales it to unit variance. `pca_variance()` gives the variance
#' that each component explains. `pca_scores()` gives the component scores for
#' each district.
#'
#' @param x A matrix from [composition_matrix()].
#' @param pca A result of `composition_pca()`.
#' @return `composition_pca()` returns a `prcomp` object. `pca_variance()`
#'   returns a tibble with `PC`, `variance` and `cumulative`. `pca_scores()`
#'   returns a tibble with `state_name_harmonized`, `district`, `PC1` and `PC2`.
#' @examples
#' m <- composition_matrix(census_2011_tribes, "tribe_name_original", "population")
#' pca <- composition_pca(m)
#' head(pca_variance(pca))
#' head(pca_scores(pca))
#' @export
composition_pca <- function(x) {
  keep <- apply(x, 2, stats::var) > 0
  stats::prcomp(x[, keep, drop = FALSE], center = TRUE, scale. = TRUE)
}

#' @rdname composition_pca
#' @export
pca_variance <- function(pca) {
  variance <- pca$sdev^2 / sum(pca$sdev^2)
  tibble::tibble(
    PC = seq_along(variance), variance = variance, cumulative = cumsum(variance)
  )
}

#' @rdname composition_pca
#' @export
pca_scores <- function(pca) {
  tibble::add_column(
    composition_units(rownames(pca$x)),
    PC1 = pca$x[, 1], PC2 = pca$x[, 2]
  )
}

#' @noRd
composition_units <- function(units) {
  tibble::tibble(
    state_name_harmonized = sub("[|].*", "", units),
    district = sub(".*[|]", "", units)
  )
}

#' Cluster districts by composition
#'
#' Uses Ward hierarchical clustering. With `method = "pca"`, the function
#' clusters on the principal components that give the fraction `variance` of
#' the total variance.
#'
#' @param x A matrix from [composition_matrix()].
#' @param k Number of clusters.
#' @param method A method of [composition_distance()], or `"pca"`.
#' @param variance Fraction of variance to keep with `method = "pca"`.
#' @return A tibble with `state_name_harmonized`, `district` and `cluster`.
#'   You can use the tibble with [attach_geometry()].
#' @examples
#' m <- composition_matrix(census_2011_tribes, "tribe_name_original", "population")
#' head(composition_clusters(m, 5, "jaccard"))
#' @export
composition_clusters <- function(x, k,
                                 method = c("hellinger", "tfidf", "jaccard", "bray_curtis", "pca"),
                                 variance = 0.9) {
  method <- match.arg(method)
  d <- if (method == "pca") {
    pca <- composition_pca(x)
    n <- sum(pca_variance(pca)$cumulative < variance) + 1
    stats::dist(pca$x[, seq_len(n), drop = FALSE])
  } else {
    composition_distance(x, method)
  }
  clusters <- stats::cutree(stats::hclust(d, method = "ward.D2"), k = k)
  tibble::add_column(composition_units(rownames(x)), cluster = factor(clusters))
}

#' Adjusted Rand index
#'
#' Measures the agreement between two clusterings of the same units. The value
#' is 1 for full agreement and near 0 for random agreement.
#'
#' @param x,y Cluster labels, of equal length.
#' @return A number.
#' @examples
#' adjusted_rand_index(c(1, 1, 2, 2), c("a", "a", "b", "b"))
#' @export
adjusted_rand_index <- function(x, y) {
  tab <- table(x, y)
  pairs <- sum(choose(tab, 2))
  rows <- sum(choose(rowSums(tab), 2))
  columns <- sum(choose(colSums(tab), 2))
  expected <- rows * columns / choose(sum(tab), 2)
  maximum <- (rows + columns) / 2
  if (maximum == expected) {
    return(1)
  }
  (pairs - expected) / (maximum - expected)
}
