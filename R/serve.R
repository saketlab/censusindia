#' Start the censusindia REST API
#'
#' Launches the bundled plumber API on the given host and port.
#'
#' @param host Host address to bind. Default `"127.0.0.1"` (localhost only).
#'   Use `"0.0.0.0"` to accept external connections.
#' @param port Port number. Default `8895`.
#' @param ... Additional arguments passed to `plumber`'s `$run()` method.
#'
#' @return Called for its side effect; does not return under normal operation.
#' @export
#' @examples
#' \dontrun{
#' # Start locally on the default port
#' serve()
#'
#' # Bind to all interfaces on a custom port
#' serve(host = "0.0.0.0", port = 9000)
#' }
serve <- function(host = "127.0.0.1", port = 8895L, ...) {
  rlang::check_installed("plumber", reason = "to start the REST API")
  plumber_r <- system.file("plumber", "plumber.R", package = "censusindia")
  if (nchar(plumber_r) == 0L) {
    cli::cli_abort("plumber.R not found. Re-install the {.pkg censusindia} package.")
  }
  cli::cli_alert_info("Starting censusindia API on http://{host}:{port}")
  plumber::plumb(plumber_r)$run(host = host, port = port, quiet = FALSE, ...)
}

#' @rdname serve
#' @export
census_api <- serve
