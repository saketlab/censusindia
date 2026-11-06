# censusindia 0.4.0 - Development

* New `population_projections()`: all levels and sectors in one table.
* `get_population()` gains `geography = "subdistrict"` and `method`.
* New datasets `population_projections_state_urban` and
  `population_projections_state_rural`.
* `get_census_boundaries()` gains `state`. With `geography = "village"`, it gives
  2011 village and town polygons, and `attach_geometry()` joins them by census
  code. Most large city corporations have no polygon.
* New maps: `plot_bubble_map()`, `census_bubble_layer()` and
  `plot_dot_density_map()`.
* `plot_map()` accepts a categorical `fill_var` and gains `state`, `facet`,
  `dark`, `unit_boundary_color` and `unit_boundary_width`.
* `theme_census_map()` gains `dark`, and `get_palette()` gains `"inferno"`.
* New measures: `area_km2()`, `percent_change()`, `shannon_entropy()`,
  `effective_number()`, `herfindahl_index()`, `greenberg_index()`,
  `gini_coefficient()` and `language_diversity()`.
* New functions to compare districts: `composition_matrix()`,
  `composition_distance()`, `composition_clusters()`, `composition_pca()`,
  `pca_variance()`, `pca_scores()` and `adjusted_rand_index()`.
* New `list_census_datasets()` and `census_colors()`.
* New article on population density maps.

# censusindia 0.3.0

## Breaking changes

All tables, accessors and API routes now use one column schema:
`year`, `geography`, `sector`, `state_code`,
`state_name_harmonized`, `state_name`, `district_code`, `district`,
`subdistrict_code`, `subdistrict`. Codes are integers.

| Old | New |
|---|---|
| `name` (state/district tables), `district_name`, `area_name` | `district` (or `subdistrict`) |
| `state` (source spelling) | `state_name` |
| `level`, `"sub-district"` | `geography`, `"subdistrict"` |
| `population_total`, `population_male`, `population_female`, `total_persons`, ... | `population`, `males`, `females` |
| `<x>_total` (`literate_total`, `workers_total`, `sc_total`, ...) | `<x>` (`literate`, `workers`, `sc_population`, ...) |
| `<x>_persons`, `<x>_males`, `<x>_females` (1981) | `<x>`, `<x>_male`, `<x>_female` |
| `marg_*` | `marginal_*` |
| `total_speakers`, `male_speakers`, ... | `speakers`, `speakers_male`, ... |
| `percentage` (SC/ST tables) | `percent` |
| 1961 `literacy_total`, `literacy_male`, `literacy_female` | `literacy_rate`, `literacy_rate_male`, `literacy_rate_female` |
| `population_rural`, `population_urban` columns (1971, languages) | rows with `sector = "rural"` / `"urban"` |

* Filter `sector == "total"` before you sum rows. `census_languages()` takes
  `sector` and `state`.
* `get_census()` returns the same identifier columns for all years.
  `variables = "population_rural"` is `sector = "rural"`.
* `population_projections_state_age` is in persons (was thousands).
* `census_variables` has one row per variable and geography.
* The API returns the R table columns. Read the state from
  `state_name_harmonized`.

## Data corrections

* `census_1971` and `census_1981` agree with the printed Census volumes.
  `inst/ocr-corrections.csv` gives the page and evidence for each corrected cell.
  * 1981: in each grid, persons = males + females and total = rural + urban.
    Districts sum to their state. Areas are in km2.
    Towns filed as districts are `geography = "town"`. Guna has its urban row.
  * 1971: the ten missing Mysore districts are added. Madras is wholly urban.
* `census_2011_sc_st`, `census_2011_tribes`:
  * `percent` uses the `census_2011_pca` district population (#4).
  * `parent_tribe` marks the constituent tribes of Naga in Nagaland. Rows with
    no `parent_tribe` sum to the PCA ST count.
  * District names agree with `census_2011_pca`.
* `census_2011_mother_tongue()` labels district and subdistrict rows.
* `population_projections_district`: Uttar Pradesh 2016 held the report's 2017
  column.
* `population_projections_district_age()`: Karnataka is scaled to the district
  totals. The LGD tables follow.
* `state_name_harmonized`: "MADRAS", "ORRISA" and the 1971 Laccadive name are
  Tamil Nadu, Odisha and Lakshadweep.

## Other changes

* `attach_geometry()` joins districts for the SC/ST and language tables.
* `inst/provenance.csv` gives the source, build script, test and content hash
  of each dataset. A test fails when a dataset and its hash disagree.

# censusindia 0.2.1

* `serve()` runs a plumber REST API on the accessors and the shipped datasets.
* New data: `census_1931_castes` and `census_1931_exterior_castes`.
* `census_subdistricts_2011` has all Census 2011 subdistricts and sums to
  `census_2011_pca`.
* `census_1971` and `census_1981` store an empty rural or urban sector as 0.
* `population_projections_state` has the merged "Dadra & Nagar Haveli and Daman
  & Diu" row. Drop it or the two old rows before you sum states.
* The district projection tables have no NA. Theni 2017-2031 follows Tamil
  Nadu's growth path. Moga and Tapi 80+ (2022-2026) is All ages minus the other
  groups.

# censusindia 0.2.0

* First CRAN release.

## Breaking changes

* Boundaries and seven large tables download on first use, MD5-checked and cached in
  `census_cache_dir()`. Those tables are now functions: `census_2011_workers()` etc.

## Other changes

* `census_download()` downloads all remote files at once. `clear_census_cache()` removes them.
* `clear_geometry_cache()` also releases downloaded tables held in memory.
* `plot_map()` reports a failed boundary download. It does not draw a map with no base layer.
* `at_level()` accepts all tables with a `level` column, for example `census_1981`.

# censusindia 0.1.2

* Population projection tables checked cell by cell against the printed MoHFW and IIPS reports.
* Boundary files shipped gzipped.
