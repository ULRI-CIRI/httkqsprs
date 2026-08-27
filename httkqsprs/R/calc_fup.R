#' Calculate Fup predictions and Roy AD metrics
#'
#' Retrieves only the descriptors required by the Fup model, harmonizes
#' descriptor names to match the Fup model conventions, standardizes model
#' inputs, predicts transformed Fup, back-transforms predictions, and computes
#' Roy et al. applicability-domain metrics.
#'
#' @param datalabel Character scalar used in output filenames.
#' @param chems Optional character vector of CICHEM identifiers. If provided,
#'   descriptors are retrieved from the database using [get_padel()] and
#'   [get_opera()].
#' @param operapostfix Character postfix of the OPERA descriptor CSV when
#'   `chems` is `NULL`.
#' @param padelpostfix Character postfix of the PaDEL descriptor CSV when
#'   `chems` is `NULL`.
#' @param conn_str Optional PostgreSQL connection string used by descriptor
#'   retrieval helpers when `chems` is provided.
#' @param input.folder The folder containing the input files (OPERA and PaDEL descriptors).
#'   Defaults to \code{\link{getwd}}.
#'
#' @return A named list with two elements:
#' \describe{
#'   \item{output}{Data frame of complete-case Fup predictions with columns
#'     for `Fup.RF.pred` and Roy AD metrics (`SImin`, `SImax`, `SImean`,
#'     `SIsd`, `SI90`, `Outlier`).}
#'   \item{missing}{Data frame of chemicals excluded due to incomplete
#'     descriptor data.}
#' }
#'
#' @details
#' Workflow:
#' \enumerate{
#'   \item Derive model variables from `RF.fit$importance`.
#'   \item Retrieve only required OPERA and PaDEL descriptors from CSV files or
#'   database helpers.
#'   \item Prefix matching PaDEL descriptors with `padel_` and OPERA
#'   descriptors with `Opera_`.
#'   \item Restrict to required model descriptors and standardize using
#'   `fup.msd` means/SDs.
#'   \item Remove incomplete rows (returned in `$missing`).
#'   \item Predict transformed Fup and back-transform by squaring.
#'   \item Compute Roy AD metrics with [calc_roy_ad()].
#' }
#'
#' @author Daniel E. Dawson and John Wambaugh
#'
#' @references
#' Dawson, Daniel E., et al. (2021). Designing QSARs for parameters of
#' high-throughput toxicokinetic models using open-source descriptors.
#' \emph{Environmental Science \& Technology}, 55(9), 6505-6517.
#'
#' @export calc_fup
calc_fup <- function(
  datalabel,
  chems = NULL,
  operapostfix = "-smi_OPERA2.9Pred.csv",
  padelpostfix = "_QSAR-ready_smi_PadelDesc.csv",
  input.folder = getwd()
) {
  # Load these from package in case user hasn't loaded whole package:
  Descriptors <- httkqsprs::Descriptors
  RF.fit <- httkqsprs::RF.fit
  msd <- httkqsprs::fup.msd

  fupmodvars <- row.names(RF.fit$importance)

  opera_desc_all <- paste0(Descriptors$Opera, "_pred")

  fup_padel_base <- stringr::str_remove(
    fupmodvars[stringr::str_detect(fupmodvars, "^padel_")],
    "^padel_"
  )
  fup_opera_base <- stringr::str_remove(
    fupmodvars[stringr::str_detect(fupmodvars, "^Opera_")],
    "^Opera_"
  )
  fup_opera_desc <- paste0(fup_opera_base, "_pred")

  if (is.null(chems)) {
    NEWOPERA <- paste0(input.folder, "/", datalabel, operapostfix)
    NEWPADEL <- paste0(input.folder, "/", datalabel, padelpostfix)

    Opera <- read.csv(NEWOPERA)
    Padel <- read.csv(NEWPADEL)

    missing_opera <- setdiff(fup_opera_desc, names(Opera))
    if (length(missing_opera) > 0) {
      for (nm in missing_opera) {
        Opera[[nm]] <- NA_real_
      }
    }

    missing_padel <- setdiff(fup_padel_base, names(Padel))
    if (length(missing_padel) > 0) {
      for (nm in missing_padel) {
        Padel[[nm]] <- NA_real_
      }
    }

    Opera <- Opera[,
      c(1, which(names(Opera) %in% fup_opera_desc)),
      drop = FALSE
    ]
    Padel <- Padel[,
      c(1, which(names(Padel) %in% fup_padel_base)),
      drop = FALSE
    ]
    fupchemlist <- merge(
      Opera,
      Padel,
      by.x = "MoleculeID",
      by.y = "Name",
      all.x = TRUE
    )
  } else {
    Padel <- get_padel(
      cichem_list = chems,
      descriptors = fup_padel_base
    )
    Opera <- get_opera(
      cichem_list = chems,
      descriptors = fup_opera_desc
    )
    fupchemlist <- merge(Padel, Opera, by = "MoleculeID", all = TRUE)
  }

  Padeldesc <- which(
    names(fupchemlist) %in% stringr::str_remove(fupmodvars, "padel_")
  )
  Operadesc <- which(
    stringr::str_remove(names(fupchemlist), "_pred") %in%
      stringr::str_remove(fupmodvars, "Opera_")
  )
  names(fupchemlist) <- stringr::str_remove(names(fupchemlist), "_pred")

  for (i in Padeldesc) {
    names(fupchemlist)[i] <- paste0("padel_", names(fupchemlist)[i])
  }
  for (i in Operadesc) {
    names(fupchemlist)[i] <- paste0("Opera_", names(fupchemlist)[i])
  }

  # Restrict to only the columns required for the Fup model
  chemlistfupmodvars <- which(names(fupchemlist) %in% fupmodvars)
  IDcolstart <- 1
  IDcolend <- 1
  fupchemlist <- fupchemlist[, c(IDcolstart:IDcolend, chemlistfupmodvars)]

  # Standardize descriptors using means/SDs from training data
  chemlistfupsc <- fupchemlist
  for (i in fupmodvars) {
    sub1 <- subset(msd, select = c(names(msd) == i))
    chemlistfupsc[, i] <- (chemlistfupsc[, i] - sub1[1, 1]) / sub1[2, 1]
  }

  fupscComplete <- complete.cases(chemlistfupsc)
  chemlistsc_fup_narm <- chemlistfupsc[which(fupscComplete == TRUE), ]
  Incompletescfup <- chemlistfupsc[which(fupscComplete == FALSE), ]

  set.seed(1255)
  chemlistpredictfup <- stats::predict(RF.fit, chemlistsc_fup_narm)
  chemlistsc_fup_narm$Fup.RF.pred <- chemlistpredictfup^2
  chemlistsc_fup_narm$Fup.RF.pred <- signif(
    chemlistsc_fup_narm$Fup.RF.pred,
    digits = 3
  )

  SIdf <- calc_roy_ad(
    data = chemlistsc_fup_narm,
    model_vars = fupmodvars
  )

  chemlistsc_fup_narm <- data.frame(chemlistsc_fup_narm, SIdf)

  return(list(output = chemlistsc_fup_narm, missing = Incompletescfup))
}
