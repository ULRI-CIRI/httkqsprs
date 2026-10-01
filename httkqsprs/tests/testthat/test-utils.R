# The three calc_*() functions seed the RNG so randomForest's tie-break is
# reproducible. That is an implementation detail and must not leak: a caller
# who seeded their own session, or who is midway through a simulation, has to
# find their RNG stream exactly as they left it.

test_that("with_seed() restores an existing RNG stream", {
  set.seed(99)
  before <- get(".Random.seed", envir = globalenv(), inherits = FALSE)

  with_seed(1255, stats::runif(10))

  expect_identical(
    get(".Random.seed", envir = globalenv(), inherits = FALSE),
    before
  )
})

test_that("with_seed() leaves an unseeded session unseeded", {
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    rm(".Random.seed", envir = globalenv())
  }

  with_seed(1255, stats::runif(10))

  expect_false(exists(".Random.seed", envir = globalenv(), inherits = FALSE))
})

test_that("with_seed() returns the value of the expression", {
  expect_equal(with_seed(1255, 1 + 1), 2)
})

test_that("with_seed() restores the stream even when the code errors", {
  set.seed(99)
  before <- get(".Random.seed", envir = globalenv(), inherits = FALSE)

  expect_error(with_seed(1255, stop("boom")), "boom")
  expect_identical(
    get(".Random.seed", envir = globalenv(), inherits = FALSE),
    before
  )
})

test_that("with_seed() actually fixes the draw", {
  expect_equal(
    with_seed(1255, stats::runif(3)),
    with_seed(1255, stats::runif(3))
  )
})

test_that("calc_clint(), calc_fup() and calc_papp() leave the RNG untouched", {
  descriptors <- load_fixture_descriptors()

  for (fn in list(calc_clint, calc_fup, calc_papp)) {
    set.seed(99)
    before <- get(".Random.seed", envir = globalenv(), inherits = FALSE)

    fn(descriptors)

    expect_identical(
      get(".Random.seed", envir = globalenv(), inherits = FALSE),
      before
    )
  }
})

test_that("a caller's own seeded draw is unaffected by calc_*()", {
  set.seed(7)
  expected <- stats::runif(5)

  descriptors <- load_fixture_descriptors()
  set.seed(7)
  calc_papp(descriptors)
  calc_clint(descriptors)
  calc_fup(descriptors)

  expect_equal(stats::runif(5), expected)
})
