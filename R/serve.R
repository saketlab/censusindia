#' Start the censusindia REST API
#'
#' Starts the bundled plumber API on the host and port. Each endpoint takes
#' `GET` query parameters that agree with the R function behind it. For
#' vectors, use comma-separated values (`state=KL,TN`):
#'
#' | Endpoint | Function |
#' |---|---|
#' | `/query` | [get_census()] |
#' | `/population` | [get_population()] |
#' | `/boundaries` | [get_census_boundaries()] |
#' | `/languages` | [census_languages()] |
#' | `/sc-st` | [census_sc_st()] |
#' | `/datasets`, `/dataset/<name>` | a dataset of the package, for example [census_1931_castes] |
#' | `/variables`, `/search` | [list_census_variables()], [search_census_variables()] |
#' | `/states`, `/geographies` | [list_states()], [list_census_geographies()] |
#' | `/health` | package version |
#'
#' The API returns JSON rows. It returns a GeoJSON FeatureCollection from
#' `/boundaries` and when `geometry=true`. If the R function rejects the input,
#' the API returns a 400 with the error message. A failed data download gives a
#' 503. The interactive documentation is at `/__docs__/`.
#'
#' A response has a maximum of 10,000 rows, or 100 features for GeoJSON. For
#' larger results, use `limit` and `offset` to get the pages. The
#' `X-Total-Count` header gives the full count.
#'
#' Each request writes one JSON line to standard output. The line has the path,
#' query, status, duration, client IP and a `client` label.
#'
#' If the request has an `X-Client` header, the label comes from that header.
#' An MCP server that wraps the API must send `X-Client: mcp/<name>`. For
#' other requests, the label comes from the User-Agent: `mcp`, `ai_agent`,
#' `curl`, `wget`, `python`, `r`, `node`, `browser`, `other` or `unknown`.
#' Under systemd, these lines go to the journal.
#'
#' @param host Host address. Default `"127.0.0.1"` (only localhost). Use
#'   `"0.0.0.0"` to accept external connections.
#' @param port Port number. Default `8895`.
#' @param ... More arguments for the `$run()` method of `plumber`.
#'
#' @return No value. In normal operation, the function does not stop.
#' @export
#' @examplesIf interactive() && requireNamespace("plumber", quietly = TRUE)
#' # Start locally on the default port
#' serve()
#'
#' # Bind to all interfaces on a custom port
#' serve(host = "0.0.0.0", port = 9000)
serve <- function(host = "127.0.0.1", port = 8895L, ...) {
  router <- api_router()
  cli::cli_alert_info("Starting censusindia API on http://{host}:{port}")
  router$run(host = host, port = port, quiet = FALSE, ...)
}

# router env in the namespace lets the API file call internal helpers
api_router <- function() {
  rlang::check_installed("plumber", reason = "to start the REST API")
  plumber_r <- system.file("plumber", "plumber.R", package = "censusindia")
  if (!nzchar(plumber_r)) {
    cli::cli_abort("plumber.R not found. Re-install the {.pkg censusindia} package.")
  }
  plumber::pr(plumber_r, envir = new.env(parent = asNamespace("censusindia")))
}

#' @rdname serve
#' @export
census_api <- serve
