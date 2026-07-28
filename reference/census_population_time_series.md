# Census population time series (1901-2011)

Decadal population at state and district levels, 1901-2011.

## Usage

``` r
data(census_population_time_series)
```

## Format

A tibble with 7,901 rows and 12 columns:

- year:

  Census year (1901, 1911, ..., 2011)

- geography:

  Geographic level: "state" or "district"

- state_code:

  Numeric state code

- state_name:

  Name of the state

- state_name_harmonized:

  Harmonized state name for joining across datasets

- district_code:

  Numeric district code (0 for state-level)

- name:

  Name of the state or district

- population:

  Total population

- males:

  Male population

- females:

  Female population

- variation_absolute:

  Absolute change from previous census

- variation_percent:

  Percentage change from previous census

## Source

Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
Collection, 1901-2026: Digitised Subnational Population and
Administrative Datasets." Harvard Dataverse.
[doi:10.7910/DVN/ON8CP8](https://doi.org/10.7910/DVN/ON8CP8) .
