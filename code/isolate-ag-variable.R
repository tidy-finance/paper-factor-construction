library(dplyr)
library(tidyr)
library(lubridate)
library(arrow)
library(tidyfinance)

date_start <- as.Date("1960-01-01")
date_end <- as.Date("2024-12-31")

crsp_monthly <- download_data(
  domain = "wrds",
  dataset = "crsp_monthly",
  version = "v2",
  start_date = date_start,
  end_date = date_end,
  add_ccm_links = TRUE
)

compustat_annual <- download_data(
  domain = "wrds",
  dataset = "compustat_annual",
  start_date = date_start,
  end_date = date_end,
  additional_columns = c("at", "ib"),
  only_us = TRUE
)

# Step 2: Construct AG sorting variable -----------------------------------

# Lag total assets by one year
compustat_annual <- compustat_annual |>
  add_lag_columns(
    "at",
    lag = years(1),
    by = "gvkey"
  ) |>
  rename(at_lag1 = at_lag)

# Compute AG: year-over-year change in total assets scaled by prior year
sorting_variables_yearly <- compustat_annual |>
  mutate(
    sv_ag = (at - at_lag1) / at_lag1,
    filter_earnings = ib
  )

# Remove non-finite values
sorting_variables_yearly <- sorting_variables_yearly |>
  mutate(sv_ag = if_else(is.finite(sv_ag), sv_ag, NA_real_))

sorting_variables_yearly <- sorting_variables_yearly |>
  select(gvkey, date, filter_earnings, sv_ag)


# Step 3: Apply lagging schemes -------------------------------------------

# Exclude stocks listed for less than 2 years
min_stock_age <- 2

crsp_monthly <- crsp_monthly |>
  arrange(permno, date) |>
  group_by(permno) |>
  mutate(
    stock_age = as.numeric(difftime(date, min(date), units = "days")) / 365
  ) |>
  ungroup() |>
  filter(stock_age >= min_stock_age) |>
  select(-stock_age)

filter_yearly <- sorting_variables_yearly |>
  select(gvkey, date, starts_with("filter_"))

sorting_variables_yearly <- sorting_variables_yearly |>
  select(gvkey, date, sv_ag)

# Lag 3m: sorting variable from 3-12 months prior
sv_lag3m <- crsp_monthly |>
  join_lagged_values(
    filter_yearly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(3),
    max_lag = months(12)
  )


# Lag 6m: sorting variable from 6-12 months prior
sv_lag6m <- crsp_monthly |>
  join_lagged_values(
    filter_yearly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(12)
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(6),
    max_lag = months(12)
  )


# Lag FF: Fama-French convention (June fiscal year-end to July t+1)
sv_lag_ff <- crsp_monthly |>
  join_lagged_values(
    filter_yearly,
    "gvkey",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  ) |>
  join_lagged_values(
    sorting_variables_yearly,
    "gvkey",
    min_lag = months(12),
    max_lag = months(18),
    ff_adjustment = TRUE
  )

# Step 4: Define the portfolio sort grid ----------------------------------

# TODO: Replace by proper r-tidyfinance function once implemented
grid <- get_available_hf_files("tidy-finance",
      "factor-library-grid"
    )|> pull(url) |> 
  arrow::read_parquet() |>
  filter(sorting_variable == "sv_ag")

# Step 5: Portfolio sorts -------------------------------------------------

grid <- grid |>
  mutate(
    direction = "bottom_minus_top",
    parquet_path = file.path(
      "data",
      paste0("sorting_variables_lag_", sorting_variable_lag, ".parquet")
    )
  )

process_task <- function(row, sorting_data, output_dir) {
  sorting_variables <- grep("sv_", names(sorting_data), value = TRUE)

  if (row$exclude_size != 0) {
    sorting_data <- sorting_data |>
      group_by(date) |>
      filter(
        mktcap_lag >=
          quantile(
            mktcap_lag[exchange == "NYSE"],
            row$exclude_size,
            na.rm = TRUE
          )
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

  rebalancing_month <- if (row$rebalancing == "monthly") NULL else 7
  bp_exchanges <- strsplit(row$breakpoints_exchanges, split = "\\|")[[1]]

  options_main <- breakpoint_options(
    n_portfolios = row$breakpoints_main,
    breakpoint_exchanges = bp_exchanges
  )

  options_secondary <- NULL

  if (row$sorting_method != "univariate") {
    sorting_variables <- c(sorting_variables, "mktcap_lag")
    options_secondary <- breakpoint_options(
      n_portfolios = row$breakpoints_secondary,
      breakpoint_exchanges = bp_exchanges
    )
  }

  if (row$sorting_method == "univariate") {
    min_portfolio_size <- options_main$n_portfolios
  } else {
    min_portfolio_size <- options_main$n_portfolios *
      options_secondary$n_portfolios
  }

  portfolio_returns <- compute_portfolio_returns(
    sorting_data,
    sorting_variables,
    sorting_method = row$sorting_method,
    rebalancing_month,
    options_main,
    options_secondary,
    min_portfolio_size = min_portfolio_size,
    quiet = TRUE
  )

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

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write_parquet(
    long_short_return,
    file.path(output_dir, paste0("id_", row$id, ".parquet"))
  )
}

# Process all tasks
unique_paths <- unique(grid$parquet_path)

for (p in seq_along(unique_paths)) {
  path <- unique_paths[p]
  group_grid <- grid[grid$parquet_path == path, ]
  sv_lag_data <- read_parquet(path)

  output_dirs <- file.path(
    "test-data",
    "portfolio_returns",
    paste0("sorting_variable=", group_grid$sorting_variable),
    paste0("sorting_variable_lag=", group_grid$sorting_variable_lag)
  )

  lapply(
    seq_len(nrow(group_grid)),
    function(i) {
      row <- group_grid[i, ]

      task_data <- sv_lag_data[,
        c(
          "permno",
          "date",
          "ret_excess",
          "exchange",
          "industry",
          "filter_earnings",
          "mktcap_lag",
          row$sorting_variable
        ),
        drop = FALSE
      ]

      process_task(row, task_data, output_dirs[i])
    }
  )
}
