#' Plotting functions for census data
#'
#' @description
#' Choropleth maps and comparison plots of census data.
#'
#' @name plotting
NULL

#' Create a choropleth map from census data.
#'
#' @param data An `sf` object, or a data frame with geometry from
#'   \code{\link{attach_geometry}}.
#' @param fill_var Variable for the fill color (unquoted column name or string).
#' @param title Optional title for the map.
#' @param subtitle Optional subtitle for the map.
#' @param legend_title Title for the legend.
#' @param palette Color palette. Available options:
#'   \itemize{
#'     \item \code{"viridis"} - Perceptually uniform and colorblind-safe (default)
#'     \item \code{"red_blue"} - Diverging red to blue (red = high)
#'     \item \code{"blue_red"} - Diverging blue to red (blue = high)
#'     \item \code{"greens"} - Sequential green palette
#'     \item \code{"oranges"} - Sequential orange palette
#'     \item \code{"reds"} - Sequential red palette
#'     \item \code{"blues"} - Sequential blue palette
#'     \item \code{"purple_green"} - Diverging purple to green
#'   }
#' @param reverse Logical. If `TRUE`, reverses the palette direction. Default
#'   `FALSE`.
#' @param direction Numeric. Alternative to `reverse`: `-1` reverses the palette
#'   and `1` keeps the default. Takes precedence over `reverse` if both are set.
#' @param boundary_year Census year of the state outline drawn beneath the data.
#'   This background layer preserves India's full claimed northern extent where
#'   district polygons are absent. If `NULL`, inferred from `data`.
#' @param base_layer Logical. If `TRUE` (default), draws the full state outline
#'   of India beneath the data.
#' @param na_color Color for missing values. Default `"grey80"`.
#' @param show_state_boundaries Logical. If `TRUE`, overlays state boundary lines
#'   on top of the data.
#' @param state_boundary_color Color for state boundary lines. Default `"black"`.
#' @param state_boundary_width Width of state boundary lines. Default `0.3`.
#' @param trans Transformation for the color scale (e.g., `"log10"`, `"sqrt"`).
#'   Default `"identity"`.
#' @param midpoint Center value for a diverging palette (e.g., `0` for growth or
#'   `1000` for sex ratio). If `NULL`, defaults to the midpoint of `limits`.
#' @param oob Out-of-bounds handler for values outside `limits`. By default
#'   ggplot2 maps out-of-bounds values to `na_color`, making them
#'   indistinguishable from missing data; pass `scales::squish` to clamp them to
#'   the nearest limit instead.
#' @param limits Optional numeric vector `c(min, max)` for the color scale.
#' @param breaks Optional breaks for the legend.
#' @param labels Optional labels for the legend breaks.
#' @param font_family Font family for all map text (e.g., `"Arial"`). Default
#'   `NULL` uses the system font.
#' @param legend_position One of `"right"` (default), `"left"`, `"bottom"`,
#'   `"top"`, or `"none"`. `"bottom"` and `"top"` orient the colorbar
#'   horizontally.
#'
#' @return A `ggplot2` object.
#'
#' @examplesIf interactive()
#' # Calculate ST percentage and attach geometry
#' st_data <- census_2011_pca |>
#'   dplyr::mutate(st_pct = 100 * st_population / population) |>
#'   attach_geometry(2011)
#'
#' # Create a basic map
#' plot_map(st_data, st_pct, title = "ST Population %")
#'
#' # With red-blue palette and state boundaries
#' plot_map(st_data, st_pct,
#'   title = "ST Population % (2011)",
#'   palette = "red_blue",
#'   show_state_boundaries = TRUE
#' )
#'
#' @export
plot_map <- function(data,
                     fill_var,
                     title = NULL,
                     subtitle = NULL,
                     legend_title = NULL,
                     palette = "viridis",
                     reverse = FALSE,
                     direction = NULL,
                     na_color = "grey80",
                     boundary_year = NULL,
                     base_layer = TRUE,
                     show_state_boundaries = FALSE,
                     state_boundary_color = "black",
                     state_boundary_width = 0.3,
                     trans = "identity",
                     midpoint = NULL,
                     oob = NULL,
                     limits = NULL,
                     breaks = NULL,
                     labels = NULL,
                     font_family = NULL,
                     legend_position = "right") {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required.")
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg sf} is required.")
  }

  if (!inherits(data, "sf")) {
    if ("geometry" %in% names(data)) {
      data <- sf::st_as_sf(data)
    } else {
      cli::cli_abort("{.arg data} must be an {.cls sf} object or have a {.field geometry} column.")
    }
  }

  # substitute() before fill_var is evaluated, or plot_map(d, value) fails
  fill_var_name <- resolve_fill_var(substitute(fill_var), names(data), function() fill_var, parent.frame())

  if (!fill_var_name %in% names(data)) {
    cli::cli_abort("{.arg fill_var} {.val {fill_var_name}} is not a column of {.arg data}.")
  }

  if (is.null(legend_title)) {
    legend_title <- fill_var_name
  }

  if (!is.null(direction)) {
    reverse <- (direction == -1)
  }

  colors <- get_palette(palette, reverse)

  base_sf <- if (base_layer) {
    census_base_shapes(
      if (is.null(boundary_year)) detect_year(data) else boundary_year
    )
  }

  p <- ggplot2::ggplot()

  # base layer keeps India's full northern extent
  if (!is.null(base_sf)) {
    p <- p + ggplot2::geom_sf(data = base_sf, fill = na_color, color = NA)
  }

  p <- p + ggplot2::geom_sf(
    data = data,
    ggplot2::aes(fill = .data[[fill_var_name]]),
    color = NA
  )

  if (show_state_boundaries && is.null(base_sf)) {
    cli::cli_warn(c(
      "{.arg show_state_boundaries} has no effect with {.code base_layer = FALSE}.",
      "i" = "The boundary overlay is drawn from the same base layer that {.arg base_layer} disables."
    ))
  }
  if (show_state_boundaries && !is.null(base_sf)) {
    p <- p + ggplot2::geom_sf(
      data = base_sf,
      fill = NA,
      color = state_boundary_color,
      linewidth = state_boundary_width
    )
  }

  scale_args <- list(
    colors = colors,
    na.value = na_color,
    name = legend_title,
    trans = trans
  )

  if (!is.null(midpoint)) {
    scale_args$rescaler <- function(x, to = c(0, 1), from = range(x, na.rm = TRUE)) {
      scales::rescale_mid(x, to, from, mid = midpoint)
    }
  }
  if (!is.null(oob)) scale_args$oob <- oob
  if (!is.null(limits)) scale_args$limits <- limits
  if (!is.null(breaks)) scale_args$breaks <- breaks
  if (!is.null(labels)) scale_args$labels <- labels

  bar_size <- if (legend_position %in% c("bottom", "top")) c(6, 0.4) else c(0.4, 4)
  scale_args$guide <- ggplot2::guide_colorbar(
    barwidth = ggplot2::unit(bar_size[1], "cm"),
    barheight = ggplot2::unit(bar_size[2], "cm")
  )

  p <- p + do.call(ggplot2::scale_fill_gradientn, scale_args)

  if (!is.null(title) || !is.null(subtitle)) {
    p <- p + ggplot2::labs(title = title, subtitle = subtitle)
  }

  p <- p + ggplot2::theme_void(base_family = if (is.null(font_family)) "" else font_family) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, size = 12, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5, size = 10),
      legend.position = legend_position,
      legend.title = ggplot2::element_text(size = 9),
      legend.text = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(5, 5, 5, 5)
    )

  p
}

#' Compare maps across years
#'
#' @param data_list A named list of `sf` data frames, keyed by year or panel
#'   label.
#' @param fill_var Variable to map (unquoted column name or string).
#' @param title Title for the combined plot.
#' @param ncol Number of columns in the layout.
#' @param palette Color palette; see \code{\link{plot_map}} for options.
#' @param common_scale Logical. If `TRUE` (default), all panels share the same
#'   color scale limits.
#' @param limits Optional numeric vector `c(min, max)` for the shared color
#'   scale. Overrides the range computed when `common_scale = TRUE`.
#' @param show_state_boundaries Logical. If `TRUE` (default), overlays state
#'   boundaries on each panel.
#' @param ... Additional arguments passed to \code{\link{plot_map}}.
#'
#' @return A `patchwork` object.
#'
#' @examplesIf interactive()
#' # Compare ST percentage across years
#' library(dplyr)
#'
#' st_1971 <- census_1971 |>
#'   filter(geography == "district", sector == "total") |>
#'   mutate(st_pct = 100 * st_population / population) |>
#'   attach_geometry(1971)
#'
#' st_2011 <- census_2011_pca |>
#'   mutate(st_pct = 100 * st_population / population) |>
#'   attach_geometry(2011)
#'
#' # Compare
#' compare_maps(
#'   list("1971" = st_1971, "2011" = st_2011),
#'   fill_var = "st_pct",
#'   title = "ST Population % by District",
#'   palette = "red_blue"
#' )
#'
#' @export
compare_maps <- function(data_list,
                         fill_var,
                         title = NULL,
                         ncol = NULL,
                         palette = "viridis",
                         common_scale = TRUE,
                         limits = NULL,
                         show_state_boundaries = TRUE,
                         ...) {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg patchwork} is required.")
  }

  first_cols <- if (length(data_list)) names(data_list[[1]]) else character()
  fill_var_name <- resolve_fill_var(substitute(fill_var), first_cols, function() fill_var, parent.frame())

  if (is.null(limits) && common_scale) {
    all_values <- unlist(lapply(data_list, function(d) d[[fill_var_name]]))
    limits <- range(all_values, na.rm = TRUE)
  }

  plots <- vector("list", length(data_list))
  names(plots) <- names(data_list)

  for (i in seq_along(data_list)) {
    year_label <- names(data_list)[i]
    plots[[i]] <- plot_map(
      data_list[[i]],
      fill_var = fill_var_name,
      title = year_label,
      palette = palette,
      limits = limits,
      show_state_boundaries = show_state_boundaries,
      ...
    )
  }

  if (is.null(ncol)) {
    ncol <- min(length(plots), 3)
  }

  combined <- patchwork::wrap_plots(plots, ncol = ncol) +
    patchwork::plot_layout(guides = "collect")

  if (!is.null(title)) {
    combined <- combined +
      patchwork::plot_annotation(
        title = title,
        theme = ggplot2::theme(
          plot.title = ggplot2::element_text(
            hjust = 0.5,
            size = 14,
            face = "bold"
          )
        )
      )
  }

  combined
}

#' Get color palette
#'
#' Gives a color palette for maps. The palettes are "viridis", "red_blue",
#' "blue_red", "greens", "oranges", "reds", "blues" and "purple_green".
#'
#' @param name Name of the palette
#' @param reverse Logical. If TRUE, the direction is reversed.
#'
#' @return A character vector of colors
#' @examples
#' get_palette("blues")
#' get_palette("red_blue", reverse = TRUE)
#' @export
get_palette <- function(name, reverse = FALSE) {
  palettes <- list(
    red_blue = c(
      "#67001F", "#B2182B", "#D6604D", "#F4A582", "#FDDBC7",
      "#F7F7F7", "#D1E5F0", "#92C5DE", "#4393C3", "#2166AC", "#053061"
    ),
    blue_red = c(
      "#053061", "#2166AC", "#4393C3", "#92C5DE", "#D1E5F0",
      "#F7F7F7", "#FDDBC7", "#F4A582", "#D6604D", "#B2182B", "#67001F"
    ),
    greens = c(
      "#F7FCF5", "#E5F5E0", "#C7E9C0", "#A1D99B", "#74C476",
      "#41AB5D", "#238B45", "#006D2C", "#00441B"
    ),
    oranges = c(
      "#FFF5EB", "#FEE6CE", "#FDD0A2", "#FDAE6B", "#FD8D3C",
      "#F16913", "#D94801", "#A63603", "#7F2704"
    ),
    reds = c(
      "#FFF5F0", "#FEE0D2", "#FCBBA1", "#FC9272", "#FB6A4A",
      "#EF3B2C", "#CB181D", "#A50F15", "#67000D"
    ),
    blues = c(
      "#F7FBFF", "#DEEBF7", "#C6DBEF", "#9ECAE1", "#6BAED6",
      "#4292C6", "#2171B5", "#08519C", "#08306B"
    ),
    purple_green = c(
      "#40004B", "#762A83", "#9970AB", "#C2A5CF", "#E7D4E8",
      "#F7F7F7", "#D9F0D3", "#A6DBA0", "#5AAE61", "#1B7837", "#00441B"
    ),
    viridis = c(
      "#440154", "#482878", "#3E4A89", "#31688E", "#26828E",
      "#1F9E89", "#35B779", "#6DCD59", "#B4DE2C", "#FDE725"
    )
  )

  colors <- palettes[[name]]
  if (is.null(colors)) {
    cli::cli_abort(c(
      "Unknown palette {.val {name}}.",
      "i" = "Available: {.val {names(palettes)}}."
    ))
  }

  if (reverse) {
    colors <- rev(colors)
  }

  colors
}

#' Gives the state outline to draw below a map. The outline comes from the
#' requested vintage, or from the nearest vintage with a boundary file. If the
#' year is not known, the function uses the most recent vintage.
#' @noRd
census_base_shapes <- function(year) {
  if (is.null(year) || is.na(year) || !is.numeric(year)) {
    year <- max(BOUNDARY_YEARS)
  }
  get_census_boundaries(nearest_boundary_year(year), "state")
}

#' Finds the boundary year of a data frame.
#'
#' First uses the attribute that attach_geometry() sets, then a `year` column.
#' @param data A data frame or sf object.
#' @return Integer year, or NULL if the data has neither.
#' @noRd
detect_year <- function(data) {
  stamped <- attr(data, "census_boundary_year")
  if (!is.null(stamped) && !is.na(stamped)) {
    return(stamped)
  }
  if ("year" %in% names(data)) {
    y <- unique(data$year)
    y <- suppressWarnings(as.numeric(y[!is.na(y)]))
    if (length(y)) {
      return(max(y))
    }
  }
  NULL
}

# a bare column name, a variable holding a name, a string, or an expression
#' @noRd
resolve_fill_var <- function(expr, cols, value, env) {
  if (is.character(expr)) {
    return(expr)
  }
  if (!is.name(expr)) {
    return(as.character(eval(expr, env)))
  }
  nm <- deparse(expr)
  if (nm %in% cols) {
    return(nm)
  }
  v <- tryCatch(value(), error = function(e) NULL)
  if (is.character(v) && length(v) == 1) v else nm
}
