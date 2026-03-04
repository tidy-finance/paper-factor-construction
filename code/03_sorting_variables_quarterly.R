library(dplyr)
library(tidyr)
library(lubridate)
library(multidplyr)
library(arrow)
library(slider)
library(tidyfinance)

min_analysis_date <- as.Date("1972-01-01")

cluster <- new_cluster(parallel::detectCores() - 1)
cluster_library(cluster, c("tidyfinance", "dplyr"))

compustat_quarterly <- open_dataset("data/compustat_quarterly.parquet")

crsp_monthly <- open_dataset("data/crsp_monthly.parquet")

compustat_quarterly <- compustat_quarterly |>
  left_join(
    crsp_monthly |>
      select(gvkey, date, mktcap, siccd),
    join_by(gvkey, date),
    relationship = "one-to-one"
  ) |>
  collect()

compustat_quarterly <- compustat_quarterly |>
  mutate(
    int_rps = saleq / (cshprq * ajexq),
    int_sue = epspxq / ajexq,
    int_beq = coalesce(seqq, ceqq + pstkq, atq - ltq) +
      coalesce(txditcq, txdbq, 0) -
      coalesce(pstkrq, pstkq, 0)
  ) |>
  rename(int_me = mktcap)

## One quarter lag
compustat_quarterly <- compustat_quarterly |>
  add_lag_columns(cols = c("atq", "int_beq"), by = "gvkey", lag = months(3)) |>
  rename(atq_lag1 = atq_lag, int_beq_lag1 = int_beq_lag)

## Four quarter lag
compustat_quarterly <- compustat_quarterly |>
  add_lag_columns(
    cols = c("int_rps", "int_sue"),
    by = "gvkey",
    lag = months(12)
  ) |>
  rename(int_rps_lag4 = int_rps_lag, int_sue_lag4 = int_sue_lag)

# Revenue surprise
compustat_quarterly_rs <- compustat_quarterly |>
  arrange(gvkey, date) |>
  group_by(gvkey) |>
  partition(cluster) |>
  mutate(
    int_rps_delta = int_rps - int_rps_lag4
  ) |>
  filter(!is.na(int_rps_delta)) |>
  mutate(
    sv_rs = compute_rolling_value(
      pick(everything()),
      .f = ~ last(.x$int_rps_delta) / sd(.x$int_rps_delta),
      period = "quarter",
      periods = 8,
      min_obs = 6
    )
  ) |>
  ungroup() |>
  collect() |>
  select(gvkey, date, sv_rs) |>
  filter(date >= min_analysis_date)

compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_rs,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )

# Standardized unexpected earnings
compustat_quarterly_sue <- compustat_quarterly |>
  arrange(gvkey, date) |>
  group_by(gvkey) |>
  partition(cluster) |>
  mutate(
    int_sue_delta = int_sue - int_sue_lag4
  ) |>
  filter(!is.na(int_sue_delta)) |>
  mutate(
    sv_sue = compute_rolling_value(
      pick(everything()),
      .f = ~ last(.x$int_sue_delta) / sd(.x$int_sue_delta),
      period = "quarter",
      periods = 8,
      min_obs = 6
    )
  ) |>
  ungroup() |>
  collect() |>
  select(gvkey, date, sv_sue) |>
  filter(date >= min_analysis_date)

compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_sue,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )

sorting_variables_quarterly <- compustat_quarterly |>
  mutate(
    sv_roa = ibq / atq_lag1,
    sv_roe = ibq / int_beq_lag1
  )

# Remove Inf and NaN
sorting_variables_quarterly <- sorting_variables_quarterly |>
  mutate(
    across(starts_with("sv_"), ~ na_if(., Inf)),
    across(starts_with("sv_"), ~ na_if(., -Inf)),
    across(starts_with("sv_"), ~ if_else(is.nan(.x), NA_real_, .x))
  )

sorting_variables_quarterly <- sorting_variables_quarterly |>
  select(gvkey, date, starts_with("sv_"))

write_parquet(
  sorting_variables_quarterly,
  "data/sorting_variables_quarterly.parquet"
)
