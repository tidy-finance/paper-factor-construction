library("dplyr")
library("tidyr")
library("arrow")
library("slider")
library("lubridate")
library("tidyfinance")
library("future")
library("multidplyr")
library("moments")

options(future.globals.maxSize = 10000 * 1024^2)

crsp_monthly <- open_dataset("data/crsp_monthly.parquet") |>
  mutate(int_me = mktcap) |>
  collect()

factors_ff_5_monthly <- open_dataset("data/factors_ff_5_monthly.parquet") |>
  collect()

crsp_daily <- open_dataset("data/crsp_daily.parquet")

factors_ff_5_daily <- open_dataset("data/factors_ff_5_daily.parquet")

# Daily and monthly Amihud measure
# Aggregate each liquidity input separately so that a missing shrout (needed
# only for turnover) does not reduce int_daily_obs or contaminate sv_ami/sv_dtv.
crsp_daily_raw <- crsp_daily |>
  mutate(
    int_daily_dollar_volume = abs(prc) * vol_adj,
    int_daily_turnover = vol_adj / shrout,
    int_amihud = abs(ret) / int_daily_dollar_volume,
    int_amihud = if_else(is.finite(int_amihud), int_amihud, NA_real_)
  ) |>
  select(
    permno,
    date,
    int_daily_dollar_volume,
    int_daily_turnover,
    int_amihud
  ) |>
  collect()

crsp_monthly_liquidity <- crsp_daily_raw |>
  filter(
    !is.na(int_daily_dollar_volume) |
      !is.na(int_daily_turnover) |
      !is.na(int_amihud)
  ) |>
  group_by(permno, date = floor_date(date, "month")) |>
  summarize(
    int_daily_obs = sum(!is.na(int_daily_dollar_volume)),
    int_daily_obs_ami = sum(!is.na(int_amihud)),
    int_daily_obs_tur = sum(!is.na(int_daily_turnover)),
    int_amihud = sum(int_amihud, na.rm = TRUE),
    int_daily_dollar_volume = sum(int_daily_dollar_volume, na.rm = TRUE),
    int_daily_turnover = sum(int_daily_turnover, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    int_amihud = if_else(int_daily_obs_ami == 0L, NA_real_, int_amihud),
    int_daily_dollar_volume = if_else(
      int_daily_obs == 0L,
      NA_real_,
      int_daily_dollar_volume
    ),
    int_daily_turnover = if_else(
      int_daily_obs_tur == 0L,
      NA_real_,
      int_daily_turnover
    )
  ) |>
  select(-int_daily_obs_ami)

crsp_monthly <- crsp_monthly |>
  left_join(
    crsp_monthly_liquidity,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  left_join(
    factors_ff_5_monthly,
    join_by(date),
    relationship = "many-to-one"
  )

## Five year lag
crsp_monthly <- crsp_monthly |>
  add_lagged_columns(cols = "int_me", by = "permno", lag = years(5)) |>
  rename(int_me_lag5y = int_me_lag)

# Compute CAPM regression coefficients and FF3 residuals
# NOTE: multisession needs to be initialized before using furrr for beta estimation
future::plan(future::multisession, workers = future::availableCores() - 1)

capm_betas <- crsp_monthly |>
  arrange(permno, date) |>
  estimate_betas(
    "ret_excess ~ mkt_excess",
    months(60),
    min_obs = 24,
    use_furrr = TRUE
  ) |>
  select(everything(), int_capm_beta = beta_mkt_excess, -intercept)

crsp_monthly <- crsp_monthly |>
  left_join(capm_betas, join_by(permno, date), relationship = "one-to-one")

# NOTE: cluster needs to be initialized after parallelization with furrr
cluster <- new_cluster(future::availableCores() - 1)
cluster_library(cluster, c("tidyfinance", "dplyr", "slider"))

crsp_monthly <- crsp_monthly |>
  arrange(permno, date) |>
  group_by(permno) |>
  partition(cluster) |>
  mutate(
    int_roll_residual = compute_rolling_value(
      pick(everything()),
      .f = ~ last(lm(ret_excess ~ mkt_excess + smb + hml, data = .x)$residuals),
      period = "month",
      periods = 36,
      min_obs = 24
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
      periods = 11,
      min_obs = 11
    )
  ) |>
  select(-ret_gross) |>
  ungroup() |>
  collect()

# Skip one month — keep lag tables separate so drop_na() on int_rmom_11m_lag
# does not contaminate int_roll_ret_11m_lag (sv_mom needs only 11m; rmom needs ~47m)
crsp_monthly_lag1m_mom <- crsp_monthly |>
  add_lagged_columns("int_roll_ret_11m", lag = months(1), by = "permno") |>
  select(permno, date, int_roll_ret_11m_lag) |>
  drop_na()

crsp_monthly_lag1m_rmom <- crsp_monthly |>
  add_lagged_columns("int_rmom_11m", lag = months(1), by = "permno") |>
  select(permno, date, int_rmom_11m_lag) |>
  drop_na()

# Skip one year
crsp_monthly_lag1y <- crsp_monthly |>
  add_lagged_columns(
    c("int_roll_ret_47m"),
    lag = months(13),
    by = "permno"
  ) |>
  select(permno, date, int_roll_ret_47m_lag) |>
  drop_na()

# Merge skips back
crsp_monthly <- crsp_monthly |>
  select(-int_roll_ret_11m, -int_roll_ret_47m, -int_rmom_11m) |>
  left_join(
    crsp_monthly_lag1m_mom,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  left_join(
    crsp_monthly_lag1m_rmom,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  left_join(
    crsp_monthly_lag1y,
    join_by(permno, date),
    relationship = "one-to-one"
  )

# Rolling maximum
# Minimum daily price observations per month to compute monthly max
min_obs_for_max_price <- 3
crsp_maxima <- crsp_daily |>
  select(permno, date, prc_adj) |>
  arrange(permno, date) |>
  collect() |>
  drop_na() |>
  group_by(permno, date = floor_date(date, "month")) |>
  summarise(
    int_max_price_month = if_else(
      n() > min_obs_for_max_price,
      max(prc_adj, na.rm = TRUE),
      NA_real_
    ),
    .groups = "drop"
  )

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

# sv_ami and sv_dtv share the price/volume obs count; sv_tur uses its own
# turnover obs count so missing shrout does not contaminate the other two.
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
      complete = FALSE,
      na_rm = TRUE
    ) /
      int_rolling_daily_obs,
    int_rolling_daily_obs_tur = slide_index_sum(
      int_daily_obs_tur,
      date,
      before = months(6 - 1),
      complete = FALSE,
      na_rm = TRUE
    ),
    int_rolling_turnover = slide_index_sum(
      int_daily_turnover,
      date,
      before = months(6 - 1),
      complete = FALSE,
      na_rm = TRUE
    ) /
      if_else(
        int_rolling_daily_obs_tur < 50,
        NA_real_,
        int_rolling_daily_obs_tur
      )
  ) |>
  select(-int_rolling_daily_obs, -int_rolling_daily_obs_tur) |>
  ungroup() |>
  collect()

crsp_daily_aggregation <- crsp_daily |>
  left_join(factors_ff_5_daily, join_by(date), relationship = "many-to-one") |>
  mutate(date = floor_date(date, "month")) |>
  select(permno, date, ret_excess, mkt_excess, smb, hml) |>
  collect()

# sv_mdr = max(ret_excess) needs only 1 observation; compute it before the
# 15-obs regression filter so it is not contaminated by sv_ivol / sv_iskew.
int_max_ret_data <- crsp_daily_aggregation |>
  group_by(permno, date) |>
  summarize(int_max_ret = max(ret_excess, na.rm = TRUE), .groups = "drop")

# Minimum daily observations to estimate within-month regressions
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
    relationship = "many-to-one"
  )

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
    int_res_ivol = sd(residual_ff3, na.rm = TRUE),
    int_res_iskew = moments::skewness(residual_ff3, na.rm = TRUE)
  ) |>
  collect() |>
  ungroup()

# Use left_join to preserve only the crsp_monthly universe
crsp_monthly <- crsp_monthly |>
  left_join(
    int_max_ret_data,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  left_join(
    aggregation_data_all,
    join_by(permno, date),
    relationship = "one-to-one"
  )

# Main variables
sorting_variables_monthly <- crsp_monthly |>
  mutate(
    sv_csi = log(int_me / int_me_lag5y) - log(1 + int_roll_ret_5y),
    sv_mom = int_roll_ret_11m_lag,
    sv_rmom = int_rmom_11m_lag,
    sv_52w = prc / int_max_price_month_52w,
    sv_ami = int_rolling_amihud,
    sv_beta = int_capm_beta,
    sv_dtv = int_rolling_dtv,
    sv_iskew = int_res_iskew,
    sv_ivol = int_res_ivol,
    sv_mdr = int_max_ret,
    sv_tur = int_rolling_turnover,
    sv_me = log(mktcap * 10^6),
    sv_rev = int_roll_ret_47m_lag
  )

# Filters

# Remove Inf and NaN
sorting_variables_monthly <- sorting_variables_monthly |>
  mutate(
    across(starts_with("sv_"), ~ if_else(is.finite(.x), .x, NA_real_))
  )

sorting_variables_monthly <- sorting_variables_monthly |>
  select(permno, date, starts_with("sv_")) |>
  arrange(permno, date)

write_parquet(
  sorting_variables_monthly,
  "data/sorting_variables_monthly.parquet"
)
