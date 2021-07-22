# use 2020 to check if all years are avail
safe_s3_check <- function(h3) {
  s3_uris <- paste0("s3://pm25-brokamp/", h3, "_2020_h3pm.fst")
  safe_check <- purrr::possibly(s3:::s3_check_for_file_s3, otherwise = FALSE)
  safe_check(s3_uris)
}

.onLoad <- function(libname, pkgname){
  message('Checking for PM data availability...')
  safe_harbor_h3_avail <- purrr::map_lgl(safe_harbor_h3, safe_s3_check)
  safe_harbor_h3_avail <<- safe_harbor_h3[safe_harbor_h3_avail]
  pct <- round(length(safe_harbor_h3[safe_harbor_h3_avail]) / length(safe_harbor_h3) * 100)
  cli::cli_alert_success("Done. {pct}% of resolution 3 hexagons have PM data available.")
}


