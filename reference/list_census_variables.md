# List census variables

Available census variables, optionally filtered by year, geography, or
category.

## Usage

``` r
list_census_variables(year = NULL, geography = NULL, category = NULL)
```

## Arguments

- year:

  Filter to variables available for specific census year.

- geography:

  Filter to "state", "district", or "subdistrict".

- category:

  Filter to "population", "literacy", "workers", "sc_st", "housing",
  "geography", or "change".

## Value

A tibble of available variables.

## Examples

``` r
list_census_variables()
#> # A tibble: 23 × 5
#>    variable         label                      years        geographies category
#>    <chr>            <chr>                      <chr>        <chr>       <chr>   
#>  1 population       Total Population           1901,1911,1… state,dist… populat…
#>  2 males            Male Population            1901,1911,1… state,dist… populat…
#>  3 females          Female Population          1901,1911,1… state,dist… populat…
#>  4 population_rural Rural Population           1971,1981,2… state,dist… populat…
#>  5 population_urban Urban Population           1971,1981,2… state,dist… populat…
#>  6 sc_population    Scheduled Caste Population 1971,1981,2… state,dist… sc_st   
#>  7 st_population    Scheduled Tribe Population 1971,1981,2… state,dist… sc_st   
#>  8 literacy_rate    Literacy Rate (%)          1961,1981,2… state,dist… literacy
#>  9 literacy_male    Male Literacy Rate (%)     1961,1981,2… state,dist… literacy
#> 10 literacy_female  Female Literacy Rate (%)   1961,1981,2… state,dist… literacy
#> # ℹ 13 more rows
list_census_variables(year = 1981)
#> # A tibble: 22 × 5
#>    variable         label                      years        geographies category
#>    <chr>            <chr>                      <chr>        <chr>       <chr>   
#>  1 population       Total Population           1901,1911,1… state,dist… populat…
#>  2 males            Male Population            1901,1911,1… state,dist… populat…
#>  3 females          Female Population          1901,1911,1… state,dist… populat…
#>  4 population_rural Rural Population           1971,1981,2… state,dist… populat…
#>  5 population_urban Urban Population           1971,1981,2… state,dist… populat…
#>  6 sc_population    Scheduled Caste Population 1971,1981,2… state,dist… sc_st   
#>  7 st_population    Scheduled Tribe Population 1971,1981,2… state,dist… sc_st   
#>  8 literacy_rate    Literacy Rate (%)          1961,1981,2… state,dist… literacy
#>  9 literacy_male    Male Literacy Rate (%)     1961,1981,2… state,dist… literacy
#> 10 literacy_female  Female Literacy Rate (%)   1961,1981,2… state,dist… literacy
#> # ℹ 12 more rows
list_census_variables(category = "literacy", geography = "district")
#> # A tibble: 4 × 5
#>   variable         label                    years          geographies  category
#>   <chr>            <chr>                    <chr>          <chr>        <chr>   
#> 1 literacy_rate    Literacy Rate (%)        1961,1981,2011 state,distr… literacy
#> 2 literacy_male    Male Literacy Rate (%)   1961,1981,2011 state,distr… literacy
#> 3 literacy_female  Female Literacy Rate (%) 1961,1981,2011 state,distr… literacy
#> 4 literate_persons Total Literates          1981,2011      state,distr… literacy
```
