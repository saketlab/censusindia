# Census 1981 Primary Census Abstract

State and district data from the 1981 Census with literacy and worker
classification.

## Usage

``` r
data(census_1981)
```

## Format

A tibble with 2,364 rows and 39 columns including:

- year:

  Census year (1981)

- geo_id:

  Unique geographic identifier

- geo_name:

  Name of the geographic unit

- level:

  Geographic level (india, state, district)

- state:

  Name of the state

- state_name_harmonized:

  Harmonized state name for joining across datasets

- district:

  Name of the district (if applicable)

- sector:

  Sector: "total", "rural", or "urban"

- area_km2:

  Area in square kilometers

- total_persons:

  Total population

- total_males:

  Male population

- total_females:

  Female population

- literate_persons:

  Total literate population

- main_workers_persons:

  Total main workers

- cultivators_persons:

  Total cultivators

- agri_labour_persons:

  Total agricultural labourers

- hh_industry_persons:

  Household industry workers

- other_workers_persons:

  Other workers

- non_workers_persons:

  Non-workers

## Source

Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
Collection, 1901-2026: Digitised Subnational Population and
Administrative Datasets." Harvard Dataverse.
[doi:10.7910/DVN/ON8CP8](https://doi.org/10.7910/DVN/ON8CP8) .
