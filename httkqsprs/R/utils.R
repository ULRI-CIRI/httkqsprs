#' Evaluate an expression under a fixed seed, leaving the caller's RNG alone
#'
#' `set.seed()` writes to `.Random.seed` in the global environment, so a
#' prediction function that seeds itself silently resets the RNG stream of
#' whoever called it: every random draw they make afterwards becomes a
#' function of our seed rather than theirs. The three `calc_*()` functions
#' need a fixed seed so that `randomForest`'s tie-break is reproducible, but
#' that is our business, not the caller's.
#'
#' Saves `.Random.seed`, seeds, evaluates `code`, and restores on exit --
#' including the case where the caller had never used the RNG and
#' `.Random.seed` did not exist, which must be restored to not existing
#' rather than to some arbitrary state.
#'
#' @param seed Integer seed passed to [set.seed()].
#' @param code Expression to evaluate. Evaluated lazily, in the caller's
#'   frame, after the seed is set.
#' @return The value of `code`.
#' @noRd
with_seed <- function(seed, code) {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old_seed <- if (had_seed) {
    get(".Random.seed", envir = globalenv(), inherits = FALSE)
  }

  on.exit(
    {
      if (had_seed) {
        assign(".Random.seed", old_seed, envir = globalenv())
      } else if (
        exists(".Random.seed", envir = globalenv(), inherits = FALSE)
      ) {
        rm(".Random.seed", envir = globalenv())
      }
    },
    add = TRUE
  )

  set.seed(seed)
  code
}
