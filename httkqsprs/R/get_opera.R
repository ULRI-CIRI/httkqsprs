#' Retrieve OPeRA descriptors from SQL database
#' 
#' @author John Wambaugh and Andy Shapiro
#'
#' @references
#' Mansouri, Kamel, et al. "OPERA models for predicting physicochemical properties and environmental fate endpoints." Journal of cheminformatics 10.1 (2018): 10.
#' 
#' @export get_opera
get_opera <- function(cichem_list = NULL,
                      descriptors = NULL,
                      opera_version = "2.9", 
                      conn_str = NULL)
{
  conn <- pg_connection_from_env('PIPELINES_CONN_STR')

  # ── Parameters ────────────────────────────────────────────────────────────────
  # parameters are set by call to function
  column_names  <- descriptors # NULL = all descriptors; or e.g. c("ALogP", "AMR")

# Convert names as given by OPERA Excel output into SQL names:
Opera.SQL.names <- paste0("opera_",
  gsub("_pred","",tolower(column_names)),
  "_endpoint") 
# Make the names of the tables match the database:
Opera.SQL.names <- gsub("logws","ws", Opera.SQL.names)
Opera.SQL.names <- gsub("logbcf","bcf", Opera.SQL.names)
Opera.SQL.names <- gsub("logkm","km", Opera.SQL.names)
Opera.SQL.names <- gsub("logvp","vp", Opera.SQL.names)
Opera.SQL.names <- gsub("logoh","aoh", Opera.SQL.names)
Opera.SQL.suffix <- rep("prediction",length(Opera.SQL.names))
# Make the names of the columns match the database:
Opera.SQL.suffix[regexpr("logd55", Opera.SQL.names)!=-1] <- "logd55"
Opera.SQL.suffix[regexpr("logd74", Opera.SQL.names)!=-1] <- "logd74"
Opera.SQL.suffix[regexpr("pka_a", Opera.SQL.names)!=-1] <- "pka_a"
Opera.SQL.suffix[regexpr("pka_b", Opera.SQL.names)!=-1] <- "pka_b"
# Can't change this until we have identified the columns:
Opera.SQL.names <- gsub("logd55","logd", Opera.SQL.names)
Opera.SQL.names <- gsub("logd74","logd", Opera.SQL.names)
Opera.SQL.names <- gsub("pka_a","pka", Opera.SQL.names)
Opera.SQL.names <- gsub("pka_b","pka", Opera.SQL.names)

  # ── Build SQL Query ─────────────────────────
  var.names <- paste0('\"',
    paste0(Opera.SQL.names,
      '\".\"',
      Opera.SQL.suffix,
      collapse='\",\n\"'),
    '\"\n')

  Opera <- try(pg_query(
  conn, paste0('
  SELECT "chemical_identifier"."cichem" AS "cichem", ', 
  var.names, '
  FROM "opera_prediction_molecule"
  LEFT OUTER JOIN "chemical_identifier" 
    ON ("opera_prediction_molecule"."inchikey" = "chemical_identifier"."inchikey")
   LEFT OUTER JOIN "opera_aoh_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_aoh_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_bcf_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_bcf_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_biodeg_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_biodeg_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_bp_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_bp_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_caco2_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_caco2_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_clint_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_clint_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_fub_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_fub_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_hl_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_hl_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_km_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_km_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_koa_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_koa_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_koc_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_koc_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_logp_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_logp_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_mp_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_mp_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_vp_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_vp_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_ws_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_ws_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_rbiodeg_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_rbiodeg_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_rt_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_rt_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_logd_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_logd_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_pka_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_pka_endpoint"."molecule_id")
  LEFT OUTER JOIN "opera_catmos_endpoint"
    ON ("opera_prediction_molecule"."id" = "opera_catmos_endpoint"."molecule_id")
 WHERE "chemical_identifier"."cichem" IN (?cichems) AND 
    "opera_prediction_molecule"."opera_version" = \'',
    opera_version, '\'
 ORDER BY "opera_prediction_molecule"."opera_version" DESC'),
  schema = "public",
  cichems = pg_escape_vector(cichem_list)
  ))

  colnames(Opera) <- c("MoleculeID",descriptors)

  rownames(Opera) <- Opera$MoleculeID

  return(Opera)
}