DATA_URL <- "https://geo.bharatviz.org/_censusindia"

#' Remote files with their version directory and pinned md5 (inst/manifest.csv).
#' @noRd
census_manifest <- function() {
  path <- system.file("manifest.csv", package = "censusindia", mustWork = TRUE)
  utils::read.csv(path, colClasses = "character")
}

#' @noRd
cache_path <- function(version, file) file.path(census_cache_dir(), version, file)

#' Downloaded data cache
#'
#' Census boundaries and the seven largest tables are downloaded on first use,
#' checked against a pinned MD5 checksum, and kept here for later sessions.
#'
#' The cache lives in [tools::R_user_dir()]. Set the option
#' `censusindia.cache_dir` to use another directory.
#'
#' @return `census_cache_dir()` returns the cache path, which may not exist
#'   yet. `clear_census_cache()` deletes it and invisibly returns that path.
#' @seealso [census_download()] to fetch everything at once;
#'   [clear_geometry_cache()] to release what the session holds in memory.
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
#' Fetches every boundary file and large table not yet in [census_cache_dir()],
#' so later calls work offline.
#'
#' @return The cache directory, invisibly.
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

#' Manifest files not yet in the cache.
#' @noRd
census_missing <- function() {
  m <- census_manifest()
  m$file[!file.exists(cache_path(m$version, m$file))]
}

#' Path to a remote file, downloading it into the cache if absent.
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
    ))
  }
  if (!identical(unname(tools::md5sum(tmp)), entry$md5)) {
    cli::cli_abort(c(
      "Downloaded {.file {file}} does not match its expected checksum.",
      "i" = "The file may be truncated. Try again; if it persists, please report it at {.url https://github.com/saketlab/censusindia/issues}."
    ))
  }
  file.rename(tmp, path)
  path
}

#' @noRd
remote_table <- function(name) {
  rlang::env_cache(.session_cache, name, readRDS(census_file(paste0(name, ".rds"))))
}

#' Census 2011 demographics (PCA)
#'
#' Population, SC/ST, and literacy counts from the 2011 Primary Census
#' Abstract at all geographic levels (India, state, district, subdistrict,
#' town/village, ward), split by total/rural/urban sector. Downloaded on first
#' use; see [census_cache_dir()]. Use [at_level()] before summing.
#'
#' @return A tibble with 751,594 rows and 28 columns:
#' \describe{
#'   \item{state_code}{Numeric state code}
#'   \item{district_code}{Numeric district code}
#'   \item{subdistrict_code}{Numeric subdistrict code}
#'   \item{town_village_code}{Town or village code}
#'   \item{ward_code}{Ward code}
#'   \item{level}{Geographic level (india, state, district, subdistrict, town, village, ward)}
#'   \item{name}{Name of the geographic unit}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{sector}{Sector: "total", "rural", or "urban"}
#'   \item{households}{Number of households}
#'   \item{population_total,population_male,population_female}{Total, male, and female population}
#'   \item{pop_0_6_total,pop_0_6_male,pop_0_6_female}{Population aged 0-6 years}
#'   \item{sc_total,sc_male,sc_female}{Scheduled Caste population}
#'   \item{st_total,st_male,st_female}{Scheduled Tribe population}
#'   \item{literate_total,literate_male,literate_female}{Literate population}
#'   \item{illiterate_total,illiterate_male,illiterate_female}{Illiterate population}
#' }
#' @source Census of India 2011, Primary Census Abstract.
#' @examplesIf interactive()
#' census_2011_demographics() |> at_level("state")
#' @export
census_2011_demographics <- function() remote_table("census_2011_demographics")

#' Census 2011 workers (PCA)
#'
#' Worker classification from the 2011 Primary Census Abstract at all
#' geographic levels, split by total/rural/urban sector. Main and marginal
#' workers are broken down by activity (cultivators, agricultural labourers,
#' household industry, other workers). Downloaded on first use; see
#' [census_cache_dir()]. Use [at_level()] before summing.
#'
#' @return A tibble with 751,594 rows and 42 columns:
#' \describe{
#'   \item{state_code,district_code,subdistrict_code,town_village_code,ward_code}{Geographic codes}
#'   \item{level}{Geographic level (india, state, district, subdistrict, town, village, ward)}
#'   \item{name}{Name of the geographic unit}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{sector}{Sector: "total", "rural", or "urban"}
#'   \item{total_workers_total,total_workers_male,total_workers_female}{All workers}
#'   \item{main_workers_total,main_workers_male,main_workers_female}{Main workers}
#'   \item{main_cultivators_total,main_cultivators_male,main_cultivators_female}{Main cultivators}
#'   \item{main_agri_labour_total,main_agri_labour_male,main_agri_labour_female}{Main agricultural labourers}
#'   \item{main_hh_industry_total,main_hh_industry_male,main_hh_industry_female}{Main household industry workers}
#'   \item{main_other_total,main_other_male,main_other_female}{Main other workers}
#'   \item{marginal_workers_total,marginal_workers_male,marginal_workers_female}{Marginal workers}
#'   \item{marginal_cultivators_total,marginal_cultivators_male,marginal_cultivators_female}{Marginal cultivators}
#'   \item{marginal_agri_labour_total,marginal_agri_labour_male,marginal_agri_labour_female}{Marginal agricultural labourers}
#'   \item{marginal_hh_industry_total,marginal_hh_industry_male,marginal_hh_industry_female}{Marginal household industry workers}
#'   \item{marginal_other_total,marginal_other_male,marginal_other_female}{Marginal other workers}
#' }
#' @source Census of India 2011, Primary Census Abstract.
#' @examplesIf interactive()
#' census_2011_workers() |> at_level("state")
#' @export
census_2011_workers <- function() remote_table("census_2011_workers")

#' Census 2011 marginal worker detail (PCA)
#'
#' Marginal workers from the 2011 Primary Census Abstract split by duration
#' of work (3-6 months and 0-3 months) and by activity, plus non-workers,
#' at all geographic levels and total/rural/urban sector. Downloaded on first
#' use; see [census_cache_dir()]. Use [at_level()] before summing.
#'
#' @return A tibble with 751,594 rows and 42 columns:
#' \describe{
#'   \item{state_code,district_code,subdistrict_code,town_village_code,ward_code}{Geographic codes}
#'   \item{level}{Geographic level (india, state, district, subdistrict, town, village, ward)}
#'   \item{name}{Name of the geographic unit}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{sector}{Sector: "total", "rural", or "urban"}
#'   \item{marginal_workers_3_6_total,marginal_workers_3_6_male,marginal_workers_3_6_female}{Marginal workers employed 3-6 months}
#'   \item{marg_cultivators_3_6_total,marg_cultivators_3_6_male,marg_cultivators_3_6_female}{Marginal cultivators, 3-6 months}
#'   \item{marg_agri_labour_3_6_total,marg_agri_labour_3_6_male,marg_agri_labour_3_6_female}{Marginal agricultural labourers, 3-6 months}
#'   \item{marg_hh_industry_3_6_total,marg_hh_industry_3_6_male,marg_hh_industry_3_6_female}{Marginal household industry workers, 3-6 months}
#'   \item{marg_other_3_6_total,marg_other_3_6_male,marg_other_3_6_female}{Marginal other workers, 3-6 months}
#'   \item{marginal_workers_0_3_total,marginal_workers_0_3_male,marginal_workers_0_3_female}{Marginal workers employed 0-3 months}
#'   \item{marg_cultivators_0_3_total,marg_cultivators_0_3_male,marg_cultivators_0_3_female}{Marginal cultivators, 0-3 months}
#'   \item{marg_agri_labour_0_3_total,marg_agri_labour_0_3_male,marg_agri_labour_0_3_female}{Marginal agricultural labourers, 0-3 months}
#'   \item{marg_hh_industry_0_3_total,marg_hh_industry_0_3_male,marg_hh_industry_0_3_female}{Marginal household industry workers, 0-3 months}
#'   \item{marg_other_0_3_total,marg_other_0_3_male,marg_other_0_3_female}{Marginal other workers, 0-3 months}
#'   \item{non_workers_total,non_workers_male,non_workers_female}{Non-workers}
#' }
#' @source Census of India 2011, Primary Census Abstract.
#' @examplesIf interactive()
#' census_2011_marginal_detail() |> at_level("state")
#' @export
census_2011_marginal_detail <- function() remote_table("census_2011_marginal_detail")

#' Census 2011 mother tongue data (C-16)
#'
#' Mother tongue speakers by language at state and district levels from the
#' 2011 Census C-16 tables, with rural/urban and male/female breakdowns.
#' Downloaded on first use; see [census_cache_dir()]. For per-district
#' or per-subdistrict counts that sum correctly, use [census_languages()].
#'
#' @return A tibble with 350,157 rows and 18 columns:
#' \describe{
#'   \item{state_code}{Numeric state code}
#'   \item{state_name}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_code}{District code ("000" for state total)}
#'   \item{area_name}{Name of the state or district}
#'   \item{language_code}{Census language code}
#'   \item{language_name}{Name of the language or dialect}
#'   \item{language_level}{L1 for main languages, L2 for dialects}
#'   \item{language_group}{Numeric language group code}
#'   \item{total_persons}{Total speakers}
#'   \item{total_males}{Male speakers}
#'   \item{total_females}{Female speakers}
#'   \item{rural_persons}{Rural speakers}
#'   \item{rural_males}{Rural male speakers}
#'   \item{rural_females}{Rural female speakers}
#'   \item{urban_persons}{Urban speakers}
#'   \item{urban_males}{Urban male speakers}
#'   \item{urban_females}{Urban female speakers}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables.
#' @examplesIf interactive()
#' census_2011_mother_tongue() |> head()
#' @export
census_2011_mother_tongue <- function() remote_table("census_2011_mother_tongue")

#' Census 2011 subdistrict languages (C-16)
#'
#' Mother tongue speakers by language at subdistrict level from the 2011
#' Census C-16 tables, with male/female and rural/urban breakdowns. The
#' district rows that share each subdistrict's `district_code` are excluded,
#' so these rows sum to the matching row of [census_2011_district_languages].
#' Downloaded on first use; see [census_cache_dir()].
#'
#' @return A tibble with 144,134 rows and 11 columns:
#' \describe{
#'   \item{state_code}{Numeric state code}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_code}{Numeric district code}
#'   \item{area_name}{Name of the subdistrict}
#'   \item{language_name}{Name of the language}
#'   \item{language_group}{Numeric language group code}
#'   \item{total_speakers}{Total speakers}
#'   \item{male_speakers}{Male speakers}
#'   \item{female_speakers}{Female speakers}
#'   \item{rural_speakers}{Rural speakers}
#'   \item{urban_speakers}{Urban speakers}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables.
#' @examplesIf interactive()
#' census_2011_subdistrict_languages() |> head()
#' @export
census_2011_subdistrict_languages <- function() remote_table("census_2011_subdistrict_languages")

#' Population projections, district level, Census 2011 boundaries, by age group (2012-2031)
#'
#' Age-stratified detail behind [population_projections_district], on Census
#' 2011 district boundaries (no LGD spatial apportionment involved). Same
#' age-group scheme as [population_projections_district_lgd_age()]: single
#' years 0-14, then 5-year bands through 80+. Downloaded on first use;
#' see [census_cache_dir()].
#'
#' Values are as printed in the IIPS report. District names match
#' [population_projections_district].
#'
#' The following are NA in the PDF: Theni (Tamil Nadu) in 2017-2031, and
#' the 80+ group of Moga (Punjab) and Tapi (Gujarat) in 2022-2026. Karnataka's
#' age tables sum to a different projection from
#' [population_projections_district].
#'
#' @return A tibble with 371,200 rows and 7 columns:
#' \describe{
#'   \item{year}{Projection year (annual, 2012-2031)}
#'   \item{state_name_harmonized}{Harmonized state name for joining}
#'   \item{district}{District name (Census 2011 naming convention)}
#'   \item{age_group}{Single years "0".."14", then 5-year bands "15-19"
#'     through "80+"}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @source Same as [population_projections_district].
#' @examplesIf interactive()
#' population_projections_district_age() |> head()
#' @export
population_projections_district_age <- function() remote_table("population_projections_district_age")

#' Population projections, district level, LGD boundaries, by age group (2012-2031)
#'
#' Age-stratified detail behind [population_projections_district_lgd]: single
#' years of age for 0-14, five-year bands from 15-19 through 80+. Fixes the
#' same double-counted "All ages" row bug documented on that table. Downloaded
#' on first use; see [census_cache_dir()].
#'
#' @return A tibble with 454,140 rows and 7 columns:
#' \describe{
#'   \item{year}{Projection year (annual, 2012-2031)}
#'   \item{state_name_harmonized}{Harmonized state name for joining. See
#'     [population_projections_district_lgd] for the Dadra & Nagar Haveli /
#'     Daman & Diu merged-UT caveat.}
#'   \item{district}{District name (LGD naming convention)}
#'   \item{age_group}{Single years "0".."14", then 5-year bands "15-19"
#'     through "80+". Non-overlapping: summing all rows for a district-year
#'     reproduces [population_projections_district_lgd].}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @source Same as [population_projections_district_lgd].
#' @examplesIf interactive()
#' population_projections_district_lgd_age() |> head()
#' @export
population_projections_district_lgd_age <- function() remote_table("population_projections_district_lgd_age")
