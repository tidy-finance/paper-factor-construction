library(dplyr)
library(tidyr)
library(tidyfinance)
library(tidylog)
library(arrow)

full_grid <- read_parquet("data/portfolio_sort_grid.parquet")

grid <- full_grid |>
  mutate(task_id = row_number())

sv_directions <- read_parquet("data/sorting_variable_information.parquet") |>
  select(sorting_variable, direction)

grid <- grid |>
  inner_join(sv_directions, join_by(sorting_variable))

# Define task to debug
row <- grid |>
  filter(task_id == 1)

sorting_data <- read_sorting_data(
  pull(row, sorting_variable_lag),
  pull(row, sorting_variable)
)

sorting_data <- list(
  "3m" = sorting_data
)

# Verify issue
process_task(row, sorting_data)

if (row$exclude_size != 0) {
  sorting_data <- sorting_data |>
    group_by(date) |>
    filter(
      mktcap_lag >= quantile(mktcap_lag[exchange == "NYSE"], row$exclude_size)
    ) |>
    ungroup()
}

if (row$exclude_financials) {
  sorting_data <- sorting_data |>
    filter(industry != "Finance")
}

if (row$exclude_utilities) {
  sorting_data <- sorting_data |>
    filter(industry != "Utilities")
}

if (row$exclude_negative_earnings) {
  sorting_data <- sorting_data |>
    filter(filter_earnings > 0)
}

sorting_data <- sorting_data |>
  select(
    permno,
    date,
    ret_excess,
    all_of(row$sorting_variable),
    exchange,
    mktcap_lag
  ) |>
  drop_na(all_of(row$sorting_variable))

rebalancing_month <- if (row$rebalancing == "monthly") NULL else 7

options_main <- breakpoint_options(
  n_portfolios = row$breakpoints_main,
  breakpoint_exchanges = strsplit(
    row$breakpoints_exchanges,
    split = "\\|"
  )[[1]]
)

sorting_variables <- row$sorting_variable
options_secondary <- NULL

if (row$sorting_method != "univariate") {
  sorting_variables <- c(row$sorting_variable, "mktcap_lag")
  options_secondary <- breakpoint_options(
    n_portfolios = row$breakpoints_secondary,
    breakpoint_exchanges = strsplit(
      row$breakpoints_exchanges,
      split = "\\|"
    )[[1]]
  )
}

min_portfolio_size <- 10
sorting_data <- sorting_data |>
  group_by(date) |>
  filter(n() >= min_portfolio_size) |>
  ungroup()

cpr_start <- Sys.time()
portfolio_returns <- compute_portfolio_returns(
  sorting_data,
  sorting_variables,
  sorting_method = row$sorting_method,
  rebalancing_month,
  options_main,
  options_secondary,
  min_portfolio_size = min_portfolio_size
)
state$cpr_elapsed <- as.numeric(difftime(
  Sys.time(),
  cpr_start,
  units = "secs"
))

long_short_return <- portfolio_returns |>
  compute_long_short_returns(direction = row$direction) |>
  pivot_longer(-date, names_to = "ret_type", values_to = "ret") |>
  mutate(
    id = row$id,
    ret_type = gsub("ret_excess_", "", ret_type),
    sorting_variable = row$sorting_variable,
    ret = replace_na(ret, 0)
  ) |>
  select(id, sorting_variable, date, ret_type, ret)

long_short_return
