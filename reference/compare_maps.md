# Compare maps across years

Compare maps across years

## Usage

``` r
compare_maps(
  data_list,
  fill_var,
  title = NULL,
  ncol = NULL,
  palette = "viridis",
  common_scale = TRUE,
  show_state_boundaries = TRUE,
  ...
)
```

## Arguments

- data_list:

  A named list of sf data frames, with names as years

- fill_var:

  The variable to map (string)

- title:

  Overall title for the combined plot

- ncol:

  Number of columns for arrangement

- palette:

  Color palette (see
  [`plot_map`](https://saketlab.github.io/censusindia/reference/plot_map.md)
  for options)

- common_scale:

  Logical. Use the same color scale across all maps?

- show_state_boundaries:

  Logical. Overlay state boundaries?

- ...:

  Additional arguments passed to
  [`plot_map`](https://saketlab.github.io/censusindia/reference/plot_map.md)

## Value

A patchwork object

## Examples

``` r
if (FALSE) { # \dontrun{
# Compare ST percentage across years
library(dplyr)

# Prepare 1971 data
data(census_1971)
st_1971 <- census_1971 |>
  filter(geography == "district") |>
  mutate(st_pct = 100 * st_population_total / population_total) |>
  attach_geometry(1971)

# Prepare 2011 data
data(census_2011_pca)
st_2011 <- census_2011_pca |>
  mutate(st_pct = 100 * st_population / population_total) |>
  attach_geometry(2011)

# Compare
compare_maps(
  list("1971" = st_1971, "2011" = st_2011),
  fill_var = "st_pct",
  title = "ST Population % by District",
  palette = "red_blue"
)
} # }
```
