# Population projections – district level, LGD boundaries (2012-2031)

MOHFW population projections scaled to current Local Government
Directory (LGD) district boundaries (785 districts). Annual projections
from 2012 to 2031, aggregated across age groups.

## Usage

``` r
data(population_projections_district_lgd)
```

## Format

A tibble with 15,700 rows and 6 columns:

- year:

  Projection year (annual, 2012-2031)

- state_name_harmonized:

  Harmonized state name for joining

- district:

  District name (LGD naming convention)

- males:

  Projected male population

- females:

  Projected female population

- population:

  Projected total population (males + females)

## Source

Ministry of Health and Family Welfare, Government of India. Population
Projections for India and States 2011-2036. District scaling from
India_Population_Estimates project using spatial overlap analysis.
