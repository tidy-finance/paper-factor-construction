library(dplyr)
library(tidyr)
library(arrow)
library(slider)
library(purrr)
library(lubridate)
library(tidyfinance)
library(multidplyr)
library(moments)

source("code/00_global_options.R")
options(future.globals.maxSize = 1000 * 1024^2)

crsp_monthly <- open_dataset(
  file.path(data_folder, "crsp_monthly.parquet")
) |>
  mutate(int_me = mktcap) |>
  collect()

crsp_daily <- open_dataset(
  file.path(data_folder, "crsp_daily.parquet")
)

factors_ff_3_monthly <- open_dataset(
  file.path(data_folder, "factors_ff_3_monthly.parquet")
)

factors_ff_3_daily <- open_dataset(
  file.path(data_folder, "factors_ff_3_daily.parquet")
)

# Daily and monthly Amihud measure
crsp_monthly_liquidity <- crsp_daily |>
  mutate(
    int_daily_dollar_volume = (abs(prc) * vol_adj),
    int_daily_turnover = vol_adj / shrout,
    int_amihud = abs(ret_excess) / int_daily_dollar_volume,
    int_amihud = if_else(is.nan(int_amihud), NA_real_, int_amihud),
    int_amihud = if_else(is.infinite(int_amihud), NA_real_, int_amihud)
  ) |>
  select(
    permno,
    date,
    int_daily_dollar_volume,
    int_daily_turnover,
    int_amihud
  ) |>
  filter(across(everything(), ~ !is.na(.))) |>
  group_by(permno, date = floor_date(date, "month")) |>
  summarize(
    int_amihud = sum(int_amihud),
    int_daily_dollar_volume = sum(int_daily_dollar_volume),
    int_daily_turnover = sum(int_daily_turnover),
    int_daily_obs = n(),
    .groups = "drop"
  ) |>
  collect()

crsp_monthly <- crsp_monthly |>
  left_join(
    crsp_monthly_liquidity,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  left_join(
    factors_ff_3_monthly |> collect(),
    join_by(date),
    relationship = "many-to-one"
  )

## Five year lag
crsp_monthly <- crsp_monthly |>
  add_lag_columns("int_me", by = "permno", lag = years(5)) |>
  rename(int_me_lag5y = int_me_lag)

# Compute CAPM regression coefficients and FF3 residuals

capm_betas <- crsp_monthly |>
  arrange(permno, date) |>
  estimate_betas("ret_excess ~ mkt_excess", months(60), use_furrr = TRUE) |>
  select(everything(), int_capm_beta = beta_mkt_excess, -intercept)

crsp_monthly <- crsp_monthly |>
  left_join(capm_betas, join_by(permno, date), relationship = "one-to-one")

# NOTE: cluster needs to be initialized after parallelization with furrr
cluster <- new_cluster(parallel::detectCores() - 1)
cluster_library(cluster, c("tidyfinance"))

crsp_monthly <- crsp_monthly |>
  group_by(permno) |>
  partition(cluster) |>
  mutate(
    int_roll_residual = compute_rolling_value(
      pick(everything()),
      .f = ~ last(lm(ret_excess ~ mkt_excess + smb + hml, data = .x)$residuals),
      period = "month",
      periods = 36,
      min_obs = 12
    )
  ) |>
  ungroup() |>
  collect()

# Add rolling window returns
crsp_monthly <- crsp_monthly |>
  arrange(permno, date) |>
  group_by(permno) |>
  partition(cluster) |>
  mutate(
    ret_gross = 1 + ret,
    int_roll_ret_11m = slide_index_prod(
      ret_gross,
      date,
      before = months(11 - 1),
      complete = TRUE
    ) -
      1,
    int_roll_ret_5y = slide_index_prod(
      ret_gross,
      date,
      before = months(60 - 1),
      complete = TRUE
    ) -
      1,
    int_roll_ret_47m = slide_index_prod(
      ret_gross,
      date,
      before = months(47 - 1),
      complete = TRUE
    ) -
      1,
    int_rmom_11m = compute_rolling_value(
      pick(everything()),
      .f = ~ (prod(1 + .x$int_roll_residual) - 1) / sd(.x$int_roll_residual),
      period = "month",
      periods = 12,
      min_obs = 12
    )
  ) |>
  select(-ret_gross) |>
  ungroup() |>
  collect()

# Skip one month
crsp_monthly <- crsp_monthly |>
  add_lag_columns(
    c("int_roll_ret_11m", "int_rmom_11m"),
    by = "permno",
    lag = months(1)
  ) |>
  rename(
    int_roll_ret_11m_skip1 = int_roll_ret_11m_lag,
    int_rmom_11m_skip1 = int_rmom_11m_lag
  ) |>
  select(-int_roll_ret_11m, -int_rmom_11m)

# Skip one year (13 months)
crsp_monthly <- crsp_monthly |>
  add_lag_columns("int_roll_ret_47m", by = "permno", lag = months(13)) |>
  rename(int_roll_ret_47m_skip13 = int_roll_ret_47m_lag) |>
  select(-int_roll_ret_47m)

# Rolling maximum

min_obs_for_max_price <- 3
# Compute monthly max
crsp_maxima <- crsp_daily |>
  select(permno, date, prc_adj) |>
  arrange(permno, date) |>
  filter(across(everything(), ~ !is.na(.x))) |>
  group_by(permno, date = floor_date(date, "month")) |>
  summarise(
    int_max_price_month = if_else(
      n() > min_obs_for_max_price,
      max(prc_adj, na.rm = TRUE),
      NA_real_
    ),
    .groups = "drop"
  ) |>
  collect()

# Compute rolling window max
crsp_maxima <- crsp_maxima |>
  group_by(permno) |>
  partition(cluster) |>
  mutate(
    int_max_price_month_52w = slide_index_max(
      int_max_price_month,
      date,
      before = months(12 - 1),
      complete = FALSE
    )
  ) |>
  ungroup() |>
  collect()

crsp_monthly <- crsp_monthly |>
  left_join(crsp_maxima, join_by(permno, date), relationship = "one-to-one")

# Rolling window estimation

crsp_monthly <- crsp_monthly |>
  arrange(permno, date) |>
  group_by(permno) |>
  partition(cluster) |>
  mutate(
    int_rolling_daily_obs = slide_index_sum(
      int_daily_obs,
      date,
      before = months(6 - 1),
      complete = FALSE,
      na_rm = TRUE
    ),
    int_rolling_daily_obs = if_else(
      int_rolling_daily_obs < 50,
      NA,
      int_rolling_daily_obs
    ),
    int_rolling_amihud = slide_index_sum(
      int_amihud,
      date,
      before = months(6 - 1),
      complete = FALSE,
      na_rm = TRUE
    ) /
      int_rolling_daily_obs,
    int_rolling_dtv = slide_index_sum(
      int_daily_dollar_volume,
      date,
      before = months(6 - 1),
      complete = FALSE
    ) /
      int_rolling_daily_obs,
    int_daily_turnover = slide_index_sum(
      int_daily_turnover,
      date,
      before = months(6 - 1),
      complete = FALSE
    ) /
      int_rolling_daily_obs
  ) |>
  select(-int_rolling_daily_obs) |>
  ungroup() |>
  collect()

crsp_daily_aggregation <- crsp_daily |>
  left_join(factors_ff_3_daily, join_by(date), relationship = "many-to-one") |>
  mutate(date = floor_date(date, "month")) |>
  select(permno, date, ret_excess, mkt_excess, smb, hml)

min_daily_obs_per_month <- 15

permno_month_combinations <- crsp_daily_aggregation |>
  group_by(permno, date) |>
  count() |>
  filter(n >= min_daily_obs_per_month) |>
  select(-n) |>
  ungroup()

crsp_daily_aggregation <- crsp_daily_aggregation |>
  inner_join(
    permno_month_combinations,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  collect()

aggregation_data_all <- crsp_daily_aggregation |>
  group_by(permno, date) |>
  partition(cluster) |>
  mutate(
    residual_ff3 = estimate_model(
      pick(everything()),
      model = "ret_excess ~ mkt_excess + smb + hml",
      output = "residuals"
    )
  ) |>
  summarize(
    int_max_ret = max(ret_excess, na.rm = TRUE),
    int_res_ivol = sd(residual_ff3, na.rm = TRUE),
    int_res_iskew = moments::skewness(residual_ff3, na.rm = TRUE)
  ) |>
  collect() |>
  ungroup()

# Merge into monthly sorting variable dataset
crsp_monthly <- crsp_monthly |>
  full_join(
    aggregation_data_all,
    join_by(permno, date),
    relationship = "one-to-one"
  )

# Main variables
sorting_variables_monthly <- crsp_monthly |>
  mutate(
    sv_csi = log(int_me / int_me_lag5y) - log(int_roll_ret_5y),
    sv_mom = int_roll_ret_11m_skip1,
    sv_rmom = int_rmom_11m_skip1,
    sv_52w = prc_adj / int_max_price_month_52w,
    sv_ami = int_rolling_amihud,
    sv_beta = int_capm_beta,
    sv_dtv = int_rolling_dtv,
    sv_iskew = int_res_iskew,
    sv_ivol = int_res_ivol,
    sv_mdr = int_max_ret,
    sv_tur = int_daily_turnover,
    sv_me = log(mktcap * 10^6),
    sv_rev = int_roll_ret_47m_skip13
  )

# Filters

# Remove Inf and NaN
sorting_variables_monthly <- sorting_variables_monthly |>
  mutate(
    across(starts_with("sv_"), ~ na_if(., Inf)),
    across(starts_with("sv_"), ~ na_if(., -Inf)),
    across(starts_with("sv_"), ~ if_else(is.nan(.x), NA_real_, .x))
  )

# Create column with stock_age to filter later
sorting_variables_monthly <- sorting_variables_monthly |>
  arrange(permno, date) |>
  group_by(permno) |>
  mutate(
    filter_stock_age = as.numeric(difftime(date, min(date), units = "days")) /
      365
  )

sorting_variables_monthly <- sorting_variables_monthly |>
  select(permno, date, filter_stock_age, starts_with("sv_")) |>
  ungroup()

write_parquet(
  sorting_variables_monthly,
  file.path(data_folder, "sorting_variables_monthly.parquet")
)
