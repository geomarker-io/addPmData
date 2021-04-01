#' @import data.table

prep_data <- function(d) {
  dht::check_for_column(d, 'lon', d$lon)
  dht::check_for_column(d, 'lat', d$lat)
  dht::check_for_column(d, 'start_date', d$start_date)
  dht::check_for_column(d, 'end_date', d$end_date)

  d$start_date <- dht::check_dates(d$start_date)
  d$end_date <- dht::check_dates(d$end_date)

  check_date_order <- d$end_date > d$start_date
  if (FALSE %in% check_date_order) {
    row_num <- which(!check_date_order)
    cli::cli_alert_danger('end_date occurs before start_date in these rows: {row_num}')
    stop(call. = FALSE)
  }
  # dht::check_end_after_start_date(d$start_date, d$end_date)

  if (any(c(d$start_date < as.Date("2000-01-01"), d$end_date > as.Date("2020-12-31")))) {
    cli::cli_alert_warning("one or more dates are out of range. data is available 2000-2020.")
  }
}

expand_dates <- function(d) {
  d <- dplyr::mutate(d, date = purrr::map2(start_date, end_date, ~seq.Date(from = .x, to = .y, by = 'day')))
  tidyr::unnest(d, cols = c(date))
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
add_pm <- function(d, verbose = FALSE, ...) {
  prep_data(d)

  d <- expand_dates(d)
  # d <- dht::expand_dates(d, by = 'day')

  message('matching lat/lon to h3 cells...')
  d$h3_3 <- suppressMessages(h3jsr::point_to_h3(dplyr::select(d, lon, lat), res = 3))
  cincinnati_h3_3 <- c("832a93fffffffff", "832a90fffffffff", "83266dfffffffff", "832a9efffffffff")
  if (sum(!d$h3_3 %in% cincinnati_h3_3) > 0) {
    cli::cli_alert_warning("This package is under development. Data is only currently available for the Cincinnati region, but will be available nationwide soon.\n
                           Removing non-Cincinnati rows...\n")
    d <- dplyr::filter(d, h3_3 %in% cincinnati_h3_3)
  }

  d$h3 <- suppressMessages(h3jsr::point_to_h3(dplyr::select(d, lon, lat), res = 8))
  d$year <- lubridate::year(d$date)

  message('downloading PM chunk files...')
  pm_chunks <-
    glue::glue("s3://geomarker/st_pm_hex/h3_pm/{d$h3_3}_{d$year}_h3pm.fst") %>%
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

  d_pm <- dplyr::bind_rows(d_pm)
  return(d_pm)
}
