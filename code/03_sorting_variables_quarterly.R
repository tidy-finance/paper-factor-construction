library(dplyr)
library(tidyr)
library(lubridate)
library(multidplyr)
library(arrow)
library(slider)
library(tidyfinance)

source("code/00_global_options.R")

cluster <- new_cluster(parallel::detectCores() - 1)
cluster_library(cluster, c("lubridate", "slider", "dplyr", "tidyfinance"))

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

# Define analysis start date
min_analysis_date <- as.Date("1972-01-01")

# Helper function to compute standardized quarterly variables
compute_standardized_variable <- function(
  data,
  variable_name,
  lag_variable_name,
  output_name,
  cluster,
  min_analysis_date
) {
  data |>
    mutate(
      temp_var = {{ variable_name }} - {{ lag_variable_name }}
    ) |>
    select(gvkey, date, temp_var) |>
    drop_na() |>
    arrange(gvkey, date) |>
    group_by(gvkey) |>
    multidplyr::partition(cluster) |>
    mutate(
      temp_sd = compute_rolling_sd(
        pick(everything()),
        column = temp_var,
        period = "quarter",
        periods = 8,
        min_obs = 6
      ),
      {{ output_name }} := temp_var / temp_sd,
      {{ output_name }} := if_else(
        date >= min_analysis_date,
        {{ output_name }},
        NA_real_
      )
    ) |>
    collect() |>
    ungroup() |>
    select(gvkey, date, {{ output_name }}) |>
    drop_na()
}

# Revenue surprise
compustat_quarterly_rs <- compute_standardized_variable(
  data = compustat_quarterly,
  variable_name = int_rps,
  lag_variable_name = int_rps_lag4,
  output_name = sv_rs,
  cluster = cluster,
  min_analysis_date = min_analysis_date
)

compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_rs,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )

# Standardized unexpected earnings
compustat_quarterly_sue <- compute_standardized_variable(
  data = compustat_quarterly,
  variable_name = int_sue,
  lag_variable_name = int_sue_lag4,
  output_name = sv_sue,
  cluster = cluster,
  min_analysis_date = min_analysis_date
)

compustat_quarterly <- compustat_quarterly |>
  left_join(
    compustat_quarterly_sue,
    join_by(gvkey, date),
    relationship = "one-to-one"
  )

# Calculate main variables

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

sorting_variables_quarterly |>
  write_parquet(file.path(data_folder, "sorting_variables_quarterly.parquet"))
