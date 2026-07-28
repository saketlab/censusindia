# Census 2011 Scheduled Castes and Scheduled Tribes (A-10/A-11)

District-level population of individual Scheduled Castes and Scheduled
Tribes from the 2011 Census A-10 and A-11 tables.

## Usage

``` r
data(census_2011_sc_st)
```

## Format

A tibble with 14,028 rows and 8 columns:

- year:

  Census year (2011)

- state_name_harmonized:

  Harmonized state name for joining across datasets

- district_name:

  Name of the district

- category:

  "SC" or "ST"

- caste_tribe_name:

  Name of the caste or tribe

- population:

  Population of the caste or tribe

- percentage:

  Share of district population

- district_total_population:

  Total district population

## Source

Census of India 2011, A-10 (SC) and A-11 (ST) tables.
