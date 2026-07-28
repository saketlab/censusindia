# Get census boundaries

State or district boundaries for a given census year.

## Usage

``` r
get_census_boundaries(year, geography = c("state", "district"))
```

## Arguments

- year:

  Census year. Available: 1941, 1951, 1961, 1971, 1981, 1991, 2001,
  2011.

- geography:

  Geographic level: "state" or "district".

## Value

An sf object containing the geographic boundaries with harmonized state
names.

## Examples

``` r
if (FALSE) { # \dontrun{
boundaries <- get_census_boundaries(1971, "district")
ggplot2::ggplot(boundaries) +
  ggplot2::geom_sf()
} # }
```
