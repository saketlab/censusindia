# Get population projections

MOHFW population projections (2011-2036) at state or district level,
based on the 2011 Census. District projections are available using
either Census 2011 boundaries (640 districts, 5-year intervals) or
current LGD boundaries (785 districts, annual).

## Usage

``` r
get_population(
  year = NULL,
  geography = c("state", "district"),
  state = NULL,
  boundary = c("census2011", "lgd"),
  geometry = FALSE
)
```

## Arguments

- year:

  Integer or integer vector of projection years. If NULL (default),
  returns all available years.

- geography:

  Geographic level: `"state"` or `"district"`.

- state:

  Optional. Filter to specific state(s) by name or abbreviation (e.g.,
  `"Maharashtra"` or `"MH"`).

- boundary:

  For district geography, which boundary system: `"census2011"`
  (default, 640 districts) or `"lgd"` (785 districts). Ignored for state
  geography.

- geometry:

  If `TRUE`, attaches geographic boundaries (Census 2011). Only works
  with `boundary = "census2011"` for district level.

## Value

A tibble (or sf object if `geometry = TRUE`) with columns: `year`,
`state_name_harmonized`, `males`, `females`, `population`, and
`district` for district-level data.

## Details

State-level data covers 2011-2036 for 38 entries (36 states/UTs plus
India total plus Ladakh). Values are in absolute numbers.

The source data rounds Persons, Male, and Female independently (in
thousands), so `population` may differ from `males + females` by up to
1000 at the state level.

District-level Census 2011 data has projections at 5-year intervals
(2011, 2016, 2021, 2026, 2031). LGD district data has annual projections
from 2012 to 2031.

Telangana and Ladakh are included as separate entries even though they
did not exist as states at the time of the 2011 Census.

## Examples

``` r
# State-level projections for 2021
get_population(2021, "state")
#> # A tibble: 38 × 5
#>     year state_name_harmonized        males  females population
#>    <int> <chr>                        <dbl>    <dbl>      <dbl>
#>  1  2021 Andaman & Nicobar Islands   211000   189000     400000
#>  2  2021 Andhra Pradesh            26403000 26384000   52787000
#>  3  2021 Arunachal Pradesh           789000   745000    1533000
#>  4  2021 Assam                     17843000 17200000   35043000
#>  5  2021 Bihar                     64012000 59071000  123083000
#>  6  2021 Chandigarh                  654000   554000    1208000
#>  7  2021 Chhattisgarh              14794000 14698000   29493000
#>  8  2021 Dadra & Nagar Haveli        363000   245000     608000
#>  9  2021 Daman & Diu                 330000   140000     469000
#> 10  2021 Delhi                     10963000  9609000   20571000
#> # ℹ 28 more rows

# District-level for Kerala
get_population(2021, "district", state = "Kerala")
#> # A tibble: 14 × 6
#>     year state_name_harmonized district             males females population
#>    <int> <chr>                 <chr>                <int>   <int>      <int>
#>  1  2021 Kerala                Alappuzha          1036894 1133032    2169926
#>  2  2021 Kerala                Ernakulam          1749389 1764134    3513523
#>  3  2021 Kerala                Idukki              551316  546906    1098222
#>  4  2021 Kerala                Kannur             1242468 1432781    2675249
#>  5  2021 Kerala                Kasaragod           688953  746943    1435896
#>  6  2021 Kerala                Kollam             1275159 1442728    2717887
#>  7  2021 Kerala                Kottayam            996155 1022264    2018419
#>  8  2021 Kerala                Kozhikode          1586515 1762066    3348581
#>  9  2021 Kerala                Malappuram         2235935 2461929    4697864
#> 10  2021 Kerala                Palakkad           1495307 1557656    3052963
#> 11  2021 Kerala                Pathanamthitta      545232  623267    1168499
#> 12  2021 Kerala                Thiruvananthapuram 1634102 1775637    3409739
#> 13  2021 Kerala                Thrissur           1582398 1733742    3316140
#> 14  2021 Kerala                Wayanad             423177  443915     867092

# LGD boundary districts
get_population(2021, "district", boundary = "lgd")
#> # A tibble: 785 × 6
#>     year state_name_harmonized     district             males females population
#>    <int> <chr>                     <chr>                <int>   <int>      <int>
#>  1  2021 Andaman & Nicobar Islands Nicobars            3.77e4   29949      67622
#>  2  2021 Andaman & Nicobar Islands North And Middle A… 1.09e5  103353     212666
#>  3  2021 Andaman & Nicobar Islands South Andamans      2.51e5  223118     473640
#>  4  2021 Andhra Pradesh            Alluri Sitharama R… 4.97e6 5037064   10005537
#>  5  2021 Andhra Pradesh            Anakapalli          1.64e6 1669788    3314233
#>  6  2021 Andhra Pradesh            Anantapur           2.38e6 2346891    4728742
#>  7  2021 Andhra Pradesh            Annamayya           2.21e6 2195473    4404622
#>  8  2021 Andhra Pradesh            Bapatla             1.23e6 1226631    2453833
#>  9  2021 Andhra Pradesh            Chittoor            2.05e6 2046458    4091632
#> 10  2021 Andhra Pradesh            East Godavari       1.28e6 1292751    2577228
#> # ℹ 775 more rows
```
