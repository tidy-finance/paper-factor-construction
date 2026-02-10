library(dplyr)
library(tidyr)
library(arrow)
library(slider)
library(purrr)
library(multidplyr)
library(moments)
library(here)

source("factor-library-code/00_global_options.R")

cluster <- new_cluster(parallel::detectCores() - 1)
cluster_library(cluster, c("lubridate", "slider", "dplyr", "tidyr"))

crsp_monthly <- open_dataset(
  here(data_folder, "crsp_monthly.parquet")
) |>
  mutate(int_me = mktcap) |>
  collect()

crsp_daily <- open_dataset(
  here(data_folder, "crsp_daily.parquet")
)

factors_ff_3_monthly <- open_dataset(
  here(data_folder, "factors_ff_3_monthly.parquet")
)

factors_ff_3_daily <- open_dataset(
  here(data_folder, "factors_ff_3_daily.parquet")
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

# Lag certain variables
## Five year lag
crsp_monthly_lag5y <- crsp_monthly |>
  select(permno, date, int_me) |>
  mutate(date = date %m+% years(5)) |>
  rename_with(.cols = -c("permno", "date"), .fn = ~ paste0(.x, "_lag5y"))

# Merge back
crsp_monthly <- crsp_monthly |>
  left_join(
    crsp_monthly_lag5y,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  left_join(
    crsp_monthly_liquidity,
    join_by(permno, date),
    relationship = "one-to-one"
  )

crsp_monthly <- crsp_monthly |>
  left_join(
    factors_ff_3_monthly |> collect(),
    join_by(date),
    relationship = "many-to-one"
  )

# Rolling regressions -----------------------------------------------------

# TODO: replace by functions from r-tidyfinance
rolling_window_capm <- function(data, months) {
  beta_coefficients <- slide_period_vec(
    .x = data,
    .i = data$date,
    .period = "month",
    .f = ~ {
      complete <- drop_na(.x)
      if (nrow(complete) < months) {
        NA_real_
      } else {
        coefficients(lm(ret_excess ~ mkt_excess, data = complete))[2]
      }
    },
    .before = months - 1,
    .complete = FALSE
  )

  return(beta_coefficients)
}

rolling_window_residual <- function(data, months) {
  residuals <- slide_period_vec(
    .x = data,
    .i = data$date,
    .period = "month",
    .f = ~ {
      complete <- drop_na(.x)
      if (nrow(complete) < months) {
        NA_real_
      } else {
        last(lm(ret_excess ~ mkt_excess + smb + hml, data = complete)$residuals)
      }
    },
    .before = months - 1,
    .complete = FALSE
  )

  return(residuals)
}

cluster_copy(cluster, c("rolling_window_residual", "rolling_window_capm"))

# Compute CAPM regression coefficients and FF3 residuals

crsp_monthly <- crsp_monthly |>
  arrange(permno, date) |>
  group_by(permno) |>
  partition(cluster) |>
  mutate(
    int_roll_residual = rolling_window_residual(
      pick(date, ret_excess, mkt_excess, hml, smb),
      months = 36
    ),
    int_capm_beta = rolling_window_capm(
      pick(date, ret_excess, mkt_excess),
      months = 60
    )
  ) |>
  ungroup() |>
  collect()

rolling_window_residual_to_sd <- function(data, months) {
  returns <- slide_period_vec(
    .x = data,
    .i = data$date,
    .period = "month",
    .f = ~ {
      if (nrow(.x) < months) {
        NA_real_
      } else {
        (prod(1 + .x$int_roll_residual) - 1) / sd(.x$int_roll_residual)
      }
    },
    .before = months - 1,
    .complete = FALSE
  )

  return(returns)
}

cluster_copy(cluster, c("rolling_window_residual_to_sd"))

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
    int_rmom_11m = rolling_window_residual_to_sd(
      pick(date, int_roll_residual),
      months = 11
    )
  ) |>
  select(-ret_gross) |>
  ungroup() |>
  collect()

# Skip one month
crsp_monthly_skip1m <- crsp_monthly |>
  select(permno, date, int_roll_ret_11m, int_rmom_11m) |>
  mutate(date = date %m+% months(1)) |>
  rename(
    int_roll_ret_11m_skip1 = int_roll_ret_11m,
    int_rmom_11m_skip1 = int_rmom_11m
  ) |>
  drop_na()

# Skip one year
crsp_monthly_skip1y <- crsp_monthly |>
  select(permno, date, int_roll_ret_47m) |>
  mutate(date = date %m+% months(13)) |>
  rename(int_roll_ret_47m_skip13 = int_roll_ret_47m) |>
  drop_na()

# Merge skips back
crsp_monthly <- crsp_monthly |>
  select(-int_roll_ret_11m, -int_roll_ret_47m, -int_rmom_11m) |>
  left_join(
    crsp_monthly_skip1m,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  left_join(
    crsp_monthly_skip1y,
    join_by(permno, date),
    relationship = "one-to-one"
  )

# Rolling maximum ---------------------------------------------------------

# Compute monthly max
crsp_maxima <- crsp_daily |>
  select(permno, date, prc_adj) |>
  arrange(permno, date) |>
  filter(across(everything(), ~ !is.na(.x))) |>
  group_by(permno, date = floor_date(date, "month")) |>
  summarise(
    int_max_price_month = if_else(
      n() > 3,
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

# Merge back
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

# TODO: replace 15 by expressive object
permno_month_combinations <- crsp_daily_aggregation |>
  group_by(permno, date) |>
  count() |>
  filter(n >= 15) |>
  select(-n) |>
  ungroup()

crsp_daily_aggregation <- crsp_daily_aggregation |>
  inner_join(
    permno_month_combinations,
    join_by(permno, date),
    relationship = "one-to-one"
  ) |>
  compute()

# TODO: replace this by a r-tidyfinance function (calculate_residuals()?)
calculate_residuals <- function(data, formula) {
  complete <- complete.cases(model.frame(
    formula,
    data = data,
    na.action = na.pass
  ))
  if (sum(complete) <= length(all.vars(formula))) {
    return(rep(NA_real_, nrow(data)))
  }
  res <- rep(NA_real_, nrow(data))
  res[complete] <- lm(formula, data = data[complete, ])$residuals
  res
}

# TODO: parallelize this via batches
aggregation_data_all <- permno_month_combinations |>
  distinct(permno) |>
  collect() |>
  mutate(
    value = map(
      permno,
      .f = \(selected_permno) {
        crsp_daily_aggregation |>
          filter(permno == selected_permno) |>
          collect() |>
          group_by(date) |>
          mutate(
            residual_ff3 = calculate_residuals(
              pick(everything()),
              ret_excess ~ mkt_excess + smb + hml
            )
          ) |>
          summarize(
            int_max_ret = max(ret_excess, na.rm = TRUE),
            int_res_ivol = sd(residual_ff3, na.rm = TRUE),
            int_res_iskew = moments::skewness(residual_ff3, na.rm = TRUE),
            .groups = 'drop'
          )
      },
      .progress = "permno_iterations"
    )
  ) |>
  unnest(value) |>
  mutate(across(starts_with("int_res_"), ~ if_else(is.nan(.x), NA_real_, .x)))

# Merge into monthly sorting variable dataset
crsp_monthly <- crsp_monthly |>
  full_join(
    aggregation_data_all,
    join_by(permno, date),
    relationship = "one-to-one"
  )

# Main variables ----------------------------------------------------------
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

# Filters -----------------------------------------------------------------

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
  here(data_folder, "sorting_variables_monthly.parquet")
)
