test_that("papp requests pKa inputs but excludes fraction_neutral", {
  got <- required_descriptors("papp")
  expect_true(all(c("pKa_a_pred", "pKa_b_pred") %in% got$opera))
  expect_false("fraction_neutral" %in% c(got$opera, got$padel))
})

test_that("opera names carry _pred and padel names do not", {
  for (endpoint in c("clint", "fup", "papp")) {
    got <- required_descriptors(endpoint)
    expect_true(
      all(grepl("_pred$", got$opera)),
      info = paste(endpoint, "opera")
    )
    expect_false(
      any(grepl("_pred$", got$padel)),
      info = paste(endpoint, "padel")
    )
  }
})

test_that("opera and padel name sets never collide", {
  for (endpoint in c("clint", "fup", "papp")) {
    got <- required_descriptors(endpoint)
    expect_length(intersect(got$opera, got$padel), 0)
  }
})

test_that("an unknown endpoint is rejected", {
  expect_error(required_descriptors("clearance"))
})
