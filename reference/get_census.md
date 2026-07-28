# Get India census data

Census data for India at state, district, or subdistrict level.

## Usage

``` r
get_census(
  year,
  geography = c("state", "district", "subdistrict"),
  variables = NULL,
  state = NULL,
  geometry = FALSE,
  sector = "total"
)
```

## Arguments

- year:

  Census year. One of: 1901, 1911, 1921, 1931, 1941, 1951, 1961, 1971,
  1981, 1991, 2001, 2011.

- geography:

  Geographic level: "state", "district", or "subdistrict". Not all
  geographies are available for all years.

- variables:

  Character vector of variables to retrieve. Use
  [`list_census_variables()`](https://saketlab.github.io/censusindia/reference/list_census_variables.md)
  to see available variables. If NULL (default), returns all available
  variables for the specified year and geography.

- state:

  Optional. Filter to specific state(s). Can be state name or
  abbreviation (e.g., "Maharashtra" or "MH").

- geometry:

  If TRUE, returns an sf object with geographic boundaries.

- sector:

  For 1971/1981, filter to "total", "rural", or "urban".

## Value

A tibble (or sf object if geometry = TRUE).

## Examples

``` r
get_census(2011, "state")
#> # A tibble: 32 × 12
#>     year geography state_code state_name     state_name_harmonized district_code
#>    <int> <chr>          <int> <chr>          <chr>                         <int>
#>  1  2011 state              1 JAMMU&KASHMIR  Jammu & Kashmir                   0
#>  2  2011 state              2 HIMACHAL PRAD… Himachal Pradesh                  0
#>  3  2011 state              3 PUNJAB         Punjab                            0
#>  4  2011 state              4 CHANDIGARH     Chandigarh                        0
#>  5  2011 state              5 UTTARAKHAND    Uttarakhand                       0
#>  6  2011 state              6 HARYANA        Haryana                           0
#>  7  2011 state              7 NCT OF DELHI   Nct Of Delhi                      0
#>  8  2011 state              8 RAJASTHAN      Rajasthan                         0
#>  9  2011 state              9 UTTAR PRADESH  Uttar Pradesh                     0
#> 10  2011 state             10 BIHAR          Bihar                             0
#> # ℹ 22 more rows
#> # ℹ 6 more variables: name <chr>, population <dbl>, males <dbl>, females <dbl>,
#> #   variation_absolute <dbl>, variation_percent <dbl>
get_census(1971, "district", state = "Maharashtra")
#> # A tibble: 26 × 21
#>     year geography state       name         area_km2 population population_rural
#>    <int> <chr>     <chr>       <chr>           <dbl>      <dbl>            <dbl>
#>  1  1971 district  MAHARASHTRA Ahmadnagar      17035    2269117          2017617
#>  2  1971 district  MAHARASHTRA Akola           10567    1501478          1148129
#>  3  1971 district  MAHARASHTRA Amravati        12210    1541209          1116526
#>  4  1971 district  MAHARASHTRA Aurangabad      16200    1971006          1641745
#>  5  1971 district  MAHARASHTRA Bhandara         9214    1585580          1405067
#>  6  1971 district  MAHARASHTRA Bhir            11227    1286121          1136820
#>  7  1971 district  MAHARASHTRA Buldhana         9745    1262978          1041170
#>  8  1971 district  MAHARASHTRA Chandrapur      25641    1640137          1473037
#>  9  1971 district  MAHARASHTRA Dhulia          13143    1662181          1374445
#> 10  1971 district  MAHARASHTRA Greater Bom…      603    5970575               NA
#> # ℹ 16 more rows
#> # ℹ 14 more variables: population_urban <dbl>, males <dbl>, males_rural <dbl>,
#> #   males_urban <dbl>, females <dbl>, females_rural <dbl>, females_urban <dbl>,
#> #   sc_population <dbl>, sc_population_rural <dbl>, sc_population_urban <dbl>,
#> #   st_population <dbl>, st_population_rural <dbl>, st_population_urban <dbl>,
#> #   state_name_harmonized <chr>
get_census(1981, "district", variables = c("population", "literacy_rate"), geometry = TRUE)
#> Simple feature collection with 398 features and 8 fields (with 26 geometries empty)
#> Geometry type: MULTIPOLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 68.43074 ymin: 8.066995 xmax: 97.35811 ymax: 33.08975
#> Geodetic CRS:  WGS 84
#> # A tibble: 398 × 9
#>     year state        district geo_id geo_name level population literate_persons
#>    <int> <chr>        <chr>    <chr>  <chr>    <chr>      <dbl>            <dbl>
#>  1  1981 ANDHRA PRAD… Srikaku… IN_AN… Srikaku… dist…    1959352           445209
#>  2  1981 ANDHRA PRAD… Viziana… IN_AN… Viziana… dist…    1804196           392277
#>  3  1981 ANDHRA PRAD… Vishakh… IN_AN… Vishakh… dist…    2576474           716913
#>  4  1981 ANDHRA PRAD… East Go… IN_AN… East Go… dist…    3701040          1306901
#>  5  1981 ANDHRA PRAD… West Go… IN_AN… West Go… dist…    2873958          1080947
#>  6  1981 ANDHRA PRAD… Krishna  IN_AN… Krishna  dist…    3048463          1271423
#>  7  1981 ANDHRA PRAD… Guntur   IN_AN… Guntur   dist…    3434724          1238404
#>  8  1981 ANDHRA PRAD… Prakasam IN_AN… Prakasam dist…    2329571           684667
#>  9  1981 ANDHRA PRAD… Nellore  IN_AN… Nellore  dist…    2014879           648006
#> 10  1981 ANDHRA PRAD… Chittoor IN_AN… Chittoor dist…    2737316           871844
#> # ℹ 388 more rows
#> # ℹ 1 more variable: geometry <MULTIPOLYGON [°]>
```
