# Search census variables

Find census variables by keyword in names and labels.

## Usage

``` r
search_census_variables(pattern)
```

## Arguments

- pattern:

  Character string or regex pattern to search.

## Value

A tibble of matching variables.

## Examples

``` r
search_census_variables("population")
#> # A tibble: 10 × 5
#>    variable           label                           years geographies category
#>    <chr>              <chr>                           <chr> <chr>       <chr>   
#>  1 population         Total Population                1901… state,dist… populat…
#>  2 males              Male Population                 1901… state,dist… populat…
#>  3 females            Female Population               1901… state,dist… populat…
#>  4 population_rural   Rural Population                1971… state,dist… populat…
#>  5 population_urban   Urban Population                1971… state,dist… populat…
#>  6 sc_population      Scheduled Caste Population      1971… state,dist… sc_st   
#>  7 st_population      Scheduled Tribe Population      1971… state,dist… sc_st   
#>  8 density            Population Density (per sq km)  2011  subdistrict geograp…
#>  9 variation_absolute Decadal Population Change (Abs… 1911… state,dist… change  
#> 10 variation_percent  Decadal Population Change (%)   1911… state,dist… change  
search_census_variables("worker")
#> # A tibble: 4 × 5
#>   variable      label                      years     geographies    category
#>   <chr>         <chr>                      <chr>     <chr>          <chr>   
#> 1 main_workers  Main Workers               1981,2011 state,district workers 
#> 2 hh_industry   Household Industry Workers 1981,2011 state,district workers 
#> 3 other_workers Other Workers              1981,2011 state,district workers 
#> 4 non_workers   Non-Workers                1981,2011 state,district workers 
```
