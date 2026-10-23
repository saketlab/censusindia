# a missing export fails the pkgdown deploy; skips without _pkgdown.yml

find_pkgdown <- function() {
  for (p in c(
    "_pkgdown.yml", "../_pkgdown.yml", "../../_pkgdown.yml",
    "../../../_pkgdown.yml"
  )) {
    if (file.exists(p)) {
      return(normalizePath(p))
    }
  }
  NA_character_
}

test_that("every export appears in the pkgdown reference index", {
  yml <- find_pkgdown()
  skip_if(is.na(yml), "_pkgdown.yml not reachable from the test directory")
  man <- file.path(dirname(yml), "man")
  skip_if_not(dir.exists(man), "man/ not reachable")

  lines <- readLines(yml, warn = FALSE)
  ref <- lines[seq(match("reference:", lines), length(lines))]
  listed <- trimws(sub("^\\s*-\\s*", "", grep("^\\s*-\\s+[A-Za-z0-9_.]+\\s*$", ref, value = TRUE)))

  rd <- list.files(man, pattern = "[.]Rd$")
  # an export can be documented under another topic's Rd via @rdname
  topic_for <- function(e) {
    if (file.exists(file.path(man, paste0(e, ".Rd")))) {
      return(e)
    }
    hit <- rd[vapply(rd, function(r) {
      any(grepl(
        paste0("\\\\alias\\{", e, "\\}"),
        readLines(file.path(man, r), warn = FALSE)
      ))
    }, logical(1))]
    if (length(hit)) sub("[.]Rd$", "", hit[1]) else NA_character_
  }

  exports <- sort(getNamespaceExports(asNamespace("censusindia")))
  missing <- exports[vapply(exports, function(e) {
    t <- topic_for(e)
    !(e %in% listed || (!is.na(t) && t %in% listed))
  }, logical(1))]

  expect_equal(missing, character(0))
})
