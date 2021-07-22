library(tidyverse)

safe_hex_lookup <- tibble::tibble(safe_hex = safe_harbor_h3) %>%
  filter(stringr::str_detect(safe_hex, "-")) %>%
  mutate(row_id = 1:nrow(.)) %>%
  group_by(row_id) %>%
  nest() %>%
  mutate(splits = map(data, ~stringr::str_split(.x$safe_hex, "-"))) %>%
  unnest(cols = c(data, splits)) %>%
  unnest(cols = c(splits)) %>%
  ungroup() %>%
  select(h3_3 = splits, safe_hex)

saveRDS(safe_hex_lookup, './data-raw/safe_hex_lookup.rds')

