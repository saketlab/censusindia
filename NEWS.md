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
