# censusindia 0.2.1

## REST API

* `serve()` runs a plumber REST API over the accessors and shipped datasets,
  with paging, GeoJSON geometry and per-request logging.

## New data

* `census_1931_castes`: 1931 caste populations by religion for 24 provinces, states and agencies.
* `census_1931_exterior_castes`: castes the 1931 Census classed as exterior, by province.

## Data fixes

* `population_projections_state` adds a merged "Dadra & Nagar Haveli and Daman & Diu" row
  (the sum of the two old UTs, kept alongside). Drop one form and "India" before summing states.
* `census_subdistricts_2011` now covers all Census 2011 subdistricts and sums to `census_2011_pca`.
* `census_1971` and `census_1981` record an empty rural or urban sector as 0.
* `population_projections_district_lgd` and both district age tables have no NA (Theni
  2017-2031, Moga and Tapi 80+ 2022-2026 derived). The age tables download again on first use.

# censusindia 0.2.0

* First CRAN release.

## Breaking changes

* Boundaries and seven large tables download on first use, MD5-checked and cached in
  `census_cache_dir()`. Those tables are now functions: `census_2011_workers()` etc.

## Other changes

* `census_download()` fetches every remote file at once; `clear_census_cache()` removes them.
* `clear_geometry_cache()` also releases downloaded tables held in memory.
* `plot_map()` reports a failed boundary download instead of drawing without its base layer.
* `at_level()` accepts any table with a `level` column, including `census_1981`.

# censusindia 0.1.2

* Population projection tables checked cell by cell against the printed MoHFW and IIPS reports.
* Boundary files shipped gzipped.
