library(dplyr)
library(tidyr)
library(lubridate)
library(multidplyr)
library(arrow)
library(slider)
library(tidyfinance)

source("code/00_global_options.R")

cluster <- new_cluster(parallel::detectCores() - 1)
cluster_library(cluster, c("lubridate", "slider", "dplyr"))

compustat_quarterly <- open_dataset(
  file.path(data_folder, "compustat_quarterly.parquet")
)

crsp_monthly <- open_dataset(
  file.path(data_folder, "crsp_monthly.parquet")
)

compustat_quarterly <- compustat_quarterly |>
  left_join(
    crsp_monthly |>
      select(gvkey, date, mktcap, siccd),
    join_by(gvkey, date),
    relationship = "one-to-one"
  ) |>
  collect()

# Calculate intermediate variables ---------------------------------------

compustat_quarterly <- compustat_quarterly |>
  mutate(
    int_rps = saleq / (cshprq * ajexq),
    int_sue = epspxq / ajexq,
    int_beq = coalesce(seqq, ceqq + pstkq, atq - ltq) +
      coalesce(txditcq, txdbq, 0) -
      coalesce(pstkrq, pstkq, 0)
  ) |>
  rename(int_me = mktcap)

# Lag certain variables
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
# TODO: Remove compute_rolling_sd definition as soon as it is available in the tidyfinance package
compute_rolling_sd <- function(
  data,
  column,
  period = "quarter",
  periods = 4,
  min_obs = 2
) {
  stopifnot("date" %in% names(data))
  stopifnot(inherits(data$date, "Date"))
  stopifnot(is.character(period), length(period) == 1)

  x <- data |> dplyr::pull({{ column }})

  slider::slide_period_vec(
    .x = x,
    .i = data$date,
    .period = period,
    .f = ~ {
      if (sum(!is.na(.x)) < min_obs) NA_real_ else stats::sd(.x, na.rm = TRUE)
    },
    .before = periods - 1,
    .complete = FALSE
  )
}

cluster_copy(cluster, "compute_rolling_sd")

# Estimate sorting variable
compustat_quarterly_rs <- compustat_quarterly |>
  mutate(
    int_drps = int_rps - int_rps_lag4,
    int_drps = if_else(
      is.nan(int_drps) | is.infinite(int_drps),
      NA_real_,
      int_drps
    )
  ) |>
  select(gvkey, date, int_drps) |>
  drop_na() |>
  arrange(gvkey, date) |>
  group_by(gvkey) |>
  partition(cluster) |>
  mutate(
    sd_drps = compute_rolling_sd(
      pick(everything()),
      column = int_drps,
      period = "quarter",
      periods = 8,
      min_obs = 6
    ),
    sv_rs = int_drps / sd_drps,
    sv_rs = if_else(date >= as.Date("1972-01-01"), sv_rs, NA_real_)
  ) |>
  collect() |>
  ungroup() |>
  select(gvkey, date, sv_rs) |>
  drop_na()

# Remerge
compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_rs,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )

# Standardized unexpected earnings ---------------------------------------

compustat_quarterly_sue <- compustat_quarterly |>
  mutate(
    int_sue = int_sue - int_sue_lag4,
    int_sue = if_else(is.nan(int_sue) | is.infinite(int_sue), NA_real_, int_sue)
  ) |>
  select(gvkey, date, int_sue) |>
  drop_na() |>
  arrange(gvkey, date) |>
  group_by(gvkey) |>
  partition(cluster) |>
  mutate(
    sd_sue = compute_rolling_sd(
      pick(everything()),
      column = int_sue,
      period = "quarter",
      periods = 8,
      min_obs = 6
    ),
    sv_sue = int_sue / sd_sue,
    sv_sue = if_else(date >= as.Date("1972-01-01"), sv_sue, NA_real_)
  ) |>
  collect() |>
  ungroup() |>
  select(gvkey, date, sv_sue) |>
  drop_na()

# Remerge
compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_sue,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )


# Calculate main variables -----------------------------------------------

sorting_variables_quarterly <- compustat_quarterly |>
  mutate(
    sv_roa = ibq / atq_lag1,
    sv_roe = ibq / int_beq_lag1
  )

# Apply filters ----------------------------------------------------------

# Remove Inf and NaN
sorting_variables_quarterly <- sorting_variables_quarterly |>
  mutate(
    across(starts_with("sv_"), ~ na_if(., Inf)),
    across(starts_with("sv_"), ~ na_if(., -Inf)),
    across(starts_with("sv_"), ~ if_else(is.nan(.x), NA_real_, .x))
  )


sorting_variables_quarterly <- sorting_variables_quarterly |>
  select(gvkey, date, starts_with("sv_"))

sorting_variables_quarterly |>
  write_parquet(file.path(data_folder, "sorting_variables_quarterly.parquet"))
