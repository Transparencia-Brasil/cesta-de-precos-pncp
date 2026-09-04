suppressPackageStartupMessages(library(DBI))
suppressPackageStartupMessages(library(RPostgres))
suppressPackageStartupMessages(library(dotenv))

conecta_bd_medicamentos_transparentes <- function() {
  dotenv::load_dot_env()

  DBI::dbConnect(
    RPostgres::Postgres(),
    dbname = "medicamentos_transparentes",
    host = Sys.getenv("DB_HOST"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASS"),
    port = Sys.getenv("DB_PORT")
  )
}

get_query <- function(qry, quiet = FALSE) {
  if (!quiet) {
    dbname <- DBI::dbGetInfo(con)$dbname
    message(sprintf("dbname: %s\n%s", dbname, qry))
  }

  DBI::dbGetQuery(con, qry) |>
    tibble::as_tibble()
}
