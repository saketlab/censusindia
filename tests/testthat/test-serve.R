test_that("serve() is available and points to the Plumber router", {
  expect_true(exists("serve", mode = "function"))

  plumber_r <- system.file("plumber", "plumber.R", package = "censusindia")
  expect_true(file.exists(plumber_r))
})
