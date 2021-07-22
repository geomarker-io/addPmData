#' @import data.table

prep_data <- function(d, type = 'coords') {
  d$row_index <- 1:nrow(d)

  if(type == 'coords') {
    dht::check_for_column(d, 'lon', d$lon)
    dht::check_for_column(d, 'lat', d$lat)
  }

  if(type == 'h3') {
    dht::check_for_column(d, 'h3', d$h3)
  }

  dht::check_for_column(d, 'start_date', d$start_date)
  dht::check_for_column(d, 'end_date', d$end_date)

  d$start_date <- dht::check_dates(d$start_date)
  d$end_date <- dht::check_dates(d$end_date)
  dht::check_end_after_start_date(d$start_date, d$end_date)
  return(d)
}

read_chunk_join <- function(d_split, fl_path, verbose=FALSE) {
  if(verbose) message("processing ", stringr::str_split(fl_path, '/')[[1]][length(stringr::str_split(fl_path, '/')[[1]])], " ...")
  chunk <- fst::read_fst(fl_path, as.data.table = TRUE)

  d_split_pm <- dplyr::left_join(d_split, chunk, by = c('h3', 'date'))
  rm(chunk)
  return(d_split_pm)
}

get_unique_h3_3_year <- function(pm_chunks) {
  pm_chunks %>%
    dplyr::mutate(split_str = stringr::str_split(uri, '/')) %>%
    tidyr::unnest(split_str) %>%
    dplyr::group_by(uri) %>%
    dplyr::slice_tail() %>%
    dplyr::mutate(h3_3_year = stringr::str_sub(split_str, 1,  -10))
}


#' add PM2.5 concentrations to geocoded data based on h3 geohash
#'
#' @param d dataframe with columns called 'lat', 'lon', 'start_date' and 'end_date'
#' @param type either 'coords' (if d contains lat/lon) or 'h3' (if d contains
#'             . resolution 8 h3 ids)
#' @param verbose if TRUE a statement is printed to the console telling the user
#'                which chunk file is currently being processed. Defaults to FALSE.
#' @param ... arguments passed to \code{\link[s3]{s3_get_files}}
#'
#' @return the input dataframe, expanded to include one row per day between the given 'start_date'
#'         and 'end_date', with appended columns for h3_3 (resolution 3), h3 (resolution 8),
#'         year, pm_pred, and pm_se.
#'
#' @examples
#' if (FALSE) {
#' d <- tibble::tribble(
#'      ~id,         ~lat,    ~lon, ~start_date,    ~end_date,
#'      '55000100280', 39.2, -84.6, '2008-09-09', '2008-09-11',
#'      '55000100281', 39.2, -84.6, '2007-08-05', '2007-08-08',
#'      '55000100282', 39.2, -84.6, '2015-08-31', '2015-09-02') %>%
#'    dplyr::mutate(dplyr::across(c(start_date, end_date), as.Date))
#'
#'    add_pm(d)
#' }
#' @export
add_pm <- function(d, type = 'coords', verbose = FALSE, ...) {
  d <- prep_data(d, type)

  # dates - expand, extract year, filter out of range
  d <- dht::expand_dates(d, by = 'day')
  d$year <- lubridate::year(d$date)
  out_of_range_year <- sum(d$year < 2000 | d$year > 2020)
  if (out_of_range_year > 0) {
    cli::cli_alert_warning("Data is currently available from 2000 through 2020.")
    cli::cli_alert_info(glue::glue("PM estimates for {out_of_range_year} rows will be NA due to unavailable data.\n"))
    d_missing_date <- dplyr::filter(d, !year %in% 2000:2020)
    d <- dplyr::filter(d, year %in% 2000:2020)
  }

  # coords - filter out missing, match to h3 ids
  if(type == 'coords'){
    n_missing_coords <- nrow(d %>% dplyr::filter(is.na(lat) | is.na(lon)))
    if (n_missing_coords > 0) {
      cli::cli_alert_warning(glue::glue("PM estimates for {n_missing_coords} rows will be NA due to missing coordinates in input data.\n"))
      d_missing_coords <- dplyr::filter(d, is.na(lat) | is.na(lon))
      d <- dplyr::filter(d, !is.na(lat), !is.na(lon))
    }

    message('matching lat/lon to h3 cells...')
    d$h3 <- suppressMessages(h3jsr::point_to_h3(dplyr::select(d, lon, lat), res = 8))
  } else n_missing_coords <- 0

  # h3 res 3 - and match to safe harbor
  d$h3_3 <- h3jsr::get_parent(d$h3, res = 3)

  d <- d %>%
    dplyr::left_join(safe_hex_lookup, by = 'h3_3') %>%
    dplyr::mutate(h3_3 = ifelse(!is.na(safe_hex), safe_hex, h3_3)) %>%
    dplyr::select(-safe_hex)

  # h3 availability  - check and filter
  n_unavail <- sum(!d$h3_3 %in% safe_harbor_h3_avail)
  if (n_unavail > 0) {
    cli::cli_alert_warning("This package is under development. Available data is currently limited, but will be available nationwide soon.\n")
    cli::cli_alert_info(glue::glue("PM estimates for {n_unavail} rows will be NA due to unavailable data.\n"))
    d_missing_h3 <- dplyr::filter(d, !h3_3 %in% safe_harbor_h3_avail)
    d <- dplyr::filter(d, h3_3 %in% safe_harbor_h3_avail)
  }

  message('downloading PM chunk files...')
  pm_chunks <-
    glue::glue("s3://pm25-brokamp/{d$h3_3}_{d$year}_h3pm.fst") %>%
    unique() %>%
    s3::s3_get_files(...) %>%
    get_unique_h3_3_year()

  d_split <- split(d, f = list(d$h3_3, d$year), drop=TRUE)

  message('Reading in and joining PM data...')
  xs <- 1:length(d_split)
  progressr::with_progress({
    p <- progressr::progressor(along = xs)
    d_split_pm <- purrr::map(xs, function(x) {
      p(sprintf("x=%g", x))
      read_chunk_join(d_split[[x]],
                      # ensure d_split chunk matches file path
                      pm_chunks[pm_chunks$h3_3_year == paste0(unique(d_split[[x]]$h3_3), "_", unique(d_split[[x]]$year)),]$file_path,
                      verbose)
    })
  })

  d_pm <- dplyr::bind_rows(d_split_pm)
  if (out_of_range_year > 0) d_pm <- dplyr::bind_rows(d_missing_date, d_pm)
  if (n_unavail > 0) d_pm <- dplyr::bind_rows(d_missing_h3, d_pm)
  if (n_missing_coords > 0) d_pm <- dplyr::bind_rows(d_missing_coords, d_pm)
  d_pm <- d_pm %>%
    dplyr::arrange(row_index, date) %>%
    dplyr::select(-row_index)
  return(d_pm)
}

