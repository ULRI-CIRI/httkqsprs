#' Retrieve Padel descriptors from SQL database
#'
#' @author Andy Shapiro and John Wambaugh
#'
#' @references
#' Yap, Chun Wei. "PaDEL‐descriptor: An open source software to calculate molecular descriptors and fingerprints." Journal of computational chemistry 32.7 (2011): 1466-1474.
#'
#' @export get_padel
get_padel <- function(
  cichem_list = NULL,
  descriptors = NULL,
  opera_version = "2.9"
) {
  if (nchar(Sys.getenv("PIPELINES_CONN_STR")) == 0) {
    stop("Environmental variable PIPELINES_CONN_STR is not set")
  }

  conn <- pg_connection_from_env('PIPELINES_CONN_STR')

  selected <- descriptors
  col_defs <- paste(
    c('"cichem" TEXT', paste0('"', selected, '" FLOAT8')),
    collapse = ", "
  )

  sql <- sprintf(
    "SELECT * FROM get_padel_descriptors(?cichems, '%s', ?descriptors) AS t(%s)",
    opera_version,
    col_defs
  )

  valid.descs <- unlist(pg_query(
    conn,
    '
    SELECT
      descriptor_lookup.name
    FROM descriptor_lookup
      WHERE descriptor_lookup.tool_name = ?tool_name
      AND descriptor_lookup.tool_version = ?tool_version
    ',
    tool_name = "Padel",
    tool_version = opera_version,
  ))

  # Convert strings in older models to current names in the database:
  selected <- gsub("\\.", "-", selected)
  # Many underscors are dashes in the db:
  selected <- gsub("_", "-", selected)
  # Name change:
  selected <- gsub("nbRotBd", "nRotB", selected)
  # some variables do have underscores:
  for (this.substring in c("mlfer", "spmax", "eta", "tpipctpc", "spmin")) {
    selected[regexpr(this.substring, tolower(selected)) != -1] <-
      gsub("-", "_", selected[regexpr(this.substring, tolower(selected)) != -1])
  }

  if (!all(selected %in% valid.descs)) {
    cat(
      "The following requested descriptors are not available for PaDEL version ",
      opera_version,
      ":\n"
    )
    cat(setdiff(selected, valid.descs), sep = "\n")
    browser()
  }

  Padel <- as.data.frame(pg_query(
    conn,
    sql,
    schema = "public",
    cichems = pg_escape_vector(cichem_list, array_type = "TEXT"),
    descriptors = pg_escape_vector(selected, array_type = "TEXT")
  ))

  colnames(Padel)[1] <- "MoleculeID"
  colnames(Padel) <- c("MoleculeID", descriptors)
  rownames(Padel) <- Padel$MoleculeID

  return(Padel)
}
