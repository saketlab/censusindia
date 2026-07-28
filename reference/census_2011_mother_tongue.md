# Census 2011 mother tongue data (C-16)

Mother tongue speakers by language at state and district levels from the
2011 Census C-16 tables, with rural/urban and male/female breakdowns.

## Usage

``` r
data(census_2011_mother_tongue)
```

## Format

A tibble with 350,157 rows and 18 columns:

- state_code:

  Numeric state code

- state_name:

  Name of the state

- state_name_harmonized:

  Harmonized state name for joining across datasets

- district_code:

  District code ("000" for state total)

- area_name:

  Name of the state or district

- language_code:

  Census language code

- language_name:

  Name of the language or dialect

- language_level:

  L1 for main languages, L2 for dialects

- language_group:

  Numeric language group code

- total_persons:

  Total speakers

- total_males:

  Male speakers

- total_females:

  Female speakers

- rural_persons:

  Rural speakers

- rural_males:

  Rural male speakers

- rural_females:

  Rural female speakers

- urban_persons:

  Urban speakers

- urban_males:

  Urban male speakers

- urban_females:

  Urban female speakers

## Source

Census of India 2011, C-16 Mother Tongue Tables.
