# Census 2011 Primary Census Abstract (PCA)

District-level population, SC/ST, literacy, and worker statistics from
the 2011 Census.

## Usage

``` r
data(census_2011_pca)
```

## Format

A tibble with 593 rows and 19 columns:

- year:

  Census year (2011)

- geography:

  Geographic level ("district")

- state_code:

  Numeric state code

- state_name:

  Name of the state

- state_name_harmonized:

  Harmonized state name for joining across datasets

- district_code:

  Numeric district code

- name:

  Name of the district

- households:

  Number of households

- population_total:

  Total population

- population_male:

  Male population

- population_female:

  Female population

- population_0_6:

  Population aged 0-6 years

- sc_population:

  Scheduled Caste population

- st_population:

  Scheduled Tribe population

- literate_total:

  Total literate population

- workers_total:

  Total workers

- main_workers:

  Main workers

- marginal_workers:

  Marginal workers

- non_workers:

  Non-workers

## Source

Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
Collection, 1901-2026: Digitised Subnational Population and
Administrative Datasets." Harvard Dataverse.
[doi:10.7910/DVN/ON8CP8](https://doi.org/10.7910/DVN/ON8CP8) .
