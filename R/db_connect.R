load_config <- function() {
  load_dot_env(file.path(getwd(), ".env"), overwrite = FALSE)
  list(
    pg_host = Sys.getenv("PGHOST", unset = NA_character_),
    pg_port = as.integer(Sys.getenv("PGPORT", unset = "5432")),
    pg_database = Sys.getenv("PGDATABASE", unset = "spainelectoralpollsdb"),
    pg_user = Sys.getenv("PGUSER", unset = NA_character_),
    pg_password = Sys.getenv("PGPASSWORD", unset = NA_character_),
    wiki_user_agent = Sys.getenv("WIKI_USER_AGENT", unset = NA_character_)
  )
}

validate_config <- function(config) {
  required <- c("pg_host", "pg_database", "pg_user", "pg_password", "wiki_user_agent")
  env_names <- c(
    pg_host = "PGHOST",
    pg_database = "PGDATABASE",
    pg_user = "PGUSER",
    pg_password = "PGPASSWORD",
    wiki_user_agent = "WIKI_USER_AGENT"
  )
  missing <- required[vapply(required, function(name) is_blank(config[[name]]), logical(1))]
  if (length(missing) > 0) {
    stop("Missing required environment variables: ", paste(unname(env_names[missing]), collapse = ", "), call. = FALSE)
  }
  invisible(TRUE)
}

db_connect <- function(config = load_config()) {
  validate_config(config)
  DBI::dbConnect(
    RPostgres::Postgres(),
    host = config$pg_host,
    port = config$pg_port,
    dbname = config$pg_database,
    user = config$pg_user,
    password = config$pg_password
  )
}

db_disconnect <- function(con) {
  if (!is.null(con) && DBI::dbIsValid(con)) {
    DBI::dbDisconnect(con)
  }
}
