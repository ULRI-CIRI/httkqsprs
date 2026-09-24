#' Descriptors required by each QSPR model
#'
#' Reports the OPERA and PaDEL descriptor names a given endpoint's model
#' needs. Callers use this to retrieve exactly those descriptors from
#' whatever source they have, then pass the resulting data frame to
#' [calc_clint()], [calc_fup()], or [calc_papp()].
#'
#' The returned names are *retrieval* names. OPERA names carry a `_pred`
#' suffix and PaDEL names do not, so the two sets never collide and may be
#' merged into a single wide data frame.
#'
#' For `"papp"`, `pKa_a_pred` and `pKa_b_pred` are included even though the
#' model never consumes them directly: [calc_papp()] passes them to
#' [httk::calc_ionization()] to derive `fraction_neutral`, which is neither
#' an OPERA nor a PaDEL descriptor and so is never retrieved.
#'
#' @param endpoint One of `"clint"`, `"fup"`, or `"papp"`.
#'
#' @return A named list with elements `opera` and `padel`, each a character
#'   vector of descriptor names.
#'
#' @examples
#' required_descriptors("clint")
#'
#' @import randomForest
#' @import stringr
#' @export required_descriptors
required_descriptors <- function(endpoint = c("clint", "fup", "papp")) {
  endpoint <- match.arg(endpoint)

  Descriptors <- httkqsprs::Descriptors
  opera_desc_all <- paste0(Descriptors$Opera, "_pred")

  if (endpoint == "clint") {
    clintmodvars <- row.names(importance(httkqsprs::ClintClass3Mod))
    return(list(
      opera = intersect(opera_desc_all, clintmodvars),
      padel = intersect(Descriptors$Padel, clintmodvars)
    ))
  }

  if (endpoint == "fup") {
    fupmodvars <- row.names(httkqsprs::RF.fit$importance)
    fup_padel_base <- stringr::str_remove(
      fupmodvars[stringr::str_detect(fupmodvars, "^padel_")],
      "^padel_"
    )
    fup_opera_base <- stringr::str_remove(
      fupmodvars[stringr::str_detect(fupmodvars, "^Opera_")],
      "^Opera_"
    )
    return(list(
      opera = paste0(fup_opera_base, "_pred"),
      padel = fup_padel_base
    ))
  }

  papp_opt_desc <- httkqsprs::papp_opt_desc
  papp_opera_desc <- unique(c(
    grep("_pred$", papp_opt_desc, value = TRUE),
    "pKa_a_pred",
    "pKa_b_pred"
  ))
  list(
    opera = papp_opera_desc,
    padel = setdiff(papp_opt_desc, c("fraction_neutral", papp_opera_desc))
  )
}

#' Subset a descriptor frame to one endpoint's columns
#'
#' Validates that every required descriptor is present, then returns
#' `MoleculeID` plus exactly those columns. Subsetting before any renaming
#' or standardization keeps a wide union frame behaving identically to a
#' per-endpoint frame.
#'
#' @param descriptors A data frame keyed on `MoleculeID`.
#' @param required Character vector of required descriptor column names.
#' @return A data frame with `MoleculeID` first, then `required`.
#' @noRd
subset_descriptors <- function(descriptors, required) {
  if (!is.data.frame(descriptors)) {
    stop("`descriptors` must be a data frame.", call. = FALSE)
  }
  if (!"MoleculeID" %in% names(descriptors)) {
    stop("`descriptors` must contain a `MoleculeID` column.", call. = FALSE)
  }
  absent <- setdiff(required, names(descriptors))
  if (length(absent) > 0) {
    stop(
      "`descriptors` is missing required columns: ",
      paste(absent, collapse = ", "),
      call. = FALSE
    )
  }
  descriptors[, c("MoleculeID", required), drop = FALSE]
}
