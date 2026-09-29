#' Calculate Roy et al. (2015) applicability domain metrics.
#'
#' Applies the Roy et al. (2015) applicability domain (AD) procedure to
#' standardized descriptor values for each chemical. This method essentially
#' calculates a z-score for each descriptor using the mean and standard deviation
#' of the training set.
#'
#' Recall that the descriptors are all centered and scaled by the mean and standard
#' deviation of the respective training set, so that the values passed in data are
#' already the number of standad deviations from the mean.
#'
#' The function first subsets to the descriptor columns used by the model,
#' computes absolute standardized values, and then calculates:
#' \describe{
#'   \item{\code{SImin}}{Minimum absolute descriptor value by row.}
#'   \item{\code{SImax}}{Maximum absolute descriptor value by row.}
#'   \item{\code{SImean}}{Mean absolute descriptor value by row.}
#'   \item{\code{SIsd}}{Standard deviation of absolute descriptor values by row.}
#'   \item{\code{SI90}}{\code{SImean + z_multiplier * SIsd}.}
#'   \item{\code{Outlier}}{Out-of-domain indicator (1 = outside AD, 0 = inside AD).}
#' }
#'
#' Outlier classification follows the algorithm implemented in Dawson et al.
#' (2021), based on Roy et al. (2015):
#' \itemize{
#'   \item If \code{SImax < threshold}, the row is kept in-domain.
#'   \item Otherwise, if \code{SImin > threshold}, it is flagged as out-of-domain.
#'   \item Otherwise, if \code{SI90 > threshold}, it is flagged as out-of-domain.
#'   \item Otherwise, it remains in-domain.
#' }
#'
#' @param data A data frame containing model descriptor columns. Rows are
#'   chemicals; columns include (at minimum) the descriptors listed in
#'   \code{model_vars}.
#' @param model_vars A character vector of descriptor names used to calculate AD.
#'   Only matching columns in \code{data} are used.
#' @param threshold Numeric scalar threshold for the Roy AD decision rule.
#'   Defaults to \code{3}.
#' @param z_multiplier Numeric scalar multiplier used to compute \code{SI90} from
#'   \code{SImean} and \code{SIsd}. Defaults to \code{1.28}.
#'
#' @return A data frame with one row per input row and columns
#'   \code{SImin}, \code{SImax}, \code{SImean}, \code{SIsd}, \code{SI90}, and
#'   \code{Outlier}.
#'
#' @references
#' Roy, K., Kar, S., and Ambure, P. (2015). On a simple approach for
#' determining applicability domain of QSAR models.
#' \emph{Chemometrics and Intelligent Laboratory Systems}, 145, 22-29.
#'
#' @keywords internal
calc_roy_ad <- function(
  data,
  model_vars,
  threshold = 3,
  z_multiplier = 1.28
) {
  ad_data <- data[, model_vars]

  # apply() over zero rows returns a list rather than a numeric vector, and
  # the `$Outlier <- 0` assignment below then fails with "replacement has 1
  # row, data has 0". Short-circuit with the documented column set so callers
  # can rely on the shape regardless of row count.
  if (nrow(data) == 0) {
    return(data.frame(
      SImin = numeric(0),
      SImax = numeric(0),
      SImean = numeric(0),
      SIsd = numeric(0),
      SI90 = numeric(0),
      Outlier = numeric(0)
    ))
  }

  ad_data <- abs(ad_data)

  SImin <- apply(ad_data, 1, min)
  SImax <- apply(ad_data, 1, max)
  SImean <- apply(ad_data, 1, mean)
  SIsd <- apply(ad_data, 1, sd)

  ad_metrics <- data.frame(SImin, SImax, SImean, SIsd)
  ad_metrics$SI90 <- ad_metrics$SImean + (z_multiplier * ad_metrics$SIsd)
  ad_metrics$Outlier <- 0

  for (i in seq_len(nrow(ad_metrics))) {
    if (ad_metrics$SImax[i] < threshold) {
      next
    } else if (ad_metrics$SImin[i] > threshold) {
      ad_metrics$Outlier[i] <- 1
    } else if (ad_metrics$SI90[i] > threshold) {
      ad_metrics$Outlier[i] <- 1
    }
  }

  return(ad_metrics)
}
