library("dplyr")
library("lubridate")
library("arrow")
library("tidyfinance")

sorting_variables_yearly <- read_parquet(
  "data/sorting_variables_yearly.parquet"
)

sorting_variables_quarterly <- read_parquet(
  "data/sorting_variables_quarterly.parquet"
)

sorting_variables_monthly <- read_parquet(
  "data/sorting_variables_monthly.parquet"
)

crsp_monthly <- open_dataset("data/crsp_monthly.parquet") |>
  select(
    gvkey,
    permno,
    date,
    ret_excess,
    exchange,
    siccd,
    mktcap_lag,
    listing_age
  ) |>
  collect()

sorting_variables_monthly <- sorting_variables_monthly |>
  select(permno, date, starts_with("sv_"))

# Bundle filter_earnings with sv_* so both travel through the same join_lagged_values call.
sorting_variables_yearly <- sorting_variables_yearly |>
  select(gvkey, date, filter_earnings, starts_with("sv_"))

# Lag 3m ------------------------------------------------------------------
# Exactly lag by three months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag3m <- crsp_monthly |>
  join_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(3),
    max_lag = months(15)
  ) |>
  join_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(15)
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(15)
  )

write_parquet(sv_lag3m, "data/sorting_variables_lag_3m.parquet")

# Lag 6m ------------------------------------------------------------------
# Exactly lag by six months
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 12 months after sorting date (not including)

sv_lag6m <- crsp_monthly |>
  join_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(6),
    max_lag = months(18)
  ) |>
  join_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(18)
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(18)
  )

write_parquet(sv_lag6m, "data/sorting_variables_lag_6m.parquet")

# Lag FF ------------------------------------------------------------------
# Lag variables from year t to July t+1
## Include: Monthly, quarterly, and yearly variables
## Allow "old" date up until 18 months after sorting date (not including)
sv_lag_ff <- crsp_monthly |>
  join_lagged_values(
    sorting_variables_monthly,
    "permno",
    min_lag = months(7),
    max_lag = months(18),
    ff_adjustment = TRUE
  ) |>
  join_lagged_values(
    sorting_variables_quarterly,
    "gvkey",
    min_lag = months(7),
    max_lag = months(18),
    ff_adjustment = TRUE
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(7),
    max_lag = months(18),
    ff_adjustment = TRUE
  )

write_parquet(sv_lag_ff, "data/sorting_variables_lag_ff.parquet")
