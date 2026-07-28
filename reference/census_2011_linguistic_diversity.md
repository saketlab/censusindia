# Census 2011 linguistic diversity

District-level linguistic diversity metrics derived from the 2011 Census
C-16 mother tongue tables.

## Usage

``` r
data(census_2011_linguistic_diversity)
```

## Format

A tibble with 640 rows and 10 columns:

- state_name_harmonized:

  Harmonized state name for joining across datasets

- state_code:

  Numeric state code

- district_code:

  Numeric district code

- n_languages:

  Number of distinct languages spoken

- total_speakers:

  Total speakers across all languages

- shannon_entropy:

  Shannon entropy of the language distribution

- effective_languages:

  Effective number of languages (exp of Shannon entropy)

- dominant_language:

  Most-spoken language

- dominant_share:

  Share of speakers of the dominant language

- district_name:

  Name of the district

## Source

Census of India 2011, C-16 Mother Tongue Tables (derived).
