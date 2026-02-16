library(dplyr)
library(lubridate)
library(arrow)
library(tidyfinance)

source("code/00_global_options.R")

sorting_variables_yearly <- read_parquet(
  file.path(data_folder, "sorting_variables_yearly.parquet")
)

sorting_variables_quarterly <- read_parquet(
  file.path(data_folder, "sorting_variables_quarterly.parquet")
)

sorting_variables_monthly <- read_parquet(
  file.path(data_folder, "sorting_variables_monthly.parquet")
)

crsp_monthly <- open_dataset(
  file.path(data_folder, "crsp_monthly.parquet")
) |>
  select(gvkey, permno, date, ret_excess, exchange, industry, mktcap_lag) |>
  collect()

filter_monthly <- sorting_variables_monthly |>
  select(permno, date, starts_with("filter_"))

sorting_variables_monthly <- sorting_variables_monthly |>
  select(permno, date, starts_with("sv_"))

filter_yearly <- sorting_variables_yearly |>
  select(gvkey, date, starts_with("filter_"))

sorting_variables_yearly <- sorting_variables_yearly |>
  select(gvkey, date, starts_with("sv_"))


crsp_monthly <- crsp_monthly |>
  join_lagged_values(
    filter_monthly,
    "permno",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  join_lagged_values(
    filter_yearly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  filter(filter_stock_age >= min_stock_age) |>
  filter(date >= date_start, date <= date_end) |>
  select(-filter_stock_age)

# Lag 3m ------------------------------------------------------------------
# Exactly lag by three months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag3m <- crsp_monthly |>
  join_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  join_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  )

write_parquet(
  sv_lag3m,
  file.path(data_folder, "sorting_variables_lag_3m.parquet")
)

# Lag 6m ------------------------------------------------------------------
# Exactly lag by six months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag6m <- crsp_monthly |>
  join_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(6),
    max_lag = months(12)
  ) |>
  join_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(12)
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(12)
  )

write_parquet(
  sv_lag6m,
  file.path(data_folder, "sorting_variables_lag_6m.parquet")
)

# Lag FF ------------------------------------------------------------------
# Lag variables from year t to July t+1
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

# TODO: why does this take forever?
sv_lag_ff <- crsp_monthly |>
  join_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  ) |>
  join_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  )

write_parquet(
  sv_lag_ff,
  file.path(data_folder, "sorting_variables_lag_ff.parquet")
)
