#' Census population time series (1901-2011)
#'
#' Decadal population at state and district levels, 1901-2011.
#'
#' @format A tibble with 7,901 rows and 12 columns:
#' \describe{
#'   \item{year}{Census year (1901, 1911, ..., 2011)}
#'   \item{geography}{Geographic level: "state" or "district"}
#'   \item{state_code}{Numeric state code}
#'   \item{state_name}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_code}{Numeric district code (0 for state-level)}
#'   \item{name}{Name of the state or district}
#'   \item{population}{Total population}
#'   \item{males}{Male population}
#'   \item{females}{Female population}
#'   \item{variation_absolute}{Absolute change from previous census}
#'   \item{variation_percent}{Percentage change from previous census}
#' }
#' @section Coverage limits:
#' Sikkim, Mizoram and Daman & Diu are absent from every year, so 2011 sums to
#' 1,208,903,947 across 626 districts rather than 1,210,854,977 across 640.
#' [get_census()] uses the Primary Census Abstract for 2001 and 2011 instead.
#' District rows also fall short of their state totals before 1961 (57 districts
#' carry no population in 1901-1941) and in 1981, where all 27 Assam districts
#' are missing while the state estimate is present. The `year` column further
#' carries 1900, 1910, 1940, 1948, 1950, 1960, 1962 and 2021, which are not
#' censuses; use [census_years()] before any `lag()`.
#'
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_population_time_series"

#' Census 1961 literacy data
#'
#' District-level literacy rates from the 1961 Census.
#'
#' @format A tibble with 347 rows and 8 columns:
#' \describe{
#'   \item{year}{Census year (1961)}
#'   \item{state}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district}{Name of the district}
#'   \item{state_district_code}{Combined state-district code}
#'   \item{literacy_total}{Total literacy rate (percent)}
#'   \item{literacy_male}{Male literacy rate (percent)}
#'   \item{literacy_female}{Female literacy rate (percent)}
#' }
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_1961_literacy"

#' Census 1971 Primary Census Abstract
#'
#' State and district population from the 1971 Census with rural/urban
#' breakdown and SC/ST populations.
#'
#' @format A tibble with 370 rows and 21 columns:
#' \describe{
#'   \item{year}{Census year (1971)}
#'   \item{geography}{Geographic level: "state" or "district"}
#'   \item{state}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{name}{Name of the state or district}
#'   \item{area_km2}{Area in square kilometers}
#'   \item{population_total}{Total population}
#'   \item{population_rural}{Rural population}
#'   \item{population_urban}{Urban population}
#'   \item{males_total}{Total male population}
#'   \item{males_rural}{Rural male population}
#'   \item{males_urban}{Urban male population}
#'   \item{females_total}{Total female population}
#'   \item{females_rural}{Rural female population}
#'   \item{females_urban}{Urban female population}
#'   \item{sc_population_total}{Total Scheduled Caste population}
#'   \item{sc_population_rural}{Rural Scheduled Caste population}
#'   \item{sc_population_urban}{Urban Scheduled Caste population}
#'   \item{st_population_total}{Total Scheduled Tribe population}
#'   \item{st_population_rural}{Rural Scheduled Tribe population}
#'   \item{st_population_urban}{Urban Scheduled Tribe population}
#' }
#' @section Known defects:
#' Population, males and females partition exactly into rural and urban. The
#' SC/ST columns do not: one `sc_population` row and five `st_population` rows
#' fail `rural + urban == total`, the largest gaps being 493,272 (Hooghly, SC)
#' and 472,910 (Jhabua, ST). District coverage is also short of the state total
#' for Mysore and Tamil Nadu.
#'
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_1971"

#' Census 1981 Primary Census Abstract
#'
#' State and district data from the 1981 Census with literacy and worker
#' classification.
#'
#' @format A tibble with 2,364 rows and 39 columns including:
#' \describe{
#'   \item{year}{Census year (1981)}
#'   \item{geo_id}{Unique geographic identifier}
#'   \item{geo_name}{Name of the geographic unit}
#'   \item{level}{Geographic level (india, state, district)}
#'   \item{state}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district}{Name of the district (if applicable)}
#'   \item{sector}{Sector: "total", "rural", or "urban"}
#'   \item{area_km2}{Area in square kilometers}
#'   \item{total_persons}{Total population}
#'   \item{total_males}{Male population}
#'   \item{total_females}{Female population}
#'   \item{literate_persons}{Total literate population}
#'   \item{main_workers_persons}{Total main workers}
#'   \item{cultivators_persons}{Total cultivators}
#'   \item{agri_labour_persons}{Total agricultural labourers}
#'   \item{hh_industry_persons}{Household industry workers}
#'   \item{other_workers_persons}{Other workers}
#'   \item{non_workers_persons}{Non-workers}
#' }
#' @section Known defects:
#' The source is OCR'd and carries transcription errors. Of 420 rows with a
#' rural and urban counterpart, 83 fail `rural + urban == total`; the largest
#' gap is 101,809,324 in Himachal Pradesh `non_workers_males`, a powers-of-ten
#' slip rather than rounding. District sums disagree with the state row in 19 of
#' 30 states. Check any column you rely on before trusting it.
#'
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_1981"

#' Subdistrict directory (2011)
#'
#' Subdistrict (tehsil/taluka) population from the 2011 Census.
#'
#' @format A tibble with 7,074 rows and 15 columns:
#' \describe{
#'   \item{year}{Census year for population data (2011)}
#'   \item{geography}{Geographic level ("subdistrict")}
#'   \item{state}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district}{Name of the district}
#'   \item{subdistrict}{Name of the subdistrict (tehsil/taluka)}
#'   \item{population}{Total population}
#'   \item{males}{Male population}
#'   \item{females}{Female population}
#'   \item{households}{Number of households}
#'   \item{inhabited_villages}{Number of inhabited villages}
#'   \item{uninhabited_villages}{Number of uninhabited villages}
#'   \item{towns}{Number of towns}
#'   \item{area_km2}{Area in square kilometers}
#'   \item{density}{Population density per square kilometer}
#' }
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_subdistricts_2011"

#' Census variables lookup
#'
#' Available census variables with labels, years, geographic levels, and
#' categories.
#'
#' @format A tibble with 23 rows and 5 columns:
#' \describe{
#'   \item{variable}{Variable name used in package functions}
#'   \item{label}{Human-readable label}
#'   \item{years}{Comma-separated list of available years}
#'   \item{geographies}{Comma-separated list of available geographic levels}
#'   \item{category}{Variable category (population, literacy, workers, etc.)}
#' }
"census_variables"

#' Indian states lookup
#'
#' States and union territories with codes, abbreviations, and regions.
#'
#' @format A tibble with 36 rows and 5 columns:
#' \describe{
#'   \item{state_code}{Numeric state code (Census 2011 codes)}
#'   \item{state_name}{Official state name}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{state_abbr}{Two-letter state abbreviation}
#'   \item{region}{Geographic region (North, South, East, West, Central, Northeast, Islands)}
#' }
"india_states"

#' Census 2011 Primary Census Abstract (PCA)
#'
#' District-level population, SC/ST, literacy, and worker statistics from
#' the 2011 Census. Covers all 640 districts; `population_total` sums to
#' 1,210,854,977, the 2011 India total.
#'
#' Aggregated at district level from the village-level 2011 PCA that also
#' backs [census_2011_demographics()], [census_2011_workers()] and
#' [census_2011_marginal_detail()]. For the 2001 round see [census_2001_pca].
#'
#' @format A tibble with 640 rows and 19 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Numeric state code}
#'   \item{state_name}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_code}{Numeric district code}
#'   \item{name}{Name of the district}
#'   \item{households}{Number of households}
#'   \item{population_total}{Total population}
#'   \item{population_male}{Male population}
#'   \item{population_female}{Female population}
#'   \item{population_0_6}{Population aged 0-6 years}
#'   \item{sc_population}{Scheduled Caste population}
#'   \item{st_population}{Scheduled Tribe population}
#'   \item{literate_total}{Total literate population}
#'   \item{workers_total}{Total workers}
#'   \item{main_workers}{Main workers}
#'   \item{marginal_workers}{Marginal workers}
#'   \item{non_workers}{Non-workers}
#' }
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_2011_pca"

#' Census 2001 Primary Census Abstract (PCA)
#'
#' District-level population, SC/ST, literacy, and worker statistics from
#' the 2001 Census. Covers 593 districts; `population_total` sums to
#' 1,028,610,328, the 2001 India total.
#'
#' Use 2001 boundaries with [attach_geometry()]. Districts are 2001 vintage,
#' so the 2011 boundary file has no polygon for several of them and will
#' mismatch others: `North Cachar Hills` (renamed Dima Hasao in 2010) and an
#' undivided `Medinipur` (split into Purba and Paschim in 2002) both resolve
#' to the wrong 2011 district. See [census_2011_pca] for the 2011 round.
#'
#' Until version 0.0.0.9000 this table shipped as `census_2011_pca` with a
#' hard-coded `year` of 2011.
#'
#' @format A tibble with 593 rows and 19 columns:
#' \describe{
#'   \item{year}{Census year (2001)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Numeric state code}
#'   \item{state_name}{Name of the state}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_code}{Numeric district code}
#'   \item{name}{Name of the district}
#'   \item{households}{Number of households}
#'   \item{population_total}{Total population}
#'   \item{population_male}{Male population}
#'   \item{population_female}{Female population}
#'   \item{population_0_6}{Population aged 0-6 years}
#'   \item{sc_population}{Scheduled Caste population}
#'   \item{st_population}{Scheduled Tribe population}
#'   \item{literate_total}{Total literate population}
#'   \item{workers_total}{Total workers}
#'   \item{main_workers}{Main workers}
#'   \item{marginal_workers}{Marginal workers}
#'   \item{non_workers}{Non-workers}
#' }
#' @source Census of India 2001, Primary Census Abstract.
"census_2001_pca"

#' Census 2001 Primary Census Abstract, full indicator set
#'
#' The complete published 2001 PCA at district level: every indicator split by
#' sex, and each district given for total, rural and urban. 593 districts x 3
#' sectors = 1,779 rows.
#'
#' [census_2001_pca] is the narrower 19-column view of the same data, kept for
#' the columns it shares with [census_2011_pca].
#'
#' @format A tibble with 1,779 rows and 47 columns. Beyond the identifiers
#'   (`year`, `geography`, `state_code`, `state_name`, `district_code`, `name`,
#'   `sector`) each indicator appears with a \code{_total}, \code{_male} and \code{_female} suffix:
#' \describe{
#'   \item{households}{Number of households}
#'   \item{population_total, population_male, population_female}{Total population}
#'   \item{pop_0_6_total, pop_0_6_male, pop_0_6_female}{Population aged 0-6 years}
#'   \item{sc_total, sc_male, sc_female}{Scheduled Caste population}
#'   \item{st_total, st_male, st_female}{Scheduled Tribe population}
#'   \item{literate_total, literate_male, literate_female}{Literate population}
#'   \item{illiterate_total, illiterate_male, illiterate_female}{Illiterate population}
#'   \item{workers_total, workers_male, workers_female}{All workers}
#'   \item{main_workers_total, main_workers_male, main_workers_female}{Main workers}
#'   \item{marginal_workers_total, marginal_workers_male, marginal_workers_female}{Marginal workers}
#'   \item{main_cultivators_total, main_agri_labour_total,
#'     main_hh_industry_total, main_other_total}{Main workers by category}
#'   \item{marginal_cultivators_total, marginal_agri_labour_total,
#'     marginal_hh_industry_total, marginal_other_total}{Marginal workers by category}
#'   \item{non_workers_total, non_workers_male, non_workers_female}{Non-workers}
#' }
#' @source Census of India 2001, Primary Census Abstract (series
#'   `PC01_PCA_TOT`).
"census_2001_pca_full"

#' Population projections -- state level (2011-2036)
#'
#' MOHFW population projections at state level, based on the 2011 Census.
#' Covers 38 entries (36 states/UTs, India total, and Ladakh) with annual
#' projections from 2011 to 2036. Values are absolute numbers (the source
#' rounds in thousands independently, so `population` may differ from
#' `males + females` by up to 1000).
#'
#' Values match the report's Table 8. India and Odisha follow the July 2020
#' edition, which revised Odisha's male projection, so both rows differ from
#' the November 2019 print linked below.
#'
#' @format A tibble with 988 rows and 5 columns:
#' \describe{
#'   \item{year}{Projection year (2011-2036)}
#'   \item{state_name_harmonized}{Harmonized state name for joining}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population}
#' }
#' @source Ministry of Health and Family Welfare, Government of India.
#'   Population Projections for India and States 2011-2036.
#'   \url{https://nhm.gov.in/New_Updates_2018/Report_Population_Projection_2019.pdf}
"population_projections_state"

#' Population projections -- district level, Census 2011 boundaries (2011-2031)
#'
#' MOHFW population projections at district level using Census 2011
#' boundaries (640 districts). Projections are at 5-year intervals:
#' 2011, 2016, 2021, 2026, 2031. Values match the IIPS report's Table 8.
#'
#' The report's age tables ([population_projections_district_age()]) sum
#' to different totals for Karnataka in 2016-2031 and for Uttar Pradesh and
#' Nagaland in 2016.
#'
#' Compatible with [attach_geometry()] using 2011 district boundaries.
#'
#' @format A tibble with 3,200 rows and 6 columns:
#' \describe{
#'   \item{year}{Projection year (5-year intervals)}
#'   \item{state_name_harmonized}{Harmonized state name for joining}
#'   \item{district}{District name (MOHFW naming convention)}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @source International Institute for Population Sciences. Projection of
#'   District Level Annual Population by Quinquennial Agegroup and Sex.
#'   \url{https://www.iipsindia.ac.in/sites/default/files/1_3.pdf}
"population_projections_district"

#' Population projections -- district level, LGD boundaries (2012-2031)
#'
#' MOHFW population projections scaled to current Local Government
#' Directory (LGD) district boundaries. Annual projections from 2012 to
#' 2031, summed across age groups from [population_projections_district_lgd_age()].
#'
#' @format A tibble with 15,660 rows and 6 columns:
#' \describe{
#'   \item{year}{Projection year (annual, 2012-2031)}
#'   \item{state_name_harmonized}{Harmonized state name for joining. Dadra &
#'     Nagar Haveli and Daman & Diu appear merged as one UT (their 2020
#'     administrative merger); the LGD source has no district-level way to
#'     split them back apart.}
#'   \item{district}{District name (LGD naming convention)}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @section Known defects:
#' Derived from [population_projections_district_age()] by area overlap, so
#' district sums do not exactly reproduce [population_projections_state],
#' and Karnataka inherits the age tables' disagreement with
#' [population_projections_district].
#' Theni (Tamil Nadu) is NA for 2017-2031, and Moga (Punjab) and Tapi
#' (Gujarat) for 2022-2026, as in [population_projections_district_age()]. Use
#' [population_projections_district] for totals in those years.
#'
#' @source International Institute for Population Sciences. Projection of
#'   District Level Annual Population by Quinquennial Agegroup and Sex.
#'   \url{https://www.iipsindia.ac.in/sites/default/files/1_3.pdf}
#'   District scaling from Census 2011 to LGD boundaries via spatial
#'   overlap analysis.
"population_projections_district_lgd"

#' Population projections -- state level, by age group (2011-2036)
#'
#' Age-stratified population reshaped directly from the MOHFW report's own
#' Table 18, wide-by-year to tidy long. Summing to state-year reproduces
#' [population_projections_state] to within report rounding (Uttar Pradesh
#' 2016: 216,089 vs 216,087 thousand).
#'
#' Values match the printed Table 18.
#' `population` is the printed Person figure, rounded separately from
#' `males` and `females`, so it can differ from their sum by 1. India and
#' Odisha follow the July 2020 edition, as in [population_projections_state],
#' and there `population` is `males + females`.
#'
#' Coverage is narrower than [population_projections_state]: the report only
#' breaks out 23 major states individually plus an "India" total, lumping the
#' smaller North East states (Sikkim, Arunachal Pradesh, Nagaland, Manipur,
#' Mizoram, Tripura, Meghalaya) into one "North East States Excluding Assam"
#' row. Chandigarh, small UTs and Ladakh are not in this table at all.
#'
#' @format A tibble with 2,448 rows and 5 columns:
#' \describe{
#'   \item{year}{Projection year (2011-2036, at 5-year intervals: 2011, 2016,
#'     2021, 2026, 2031, 2036)}
#'   \item{state_name_harmonized}{Harmonized state name for joining where the
#'     report breaks the state out individually; "India" and "North East
#'     States Excluding Assam" pass through verbatim as aggregate rows}
#'   \item{age_group}{Five-year bands "0-4" through "80+"}
#'   \item{males}{Projected male population, in thousands}
#'   \item{females}{Projected female population, in thousands}
#'   \item{population}{Projected total population (the printed Person
#'     figure), in thousands}
#' }
#' @source Ministry of Health and Family Welfare, Government of India.
#'   Population Projections for India and States 2011-2036, Table 18.
#'   \url{https://nhm.gov.in/New_Updates_2018/Report_Population_Projection_2019.pdf}
"population_projections_state_age"

#' Census 2011 district languages (C-16)
#'
#' Mother tongue speakers by language at district level from the 2011
#' Census C-16 tables, with male/female and rural/urban breakdowns.
#'
#' @format A tibble with 38,993 rows and 11 columns:
#' \describe{
#'   \item{state_code}{Numeric state code}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_code}{Numeric district code}
#'   \item{language_name}{Name of the language}
#'   \item{language_group}{Numeric language group code}
#'   \item{total_speakers}{Total speakers}
#'   \item{male_speakers}{Male speakers}
#'   \item{female_speakers}{Female speakers}
#'   \item{rural_speakers}{Rural speakers}
#'   \item{urban_speakers}{Urban speakers}
#'   \item{district_name}{Name of the district}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables.
"census_2011_district_languages"

#' Census 2011 linguistic diversity
#'
#' District-level linguistic diversity metrics derived from the 2011 Census
#' C-16 mother tongue tables, counting named mother tongues only. C-16 files
#' the unscheduled languages of the northeast under per-group "Others"
#' residuals, which carry no language name and are excluded; `coverage`
#' reports the share of the district the metrics are computed from, and falls
#' below 0.9 in 34 districts and below 0.5 in 7.
#'
#' @format A tibble with 640 rows and 11 columns:
#' \describe{
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{state_code}{Numeric state code}
#'   \item{district_code}{Numeric district code}
#'   \item{n_languages}{Number of distinct languages spoken}
#'   \item{total_speakers}{Total speakers across all languages}
#'   \item{shannon_entropy}{Shannon entropy of the language distribution}
#'   \item{effective_languages}{Effective number of languages (2^shannon_entropy)}
#'   \item{dominant_language}{Most-spoken language}
#'   \item{dominant_share}{Share of speakers of the dominant language}
#'   \item{district_name}{Name of the district}
#'   \item{coverage}{Share of district population in named mother tongues}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables (derived).
"census_2011_linguistic_diversity"

#' Census 2011 Scheduled Castes and Scheduled Tribes (A-10/A-11)
#'
#' District-level Scheduled Caste and Scheduled Tribe population from the 2011
#' Census A-10 and A-11 tables.
#'
#' The two categories are not symmetric. Scheduled Tribes are enumerated by
#' name, 581 of them. Scheduled Castes are not: all 582 SC rows carry the single
#' label `"All Scheduled Castes"`, one per district. Nothing in this package
#' resolves caste below that aggregate.
#'
#' Filter with either spelling: `category` holds the long form, `category_code`
#' holds `SC`/`ST`. [census_sc_st()] accepts both.
#'
#' ST rows include `"Generic Tribes etc."`, the residual for members who
#' returned no specific tribe: 585 rows, 2,804,148 people.
#' [census_2011_tribes] is this table's ST rows with that residual removed and
#' the names harmonised.
#'
#' @format A tibble with 14,028 rows and 9 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_name}{Name of the district}
#'   \item{category}{`"Scheduled Caste"` or `"Scheduled Tribe"`, spelled out}
#'   \item{category_code}{`"SC"` or `"ST"`, for filtering by the short form}
#'   \item{caste_tribe_name}{Name of the caste or tribe}
#'   \item{population}{Population of the caste or tribe}
#'   \item{percentage}{Share of district population}
#'   \item{district_total_population}{Total district population}
#' }
#' @source Census of India 2011, A-10 (SC) and A-11 (ST) tables.
"census_2011_sc_st"

#' Census 2011 Scheduled Tribes (A-11)
#'
#' District-level population of individual Scheduled Tribes from the 2011
#' Census A-11 tables. `tribe_name` is harmonised; `tribe_name_original` keeps
#' the source string verbatim, including the full synonym list the census
#' publishes ("Gond, Arakh, Arrakh, Agaria, ...") and any parenthetical
#' district qualifier.
#'
#' Harmonisation takes the first synonym and drops the qualifier, so
#' `"Thoti (in Adilabad, Hyderabad, ...)"` becomes `"Thoti"`. That collapses 581
#' source strings to 483 tribe names, and it is deliberate: the same tribe is
#' written differently across states, sometimes differing only in whitespace.
#'
#' These are the ST rows of [census_2011_sc_st] with `"Generic Tribes etc."`
#' removed, which is why the population here sums to 103,409,280 rather than the
#' 106,213,428 in that table. Neither figure equals the 104,545,716 in
#' `census_2011_pca$st_population`; the A-11 tables and the Primary Census
#' Abstract do not reconcile, so pick one source per analysis and say which.
#'
#' @format A tibble with 12,861 rows and 8 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{state_name_harmonized}{Harmonized state name for joining across datasets}
#'   \item{district_name}{Name of the district}
#'   \item{tribe_name}{Harmonized tribe name}
#'   \item{tribe_name_original}{Original tribe name as recorded in the source}
#'   \item{population}{Tribe population}
#'   \item{percentage}{Share of district population}
#'   \item{district_total_population}{Total district population}
#' }
#' @source Census of India 2011, A-11 Scheduled Tribe tables.
"census_2011_tribes"
