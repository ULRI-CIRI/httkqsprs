#' Retrieve OPeRA descriptors from SQL database
#' 
#' @author John Wambaugh and Andy Shapiro
#'
#' @references
#' Mansouri, Kamel, et al. "OPERA models for predicting physicochemical properties and environmental fate endpoints." Journal of cheminformatics 10.1 (2018): 10.
#' 
#' @export get_opera
get_opera <- function(cichem_list = chems,
                      descriptors = NULL,
                      opera_version = "2.9", 
                      conn_str = NULL)
{
  if (is.null(conn_str)) {
    if (exists("PIPELINES_CONN_STR")) conn_str <- PIPELINES_CONN_STR
    else conn_str <- Sys.getenv("PIPELINES_CONN_STR")
  } 
  # Code from Andy Shapiro:
  if (nchar(conn_str) == 0) stop("PIPELINES_CONN_STR is not set")

  uri   <- httr::parse_url(conn_str)  # parse URI components without httr if preferred
  # Pure-base alternative using regex:
  m <- regmatches(conn_str, regexpr(
    "postgres://([^:]+):([^@]+)@([^:/]+)(?::(\\d+))?/(.+)", conn_str, perl = TRUE
  ))
  parts <- regmatches(conn_str, regexec(
    "postgres://([^:]+):([^@]+)@([^:/]+)(?::(\\d+))?/(.+)", conn_str, perl = TRUE
  ))[[1]]

  con <- dbConnect(
    RPostgres::Postgres(),
    user     = parts[2],
    password = parts[3],
    host     = parts[4],
    port     = if (nchar(parts[5]) > 0) as.integer(parts[5]) else 5432L,
    dbname   = parts[6]
  )
  on.exit(dbDisconnect(con), add = TRUE)

  # ── Parameters ────────────────────────────────────────────────────────────────
  # parameters are set by call to function
  column_names  <- descriptors # NULL = all descriptors; or e.g. c("ALogP", "AMR")

# Convert names as given by OPERA Excel output into SQL names:
Opera.SQL.names <- paste0("opera_",
  gsub("_pred","",tolower(Descriptors$Opera)),
  "_endpoint") 
Opera.SQL.names <- gsub("logws","ws", Opera.SQL.names)
Opera.SQL.names <- gsub("logbcf","bcf", Opera.SQL.names)
Opera.SQL.names <- gsub("logkm","km", Opera.SQL.names)
Opera.SQL.names <- gsub("logvp","vp", Opera.SQL.names)
Opera.SQL.names <- gsub("logoh","aoh", Opera.SQL.names)
Opera.SQL.suffix <- rep("prediction",length(Opera.SQL.names))
Opera.SQL.suffix[regexpr("logd55", Opera.SQL.names)!=-1] <- "logd55"
Opera.SQL.suffix[regexpr("logd74", Opera.SQL.names)!=-1] <- "logd74"
Opera.SQL.names <- gsub("logd55","logd", Opera.SQL.names)
Opera.SQL.names <- gsub("logd74","logd", Opera.SQL.names)

  # ── Build SQL Query ─────────────────────────
  var.names <- paste0('"',paste0(Opera.SQL.names,'"."',Opera.SQL.suffix,collapse='",\n"'),'"\n')
  chem.names <- paste0("'", paste0(cichem_list, collapse="', '"), "'")

  opera_query <- paste0('
SELECT ', var.names, '
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
 WHERE "chemical_identifier"."cichem" = ANY(ARRAY[',
  chem.names, ']) AND 
    "opera_prediction_molecule"."opera_version" = ', paste0("'",opera_version,"'"), '
 ORDER BY "opera_prediction_molecule"."opera_version" DESC
 LIMIT 100
')


  # ── Call the stored procedure ─────────────────────────────────────────────────

  Opera <- try(dbGetQuery(con, opera_query))
  colnames(Opera) <- descriptors

  rownames(Opera) <- sort(cichem_list)

  return (Opera)
}