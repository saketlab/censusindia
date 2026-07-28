# List Indian states

States and union territories with codes, abbreviations, and regions.

## Usage

``` r
list_states(region = NULL)
```

## Arguments

- region:

  Filter by region: "North", "South", "East", "West", "Central",
  "Northeast", "Islands".

## Value

A tibble of states with codes, names, abbreviations, and regions.

## Examples

``` r
list_states()
#> # A tibble: 36 × 5
#>    state_code state_name        state_abbr region state_name_harmonized
#>         <int> <chr>             <chr>      <chr>  <chr>                
#>  1          1 Jammu and Kashmir JK         North  Jammu & Kashmir      
#>  2          2 Himachal Pradesh  HP         North  Himachal Pradesh     
#>  3          3 Punjab            PB         North  Punjab               
#>  4          4 Chandigarh        CH         North  Chandigarh           
#>  5          5 Uttarakhand       UK         North  Uttarakhand          
#>  6          6 Haryana           HR         North  Haryana              
#>  7          7 Delhi             DL         North  Delhi                
#>  8          8 Rajasthan         RJ         North  Rajasthan            
#>  9          9 Uttar Pradesh     UP         North  Uttar Pradesh        
#> 10         10 Bihar             BR         East   Bihar                
#> # ℹ 26 more rows
list_states(region = "South")
#> # A tibble: 7 × 5
#>   state_code state_name     state_abbr region state_name_harmonized
#>        <int> <chr>          <chr>      <chr>  <chr>                
#> 1         28 Andhra Pradesh AP         South  Andhra Pradesh       
#> 2         29 Karnataka      KA         South  Karnataka            
#> 3         31 Lakshadweep    LD         South  Lakshadweep          
#> 4         32 Kerala         KL         South  Kerala               
#> 5         33 Tamil Nadu     TN         South  Tamil Nadu           
#> 6         34 Puducherry     PY         South  Puducherry           
#> 7         36 Telangana      TS         South  Telangana            
```
