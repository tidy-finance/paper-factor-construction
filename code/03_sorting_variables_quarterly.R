library("dplyr")
library("lubridate")
library("arrow")
library("tidyfinance")

# Quarterly Compustat data quality is insufficient before 1972 to compute revenue surprise and standardized unexpected earnings
min_analysis_date <- as.Date("1972-01-01")

compustat_quarterly <- open_dataset("data/compustat_quarterly.parquet")

compustat_quarterly <- compustat_quarterly |>
  arrange(gvkey, date) |>
  mutate(
    int_rps = saleq / (cshprq * ajexq),
    int_sue = epspxq / ajexq,
    int_beq = coalesce(seqq, ceqq + pstkq, atq - ltq) +
      coalesce(txditcq, txdbq, 0) -
      coalesce(pstkrq, pstkq, 0)
  ) |>
  collect()

## One quarter lag
compustat_quarterly <- compustat_quarterly |>
  add_lagged_columns(
    cols = c("atq", "int_beq"),
    by = "gvkey",
    lag = months(3),
    data_options = data_options(date = "date")
  ) |>
  rename(atq_lag1 = atq_lag, int_beq_lag1 = int_beq_lag)

## Four quarter lag
compustat_quarterly <- compustat_quarterly |>
  add_lagged_columns(
    cols = c("int_rps", "int_sue"),
    by = "gvkey",
    lag = months(12),
    data_options = data_options(date = "date")
  ) |>
  rename(int_rps_lag4 = int_rps_lag, int_sue_lag4 = int_sue_lag)

# Compute standardized seasonal surprise for a quarterly variable.
# Uses year-over-year change (4-quarter delta), standardized by the rolling
# standard deviation of deltas over the past 8 quarters (min 6 required).
compute_standardized_surprise <- function(
  data,
  delta_col,
  output_col
) {
  data |>
    arrange(gvkey, date) |>
    mutate(
      int_delta = {{ delta_col }},
      int_delta = if_else(is.finite(int_delta), int_delta, NA_real_)
    ) |>
    filter(!is.na(int_delta)) |>
    group_by(gvkey) |>
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
    select(gvkey, date, {{ output_col }})
}

# Revenue surprise
compustat_quarterly_rs <- compute_standardized_surprise(
  compustat_quarterly |> select(gvkey, date, int_rps, int_rps_lag4),
  int_rps - int_rps_lag4,
  sv_rs
) |>
  filter(date >= min_analysis_date)

compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_rs,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )

# Standardized unexpected earnings
compustat_quarterly_sue <- compute_standardized_surprise(
  compustat_quarterly |> select(gvkey, date, int_sue, int_sue_lag4),
  int_sue - int_sue_lag4,
  sv_sue
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
