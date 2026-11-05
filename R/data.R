#' Census population time series (1901-2011)
#'
#' Population at state and district level for each census from 1901 to 2011.
#'
#' @format A tibble with 7,901 rows and 12 columns:
#' \describe{
#'   \item{year}{Census year (integer: 1901, 1911, ..., 2011). The column also
#'     has years that are not census years. Refer to the section below.}
#'   \item{geography}{Geographic level: "state" or "district"}
#'   \item{state_code}{Integer 2011 census code of the harmonized state}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district_code}{Integer district code. NA on state rows.}
#'   \item{district}{Name of the district. NA on state rows.}
#'   \item{population}{Total population}
#'   \item{males}{Male population}
#'   \item{females}{Female population}
#'   \item{variation_absolute}{Absolute change from the previous census}
#'   \item{variation_percent}{Change from the previous census, in percent}
#' }
#' @section Coverage limits:
#' Sikkim, Mizoram and Daman & Diu are not in the table for any year. For
#' 2001 and 2011, [get_census()] uses the Primary Census Abstract.
#'
#' The district rows do not add to their state totals before 1961 and in 1981.
#' In 1901-1941, 57 districts have no population. In 1981, all 27 Assam
#' districts are missing, but the state row is present.
#'
#' The `year` column also contains 1900, 1910, 1940, 1948, 1950, 1960, 1962
#' and 2021. These are not census years. Use [census_years()] to remove them
#' before you use `lag()`.
#'
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_population_time_series"

#' Census 1961 literacy data
#'
#' State and district literacy rates from the 1961 Census. The literacy
#' columns are percentages of the population. The table has no counts.
#' You cannot add the rates across areas.
#'
#' @format A tibble with 347 rows (26 state, 321 district) and 10 columns:
#' \describe{
#'   \item{year}{Census year (1961)}
#'   \item{geography}{Geographic level: "state" or "district"}
#'   \item{state_code}{Integer 2011 census code of the harmonized state}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district_code}{Integer district code from the source. NA on state
#'     rows.}
#'   \item{district}{Name of the district. NA on state rows.}
#'   \item{literacy_rate}{Literacy rate, persons (percent)}
#'   \item{literacy_rate_male}{Male literacy rate (percent)}
#'   \item{literacy_rate_female}{Female literacy rate (percent)}
#' }
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_1961_literacy"

#' Census 1971 Primary Census Abstract
#'
#' State and district population from the 1971 Census, with rural and urban
#' values and the SC/ST population.
#'
#' The table stores each sector as a row. Each of the 28 states and 352
#' districts has one row each for `"total"`, `"rural"`, and `"urban"`. Filter
#' to `sector == "total"` before summing across rows; otherwise the sum
#' double-counts every person.
#'
#' Verified against the printed volume (Table II). Ten missing Mysore districts
#' were added and OCR errors in SC/ST cells were corrected. Madras is entirely
#' urban (rural = 0).
#'
#' [inst/ocr-corrections.csv](https://github.com/saketlab/censusindia/blob/main/inst/ocr-corrections.csv)
#' records every correction and its source page. Within each column and sector,
#' districts sum to their state and rural + urban equals total. Nil entries
#' (`".."`) are stored as `NA`.
#'
#' @format A tibble with 1,140 rows (380 areas x 3 sectors) and 13 columns:
#' \describe{
#'   \item{year}{Census year (1971)}
#'   \item{geography}{Geographic level: "state" or "district"}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code}{Integer 2011 census code of the harmonized state}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district}{Name of the district. NA on state rows.}
#'   \item{area_km2}{Area in square kilometers}
#'   \item{population}{Population}
#'   \item{males}{Male population}
#'   \item{females}{Female population}
#'   \item{sc_population}{Scheduled Caste population}
#'   \item{st_population}{Scheduled Tribe population}
#' }
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_1971"

#' Census 1981 Primary Census Abstract
#'
#' State and district data from the 1981 Census, with literacy and worker
#' categories.
#'
#' The table stores geographic levels and sectors as rows. `geography` is
#' `"india"`, `"state"`, `"district"`, `"town"`, or `"urban_agglomeration"`,
#' with one row per sector. Call [at_level()] (or filter `geography` and
#' `sector == "total"`) before summing across rows. Each of the 398 districts
#' has a total, rural, and urban row; towns and urban agglomerations have only
#' an urban row.
#'
#' Verified against the printed volume (`India_1981_PCA_General.pdf`). In every
#' state and district, persons = males + females and total = rural + urban for
#' population, literacy, and each worker category, and districts sum to their
#' state. OCR errors, leading digits clipped in the scan, and printing errors in
#' the source volume were corrected.
#'
#' [inst/ocr-corrections.csv](https://github.com/saketlab/censusindia/blob/main/inst/ocr-corrections.csv)
#' records every correction with its page and evidence. The urban row of Guna,
#' printed in the volume but omitted from the digitized source, was restored.
#' Assam held no census in 1981 and has no rows.
#'
#' @format A tibble with 2,365 rows and 38 columns:
#' \describe{
#'   \item{year}{Census year (1981)}
#'   \item{geography}{Geographic level: "india", "state", "district", "town"
#'     or "urban_agglomeration"}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code}{Integer 2011 census code of the harmonized state. NA on
#'     the India rows.}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district}{Name of the district. NA above district level and on
#'     urban agglomerations.}
#'   \item{name}{Name of the unit from the source. Urban
#'     agglomerations have only this name.}
#'   \item{area_km2}{Area in square kilometers}
#'   \item{occupied_houses}{Number of occupied residential houses}
#'   \item{households}{Number of households}
#'   \item{population, males, females}{Population: persons, males and females}
#'   \item{literate, literate_male, literate_female}{Literate population}
#'   \item{main_workers, main_workers_male, main_workers_female}{Main workers}
#'   \item{cultivators, cultivators_male, cultivators_female}{Main workers
#'     who are cultivators}
#'   \item{agri_labour, agri_labour_male, agri_labour_female}{Main workers
#'     who are agricultural laborers}
#'   \item{hh_industry, hh_industry_male, hh_industry_female}{Main workers in
#'     household industry}
#'   \item{other_workers, other_workers_male, other_workers_female}{Other main
#'     workers}
#'   \item{marginal_workers, marginal_workers_male,
#'     marginal_workers_female}{Marginal workers}
#'   \item{non_workers, non_workers_male, non_workers_female}{Non-workers}
#' }
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_1981"

#' Subdistrict directory (2011)
#'
#' Subdistrict (tehsil/taluka) population from the 2011 Census.
#'
#' If a subdistrict is in two or more districts, the table has one row for
#' each district, with the mark "(Part)". Population, males, females and
#' households come from [census_2011_demographics()] and add to
#' [census_2011_pca]. Villages, towns, area and density come from the
#' Dataverse source. They are NA where the source has no match.
#'
#' @format A tibble with 5,988 rows and 16 columns:
#' \describe{
#'   \item{year}{Census year of the population data (2011)}
#'   \item{geography}{Geographic level ("subdistrict")}
#'   \item{state_code}{Integer 2011 census state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
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
#'   \item{density}{Persons per square kilometer}
#' }
#' @source Jolad, Shivakumar and Singh, Madhav (2026). "Indian Census Data
#'   Collection, 1901-2026: Digitised Subnational Population and Administrative
#'   Datasets." Harvard Dataverse. \doi{10.7910/DVN/ON8CP8}.
"census_subdistricts_2011"

#' Census variables lookup
#'
#' Variables resolved by [get_census()], with one row per variable and
#' geographic level. `years` lists the census years in which the variable is
#' available at that level. Generated by calling [get_census()] across every
#' combination in [list_census_geographies()].
#'
#' @format A tibble with 50 rows and 5 columns:
#' \describe{
#'   \item{variable}{Variable name in the package functions}
#'   \item{label}{Label for display}
#'   \item{geography}{Geographic level: `"state"`, `"district"` or `"subdistrict"`}
#'   \item{years}{Comma-separated census years for that geography}
#'   \item{category}{Variable category (population, literacy, workers and
#'     others)}
#' }
"census_variables"

#' Indian states lookup
#'
#' States and union territories, with codes, abbreviations and regions.
#'
#' @format A tibble with 36 rows and 5 columns:
#' \describe{
#'   \item{state_code}{Integer state code (Census 2011 codes)}
#'   \item{state_name}{Official state name}
#'   \item{state_abbr}{Two-letter state abbreviation}
#'   \item{region}{Geographic region (North, South, East, West, Central, Northeast, Islands)}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#' }
"india_states"

#' Census 2011 Primary Census Abstract (PCA)
#'
#' District-level population, SC/ST, literacy and worker data from the 2011
#' Census. The table has all 640 districts. `population` adds to
#' 1,210,854,977, the 2011 India total.
#'
#' The values are district sums of the village-level 2011 PCA. The same
#' source gives [census_2011_demographics()], [census_2011_workers()] and
#' [census_2011_marginal_detail()]. For 2001, refer to [census_2001_pca].
#'
#' @format A tibble with 640 rows and 19 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district_code}{Integer district code, unique in India (1-640)}
#'   \item{district}{Name of the district}
#'   \item{households}{Number of households}
#'   \item{population}{Total population}
#'   \item{males}{Male population}
#'   \item{females}{Female population}
#'   \item{population_0_6}{Population of age 0-6 years}
#'   \item{sc_population}{Scheduled Caste population}
#'   \item{st_population}{Scheduled Tribe population}
#'   \item{literate}{Literate population}
#'   \item{workers}{Total workers}
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
#' District-level population, SC/ST, literacy and worker data from the 2001
#' Census. The table has 593 districts. `population` adds to 1,028,610,328,
#' the 2001 India total.
#'
#' Use the 2001 boundaries with [attach_geometry()]. The 2011 boundary file
#' has no polygon for some 2001 districts and the wrong polygon for others,
#' for example `North Cachar Hills` and the undivided `Medinipur`. For 2011,
#' refer to [census_2011_pca].
#'
#' @format A tibble with 593 rows and 19 columns:
#' \describe{
#'   \item{year}{Census year (2001)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district_code}{Integer district code. Each state has its own
#'     numbers. One code can occur in more than one state.}
#'   \item{district}{Name of the district}
#'   \item{households}{Number of households}
#'   \item{population}{Total population}
#'   \item{males}{Male population}
#'   \item{females}{Female population}
#'   \item{population_0_6}{Population of age 0-6 years}
#'   \item{sc_population}{Scheduled Caste population}
#'   \item{st_population}{Scheduled Tribe population}
#'   \item{literate}{Literate population}
#'   \item{workers}{Total workers}
#'   \item{main_workers}{Main workers}
#'   \item{marginal_workers}{Marginal workers}
#'   \item{non_workers}{Non-workers}
#' }
#' @source Census of India 2001, Primary Census Abstract.
"census_2001_pca"

#' Census 2001 Primary Census Abstract, full indicator set
#'
#' The full 2001 PCA at district level. Each indicator has values for
#' persons, males and females. Each district has one row each for total,
#' rural and urban: 593 districts x 3 sectors = 1,779 rows.
#'
#' [census_2001_pca] is a 19-column subset of the same data. It has the
#' columns that are also in [census_2011_pca].
#'
#' The table gives each sector as a row. Filter `sector == "total"` before
#' you add rows.
#'
#' @format A tibble with 1,779 rows and 47 columns. Male and female columns
#'   have a \code{_male} or \code{_female} suffix. A column with no suffix
#'   gives persons:
#' \describe{
#'   \item{year}{Census year (2001)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{state_name}{State name from the source}
#'   \item{district_code}{Integer district code. Each state has its own
#'     numbers.}
#'   \item{district}{Name of the district}
#'   \item{households}{Number of households}
#'   \item{population, males, females}{Population}
#'   \item{population_0_6, population_0_6_male,
#'     population_0_6_female}{Population of age 0-6 years}
#'   \item{sc_population, sc_population_male,
#'     sc_population_female}{Scheduled Caste population}
#'   \item{st_population, st_population_male,
#'     st_population_female}{Scheduled Tribe population}
#'   \item{literate, literate_male, literate_female}{Literate population}
#'   \item{illiterate, illiterate_male, illiterate_female}{Illiterate population}
#'   \item{workers, workers_male, workers_female}{All workers}
#'   \item{main_workers, main_workers_male, main_workers_female}{Main workers}
#'   \item{main_cultivators, main_agri_labour, main_hh_industry,
#'     main_other}{Main workers by category, persons}
#'   \item{marginal_workers, marginal_workers_male,
#'     marginal_workers_female}{Marginal workers}
#'   \item{marginal_cultivators, marginal_agri_labour, marginal_hh_industry,
#'     marginal_other}{Marginal workers by category, persons}
#'   \item{non_workers, non_workers_male, non_workers_female}{Non-workers}
#' }
#' @source Census of India 2001, Primary Census Abstract (series
#'   `PC01_PCA_TOT`).
"census_2001_pca_full"

#' Population projections: state level (2011-2036)
#'
#' MOHFW population projections for each state, from the 2011 Census. The
#' table gives one projection for each year from 2011 to 2036.
#'
#' India has 36 states and UTs. The table has 39 entries:
#' \itemize{
#'   \item 28 states.
#'   \item 9 UTs, with the names that the report uses: Andaman & Nicobar
#'     Islands, Chandigarh, Delhi, Jammu & Kashmir, Ladakh, Lakshadweep,
#'     Puducherry, "Dadra & Nagar Haveli" and "Daman & Diu". Jammu & Kashmir
#'     does not include Ladakh.
#'   \item "Dadra & Nagar Haveli and Daman & Diu". The two UTs became one UT
#'     in January 2020. This row is the sum of the two UTs. It has the same
#'     name as in the LGD district table, so data from 2020 and later can join.
#'   \item "India", the national total.
#' }
#' The population of the two former UTs appears twice in the table. When
#' summing across states, exclude `"India"` and either the merged UT or the two
#' former UTs.
#'
#' Values are counts of persons. Because the source report rounds persons,
#' males, and females to thousands independently, `population` can differ from
#' `males + females` by up to 1,000 (or up to 2,000 for the merged UT, which is
#' the sum of two rounded rows).
#'
#' Values are the same as Table 8 of the report. The India and Odisha rows
#' use the July 2020 edition. That edition changed the male projection for
#' Odisha. The two rows are different from the November 2019 report
#' at the link below.
#'
#' @format A tibble with 1014 rows (39 entries x 26 years) and 7 columns:
#' \describe{
#'   \item{year}{Projection year (2011-2036)}
#'   \item{geography}{"india" on the India rows, "state" on all other rows}
#'   \item{state_code}{Integer 2011 census state code. NA for India, Ladakh
#'     and the merged Dadra & Nagar Haveli and Daman & Diu.}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population}
#' }
#' @source Ministry of Health and Family Welfare, Government of India.
#'   Population Projections for India and States 2011-2036.
#'   \url{https://nhm.gov.in/New_Updates_2018/Report_Population_Projection_2019.pdf}
"population_projections_state"

#' Population projections: district level, Census 2011 boundaries (2011-2031)
#'
#' MOHFW population projections for the 640 districts of the 2011 Census
#' boundaries. The table gives projections for 2011, 2016, 2021, 2026 and
#' 2031.
#'
#' Values are the same as Table 8 of the IIPS report, with one exception:
#' Uttar Pradesh 2016. In Table 8, the 2016 column for Uttar Pradesh gives the
#' 2017 value of each district. The Uttar Pradesh rows for 2016 use the 2016
#' sums of the age tables. `data-raw/projection_consistency_fixes.csv` gives
#' these rows.
#'
#' The age tables ([population_projections_district_age()]) add to these
#' totals within rounding, except for Nagaland 2016.
#'
#' Use [attach_geometry()] with the 2011 district boundaries.
#'
#' @format A tibble with 3,200 rows and 8 columns:
#' \describe{
#'   \item{year}{Projection year (5-year intervals)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer 2011 census state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{district}{District name (MOHFW names)}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @source International Institute for Population Sciences. Projection of
#'   District Level Annual Population by Quinquennial Agegroup and Sex.
#'   \url{https://www.iipsindia.ac.in/sites/default/files/1_3.pdf}
"population_projections_district"

#' Population projections: district level, LGD boundaries (2012-2031)
#'
#' MOHFW population projections, scaled to the current Local Government
#' Directory (LGD) district boundaries. The table gives one projection for
#' each year from 2012 to 2031. Each value is the sum of the age groups in
#' [population_projections_district_lgd_age()].
#'
#' @format A tibble with 15,660 rows and 8 columns:
#' \describe{
#'   \item{year}{Projection year (each year, 2012-2031)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer 2011 census state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join
#'     datasets. Dadra & Nagar Haveli and Daman & Diu are one UT, as merged
#'     in 2020. The LGD source has no district-level data to divide them.}
#'   \item{district}{District name (LGD names)}
#'   \item{males}{Projected male population}
#'   \item{females}{Projected female population}
#'   \item{population}{Projected total population (males + females)}
#' }
#' @section Known defects:
#' The values come from [population_projections_district_age()], scaled by
#' area overlap. The district sums are not exactly equal to
#' [population_projections_state]. Karnataka has the same difference from
#' [population_projections_district] as the age tables.
#'
#' The report does not print some values. The values for Theni (Tamil Nadu)
#' 2017-2031 are calculated. The values for the 80+ group of Moga (Punjab)
#' and Tapi (Gujarat) in 2022-2026 are also calculated.
#' [population_projections_district_age()] has the same values.
#'
#' @source International Institute for Population Sciences. Projection of
#'   District Level Annual Population by Quinquennial Agegroup and Sex.
#'   \url{https://www.iipsindia.ac.in/sites/default/files/1_3.pdf}
#'   District scaling from Census 2011 to LGD boundaries via spatial
#'   overlap analysis.
"population_projections_district_lgd"

#' Population projections: state level, by age group (2011-2036)
#'
#' Population by age group, from Table 18 of the MOHFW report. For each state
#' and year, the sum of the age groups is equal to
#' [population_projections_state] within the rounding of the report. Values
#' are numbers of persons.
#'
#' Values match the printed Table 18. `population` is the printed Person
#' value, which the report rounds to thousands independently of `males` and
#' `females`, so `population` can differ from `males + females` by up to 1,000.
#' The India and Odisha rows use the July 2020 edition, as in
#' [population_projections_state], where `population` equals `males + females`.
#'
#' This table has fewer areas than [population_projections_state]. The report
#' gives 23 large states separately, and an "India" total. One row, "North
#' East States Excluding Assam", gives the sum of Sikkim, Arunachal Pradesh,
#' Nagaland, Manipur, Mizoram, Tripura and Meghalaya. Chandigarh, the small
#' UTs and Ladakh are not in this table.
#'
#' @format A tibble with 2,448 rows and 8 columns:
#' \describe{
#'   \item{year}{Projection year: 2011, 2016, 2021, 2026, 2031 and 2036}
#'   \item{geography}{"india" on the India rows, "state" on all other rows,
#'     which include the North East row}
#'   \item{state_code}{Integer 2011 census state code. NA on the India and
#'     North East rows.}
#'   \item{state_name_harmonized}{Harmonized state name, used to join
#'     datasets. "India" and "North East States Excluding Assam" are the
#'     names that the report gives to these two total rows.}
#'   \item{age_group}{Five-year age groups, "0-4" to "80+"}
#'   \item{males}{Projected male population, persons}
#'   \item{females}{Projected female population, persons}
#'   \item{population}{Projected total population (the printed Person
#'     value), persons}
#' }
#' @source Ministry of Health and Family Welfare, Government of India.
#'   Population Projections for India and States 2011-2036, Table 18.
#'   \url{https://nhm.gov.in/New_Updates_2018/Report_Population_Projection_2019.pdf}
"population_projections_state_age"

#' Census 2011 district languages (C-16)
#'
#' Mother tongue speakers by language at district level, from the 2011 Census
#' C-16 tables. The table has values by sex and by sector.
#'
#' The table stores each sector as a row. Each district and language has one
#' row each for `"total"`, `"rural"`, and `"urban"` (38,993 rows per sector).
#' Filter `sector == "total"` before summing across rows, or use
#' [census_languages()], which applies this filter automatically. The census
#' reports speakers by sex only for the total sector; `speakers_male` and
#' `speakers_female` are `NA` on rural and urban rows.
#'
#' @format A tibble with 116,979 rows and 12 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{sector}{Sector: "total", "rural" or "urban"}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{district_code}{Integer district code}
#'   \item{district}{Name of the district}
#'   \item{language_name}{Name of the language}
#'   \item{language_group}{Integer language group code}
#'   \item{speakers}{Speakers}
#'   \item{speakers_male}{Male speakers. NA on rural and urban rows.}
#'   \item{speakers_female}{Female speakers. NA on rural and urban rows.}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables.
"census_2011_district_languages"

#' Census 2011 linguistic diversity
#'
#' District-level metrics of linguistic diversity, calculated from the 2011
#' Census C-16 mother tongue tables. The metrics use only named mother
#' tongues. C-16 puts the unscheduled languages of the northeast in "Others"
#' rows for each language group. These rows have no language name, and the
#' metrics do not include them. `coverage` gives the fraction of the district
#' population that the metrics use.
#'
#' @format A tibble with 640 rows and 13 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{district_code}{Integer district code}
#'   \item{district}{Name of the district}
#'   \item{n_languages}{Number of different languages}
#'   \item{speakers}{Speakers of all named languages}
#'   \item{shannon_entropy}{Shannon entropy of the language distribution}
#'   \item{effective_languages}{Effective number of languages (2^shannon_entropy)}
#'   \item{dominant_language}{Language with the most speakers}
#'   \item{dominant_share}{Fraction of the speakers that speak
#'     `dominant_language`}
#'   \item{coverage}{Fraction of the district population with a named mother
#'     tongue}
#' }
#' @source Census of India 2011, C-16 Mother Tongue Tables (derived).
"census_2011_linguistic_diversity"

#' Census 2011 Scheduled Castes and Scheduled Tribes (A-10/A-11)
#'
#' District-level Scheduled Caste and Scheduled Tribe population from the 2011
#' Census A-10 and A-11 tables.
#'
#' The table gives each Scheduled Tribe by name: 581 names. The table does
#' not give Scheduled Castes by name. All 582 SC rows have the label
#' `"All Scheduled Castes"`, one row for each district.
#'
#' You can filter on two columns. `category` has the full name, and
#' `category_code` has `SC` or `ST`. [census_sc_st()] accepts the two forms.
#'
#' The ST rows include `"Generic Tribes etc."`. These rows give the persons
#' who did not give a specific tribe: 585 rows, 2,804,148 persons.
#' [census_2011_tribes] contains the ST rows of this table, without these rows
#' and with harmonized names.
#'
#' For Nagaland, the census tabulates the Scheduled Tribe `"Naga"` alongside its
#' constituent tribes marked `"(ST)"` (`Angami(ST)`, `Ao(ST)`, ...). Those
#' 193 rows carry `parent_tribe = "Naga"`, and in each district the `"Naga"` row
#' equals their sum. To count each person once, sum only rows where
#' `is.na(parent_tribe)`; the ST rows then match `census_2011_pca$st_population`
#' in every district (104,545,716 in total).
#'
#' @format A tibble with 14,028 rows and 12 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{district}{District name, as [census_2011_pca] writes it}
#'   \item{category}{`"Scheduled Caste"` or `"Scheduled Tribe"` (full name)}
#'   \item{category_code}{`"SC"` or `"ST"` (short form)}
#'   \item{caste_tribe_name}{Name of the caste or tribe}
#'   \item{parent_tribe}{The tribe that contains the tribe of this row ("Naga"
#'     for the (ST) rows of Nagaland). NA on other rows.}
#'   \item{population}{Population of the caste or tribe}
#'   \item{percent}{`population / district_total_population * 100`, rounded
#'     to two decimal places}
#'   \item{district_total_population}{District population: the `population`
#'     column of [census_2011_pca] for the same district}
#' }
#' @source Census of India 2011, A-10 (SC) and A-11 (ST) tables.
"census_2011_sc_st"

#' Census 2011 Scheduled Tribes (A-11)
#'
#' District-level population of each Scheduled Tribe, from the 2011 Census
#' A-11 tables. `tribe_name` is the harmonized name. `tribe_name_original` is
#' the text from the source. This text includes the full list of synonyms
#' from the census ("Gond, Arakh, Arrakh, Agaria, ...") and any district
#' qualifier in parentheses.
#'
#' To harmonize a name, the package keeps the first synonym and removes the
#' qualifier: `"Thoti (in Adilabad, Hyderabad, ...)"` becomes `"Thoti"`,
#' and `"Angami(ST)"` becomes `"Angami"`. The 581 source names become 481
#' tribe names. Different states write the same tribe in
#' different ways, and some names differ only in spaces.
#'
#' This table contains the ST rows of [census_2011_sc_st] excluding
#' `"Generic Tribes etc."`. The constituent tribes of Nagaland carry
#' `parent_tribe = "Naga"`, as in [census_2011_sc_st]. Before summing within a
#' district, exclude either those rows or the `"Naga"` umbrella rows so each
#' Naga person is counted only once. The `"Naga (ST)"` row (Naga with no
#' specific tribe) is harmonized to `"Naga (unspecified)"`.
#'
#' @format A tibble with 12,861 rows and 11 columns:
#' \describe{
#'   \item{year}{Census year (2011)}
#'   \item{geography}{Geographic level ("district")}
#'   \item{state_code}{Integer state code}
#'   \item{state_name_harmonized}{Harmonized state name, used to join datasets}
#'   \item{district}{District name, as [census_2011_pca] writes it}
#'   \item{tribe_name}{Harmonized tribe name}
#'   \item{tribe_name_original}{Tribe name from the source}
#'   \item{parent_tribe}{The tribe that contains the tribe of this row ("Naga"
#'     for the (ST) rows of Nagaland). NA on other rows.}
#'   \item{population}{Tribe population}
#'   \item{percent}{`population / district_total_population * 100`, rounded
#'     to two decimal places}
#'   \item{district_total_population}{District population: the `population`
#'     column of [census_2011_pca] for the same district}
#' }
#' @source Census of India 2011, A-11 Scheduled Tribe tables.
"census_2011_tribes"

#' Census 1931 castes by religion
#'
#' Population of each caste and community in the caste tables of the 1931
#' Census, by religion. The table has 24 provinces, princely states and
#' agencies of British India.
#'
#' A religion column is NA if the table of the province has no column for
#' that religion. The value is 0 if the column is present and has no
#' persons. Ajmer-Merwara has only totals. Its religion columns and
#' `total` are NA. Remainder entries, for example "Caste Unspecified" and
#' "Indian Christian", are separate rows.
#'
#' @format A tibble with 2,226 rows and 17 columns:
#' \describe{
#'   \item{year}{Census year (1931)}
#'   \item{province}{Province, princely state or agency, with a standard name}
#'   \item{unit_type}{`"British Province"`, `"Princely State"` or `"Agency"`}
#'   \item{caste}{Caste or community from the source}
#'   \item{rank}{Position in the ranked caste list of the province. 1 is the
#'     largest.}
#'   \item{hindu,muslim,sikh,jain,buddhist,christian,tribal,parsi,jew}{Persons
#'     of the caste in each religion. `tribal` is the 1931 "Tribal" or
#'     "Primitive" religion.}
#'   \item{total}{Sum of the religion columns}
#'   \item{total_ranked_list}{Total in the ranked list of the province. NA
#'     for the Andaman & Nicobar Islands.}
#'   \item{notes}{Note from the compiler, for example where `total` and
#'     `total_ranked_list` are different}
#' }
#' @source Jolad, Shivakumar, Kalyani, Gaurav and Baharadia, Samarth (2026).
#'   "Database of castes." Harvard Dataverse. \doi{10.7910/DVN/WT5VIY}.
#'   Digitised from the provincial, princely state and agency reports of the
#'   Census of India, 1931.
"census_1931_castes"

#' Census 1931 exterior castes
#'
#' Castes and tribes that the 1931 Census put in the "exterior castes" group,
#' with their population. Each row comes from a province or state section of
#' Appendix I of the Census of India 1931, Volume I. "Exterior castes" is the
#' term of the report.
#'
#' @format A tibble with 533 rows and 5 columns:
#' \describe{
#'   \item{year}{Census year (1931)}
#'   \item{section}{Province or state section of the appendix}
#'   \item{caste}{Caste or tribe from the source, with qualifiers in brackets}
#'   \item{population}{Persons in the exterior castes group}
#'   \item{note}{Note from the compiler}
#' }
#' @source Jolad, Shivakumar, Kalyani, Gaurav and Baharadia, Samarth (2026).
#'   "Database of castes." Harvard Dataverse. \doi{10.7910/DVN/WT5VIY}.
#'   Census of India, 1931, Volume I, Appendix I: Exterior Castes.
"census_1931_exterior_castes"
