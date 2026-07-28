# Population projections – district level, Census 2011 boundaries (2011-2031)

MOHFW population projections at district level using Census 2011
boundaries (640 districts). Projections are at 5-year intervals: 2011,
2016, 2021, 2026, 2031.

## Usage

``` r
data(population_projections_district)
```

## Format

A tibble with 3,200 rows and 6 columns:

- year:

  Projection year (5-year intervals)

- state_name_harmonized:

  Harmonized state name for joining

- district:

  District name (MOHFW naming convention)

- males:

  Projected male population

- females:

  Projected female population

- population:

  Projected total population (males + females)

## Source

Ministry of Health and Family Welfare, Government of India. Population
Projections for India and States 2011-2036.

## Details

Compatible with
[`attach_geometry()`](https://saketlab.github.io/censusindia/reference/attach_geometry.md)
using 2011 district boundaries.
