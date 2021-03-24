
<!-- README.md is generated from README.Rmd. Please edit that file -->

# addPmData

<!-- badges: start -->

[![R-CMD-check](https://github.com/geomarker-io/addPmData/workflows/R-CMD-check/badge.svg)](https://github.com/geomarker-io/addPmData/actions)
<!-- badges: end -->

The goal of addPmData is to add PM estimates to geocoded data based on
h3 geohash.

More information on the building of the PM model and creation of PM
chunk files can be found
[here](https://github.com/geomarker-io/st_pm_hex).

## Installation

You can install the development version from
[GitHub](https://github.com/) with:

``` r
# install.packages("remotes")
remotes::install_github("geomarker-io/addPmData")
```

## Example

This is a basic example which shows you how to solve a common problem:

``` r
library(addPmData)

d <- tibble::tribble(
  ~id,         ~lat,    ~lon, ~start_date,    ~end_date,
  '55000100280', 39.2, -84.6, '2008-09-09', '2008-09-11',
  '55000100281', 39.2, -84.6, '2007-08-05', '2007-08-08',
  '55000100282', 39.2, -84.6, '2015-08-31', '2015-09-02') %>%
  dplyr::mutate(dplyr::across(c(start_date, end_date), as.Date))

add_pm(d)
#> matching lat/lon to h3 cells...
#> downloading PM chunk files...
#> ℹ all files already exist
#> Reading in and joining PM data...
#> # A tibble: 10 x 11
#>    id       lat   lon start_date end_date   date       h3_3  h3     year pm_pred
#>    <chr>  <dbl> <dbl> <date>     <date>     <date>     <chr> <chr> <dbl>   <dbl>
#>  1 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-05 832a… 882a…  2007   29.3 
#>  2 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-06 832a… 882a…  2007   28.5 
#>  3 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-07 832a… 882a…  2007   22.3 
#>  4 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-08 832a… 882a…  2007   20.7 
#>  5 55000…  39.2 -84.6 2008-09-09 2008-09-11 2008-09-09 832a… 882a…  2008    8.23
#>  6 55000…  39.2 -84.6 2008-09-09 2008-09-11 2008-09-10 832a… 882a…  2008    9.58
#>  7 55000…  39.2 -84.6 2008-09-09 2008-09-11 2008-09-11 832a… 882a…  2008   13.0 
#>  8 55000…  39.2 -84.6 2015-08-31 2015-09-02 2015-08-31 832a… 882a…  2015   12.7 
#>  9 55000…  39.2 -84.6 2015-08-31 2015-09-02 2015-09-01 832a… 882a…  2015   17.2 
#> 10 55000…  39.2 -84.6 2015-08-31 2015-09-02 2015-09-02 832a… 882a…  2015   19.4 
#> # … with 1 more variable: pm_se <dbl>
```
