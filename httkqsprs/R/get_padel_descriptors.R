# get_padel_descriptors.R
#
# Example: call the get_padel_descriptors() stored procedure from R.
#
# Requirements:
#   install.packages(c("DBI", "RPostgres"))
#
# Set PIPELINES_CONN_STR in your environment or .Renviron, e.g.:
#   PIPELINES_CONN_STR="postgres://username:password@host:5432/pipelines"

library(DBI)
library(RPostgres)

# ── Connection ────────────────────────────────────────────────────────────────

conn_str <- Sys.getenv("PIPELINES_CONN_STR")
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

cichem_list   <- c("CICHEM000000001", "CICHEM000000002", "CICHEM000000003")
opera_version <- "2.9"                      # default; change as needed
column_names  <- NULL                       # NULL = all descriptors; or e.g. c("ALogP", "AMR")

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
  if (is.null(column_names)) NA else column_names  # NA -> NULL in RPostgres
))$name

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

result <- dbGetQuery(con, proc_sql, params = list(
  cichem_list,
  opera_version,
  if (is.null(column_names)) NA else column_names
))

print(result)
