#' Base layer carrying India's full claimed extent
#'
#' A `ggplot2` layer of the state polygons for a census year, drawn as flat
#' fill. Put it under a district choropleth so the national outline stays whole:
#' the census enumerates no districts in the territory India claims but does not
#' administer, so a district layer alone truncates the north by roughly two
#' degrees of latitude.
#'
#' [plot_map()] adds this automatically. Use it directly when hand-rolling a map
#' with [ggplot2::geom_sf()].
#'
#' @param year Census year whose boundaries to draw. One of 1941, 1951, 1961,
#'   1971, 1981, 1991, 2001, 2011.
#' @param fill Fill colour for the base. Defaults to the grey [plot_map()] uses
#'   for missing values.
#' @param ... Passed to [ggplot2::geom_sf()].
#'
#' @return A `ggplot2` layer.
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

#' Shared theme for censusindia figures
#'
#' `theme_census()` for plots with axes, `theme_census_map()` for choropleths.
#'
#' @param base_size Base font size in points.
#' @return A `ggplot2` theme.
#' @export
theme_census <- function(base_size = 11) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required.")
  }
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        face = "bold", size = ggplot2::rel(1.15), colour = "#1c1c1c"
      ),
      plot.subtitle = ggplot2::element_text(
        colour = "#6b6b6b", margin = ggplot2::margin(b = 10)
      ),
      plot.caption = ggplot2::element_text(
        colour = "#6b6b6b", size = ggplot2::rel(0.8), hjust = 0
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      axis.title = ggplot2::element_text(colour = "#6b6b6b", size = ggplot2::rel(0.9)),
      axis.text = ggplot2::element_text(colour = "#6b6b6b"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "grey92", linewidth = 0.3),
      strip.text = ggplot2::element_text(
        face = "bold", size = ggplot2::rel(0.8), colour = "#1c1c1c"
      ),
      legend.position = "bottom",
      legend.key.height = ggplot2::unit(0.35, "cm")
    )
}

#' @rdname theme_census
#' @export
theme_census_map <- function(base_size = 11) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required.")
  }
  ggplot2::theme_void(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", colour = "#1c1c1c"),
      plot.subtitle = ggplot2::element_text(
        colour = "#6b6b6b", margin = ggplot2::margin(b = 8)
      ),
      plot.caption = ggplot2::element_text(
        colour = "#6b6b6b", size = ggplot2::rel(0.8), hjust = 0
      ),
      plot.title.position = "plot",
      legend.position = "right",
      legend.key.width = ggplot2::unit(0.4, "cm")
    )
}

#' Sex ratio
#'
#' Females per 1,000 males, the convention the Census of India reports.
#'
#' @param females,males Counts, of equal length.
#' @return Numeric vector.
#' @export
sex_ratio <- function(females, males) {
  1000 * females / males
}

#' Share of a total, as a percentage
#'
#' @param part,whole Counts, of equal length.
#' @return Numeric vector.
#' @export
share <- function(part, whole) {
  100 * part / whole
}
