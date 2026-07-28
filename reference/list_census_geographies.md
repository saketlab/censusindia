# List available census geographies

Geographic levels available for each census year.

## Usage

``` r
list_census_geographies()
```

## Value

A tibble showing available year-geography combinations.

## Examples

``` r
list_census_geographies()
#> # A tibble: 25 × 3
#>     year geography dataset               
#>    <int> <chr>     <chr>                 
#>  1  1901 state     Population time series
#>  2  1901 district  Population time series
#>  3  1911 state     Population time series
#>  4  1911 district  Population time series
#>  5  1921 state     Population time series
#>  6  1921 district  Population time series
#>  7  1931 state     Population time series
#>  8  1931 district  Population time series
#>  9  1941 state     Population time series
#> 10  1941 district  Population time series
#> # ℹ 15 more rows
```
