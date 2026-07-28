# Census 2011 workers (PCA)

Worker classification from the 2011 Primary Census Abstract at all
geographic levels, split by total/rural/urban sector. Main and marginal
workers are broken down by activity (cultivators, agricultural
labourers, household industry, other workers).

## Usage

``` r
data(census_2011_workers)
```

## Format

A tibble with 751,594 rows and 42 columns:

- state_code,district_code,subdistrict_code,town_village_code,ward_code:

  Geographic codes

- level:

  Geographic level (india, state, district, subdistrict, town, village,
  ward)

- name:

  Name of the geographic unit

- state_name_harmonized:

  Harmonized state name for joining across datasets

- sector:

  Sector: "total", "rural", or "urban"

- total_workers_total,total_workers_male,total_workers_female:

  All workers

- main_workers_total,main_workers_male,main_workers_female:

  Main workers

- main_cultivators_total,main_cultivators_male,main_cultivators_female:

  Main cultivators

- main_agri_labour_total,main_agri_labour_male,main_agri_labour_female:

  Main agricultural labourers

- main_hh_industry_total,main_hh_industry_male,main_hh_industry_female:

  Main household industry workers

- main_other_total,main_other_male,main_other_female:

  Main other workers

- marginal_workers_total,marginal_workers_male,marginal_workers_female:

  Marginal workers

- marginal_cultivators_total,marginal_cultivators_male,marginal_cultivators_female:

  Marginal cultivators

- marginal_agri_labour_total,marginal_agri_labour_male,marginal_agri_labour_female:

  Marginal agricultural labourers

- marginal_hh_industry_total,marginal_hh_industry_male,marginal_hh_industry_female:

  Marginal household industry workers

- marginal_other_total,marginal_other_male,marginal_other_female:

  Marginal other workers

## Source

Census of India 2011, Primary Census Abstract.
