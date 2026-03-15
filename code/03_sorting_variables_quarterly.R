library(dplyr)
library(tidyr)
library(lubridate)
library(multidplyr)
library(arrow)
library(slider)
library(tidyfinance)

# Quarterly Compustat data quality is insufficient before 1972
min_analysis_date <- as.Date("1972-01-01")

cluster <- new_cluster(future::availableCores() - 1)
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
# NOTE: atq /int_beq has 25% / 23% missing
compustat_quarterly <- compustat_quarterly |>
  add_lag_columns(cols = c("atq", "int_beq"), by = "gvkey", lag = months(3)) |>
  rename(atq_lag1 = atq_lag, int_beq_lag1 = int_beq_lag)

## Four quarter lag
# NOTE: int_rps / int_sue has 20% missing
compustat_quarterly <- compustat_quarterly |>
  add_lag_columns(
    cols = c("int_rps", "int_sue"),
    by = "gvkey",
    lag = months(12)
  ) |>
  rename(int_rps_lag4 = int_rps_lag, int_sue_lag4 = int_sue_lag)

# Compute standardized seasonal surprise for a quarterly variable.
# Uses year-over-year change (4-quarter delta), standardized by the rolling
# standard deviation of deltas over the past 8 quarters (min 6 required).
# TODO: align computation with Jegadeesh & Livnat (2006): https://www.jstor.org/stable/pdf/4480742.pdf
# They estimate a random walk with drift to compute the surprise!
compute_standardized_surprise <- function(
  data,
  delta_col,
  output_col,
  cluster
) {
  data |>
    arrange(gvkey, date) |>
    group_by(gvkey) |>
    partition(cluster) |>
    mutate(int_delta = {{ delta_col }}) |>
    filter(!is.na(int_delta)) |>
    mutate(
      {{ output_col }} := compute_rolling_value(
        pick(everything()),
        .f = ~ last(.x$int_delta) / sd(.x$int_delta),
        period = "quarter",
        periods = 8,
        min_obs = 6
      )
    ) |>
    ungroup() |>
    collect() |>
    select(gvkey, date, {{ output_col }})
}

# Revenue surprise
# NOTE: sv_rs contains 89% missing values
compustat_quarterly_rs <- compute_standardized_surprise(
  compustat_quarterly,
  int_rps - int_rps_lag4,
  sv_rs,
  cluster
) |>
  filter(date >= min_analysis_date)

compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_rs,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )

# Standardized unexpected earnings
# NOTE: sv_sue contains 91% missing values
compustat_quarterly_sue <- compute_standardized_surprise(
  compustat_quarterly,
  int_sue - int_sue_lag4,
  sv_sue,
  cluster
) |>
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
    across(starts_with("sv_"), ~ if_else(is.finite(.x), .x, NA_real_))
  )

sorting_variables_quarterly <- sorting_variables_quarterly |>
  select(gvkey, date, starts_with("sv_"))

write_parquet(
  sorting_variables_quarterly,
  "data/sorting_variables_quarterly.parquet"
)
