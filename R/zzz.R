.onAttach <- function(libname, pkgname) {
  if (interactive() && length(census_missing())) {
    packageStartupMessage(
      "censusindia downloads boundaries and its largest tables on first use. ",
      "Run census_download() to fetch them all now."
    )
  }
}
