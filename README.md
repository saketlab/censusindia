# censusindia

censusindia is an R package to query Census of India data, 1901 to 2011, at state,
district, and subdistrict level. It also provides MoHFW population projections through
2036. All data including population counts, primary census abstracts, mother tongue tables, and 
SC/ST tables can be 'attached' to district-boundary GeoJSONs for quick visualisation.

## Installation

```r
install.packages("pak")
pak::pak("saketlab/censusindia")
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

# mother tongue speakers by district (2011)
census_languages() |> dplyr::filter(district_name == "Pune")
```

## Examples

Linguistic diversity by district:

```r
library(censusindia)
library(dplyr)

ling <- census_2011_linguistic_diversity |>
  rename(district = district_name) |>
  attach_geometry(2011, geography = "district")

plot_map(ling, "effective_languages",
  title = "Linguistic diversity by district, 2011",
  legend_title = "Effective\nlanguages",
  palette = "reds", show_state_boundaries = TRUE, trans = "log2"
)
```

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="man/figures/README-map-dark.png">
  <img src="man/figures/README-map.png" alt="Linguistic diversity by district, 2011">
</picture>

Projected district-level population, Maharashtra 2011 vs 2031:

```r
mh_2011 <- get_population(2011, "district", state = "Maharashtra") |>
  attach_geometry(2011, geography = "district")
mh_2031 <- get_population(2031, "district", state = "Maharashtra") |>
  attach_geometry(2011, geography = "district")

compare_maps(
  list("2011" = mh_2011, "2031" = mh_2031),
  fill_var = "population",
  title = "Projected population by district, Maharashtra: 2011 vs 2031",
  palette = "oranges",
  base_layer = FALSE
)
```

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="man/figures/README-projection-dark.png">
  <img src="man/figures/README-projection.png" alt="Projected population by district, Maharashtra: 2011 vs 2031">
</picture>

Languages spoken in a district, ranked by speakers:

```r
library(dplyr)

census_languages() |>
  filter(district_name == "Pune") |>
  arrange(desc(total_speakers)) |>
  select(language_name, total_speakers)
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

## Data sources

- Population time series (1901-2011), 1961 literacy, 1971/1981 PCA, 2011 subdistrict and PCA tables: Jolad, S. & Singh, M. (2026). [Indian Census Data Collection, 1901-2026: Digitised Subnational Population and Administrative Datasets](https://doi.org/10.7910/DVN/ON8CP8). Harvard Dataverse.
- 2001 and 2011 Primary Census Abstract, C-16 mother tongue tables, A-10/A-11 SC/ST tables: [Census of India](https://censusindia.gov.in), Office of the Registrar General & Census Commissioner, India.
- Population projections, state level (2011-2036): Ministry of Health and Family Welfare, Government of India. [Population Projections for India and States 2011-2036](https://www.india.gov.in/my-government/documents/details/population-projections-for-india-and-states-2011-2036) | [PDF](https://drive.google.com/file/d/1PmoEUi936-dJ2KiKl7SDj5SqgCPYIfx2/view?usp=sharing).
- Population projections, district level (2011-2031): International Institute for Population Sciences. [Projection of District Level Annual Population by Quinquennial Agegroup and Sex](https://www.iipsindia.ac.in/sites/default/files/1_3.pdf).
- District/state boundary GeoJSONs: via [bharatviz.org](https://bharatviz.org), collated from Jolad & Singh (2026) and [ramSeraph/indian_admin_boundaries](https://github.com/ramSeraph/indian_admin_boundaries).

