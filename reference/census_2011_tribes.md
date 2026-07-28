# Census 2011 Scheduled Tribes (A-11)

District-level population of individual Scheduled Tribes from the 2011
Census A-11 tables, with original (un-harmonized) tribe names retained.

## Usage

``` r
data(census_2011_tribes)
```

## Format

A tibble with 12,861 rows and 8 columns:

- year:

  Census year (2011)

- state_name_harmonized:

  Harmonized state name for joining across datasets

- district_name:

  Name of the district

- tribe_name:

  Harmonized tribe name

- tribe_name_original:

  Original tribe name as recorded in the source

- population:

  Tribe population

- percentage:

  Share of district population

- district_total_population:

  Total district population

## Source

Census of India 2011, A-11 Scheduled Tribe tables.
