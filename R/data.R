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

#' Census 2011 mother tongue data (C-16)
#'
#' Mother tongue speakers by language at state and district levels from the
#' 2011 Census C-16 tables, with rural/urban and male/female breakdowns.
#'
#' @format A tibble with 350,157 rows and 18 columns:
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
"census_2011_mother_tongue"

#' Census 2011 Primary Census Abstract (PCA)
#'
#' District-level population, SC/ST, literacy, and worker statistics from
#' the 2011 Census.
#'
#' @format A tibble with 593 rows and 19 columns:
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

#' Population projections -- state level (2011-2036)
#'
#' MOHFW population projections at state level, based on the 2011 Census.
#' Covers 38 entries (36 states/UTs, India total, and Ladakh) with annual
#' projections from 2011 to 2036. Values are absolute numbers (the source
#' rounds in thousands independently, so `population` may differ from
#' `males + females` by up to 1000).
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
"population_projections_state"

#' Population projections -- district level, Census 2011 boundaries (2011-2031)
#'
#' MOHFW population projections at district level using Census 2011
#' boundaries (640 districts). Projections are at 5-year intervals:
#' 2011, 2016, 2021, 2026, 2031.
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
#' @source Ministry of Health and Family Welfare, Government of India.
#'   Population Projections for India and States 2011-2036.
"population_projections_district"

#' Population projections -- district level, LGD boundaries (2012-2031)
#'
#' MOHFW population projections scaled to current Local Government
#' Directory (LGD) district boundaries (785 districts). Annual
#' projections from 2012 to 2031, aggregated across age groups.
#'
#' @format A tibble with 15,700 rows and 6 columns:
#' \describe{
#'   \item{year}{Projection year (annual, 2012-2031)}
#'   \item{state_name_harmonized}{Harmonized state name for joining}
#'   \item{district}{District name (LGD naming convention)}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @source Ministry of Health and Family Welfare, Government of India.
#'   Population Projections for India and States 2011-2036. District
#'   scaling from India_Population_Estimates project using spatial
#'   overlap analysis.
"population_projections_district_lgd"
