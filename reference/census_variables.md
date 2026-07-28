# Census variables lookup

Available census variables with labels, years, geographic levels, and
categories.

## Usage

``` r
data(census_variables)
```

## Format

A tibble with 23 rows and 5 columns:

- variable:

  Variable name used in package functions

- label:

  Human-readable label

- years:

  Comma-separated list of available years

- geographies:

  Comma-separated list of available geographic levels

- category:

  Variable category (population, literacy, workers, etc.)
