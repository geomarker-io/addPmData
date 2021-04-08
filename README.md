
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

Our PM estimates are currently private, and access requires
authenication through Amazon s3. Please contact us for credentials, and
see our documentation for [how to set up AWS credentials in
R](https://github.com/geomarker-io/s3#setting-up-aws-credentials).

## Installation

You can install the development version from
[GitHub](https://github.com/) with:

``` r
# install.packages("remotes")
remotes::install_github("geomarker-io/addPmData")
```

## Example

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
#>    id       lat   lon start_date end_date   date        year h3    h3_3  pm_pred
#>    <chr>  <dbl> <dbl> <date>     <date>     <date>     <dbl> <chr> <chr>   <dbl>
#>  1 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-05  2007 882a… 832a…   29.3 
#>  2 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-06  2007 882a… 832a…   28.5 
#>  3 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-07  2007 882a… 832a…   22.3 
#>  4 55000…  39.2 -84.6 2007-08-05 2007-08-08 2007-08-08  2007 882a… 832a…   20.7 
#>  5 55000…  39.2 -84.6 2008-09-09 2008-09-11 2008-09-09  2008 882a… 832a…    8.23
#>  6 55000…  39.2 -84.6 2008-09-09 2008-09-11 2008-09-10  2008 882a… 832a…    9.58
#>  7 55000…  39.2 -84.6 2008-09-09 2008-09-11 2008-09-11  2008 882a… 832a…   13.0 
#>  8 55000…  39.2 -84.6 2015-08-31 2015-09-02 2015-08-31  2015 882a… 832a…   12.7 
#>  9 55000…  39.2 -84.6 2015-08-31 2015-09-02 2015-09-01  2015 882a… 832a…   17.2 
#> 10 55000…  39.2 -84.6 2015-08-31 2015-09-02 2015-09-02  2015 882a… 832a…   19.4 
#> # … with 1 more variable: pm_se <dbl>
```
