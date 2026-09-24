# Captures the descriptor name sets that calc_* derive inline on main.
# These become the expected values for the required_descriptors() tests.
devtools::load_all("httkqsprs")

Descriptors <- httkqsprs::Descriptors
ClintClass3Mod <- httkqsprs::ClintClass3Mod
RF.fit <- httkqsprs::RF.fit
papp_opt_desc <- httkqsprs::papp_opt_desc

opera_desc_all <- paste0(Descriptors$Opera, "_pred")

# --- clint: lifted verbatim from calc_clint.R ---
clintmodvars <- row.names(randomForest::importance(ClintClass3Mod))
clint <- list(
  opera = intersect(opera_desc_all, clintmodvars),
  padel = intersect(Descriptors$Padel, clintmodvars)
)

# --- fup: lifted verbatim from calc_fup.R ---
fupmodvars <- row.names(RF.fit$importance)
fup_padel_base <- stringr::str_remove(
  fupmodvars[stringr::str_detect(fupmodvars, "^padel_")],
  "^padel_"
)
fup_opera_base <- stringr::str_remove(
  fupmodvars[stringr::str_detect(fupmodvars, "^Opera_")],
  "^Opera_"
)
fup <- list(
  opera = paste0(fup_opera_base, "_pred"),
  padel = fup_padel_base
)

# --- papp: lifted verbatim from calc_papp.R ---
papp_opera_desc <- unique(c(
  grep("_pred$", papp_opt_desc, value = TRUE),
  "pKa_a_pred",
  "pKa_b_pred"
))
papp <- list(
  opera = papp_opera_desc,
  padel = setdiff(papp_opt_desc, c("fraction_neutral", papp_opera_desc))
)

dir.create("baseline", showWarnings = FALSE)
saveRDS(
  list(clint = clint, fup = fup, papp = papp),
  "baseline/descriptor-names.rds"
)

str(list(clint = clint, fup = fup, papp = papp))
