#' Start the censusindia REST API
#'
#' Launches the bundled plumber API on the given host and port. Every
#' endpoint takes `GET` query parameters that mirror the R function behind it,
#' with comma-separated values for vectors (`state=KL,TN`):
#'
#' | Endpoint | Function |
#' |---|---|
#' | `/query` | [get_census()] |
#' | `/population` | [get_population()] |
#' | `/boundaries` | [get_census_boundaries()] |
#' | `/languages` | [census_languages()] |
#' | `/sc-st` | [census_sc_st()] |
#' | `/datasets`, `/dataset/<name>` | any shipped dataset, e.g. [census_1931_castes] |
#' | `/variables`, `/search` | [list_census_variables()], [search_census_variables()] |
#' | `/states`, `/geographies` | [list_states()], [list_census_geographies()] |
#' | `/health` | package version |
#'
#' Results come back as JSON rows, or as a GeoJSON FeatureCollection when
#' `geometry=true` and from `/boundaries`. Input the R function rejects is a
#' 400 carrying its error message, and a failed data download is a 503.
#' Interactive documentation is served at `/__docs__/`.
#'
#' A response holds at most 10,000 rows, or 100 features for GeoJSON. Page
#' through larger results with `limit` and `offset`; the `X-Total-Count` header
#' gives the full count.
#'
#' Each request writes one JSON line to standard output with its path, query,
#' status, duration, client IP and a `client` label. The label comes from an
#' `X-Client` header when one is sent (an MCP server wrapping the API should
#' send `X-Client: mcp/<name>`), and otherwise from the User-Agent: `mcp`,
#' `ai_agent`, `curl`, `wget`, `python`, `r`, `node`, `browser`, `other` or
#' `unknown`. Under systemd these lines land in the journal.
#'
#' @param host Host address to bind. Default `"127.0.0.1"` (localhost only).
#'   Use `"0.0.0.0"` to accept external connections.
#' @param port Port number. Default `8895`.
#' @param ... Additional arguments passed to `plumber`'s `$run()` method.
#'
#' @return Called for its side effect; does not return under normal operation.
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

# The router's environment sits in the namespace, so the API file can call
# internal helpers.
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
