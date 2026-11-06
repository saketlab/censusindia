#' Plot functions for census data
#'
#' @description
#' Choropleth maps and comparison plots of census data.
#'
#' @name plotting
NULL

#' Create a choropleth map from census data
#'
#' @param data An `sf` object, or a data frame with geometry from
#'   \code{\link{attach_geometry}}.
#' @param fill_var Variable for the fill color (unquoted column name or string).
#'   A numeric variable gets a continuous scale. Other variables get a discrete
#'   scale, and `palette` has no effect.
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
#'     \item \code{"inferno"} - Sequential black to yellow, for `dark = TRUE`
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
#' @param na_color Color for missing values. Default `"grey80"`, or `"black"` if
#'   `dark = TRUE`.
#' @param state Optional state names. The map shows only these states. The
#'   column `state_name_harmonized` of `data` must have these names.
#' @param facet Optional name of a column. The map has one panel for each value
#'   of this column. Use `base_layer = FALSE` if the panels have different
#'   boundary years.
#' @param dark Logical. If `TRUE`, the map has a black background and white text.
#'   Use it with `palette = "inferno"`, so that high values are bright. See
#'   [theme_census_map()] for the device background.
#' @param unit_boundary_color Color of the lines around each unit of `data`. The
#'   default `NA` draws no lines.
#' @param unit_boundary_width Width of the lines around each unit of `data`.
#' @param show_state_boundaries Logical. If `TRUE`, overlays state boundary lines
#'   on top of the data.
#' @param state_boundary_color Color for state boundary lines. Default `"black"`,
#'   or `"grey35"` if `dark = TRUE`.
#' @param state_boundary_width Width of state boundary lines. Default `0.3`.
#' @param trans Transformation for the color scale (e.g., `"log10"`, `"sqrt"`).
#'   Default `"identity"`.
#' @param midpoint Center value for a diverging palette (e.g., `0` for growth or
#'   `1000` for sex ratio). If `NULL`, defaults to the midpoint of `limits`.
#' @param oob Out-of-bounds handler for values outside `limits`. By default,
#'   ggplot2 maps out-of-bounds values to `na_color`. You cannot then distinguish
#'   them from missing data. Use `scales::squish` to clamp them to the nearest
#'   limit.
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
#'   dplyr::mutate(st_pct = share(st_population, population)) |>
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
                     na_color = if (dark) "black" else "grey80",
                     boundary_year = NULL,
                     base_layer = TRUE,
                     show_state_boundaries = FALSE,
                     state_boundary_color = if (dark) "grey35" else "black",
                     state_boundary_width = 0.3,
                     trans = "identity",
                     midpoint = NULL,
                     oob = NULL,
                     limits = NULL,
                     breaks = NULL,
                     labels = NULL,
                     font_family = NULL,
                     legend_position = "right",
                     state = NULL,
                     facet = NULL,
                     dark = FALSE,
                     unit_boundary_color = NA,
                     unit_boundary_width = 0.1) {
  # substitute() before fill_var is evaluated, or plot_map(d, value) fails
  fill_var_name <- resolve_fill_var(substitute(fill_var), names(data), function() fill_var, parent.frame())
  data <- as_map_data(data, fill_var_name)

  if (is.null(legend_title)) {
    legend_title <- fill_var_name
  }

  if (!is.null(direction)) {
    reverse <- (direction == -1)
  }

  colors <- get_palette(palette, reverse)

  base_sf <- if (base_layer) {
    census_base_shapes(boundary_year %||% detect_year(data))
  }

  if (!is.null(state)) {
    data <- filter_by_state(data, state)
    if (!is.null(base_sf)) {
      # a successor state draws the outline of its parent
      outline <- remap_successor_states(data$state_name_harmonized, base_sf$year[1])
      base_sf <- base_sf[base_sf$state_name_harmonized %in% outline, ]
    }
  }

  p <- ggplot2::ggplot()

  # base layer keeps India's full northern extent
  if (!is.null(base_sf)) {
    p <- p + ggplot2::geom_sf(data = base_sf, fill = na_color, color = NA)
  }

  p <- p + ggplot2::geom_sf(
    data = data,
    ggplot2::aes(fill = .data[[fill_var_name]]),
    color = unit_boundary_color,
    linewidth = unit_boundary_width
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

  p <- p + if (is.numeric(data[[fill_var_name]])) {
    do.call(ggplot2::scale_fill_gradientn, scale_args)
  } else {
    ggplot2::scale_fill_hue(na.value = na_color, name = legend_title)
  }

  if (!is.null(title) || !is.null(subtitle)) {
    p <- p + ggplot2::labs(title = title, subtitle = subtitle)
  }

  p <- p + theme_census_map(dark = dark) +
    ggplot2::theme(
      text = ggplot2::element_text(family = font_family),
      legend.position = legend_position,
      legend.title = ggplot2::element_text(size = 9),
      legend.text = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(5, 5, 5, 5)
    )

  if (!is.null(facet)) {
    p <- p + ggplot2::facet_wrap(facet, nrow = 2) +
      ggplot2::theme(strip.text = ggplot2::element_text(face = "bold"))
  }
  p
}

#' Bubble map with one dot for each unit
#'
#' `plot_bubble_map()` makes a map with one dot for each unit. The dot size shows
#' one column, and the dot color can show a second column.
#' `census_bubble_layer()` gives only the dots, so that you can add them to
#' [plot_map()].
#'
#' The dot area is proportional to `size`. Each dot is on the surface of its
#' unit.
#'
#' @param data An `sf` object of polygons, or a data frame with geometry from
#'   [attach_geometry()].
#' @param size Name of the column for the dot size.
#' @param color Optional name of the column for the dot color.
#' @param ... Arguments for [ggplot2::scale_color_gradientn()], for example
#'   `trans`, `limits`, `breaks` and `labels`. Use these only with `color`.
#' @param title,subtitle Optional text for the map.
#' @param palette Palette for `color`. See [get_palette()]. The first two colors
#'   are not used.
#' @param max_size Size of the largest dot.
#' @param size_breaks Optional breaks for the size legend.
#' @param size_title Title of the size legend.
#' @param color_title Title of the color legend.
#' @param dot_color For `census_bubble_layer()`: dot color if `color` is `NULL`.
#' @param alpha For `census_bubble_layer()`: dot opacity.
#' @param boundary_year Census year of the state outline. If `NULL`, the function
#'   finds the year from `data`.
#' @param dark Logical. If `TRUE`, the map has a black background and white text.
#'   See [theme_census_map()] for the device background.
#'
#' @return `plot_bubble_map()` gives a `ggplot2` object. `census_bubble_layer()`
#'   gives a list of `ggplot2` layers.
#' @seealso [plot_dot_density_map()]
#' @examplesIf interactive()
#' districts <- census_2011_pca |>
#'   dplyr::mutate(millions = population / 1e6) |>
#'   attach_geometry(2011)
#' plot_bubble_map(districts, "millions", size_title = "People, millions")
#' plot_map(districts, "literate") + census_bubble_layer(districts, "millions")
#' @export
plot_bubble_map <- function(data,
                            size,
                            color = NULL,
                            ...,
                            title = NULL,
                            subtitle = NULL,
                            palette = "oranges",
                            max_size = 5,
                            size_breaks = ggplot2::waiver(),
                            size_title = NULL,
                            color_title = NULL,
                            dark = FALSE,
                            boundary_year = NULL) {
  data <- as_map_data(data, c(size, color))
  if (is.null(color)) rlang::check_dots_empty()
  p <- ggplot2::ggplot() +
    dot_base_layer(boundary_year %||% detect_year(data), dark) +
    census_bubble_layer(
      data, size, color,
      max_size = max_size, size_breaks = size_breaks, size_title = size_title
    )
  rm(data) # the plot keeps this frame
  if (!is.null(color)) p <- p + dot_color_scale(palette, color, color_title, ...)
  p + ggplot2::labs(title = title, subtitle = subtitle) + theme_census_map(dark = dark)
}

#' @rdname plot_bubble_map
#' @export
census_bubble_layer <- function(data,
                                size,
                                color = NULL,
                                max_size = 5,
                                size_breaks = ggplot2::waiver(),
                                size_title = NULL,
                                dot_color = census_colors()[["accent"]],
                                alpha = 0.8) {
  data <- as_map_data(data, c(size, color))
  # reassigned: aes() keeps this frame
  data <- suppressWarnings(sf::st_point_on_surface(data))
  # small dots on top
  data <- data[order(data[[size]], decreasing = TRUE), ]
  list(
    if (is.null(color)) {
      ggplot2::geom_sf(
        data = data, ggplot2::aes(size = .data[[size]]),
        color = dot_color, alpha = alpha, shape = 16
      )
    } else {
      ggplot2::geom_sf(
        data = data, ggplot2::aes(size = .data[[size]], color = .data[[color]]),
        alpha = alpha, shape = 16
      )
    },
    ggplot2::scale_size_area(
      max_size = max_size, breaks = size_breaks,
      name = size_title %||% size
    )
  )
}

#' Dot density map of a count
#'
#' Each dot shows `per_dot` units of `value`. The function puts each dot at a
#' random position in its unit, so one dot does not show a real location. Use
#' [set.seed()] to get the same map again.
#'
#' @inheritParams plot_bubble_map
#' @param value Name of the column with the count.
#' @param per_dot Count that one dot shows.
#' @param color Optional name of a column. Each dot gets the color of its unit,
#'   and dots with high values are on top.
#' @param dot_color Dot color if `color` is `NULL`.
#' @param dot_size Dot size.
#'
#' @return A `ggplot2` object.
#' @seealso [plot_bubble_map()]
#' @examplesIf interactive()
#' census_2011_pca |>
#'   attach_geometry(2011) |>
#'   plot_dot_density_map("population")
#' @export
plot_dot_density_map <- function(data,
                                 value,
                                 per_dot = 1e5,
                                 color = NULL,
                                 ...,
                                 title = NULL,
                                 subtitle = NULL,
                                 palette = "inferno",
                                 color_title = NULL,
                                 dot_color = get_palette("oranges")[[8]],
                                 dot_size = 0.6,
                                 dark = FALSE,
                                 boundary_year = NULL) {
  data <- as_map_data(data, c(value, color))
  if (is.null(color)) rlang::check_dots_empty()
  n <- round(data[[value]] / per_dot)
  n[is.na(n)] <- 0
  drawn <- n > 0
  # st_sample() can give a stray point for size 0
  # no CRS: faster, dots uniform in degrees
  # rep() below relies on st_sample() keeping unit order
  points <- sf::st_sample(sf::st_set_crs(sf::st_geometry(data)[drawn], NA), size = n[drawn])
  dots <- sf::st_sf(geometry = sf::st_set_crs(points, sf::st_crs(data)))
  if (!is.null(color)) dots$dot_value <- rep(data[[color]][drawn], n[drawn])
  p <- ggplot2::ggplot() +
    dot_base_layer(boundary_year %||% detect_year(data), dark)
  rm(data) # the plot keeps this frame
  if (is.null(color)) {
    p <- p + ggplot2::geom_sf(data = dots, size = dot_size, shape = 16, stroke = 0, color = dot_color)
  } else {
    p <- p +
      ggplot2::geom_sf(
        data = dots[order(dots$dot_value), ], ggplot2::aes(color = .data$dot_value),
        size = dot_size, shape = 16, stroke = 0
      ) +
      dot_color_scale(palette, color, color_title, ...)
  }
  p + ggplot2::labs(title = title, subtitle = subtitle) + theme_census_map(dark = dark)
}

#' Area in square kilometres
#'
#' @param x An `sf` object or a geometry column.
#' @return Numeric vector, one value for each feature.
#' @examples
#' square <- sf::st_sfc(
#'   sf::st_polygon(list(rbind(c(0, 0), c(1000, 0), c(1000, 1000), c(0, 1000), c(0, 0)))),
#'   crs = 32643
#' )
#' area_km2(square)
#' @export
area_km2 <- function(x) as.numeric(sf::st_area(x)) / 1e6

#' Compare maps across years
#'
#' @param data_list A named list of `sf` data frames, keyed by year or panel
#'   label.
#' @param fill_var Variable to map (unquoted column name or string).
#' @param title Title for the combined plot.
#' @param ncol Number of columns in the layout.
#' @param palette Color palette. Refer to \code{\link{plot_map}} for options.
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
#'   mutate(st_pct = share(st_population, population)) |>
#'   attach_geometry(1971)
#'
#' st_2011 <- census_2011_pca |>
#'   mutate(st_pct = share(st_population, population)) |>
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
#' "blue_red", "greens", "oranges", "reds", "blues", "purple_green" and
#' "inferno".
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
    ),
    inferno = c(
      "#000004", "#1B0C42", "#4B0C6B", "#781C6D", "#A52C60",
      "#CF4446", "#ED6925", "#FB9A06", "#F7D03C", "#FCFFA4"
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

#' @noRd
as_map_data <- function(data, cols) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg ggplot2} is required.")
  }
  if (!inherits(data, "sf")) {
    if (!"geometry" %in% names(data)) {
      cli::cli_abort("{.arg data} must be an {.cls sf} object or have a {.field geometry} column.")
    }
    data <- sf::st_as_sf(data)
  }
  missing_cols <- setdiff(cols, names(data))
  if (length(missing_cols)) {
    cli::cli_abort("{.val {missing_cols}} {?is/are} not {?a column/columns} of {.arg data}.")
  }
  data
}

#' @noRd
dot_base_layer <- function(year, dark) {
  ggplot2::geom_sf(
    data = census_base_shapes(year), fill = if (dark) "black" else "grey96",
    color = if (dark) "grey35" else "grey75", linewidth = 0.2
  )
}

#' the palette start is too pale or too dark for dots
#' @noRd
dot_color_scale <- function(palette, color, color_title, ...) {
  ggplot2::scale_color_gradientn(
    colors = get_palette(palette)[-(1:2)],
    name = color_title %||% color,
    ...
  )
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
