#' Plotting functions for census data
#'
#' @description
#' Choropleth maps and comparison plots from census data.
#'
#' @name plotting
NULL

#' Create a choropleth map from census data.
#'
#' @param data An sf object or data frame with geometry attached via
#'   \code{\link{attach_geometry}}
#' @param fill_var The variable to map to fill color (unquoted or string)
#' @param title Optional title for the map
#' @param subtitle Optional subtitle for the map
#' @param legend_title Title for the legend
#' @param palette Color palette. Options include:
#'   \itemize{
#'     \item \code{"viridis"} - Perceptually uniform, colorblind-friendly (default)
#'     \item \code{"red_blue"} - Diverging red to blue (red = high)
#'     \item \code{"blue_red"} - Diverging blue to red (blue = high)
#'     \item \code{"greens"} - Sequential green palette
#'     \item \code{"oranges"} - Sequential orange palette
#'     \item \code{"reds"} - Sequential red palette
#'     \item \code{"blues"} - Sequential blue palette
#'     \item \code{"purple_green"} - Diverging purple to green
#'   }
#' @param reverse Logical. Reverse the color palette direction? Default FALSE.
#' @param direction Numeric. Alternative to reverse: use -1 to reverse, 1 for default.
#'   If both reverse and direction are specified, direction takes precedence.
#' @param na_color Color for missing values. Default is "grey80"
#' @param show_state_boundaries Logical. Overlay state boundaries?
#' @param state_boundary_color Color for state boundaries. Default is "black"
#' @param state_boundary_width Width of state boundary lines. Default is 0.3
#' @param trans Transformation for the color scale (e.g., "log10", "sqrt").
#'   Default is "identity" (no transformation)
#' @param limits Optional limits for the color scale as c(min, max)
#' @param breaks Optional breaks for the legend
#' @param labels Optional labels for the legend breaks
#'
#' @return A ggplot2 object
#'
#' @examples
#' \dontrun{
#' # Load 2011 PCA data
#' data(census_2011_pca)
#'
#' # Calculate ST percentage and attach geometry
#' st_data <- census_2011_pca |>
#'   dplyr::mutate(st_pct = 100 * st_population / population_total) |>
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
#' }
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
                     show_state_boundaries = FALSE,
                     state_boundary_color = "black",
                     state_boundary_width = 0.3,
                     trans = "identity",
                     limits = NULL,
                     breaks = NULL,
                     labels = NULL) {
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required. Please install it.")
  }
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package 'sf' is required. Please install it.")
  }

  if (!inherits(data, "sf")) {
    if ("geometry" %in% names(data)) {
      data <- sf::st_as_sf(data)
    } else {
      stop("Data must be an sf object or have a 'geometry' column")
    }
  }

  fill_var_expr <- substitute(fill_var)
  if (is.character(fill_var)) {
    fill_var_name <- fill_var
  } else if (is.name(fill_var_expr)) {
    fill_var_name <- deparse(fill_var_expr)
  } else {
    fill_var_name <- as.character(fill_var_expr)
  }

  if (is.null(legend_title)) {
    legend_title <- fill_var_name
  }

  if (!is.null(direction)) {
    reverse <- (direction == -1)
  }

  colors <- get_palette(palette, reverse)

  p <- ggplot2::ggplot(data) +
    ggplot2::geom_sf(ggplot2::aes(fill = .data[[fill_var_name]]),
      color = NA
    )

  if (show_state_boundaries) {
    year <- detect_year(data)
    if (!is.null(year)) {
      states_sf <- get_census_boundaries(year, "state")
      p <- p + ggplot2::geom_sf(
        data = states_sf,
        fill = NA,
        color = state_boundary_color,
        linewidth = state_boundary_width
      )
    }
  }

  scale_args <- list(
    colors = colors,
    na.value = na_color,
    name = legend_title,
    trans = trans
  )

  if (!is.null(limits)) scale_args$limits <- limits
  if (!is.null(breaks)) scale_args$breaks <- breaks
  if (!is.null(labels)) scale_args$labels <- labels

  p <- p + do.call(ggplot2::scale_fill_gradientn, scale_args)

  if (!is.null(title) || !is.null(subtitle)) {
    p <- p + ggplot2::labs(title = title, subtitle = subtitle)
  }

  p <- p + ggplot2::theme_void() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(hjust = 0.5, size = 12, face = "bold"),
      plot.subtitle = ggplot2::element_text(hjust = 0.5, size = 10),
      legend.position = "right",
      legend.title = ggplot2::element_text(size = 9),
      legend.text = ggplot2::element_text(size = 8),
      plot.margin = ggplot2::margin(5, 5, 5, 5)
    )

  p
}

#' Compare maps across years
#'
#' @param data_list A named list of sf data frames, with names as years
#' @param fill_var The variable to map (string)
#' @param title Overall title for the combined plot
#' @param ncol Number of columns for arrangement
#' @param palette Color palette (see \code{\link{plot_map}} for options)
#' @param common_scale Logical. Use the same color scale across all maps?
#' @param show_state_boundaries Logical. Overlay state boundaries?
#' @param ... Additional arguments passed to \code{\link{plot_map}}
#'
#' @return A patchwork object
#'
#' @examples
#' \dontrun{
#' # Compare ST percentage across years
#' library(dplyr)
#'
#' # Prepare 1971 data
#' data(census_1971)
#' st_1971 <- census_1971 |>
#'   filter(geography == "district") |>
#'   mutate(st_pct = 100 * st_population_total / population_total) |>
#'   attach_geometry(1971)
#'
#' # Prepare 2011 data
#' data(census_2011_pca)
#' st_2011 <- census_2011_pca |>
#'   mutate(st_pct = 100 * st_population / population_total) |>
#'   attach_geometry(2011)
#'
#' # Compare
#' compare_maps(
#'   list("1971" = st_1971, "2011" = st_2011),
#'   fill_var = "st_pct",
#'   title = "ST Population % by District",
#'   palette = "red_blue"
#' )
#' }
#'
#' @export
compare_maps <- function(data_list,
                         fill_var,
                         title = NULL,
                         ncol = NULL,
                         palette = "viridis",
                         common_scale = TRUE,
                         show_state_boundaries = TRUE,
                         ...) {
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("Package 'patchwork' is required. Please install it.")
  }

  if (common_scale) {
    all_values <- unlist(lapply(data_list, function(d) d[[fill_var]]))
    limits <- range(all_values, na.rm = TRUE)
  } else {
    limits <- NULL
  }

  plots <- vector("list", length(data_list))
  names(plots) <- names(data_list)

  for (i in seq_along(data_list)) {
    year_label <- names(data_list)[i]
    plots[[i]] <- plot_map(
      data_list[[i]],
      fill_var = fill_var,
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
#' Get color palettes for maps. Available palettes: "viridis", "red_blue",
#' "blue_red", "greens", "oranges", "reds", "blues", "purple_green".
#'
#' @param name Name of the palette
#' @param reverse Logical. Reverse direction?
#'
#' @return A character vector of colors
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
    colors <- palettes[["viridis"]]
  }

  if (reverse) {
    colors <- rev(colors)
  }

  colors
}

#' Detect year from data
#'
#' Internal function to detect the census year from a data frame.
#'
#' @param data A data frame
#' @return Integer year or NULL
#'
#' @keywords internal
detect_year <- function(data) {
  if ("year" %in% names(data)) {
    return(unique(data$year)[1])
  }
  NULL
}
