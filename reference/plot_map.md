# Create a choropleth map from census data.

Create a choropleth map from census data.

## Usage

``` r
plot_map(
  data,
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
  labels = NULL
)
```

## Arguments

- data:

  An sf object or data frame with geometry attached via
  [`attach_geometry`](https://saketlab.github.io/censusindia/reference/attach_geometry.md)

- fill_var:

  The variable to map to fill color (unquoted or string)

- title:

  Optional title for the map

- subtitle:

  Optional subtitle for the map

- legend_title:

  Title for the legend

- palette:

  Color palette. Options include:

  - `"viridis"` - Perceptually uniform, colorblind-friendly (default)

  - `"red_blue"` - Diverging red to blue (red = high)

  - `"blue_red"` - Diverging blue to red (blue = high)

  - `"greens"` - Sequential green palette

  - `"oranges"` - Sequential orange palette

  - `"reds"` - Sequential red palette

  - `"blues"` - Sequential blue palette

  - `"purple_green"` - Diverging purple to green

- reverse:

  Logical. Reverse the color palette direction? Default FALSE.

- direction:

  Numeric. Alternative to reverse: use -1 to reverse, 1 for default. If
  both reverse and direction are specified, direction takes precedence.

- na_color:

  Color for missing values. Default is "grey80"

- show_state_boundaries:

  Logical. Overlay state boundaries?

- state_boundary_color:

  Color for state boundaries. Default is "black"

- state_boundary_width:

  Width of state boundary lines. Default is 0.3

- trans:

  Transformation for the color scale (e.g., "log10", "sqrt"). Default is
  "identity" (no transformation)

- limits:

  Optional limits for the color scale as c(min, max)

- breaks:

  Optional breaks for the legend

- labels:

  Optional labels for the legend breaks

## Value

A ggplot2 object

## Examples

``` r
if (FALSE) { # \dontrun{
# Load 2011 PCA data
data(census_2011_pca)

# Calculate ST percentage and attach geometry
st_data <- census_2011_pca |>
  dplyr::mutate(st_pct = 100 * st_population / population_total) |>
  attach_geometry(2011)

# Create a basic map
plot_map(st_data, st_pct, title = "ST Population %")

# With red-blue palette and state boundaries
plot_map(st_data, st_pct,
  title = "ST Population % (2011)",
  palette = "red_blue",
  show_state_boundaries = TRUE
)
} # }
```
