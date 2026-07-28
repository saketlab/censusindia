# Census 1971 Primary Census Abstract

State and district population from the 1971 Census with rural/urban
breakdown and SC/ST populations.

## Usage

``` r
data(census_1971)
```

## Format

A tibble with 370 rows and 21 columns:

- year:

  Census year (1971)

- geography:

  Geographic level: "state" or "district"

- state:

  Name of the state

- state_name_harmonized:

  Harmonized state name for joining across datasets

- name:

  Name of the state or district

- area_km2:

  Area in square kilometers

- population_total:

  Total population

- population_rural:

  Rural population

- population_urban:

  Urban population

- males_total:

  Total male population

- males_rural:

  Rural male population

- males_urban:

  Urban male population

- females_total:

  Total female population

- females_rural:

  Rural female population

- females_urban:

  Urban female population

- sc_population_total:

  Total Scheduled Caste population

- sc_population_rural:

  Rural Scheduled Caste population

- sc_population_urban:

  Urban Scheduled Caste population

- st_population_total:

  Total Scheduled Tribe population

- st_population_rural:

  Rural Scheduled Tribe population

- st_population_urban:

  Urban Scheduled Tribe population

## Source

Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
Collection, 1901-2026: Digitised Subnational Population and
Administrative Datasets." Harvard Dataverse.
[doi:10.7910/DVN/ON8CP8](https://doi.org/10.7910/DVN/ON8CP8) .
