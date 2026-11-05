# drop the 14-byte header: it records the R version, which would change the hash
content_md5 <- function(x) {
  f <- tempfile()
  on.exit(unlink(f))
  writeBin(serialize(x, NULL, xdr = TRUE, version = 2)[-(1:14)], f)
  unname(tools::md5sum(f))
}
