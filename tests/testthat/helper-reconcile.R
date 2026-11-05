# Shared with data-raw/build-deviation-ledger.R, which writes fixtures/deviations.csv.
# Each check returns one row per failing cell; NA on either side counts as a deviation.

# age groups are rounded separately, so their sum may miss the total by this much
AGE_ROUNDING_TOLERANCE <- 20

recon_row <- function(check, dataset, d, reference, actual) {
  pick <- function(v) if (v %in% names(d)) as.character(d[[v]]) else rep(NA_character_, nrow(d))
  out <- data.frame(
    check = rep(check, nrow(d)), dataset = rep(dataset, nrow(d)),
    year = suppressWarnings(as.integer(pick("year"))), sector = pick("sector"),
    state_name_harmonized = pick("state_name_harmonized"), district = pick("district"),
    variable = pick("variable"), reference = reference, actual = actual,
    stringsAsFactors = FALSE
  )
  out[is.na(out$reference) | is.na(out$actual) | out$reference != out$actual, , drop = FALSE]
}

# rows of x that correction i of f (inst/ocr-corrections.csv) targets
ocr_cell <- function(x, f, i) {
  x$geography == f$geography[i] & x$state_name == f$state_name[i] &
    dplyr::coalesce(x$district, "") == f$district[i] & x$sector == f$sector[i]
}

# District rows summed per state against the state's own row.
district_sum_gaps <- function(dataset, d, vars) {
  by <- intersect(c("year", "sector"), names(d))
  st <- d[d$geography == "state", c(by, "state_name_harmonized", vars)]
  di <- d[d$geography == "district", c(by, "state_name_harmonized", vars)]
  di <- stats::aggregate(di[vars], di[c(by, "state_name_harmonized")], sum)
  j <- merge(st, di, by = c(by, "state_name_harmonized"), suffixes = c(".state", ".districts"))
  do.call(rbind, lapply(vars, function(v) {
    recon_row(
      "district_sum_vs_state", dataset, cbind(j, variable = v),
      j[[paste0(v, ".state")]], j[[paste0(v, ".districts")]]
    )
  }))
}

# rural + urban against total, row by row.
sector_gaps <- function(dataset, d, vars) {
  keys <- c("year", "geography", "state_name_harmonized", "state_name", "district")
  keys <- intersect(keys, names(d))
  d <- d[d$geography %in% c("india", "state", "district"), ]
  s <- split(d[c(keys, vars)], d$sector)
  j <- merge(merge(s$total, s$rural, by = keys, suffixes = c("", ".rural")), s$urban,
    by = keys, suffixes = c("", ".urban")
  )
  do.call(rbind, lapply(vars, function(v) {
    recon_row(
      "rural_plus_urban_vs_total", dataset, cbind(j, sector = "total", variable = v),
      j[[v]], j[[paste0(v, ".rural")]] + j[[paste0(v, ".urban")]]
    )
  }))
}

# <x>_male + <x>_female against <x> (males + females against population), row by row.
sex_gaps <- function(dataset, d, base = "population") {
  cols <- if (base == "population") c("population", "males", "females") else paste0(base, c("", "_male", "_female"))
  recon_row(
    "males_plus_females_vs_population", dataset, cbind(d, variable = base),
    d[[cols[1]]], d[[cols[2]]] + d[[cols[3]]]
  )
}

C81_INDICATORS <- c(
  "literate", "main_workers", "cultivators", "agri_labour", "hh_industry",
  "other_workers", "marginal_workers", "non_workers"
)

# fix-ocr-errors.R passes the tables it is about to save
census_reconciliations <- function(c71 = census_1971, c81 = census_1981) {
  ts <- census_years(census_population_time_series)
  c81 <- c81[c81$geography %in% c("india", "state", "district"), ]
  c81_vars <- c(
    "population", "males", "females", "households", "literate",
    "main_workers", "marginal_workers", "non_workers"
  )
  c71_vars <- c("population", "males", "females", "sc_population", "st_population")
  c81_sector_vars <- c(
    "population", "males", "females", "households",
    as.vector(outer(C81_INDICATORS, c("", "_male", "_female"), paste0))
  )
  rbind(
    district_sum_gaps("census_population_time_series", ts, c("population", "males", "females")),
    district_sum_gaps("census_1971", c71, c71_vars),
    district_sum_gaps("census_1981", c81, c81_vars),
    sector_gaps("census_1971", c71, c71_vars),
    sector_gaps("census_1981", c81, c81_sector_vars),
    sex_gaps("census_population_time_series", ts),
    sex_gaps("census_1971", c71),
    do.call(rbind, lapply(c("population", C81_INDICATORS), function(b) sex_gaps("census_1981", c81, b))),
    a11_st_gaps()
  )
}

# A-11 ST rows per district against the PCA ST count.
a11_st_gaps <- function() {
  # rows with a parent_tribe are constituents of a tribe already counted
  st <- census_2011_sc_st[census_2011_sc_st$category_code == "ST" & is.na(census_2011_sc_st$parent_tribe), ]
  st <- stats::aggregate(st["population"], st[c("state_name_harmonized", "district")], sum)
  j <- merge(st, census_2011_pca[c("year", "state_name_harmonized", "district", "st_population")],
    by = c("state_name_harmonized", "district")
  )
  recon_row(
    "a11_st_vs_pca", "census_2011_sc_st", cbind(j, variable = "st_population"),
    j$st_population, j$population
  )
}

# District age groups summed against the district projection table.
age_sum_gaps <- function(age, total, dataset) {
  a <- stats::aggregate(age["population"], age[c("year", "state_name_harmonized", "district")], sum)
  j <- merge(a, total[c("year", "state_name_harmonized", "district", "population")],
    by = c("year", "state_name_harmonized", "district"), suffixes = c(".age", "")
  )
  recon_row(
    "age_sum_vs_total", dataset, cbind(j, variable = "population"),
    j$population, j$population.age
  )
}

read_ledger <- function() {
  path <- test_path("fixtures", "deviations.csv")
  utils::read.csv(path, colClasses = c(
    year = "integer", reference = "numeric", actual = "numeric",
    check = "character", dataset = "character", sector = "character",
    state_name_harmonized = "character", district = "character",
    variable = "character"
  ))
}

ledger_key <- function(x) {
  do.call(paste, c(lapply(x[c(
    "check", "dataset", "year", "sector", "state_name_harmonized",
    "district", "variable"
  )], function(v) ifelse(is.na(v), "", v)), sep = "|"))
}
