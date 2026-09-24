# Captures the randomForest vote matrix behind the Papp predictions.
# Votes are deterministic; only the argmax tie-break consumes the RNG, so this
# matrix - not Pab.Class.Pred - is the parity baseline for Papp.
#
# calc_papp() does not expose its prepared descriptor matrix on `main`, so we
# intercept the predict() call rather than duplicating the preparation logic.
# Task 6 exposes it directly, after which this trace can be dropped.
suppressMessages(devtools::load_all("httkqsprs", quiet = TRUE))

trace(
  what = "predict.randomForest",
  where = asNamespace("randomForest"),
  tracer = quote({
    if (!exists(".capt_nd", envir = globalenv())) {
      assign(".capt_nd", newdata, envir = globalenv())
      assign(".capt_mod", object, envir = globalenv())
    }
  }),
  print = FALSE
)
invisible(httkqsprs::calc_papp("NewHTTK_April_2026", input.folder = "scripts"))
untrace("predict.randomForest", where = asNamespace("randomForest"))

votes <- predict(.capt_mod, .capt_nd, type = "vote", norm.votes = FALSE)
dir.create("baseline", showWarnings = FALSE)
saveRDS(votes, "baseline/golden-papp-votes.rds")

top2 <- t(apply(votes, 1, function(v) sort(v, decreasing = TRUE)[1:2]))
tied <- which(top2[, 1] == top2[, 2])
cat("rows scored:", nrow(votes), " tied rows:", length(tied), "\n")
print(votes[tied, , drop = FALSE])
