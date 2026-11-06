#' Base layer with the full claimed extent of India
#'
#' A `ggplot2` layer of the state polygons for a census year, with a flat fill.
#' Put it below a district choropleth to keep the national outline complete.
#' The census has no districts in the territory that India claims but does not
#' administer.
#'
#' [plot_map()] adds this layer automatically. Use it directly when you make a
#' map with [ggplot2::geom_sf()].
#'
#' @param year Census year of the boundaries. One of 1941, 1951, 1961, 1971,
#'   1981, 1991, 2001, 2011.
#' @param fill Fill color for the base layer. The default is the grey that
#'   [plot_map()] uses for missing values.
#' @param ... Arguments for [ggplot2::geom_sf()].
#'
#' @return A `ggplot2` layer.
#' @examplesIf interactive() && requireNamespace("ggplot2", quietly = TRUE)
#' ggplot2::ggplot() +
#'   census_base_layer(2011)
#' @export
census_base_layer <- function(year, fill = "grey80", ...) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required.")
  }
  ggplot2::geom_sf(
    data = get_census_boundaries(year, "state"),
    fill = fill, colour = NA, ...
  )
}

#' Colors of censusindia figures
#'
#' The colors that [theme_census()] and [theme_census_map()] use, and the accent
#' and diverging colors for figures.
#'
#' @return A named character vector: `ink`, `ink_muted`, `accent`, `low`, `mid`
#'   and `high`.
#' @examples
#' census_colors()[["accent"]]
#' @export
census_colors <- function() {
  c(
    ink = "#1c1c1c", ink_muted = "#6b6b6b", accent = get_palette("blues")[[8]],
    low = get_palette("blue_red")[[2]], mid = "grey92",
    high = get_palette("blue_red")[[10]]
  )
}

#' Shared theme for censusindia figures
#'
#' `theme_census()` is for plots with axes. `theme_census_map()` is for
#' choropleths.
#'
#' @param base_size Base font size in points.
#' @param dark Logical. If `TRUE`, the map has a black background and white text.
#'   A map with a fixed aspect ratio does not fill the full image.
#'   [ggplot2::ggsave()] fills the remaining area. With [grDevices::png()] or
#'   knitr, set the device background to black, for example `png(bg = "black")`.
#' @return A `ggplot2` theme.
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' ggplot2::ggplot(census_2011_pca, ggplot2::aes(literate, population)) +
#'   ggplot2::geom_point() +
#'   theme_census()
#' @export
theme_census <- function(base_size = 11) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required.")
  }
  col <- census_colors()
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold", size = ggplot2::rel(1.15), colour = col[["ink"]]
      ),
      plot.subtitle = ggplot2::element_text(
        colour = col[["ink_muted"]], margin = ggplot2::margin(b = 10)
      ),
      plot.caption = ggplot2::element_text(
        colour = col[["ink_muted"]], size = ggplot2::rel(0.8), hjust = 0
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.title = ggplot2::element_text(colour = col[["ink_muted"]], size = ggplot2::rel(0.9)),
      axis.text = ggplot2::element_text(colour = col[["ink_muted"]]),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "grey92", linewidth = 0.3),
      strip.text = ggplot2::element_text(
        face = "bold", size = ggplot2::rel(0.8), colour = col[["ink"]]
      ),
      legend.position = "bottom",
      legend.key.height = ggplot2::unit(0.35, "cm")
    )
}

#' @rdname theme_census
#' @export
theme_census_map <- function(base_size = 11, dark = FALSE) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required.")
  }
  col <- census_colors()
  ink <- if (dark) "white" else col[["ink"]]
  ink_muted <- if (dark) "white" else col[["ink_muted"]]
  theme <- ggplot2::theme_void(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", colour = ink),
      plot.subtitle = ggplot2::element_text(
        colour = ink_muted, margin = ggplot2::margin(b = 8)
      ),
      plot.caption = ggplot2::element_text(
        colour = ink_muted, size = ggplot2::rel(0.8), hjust = 0
      ),
      plot.title.position = "plot",
      legend.position = "right",
      legend.key.width = ggplot2::unit(0.4, "cm")
    )
  if (!dark) {
    return(theme)
  }
  theme + ggplot2::theme(
    text = ggplot2::element_text(colour = "white"),
    plot.background = ggplot2::element_rect(fill = "black", colour = NA)
  )
}

#' Sex ratio
#'
#' Females per 1,000 males. The Census of India uses this convention.
#'
#' @param females,males Counts, of equal length.
#' @return Numeric vector.
#' @examples
#' sex_ratio(census_2011_pca$females, census_2011_pca$males) |> head()
#' @export
sex_ratio <- function(females, males) {
  1000 * females / males
}

#' Percentage change
#'
#' @param new,old Values, of equal length.
#' @return Numeric vector.
#' @examples
#' percent_change(121, 100)
#' @export
percent_change <- function(new, old) {
  100 * (new / old - 1)
}

#' Share of a total, as a percentage
#'
#' @param part,whole Counts, of equal length.
#' @return Numeric vector.
#' @examples
#' share(census_2011_pca$literate, census_2011_pca$population) |> head()
#' @export
share <- function(part, whole) {
  100 * part / whole
}
