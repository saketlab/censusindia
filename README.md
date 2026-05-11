# censusindia

Digitised Census of India data from 1901 to 2011 for R. Population time series,
primary census abstracts, mother tongue tables, SC/ST and tribal populations,
linguistic diversity indices, and administrative directories at state, district,
and subdistrict levels.

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

- [Population maps](https://saketlab.github.io/censusindia/articles/population-maps.html)
- [Population dynamics](https://saketlab.github.io/censusindia/articles/population-dynamics.html)
- [Sex ratio evolution](https://saketlab.github.io/censusindia/articles/sex-ratio.html)
- [SC/ST population distribution](https://saketlab.github.io/censusindia/articles/sc-st-population.html)
- [Social composition](https://saketlab.github.io/censusindia/articles/social-composition.html)
- [Linguistic diversity](https://saketlab.github.io/censusindia/articles/linguistic-diversity.html)

## Data source

Most datasets are derived from:

> Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data Collection, 1901-2026: Digitised Subnational Population and Administrative Datasets." Harvard Dataverse. https://doi.org/10.7910/DVN/ON8CP8

The 2011 mother tongue data comes from the Census of India C-16 tables.

## License

MIT
