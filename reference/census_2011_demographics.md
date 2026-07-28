# Census 2011 demographics (PCA)

Population, SC/ST, and literacy counts from the 2011 Primary Census
Abstract at all geographic levels (India, state, district, subdistrict,
town/village, ward), split by total/rural/urban sector.

## Usage

``` r
data(census_2011_demographics)
```

## Format

A tibble with 751,594 rows and 28 columns:

- state_code:

  Numeric state code

- district_code:

  Numeric district code

- subdistrict_code:

  Numeric subdistrict code

- town_village_code:

  Town or village code

- ward_code:

  Ward code

- level:

  Geographic level (india, state, district, subdistrict, town, village,
  ward)

- name:

  Name of the geographic unit

- state_name_harmonized:

  Harmonized state name for joining across datasets

- sector:

  Sector: "total", "rural", or "urban"

- households:

  Number of households

- population_total,population_male,population_female:

  Total, male, and female population

- pop_0_6_total,pop_0_6_male,pop_0_6_female:

  Population aged 0-6 years

- sc_total,sc_male,sc_female:

  Scheduled Caste population

- st_total,st_male,st_female:

  Scheduled Tribe population

- literate_total,literate_male,literate_female:

  Literate population

- illiterate_total,illiterate_male,illiterate_female:

  Illiterate population

## Source

Census of India 2011, Primary Census Abstract.
