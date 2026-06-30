#' Retrieve Padel descriptors from SQL database
#' 
#' @author John Wambaugh and Andy Shapiro
#'
#' @references
#' Yap, Chun Wei. "PaDEL‐descriptor: An open source software to calculate molecular descriptors and fingerprints." Journal of computational chemistry 32.7 (2011): 1466-1474.
#'
#' @export get_padel
get_padel <- function(cichem_list = chems,
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

 # cichem_list   <- chems
 # opera_version <- "2.9"                      # default; change as needed
  column_names  <- descriptors # NULL = all descriptors; or e.g. c("ALogP", "AMR")
  # R changed "-" to "."
  column_names  <- gsub("\\.", "-", column_names)
  # ── Build column annotation for RETURNS SETOF RECORD ─────────────────────────
  # The function returns an untyped record set, so we must tell PostgreSQL the
  # column names and types in the calling AS t(...) clause.

  lookup_sql <- "
    SELECT name
    FROM   descriptor_lookup
    WHERE  tool_name    = 'Padel'
      AND  tool_version = $1
      AND  ($2::TEXT[] IS NULL OR name = ANY($2::TEXT[]))
    ORDER  BY index
  "
  descriptor_names <- dbGetQuery(con, lookup_sql, params = list(
      opera_version,
      ifelse(is.null(column_names), 
        NA, 
        paste0("{", paste(column_names, collapse = ","), "}")
        )  # NA -> NULL in RPostgres
      )
    )$name

  col_defs <- paste(
    c('"cichem" TEXT',
      paste0('"', descriptor_names, '" FLOAT8')),
    collapse = ", "
  )

  # ── Call the stored procedure ─────────────────────────────────────────────────

  proc_sql <- sprintf(
    "SELECT * FROM get_padel_descriptors($1, $2, $3) AS t(%s)",
    col_defs
  )

  Padel <- dbGetQuery(con, proc_sql, params = list(
    paste0("{", paste(cichem_list, collapse = ","), "}"),
    opera_version,
    ifelse(is.null(column_names), 
        NA, 
        paste0("{", paste(column_names, collapse = ","), "}")
        )  # NA -> NULL in RPostgres
    )
    )
  
  colnames(Padel)[1] <- "MoleculeID"
  colnames(Padel) <- gsub("-", "\\.", colnames(Padel))
  rownames(Padel) <- sort(cichem_list)

  return (Padel)
}