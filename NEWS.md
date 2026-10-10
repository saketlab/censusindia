# censusindia (development version)

## REST API

* `serve()` starts a plumber REST API over `get_census()`, `get_population()`,
  `get_census_boundaries()`, `census_languages()`, `census_sc_st()`, the
  variable listings and every shipped dataset. Responses are paged, geometry
  comes back as GeoJSON, and each request is logged with the kind of client
  that made it.

## New data

* `census_1931_castes`: population of every caste in the 1931 Census caste
  tables by religion, for 24 provinces, states and agencies.
* `census_1931_exterior_castes`: castes the 1931 Census treated as exterior,
  by province section of Appendix I.

## Data fixes

* `census_subdistricts_2011` covers every Census 2011 subdistrict and sums to
  `census_2011_pca`. It had listed current subdistricts, with Telangana, Delhi,
  Puducherry and Ladakh NA.
* `census_1971` and `census_1981` record an empty rural or urban sector as 0.
* `population_projections_district_age()`, `population_projections_district_lgd_age()`
  and `population_projections_district_lgd` have no NA. Theni 2017-2031, printed
  with Madurai's numbers, follows Tamil Nadu's common growth path. Moga and
  Tapi's unprinted 80+ for 2022-2026 is All ages minus the other groups. Both
  age tables download again on first use.

# censusindia 0.2.0

* First CRAN release.

## Breaking changes

* Census boundaries and seven large tables are no longer installed with the
  package. They are downloaded on first use, checked against a pinned MD5
  checksum and cached in `census_cache_dir()`; `clear_census_cache()` removes
  them. The tables are now functions, so `census_2011_workers` becomes
  `census_2011_workers()`. The same applies to `census_2011_demographics()`,
  `census_2011_marginal_detail()`, `census_2011_mother_tongue()`,
  `census_2011_subdistrict_languages()`, `population_projections_district_age()`
  and `population_projections_district_lgd_age()`.

## Other changes

* `census_download()` fetches every remote file at once, with a progress bar.
  Checksums and version directories live in `inst/manifest.csv`.
* `clear_geometry_cache()` also releases downloaded tables held in memory.
* `plot_map()` now reports a failed boundary download instead of drawing the
  map without its base layer.
* `at_level()` documents and accepts any table with a `level` column, including
  `census_1981`.

# censusindia 0.1.2

* Population projection tables checked cell by cell against the printed
  MoHFW and IIPS reports.
* Boundary files shipped gzipped.
