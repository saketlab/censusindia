# column names the schema replaced; no table or route may return them
RETIRED_COLS <- c(
  "state", "district_name", "area_name", "level", "population_total",
  "total_persons", "percentage", "total_speakers", "population_rural", "population_urban"
)

.api <- new.env()

# headers go in as Rook names, e.g. HTTP_USER_AGENT = "curl/8.0"
api_get <- function(path, query = "", ...) {
  if (is.null(.api$router)) .api$router <- api_router()
  empty <- list(read = function(...) raw(), rewind = function() NULL)
  out <- capture.output(r <- .api$router$call(list2env(list(
    REQUEST_METHOD = "GET", PATH_INFO = path, QUERY_STRING = query,
    HTTP_HOST = "localhost", rook.input = empty, ...
  ))))
  r$log <- out
  r$json <- if (grepl("json", r$headers[["Content-Type"]])) {
    jsonlite::fromJSON(r$body)
  }
  r
}
