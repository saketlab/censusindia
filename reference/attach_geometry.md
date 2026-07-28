# Attach geographic boundaries to census data

Adds geometry for mapping. Auto-detects state or district level from
available columns.

## Usage

``` r
attach_geometry(data, year, geography = NULL)
```

## Arguments

- data:

  A data frame containing census data with state/district names.

- year:

  Census year for boundaries. Available: 1941, 1951, 1961, 1971, 1981,
  1991, 2001, 2011.

- geography:

  Geographic level: "state" or "district". If NULL (default),
  auto-detects based on available columns.

## Value

An sf object with geometry attached.

## Examples

``` r
if (FALSE) { # \dontrun{
library(dplyr)
data(census_2011_pca)

# Attach district boundaries
census_2011_pca |>
  mutate(st_pct = 100 * st_population / population_total) |>
  attach_geometry(2011)
} # }
```
