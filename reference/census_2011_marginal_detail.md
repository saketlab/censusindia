# Census 2011 marginal worker detail (PCA)

Marginal workers from the 2011 Primary Census Abstract split by duration
of work (3-6 months and 0-3 months) and by activity, plus non-workers,
at all geographic levels and total/rural/urban sector.

## Usage

``` r
data(census_2011_marginal_detail)
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

- marginal_workers_3_6_total,marginal_workers_3_6_male,marginal_workers_3_6_female:

  Marginal workers employed 3-6 months

- marg_cultivators_3_6_total,marg_cultivators_3_6_male,marg_cultivators_3_6_female:

  Marginal cultivators, 3-6 months

- marg_agri_labour_3_6_total,marg_agri_labour_3_6_male,marg_agri_labour_3_6_female:

  Marginal agricultural labourers, 3-6 months

- marg_hh_industry_3_6_total,marg_hh_industry_3_6_male,marg_hh_industry_3_6_female:

  Marginal household industry workers, 3-6 months

- marg_other_3_6_total,marg_other_3_6_male,marg_other_3_6_female:

  Marginal other workers, 3-6 months

- marginal_workers_0_3_total,marginal_workers_0_3_male,marginal_workers_0_3_female:

  Marginal workers employed 0-3 months

- marg_cultivators_0_3_total,marg_cultivators_0_3_male,marg_cultivators_0_3_female:

  Marginal cultivators, 0-3 months

- marg_agri_labour_0_3_total,marg_agri_labour_0_3_male,marg_agri_labour_0_3_female:

  Marginal agricultural labourers, 0-3 months

- marg_hh_industry_0_3_total,marg_hh_industry_0_3_male,marg_hh_industry_0_3_female:

  Marginal household industry workers, 0-3 months

- marg_other_0_3_total,marg_other_0_3_male,marg_other_0_3_female:

  Marginal other workers, 0-3 months

- non_workers_total,non_workers_male,non_workers_female:

  Non-workers

## Source

Census of India 2011, Primary Census Abstract.
