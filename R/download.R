DATA_URL <- "https://geo.bharatviz.org/_censusindia"

#' Gives the remote files, their version directory and their pinned MD5
#' (inst/manifest.csv).
#' @noRd
census_manifest <- function() {
  path <- system.file("manifest.csv", package = "censusindia", mustWork = TRUE)
  utils::read.csv(path, colClasses = "character")
}

#' @noRd
cache_path <- function(version, file) file.path(census_cache_dir(), version, file)

#' Downloaded data cache
#'
#' Census boundary files and the seven largest tables are downloaded on first
#' use, verified against pinned MD5 checksums, and cached on disk across R
#' sessions.
#'
#' By default the cache lives in [tools::R_user_dir()]. Set
#' `options(censusindia.cache_dir = ...)` to use a different directory.
#'
#' @return `census_cache_dir()` returns the cache directory path (which may not
#'   yet exist on disk). `clear_census_cache()` deletes the cache directory,
#'   clears the in-memory session cache, and returns the path invisibly.
#' @seealso [census_download()] downloads all remote files upfront;
#'   [clear_geometry_cache()] evicts objects cached in session memory.
#' @examples
#' census_cache_dir()
#' @export
census_cache_dir <- function() {
  getOption("censusindia.cache_dir", tools::R_user_dir("censusindia", "cache"))
}

#' @rdname census_cache_dir
#' @export
clear_census_cache <- function() {
  dir <- census_cache_dir()
  unlink(dir, recursive = TRUE)
  clear_geometry_cache()
  invisible(dir)
}

#' Download all remote data
#'
#' Downloads every boundary file and remote table not yet present in
#' [census_cache_dir()]. Once complete, all package functions work offline.
#'
#' @return The cache directory path, invisibly.
#' @examplesIf interactive()
#' census_download()
#' @export
census_download <- function() {
  dir <- census_cache_dir()
  todo <- census_missing()
  if (length(todo)) {
    for (i in cli::cli_progress_along(todo, "Downloading censusindia data")) {
      suppressMessages(census_file(todo[i]))
    }
    cli::cli_inform("Downloaded {length(todo)} file{?s} to {.path {dir}}.")
  } else {
    cli::cli_inform("All censusindia data is already in {.path {dir}}.")
  }
  invisible(dir)
}

#' Gives the manifest files that are not in the cache.
#' @noRd
census_missing <- function() {
  m <- census_manifest()
  m$file[!file.exists(cache_path(m$version, m$file))]
}

#' Gives the path to a remote file. If the file is not in the cache, the
#' function downloads it first.
#' @noRd
census_file <- function(file) {
  entry <- census_manifest()
  entry <- entry[entry$file == file, ]
  if (nrow(entry) != 1) {
    cli::cli_abort("{.file {file}} is not in the censusindia data manifest.")
  }
  path <- cache_path(entry$version, file)
  if (file.exists(path)) {
    return(path)
  }
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  url <- paste(DATA_URL, entry$version, file, sep = "/")

  # download beside the target so the rename is atomic
  tmp <- tempfile(tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  op <- options(timeout = max(600, getOption("timeout")))
  on.exit(options(op), add = TRUE)

  cli::cli_inform("Downloading {.file {file}} to {.path {dirname(path)}}")
  ok <- tryCatch(
    utils::download.file(url, tmp, mode = "wb", quiet = TRUE) == 0,
    error = function(e) FALSE,
    warning = function(w) FALSE
  )
  if (!ok) {
    cli::cli_abort(c(
      "Could not download {.url {url}}.",
      "i" = "This file is fetched on first use. Check your internet connection and try again."
    ), class = "censusindia_download_error")
  }
  if (!identical(unname(tools::md5sum(tmp)), entry$md5)) {
    cli::cli_abort(c(
      "Downloaded {.file {file}} does not match its expected checksum.",
      "i" = "The file may be truncated. Try again; if it persists, please report it at {.url https://github.com/saketlab/censusindia/issues}."
    ), class = "censusindia_download_error")
  }
  file.rename(tmp, path)
  path
}

#' @noRd
remote_table <- function(name) {
  # stored on the package schema (data-raw/legacy.R converts them at build time)
  rlang::env_cache(.session_cache, name, readRDS(census_file(paste0(name, ".rds"))))
}

#' Census 2011 demographics (PCA)
#'
#' Population, SC/ST and literacy counts from the 2011 Primary Census Abstract.
#' The table has all geographic levels (India, state, district, subdistrict,
#' town/village, ward) and the total, rural and urban sectors. The package
#' downloads the table on first use (refer to [census_cache_dir()]). Use
#' [at_level()] before you add rows.
#'
#' @return A tibble with 751,594 rows and 29 columns. Male and female columns
#'   have a \code{_male} or \code{_female} suffix. A column without a suffix
#'   gives persons:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level: "india", "state", "district",
#'     "subdistrict", "town", "village" or "ward"}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code,district_code,subdistrict_code,town_village_code,ward_code}{Integer
#'     geographic codes. NA above the level of the unit}
#'   \item{state_name_harmonized}{Harmonized state name. Use it to join datasets}
#'   \item{name}{Name of the geographic unit}
#'   \item{households}{Number of households}
#'   \item{population,males,females}{Total, male, and female population}
#'   \item{population_0_6,population_0_6_male,population_0_6_female}{Population of age 0-6 years}
#'   \item{sc_population,sc_population_male,sc_population_female}{Scheduled Caste population}
#'   \item{st_population,st_population_male,st_population_female}{Scheduled Tribe population}
#'   \item{literate,literate_male,literate_female}{Literate population}
#'   \item{illiterate,illiterate_male,illiterate_female}{Illiterate population}
#' }
#' @source Census of India 2011, Primary Census Abstract.
#' @examplesIf interactive()
#' census_2011_demographics() |> at_level("state")
#' @export
census_2011_demographics <- function() remote_table("census_2011_demographics")

#' Census 2011 workers (PCA)
#'
#' Workers by type from the 2011 Primary Census Abstract. The table has all
#' geographic levels and the total, rural and urban sectors. It divides main and
#' marginal workers by activity: cultivators, agricultural labourers, household
#' industry and other workers. The package downloads the table on first use
#' (refer to [census_cache_dir()]). Use [at_level()] before you add rows.
#'
#' @return A tibble with 751,594 rows and 43 columns. Male and female columns
#'   have a \code{_male} or \code{_female} suffix. A column without a suffix
#'   gives persons:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level: "india", "state", "district",
#'     "subdistrict", "town", "village" or "ward"}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code,district_code,subdistrict_code,town_village_code,ward_code}{Integer
#'     geographic codes. NA above the level of the unit}
#'   \item{state_name_harmonized}{Harmonized state name. Use it to join datasets}
#'   \item{name}{Name of the geographic unit}
#'   \item{workers,workers_male,workers_female}{All workers}
#'   \item{main_workers,main_workers_male,main_workers_female}{Main workers}
#'   \item{main_cultivators,main_cultivators_male,main_cultivators_female}{Main cultivators}
#'   \item{main_agri_labour,main_agri_labour_male,main_agri_labour_female}{Main agricultural labourers}
#'   \item{main_hh_industry,main_hh_industry_male,main_hh_industry_female}{Main household industry workers}
#'   \item{main_other,main_other_male,main_other_female}{Main other workers}
#'   \item{marginal_workers,marginal_workers_male,marginal_workers_female}{Marginal workers}
#'   \item{marginal_cultivators,marginal_cultivators_male,marginal_cultivators_female}{Marginal cultivators}
#'   \item{marginal_agri_labour,marginal_agri_labour_male,marginal_agri_labour_female}{Marginal agricultural labourers}
#'   \item{marginal_hh_industry,marginal_hh_industry_male,marginal_hh_industry_female}{Marginal household industry workers}
#'   \item{marginal_other,marginal_other_male,marginal_other_female}{Marginal other workers}
#' }
#' @source Census of India 2011, Primary Census Abstract.
#' @examplesIf interactive()
#' census_2011_workers() |> at_level("state")
#' @export
census_2011_workers <- function() remote_table("census_2011_workers")

#' Census 2011 marginal worker detail (PCA)
#'
#' Marginal workers from the 2011 Primary Census Abstract, divided by the
#' duration of work (3-6 months and 0-3 months) and by activity. The table also
#' gives non-workers. It has all geographic levels and the total, rural and
#' urban sectors. The package downloads the table on first use. Refer to
#' [census_cache_dir()]. Use [at_level()] before you add rows.
#'
#' @return A tibble with 751,594 rows and 43 columns. Male and female columns
#'   have a \code{_male} or \code{_female} suffix. A column without a suffix
#'   gives persons:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level: "india", "state", "district",
#'     "subdistrict", "town", "village" or "ward"}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code,district_code,subdistrict_code,town_village_code,ward_code}{Integer
#'     geographic codes. NA above the level of the unit}
#'   \item{state_name_harmonized}{Harmonized state name. Use it to join datasets}
#'   \item{name}{Name of the geographic unit}
#'   \item{marginal_workers_3_6,marginal_workers_3_6_male,marginal_workers_3_6_female}{Marginal workers with 3-6 months of work}
#'   \item{marginal_cultivators_3_6,marginal_cultivators_3_6_male,marginal_cultivators_3_6_female}{Marginal cultivators, 3-6 months}
#'   \item{marginal_agri_labour_3_6,marginal_agri_labour_3_6_male,marginal_agri_labour_3_6_female}{Marginal agricultural labourers, 3-6 months}
#'   \item{marginal_hh_industry_3_6,marginal_hh_industry_3_6_male,marginal_hh_industry_3_6_female}{Marginal household industry workers, 3-6 months}
#'   \item{marginal_other_3_6,marginal_other_3_6_male,marginal_other_3_6_female}{Marginal other workers, 3-6 months}
#'   \item{marginal_workers_0_3,marginal_workers_0_3_male,marginal_workers_0_3_female}{Marginal workers with 0-3 months of work}
#'   \item{marginal_cultivators_0_3,marginal_cultivators_0_3_male,marginal_cultivators_0_3_female}{Marginal cultivators, 0-3 months}
#'   \item{marginal_agri_labour_0_3,marginal_agri_labour_0_3_male,marginal_agri_labour_0_3_female}{Marginal agricultural labourers, 0-3 months}
#'   \item{marginal_hh_industry_0_3,marginal_hh_industry_0_3_male,marginal_hh_industry_0_3_female}{Marginal household industry workers, 0-3 months}
#'   \item{marginal_other_0_3,marginal_other_0_3_male,marginal_other_0_3_female}{Marginal other workers, 0-3 months}
#'   \item{non_workers,non_workers_male,non_workers_female}{Non-workers}
#' }
#' @source Census of India 2011, Primary Census Abstract.
#' @examplesIf interactive()
#' census_2011_marginal_detail() |> at_level("state")
#' @export
census_2011_marginal_detail <- function() remote_table("census_2011_marginal_detail")

#' Census 2011 mother tongue data (C-16)
#'
#' Mother tongue speakers by language from the 2011 Census C-16 tables, at
#' state, district and subdistrict level. The counts are by sector and by sex.
#' The package downloads the table on first use. Refer to [census_cache_dir()].
#' [census_languages()] gives the same counts for one level at a time, without
#' the "Others" residual rows.
#'
#' The source file has no subdistrict code. A district and its subdistricts
#' have the same `district_code`. The build sets `geography` from the row
#' order: the rows of the district come first.
#'
#' The district rows, the
#' subdistrict rows and the [census_2011_pca] population of a district have the
#' same total. Filter to one `geography` before you add rows. The table
#' also stores sector as rows, so filter to `sector == "total"` too.
#'
#' In Shajapur district (Madhya Pradesh), five tehsils (Agar, Shajapur,
#' Gulana, Moman Badodiya, Shujalpur) have only one Hindi row each. The L1 row of Kalapipal holds the Hindi speakers of all six
#' tehsils. The district rows are complete.
#'
#' @return A tibble with 1,050,471 rows (350,157 for each sector) and 16 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{"state", "district" or "subdistrict"}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name. Use it to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district_code}{Integer district code. NA on state rows}
#'   \item{district}{District name as in [census_2011_pca]. NA on state rows}
#'   \item{subdistrict}{Subdistrict name from the source. NA above subdistrict level}
#'   \item{language_code}{Census language code}
#'   \item{language_name}{Name of the language or dialect}
#'   \item{language_level}{L1 for main languages, L2 for dialects}
#'   \item{language_group}{Integer language group code}
#'   \item{speakers}{Speakers}
#'   \item{speakers_male}{Male speakers}
#'   \item{speakers_female}{Female speakers}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables.
#' @examplesIf interactive()
#' census_2011_mother_tongue() |> head()
#' @export
census_2011_mother_tongue <- function() remote_table("census_2011_mother_tongue")

#' Census 2011 subdistrict languages (C-16)
#'
#' Mother tongue speakers by language at subdistrict level from the 2011 Census
#' C-16 tables, by sector and by sex. The table does not include the district
#' rows that have the same `district_code` as the subdistricts. The rows
#' of a district add to its row in [census_2011_district_languages]. The
#' package downloads the table on first use. Refer to [census_cache_dir()].
#'
#' The table stores sector as rows (144,134 rows for each sector). Filter to
#' `sector == "total"` before you add rows, or use [census_languages()], which
#' applies this filter. `speakers_male` and `speakers_female` are NA on rural
#' and urban rows.
#'
#' @return A tibble with 432,402 rows and 12 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level ("subdistrict")}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name. Use it to join datasets}
#'   \item{district_code}{Integer code of the parent district}
#'   \item{subdistrict}{Name of the subdistrict}
#'   \item{language_name}{Name of the language}
#'   \item{language_group}{Integer language group code}
#'   \item{speakers}{Speakers}
#'   \item{speakers_male}{Male speakers. NA on rural and urban rows}
#'   \item{speakers_female}{Female speakers. NA on rural and urban rows}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables.
#' @examplesIf interactive()
#' census_2011_subdistrict_languages() |> head()
#' @export
census_2011_subdistrict_languages <- function() remote_table("census_2011_subdistrict_languages")

#' Population projections: district level, Census 2011 boundaries, by age group (2012-2031)
#'
#' The age-group detail of [population_projections_district], on Census 2011
#' district boundaries. No LGD area apportionment applies. The age groups are
#' the same as in [population_projections_district_lgd_age()]: single years
#' 0-14, then 5-year bands to 80+. The package downloads the table on first
#' use. Refer to [census_cache_dir()].
#'
#' The values are from the printed IIPS report. The district names agree
#' with [population_projections_district].
#'
#' The PDF does not print two blocks, so the package derives them. Moga
#' (Punjab) and Tapi (Gujarat) have no 80+ row for 2022-2026. Their 80+ value
#' is the printed All ages minus the other printed age groups. The 2017-2031
#' pages of Theni (Tamil Nadu) repeat the numbers of Madurai.
#'
#' The printed age tables for Karnataka are a different projection from Table 8
#' of the same report. The package keeps their age-sex shares and scales them
#' to Table 8.
#' Between the five-year points of Table 8, it interpolates geometrically.
#' The age groups of each district add to
#' [population_projections_district]. The LGD tables come from these values.
#'
#' @return A tibble with 371,200 rows and 9 columns:
#' \describe{
#'   \item{year}{Projection year (annual, 2012-2031)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer 2011 census state code}
#'   \item{state_name_harmonized}{Harmonized state name. Use it to join datasets}
#'   \item{district}{District name as in Census 2011}
#'   \item{age_group}{Single years "0".."14", then 5-year bands "15-19"
#'     to "80+"}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @source Same as [population_projections_district].
#' @examplesIf interactive()
#' population_projections_district_age() |> head()
#' @export
population_projections_district_age <- function() remote_table("population_projections_district_age")

#' Population projections: district level, LGD boundaries, by age group (2012-2031)
#'
#' The age-group detail of [population_projections_district_lgd]: single years
#' of age for 0-14, then five-year bands from 15-19 to 80+. The package
#' downloads the table on first use. Refer to [census_cache_dir()].
#'
#' @return A tibble with 454,140 rows and 9 columns:
#' \describe{
#'   \item{year}{Projection year (annual, 2012-2031)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer 2011 census state code}
#'   \item{state_name_harmonized}{Harmonized state name. Use it to join
#'     datasets. Refer to [population_projections_district_lgd] for the
#'     caveat about the merged UT Dadra & Nagar Haveli and Daman & Diu.}
#'   \item{district}{District name as in the LGD}
#'   \item{age_group}{Single years "0".."14", then 5-year bands "15-19"
#'     to "80+". The groups do not overlap. The sum of all rows for a
#'     district and year equals [population_projections_district_lgd].}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @source Same as [population_projections_district_lgd].
#' @examplesIf interactive()
#' population_projections_district_lgd_age() |> head()
#' @export
population_projections_district_lgd_age <- function() remote_table("population_projections_district_lgd_age")
