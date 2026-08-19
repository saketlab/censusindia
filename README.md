# censusindia

Digitised Census of India data from 1901 to 2011 for R. Population time series,
primary census abstracts, mother tongue tables, SC/ST and tribal populations,
linguistic diversity indices, MOHFW population projections through 2036, and
administrative directories at state, district, and subdistrict levels.

## Installation

```r
devtools::install_github("saketlab/censusindia")
```

## Quickstart

```r
library(censusindia)

get_census(2011, "state")
get_census(1971, "district", state = "Maharashtra")
get_census(1971, "district", state = "MH", geometry = TRUE)

list_census_variables()
search_census_variables("literacy")
list_census_geographies()

# MOHFW population projections (2011-2036)
get_population(2031, "state")
get_population(2031, "district")
```

## Example

```r
library(censusindia)
library(ggplot2)

mh <- get_census(1971, "district", state = "Maharashtra", geometry = TRUE)

ggplot(mh) +
  geom_sf(aes(fill = population)) +
  scale_fill_viridis_c() +
  theme_minimal() +
  labs(title = "Population by district, Maharashtra 1971")
```

## Vignettes

- [Getting started](https://censusindia.saketlab.org/articles/getting-started.html)
- [Primary Census Abstract, 2001 and 2011](https://censusindia.saketlab.org/articles/primary-census-abstract.html)
- [Population maps](https://censusindia.saketlab.org/articles/population-maps.html)
- [Population dynamics](https://censusindia.saketlab.org/articles/population-dynamics.html)
- [Population projections](https://censusindia.saketlab.org/articles/population-projections.html)
- [Sex ratio evolution](https://censusindia.saketlab.org/articles/sex-ratio.html)
- [SC/ST population distribution](https://censusindia.saketlab.org/articles/sc-st-population.html)
- [Social composition](https://censusindia.saketlab.org/articles/social-composition.html)
- [Linguistic diversity](https://censusindia.saketlab.org/articles/linguistic-diversity.html)
- [Tribal isolation and vulnerability](https://censusindia.saketlab.org/articles/tribal-isolation.html)
- [District population overview](https://censusindia.saketlab.org/articles/district-population.html)

