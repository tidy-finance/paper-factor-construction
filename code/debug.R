library(dplyr)
library(tidyr)
library(tidyfinance)
library(tidylog)
library(arrow)

# TODO: sv_mom is always missing
# TODO: sv_rmom is always missing

full_grid <- read_parquet("data/portfolio_sort_grid.parquet")

colnames(full_grid)

sv_directions <- read_parquet("data/sorting_variable_information.parquet") |>
  select(sorting_variable, direction)

grid <- full_grid |>
  inner_join(sv_directions, join_by(sorting_variable))

# Define task to debug
row <- grid |>
  filter(id == 34966)

path <- file.path(
  "data",
  paste0(
    "sorting_variables_lag_",
    row$sorting_variable_lag,
    ".parquet"
  )
)

sorting_data_raw <- open_dataset(path) |>
  select(
    permno,
    date,
    ret_excess,
    exchange,
    industry,
    filter_earnings,
    mktcap_lag,
    all_of(row$sorting_variable)
  ) |>
  collect()

# Verify issue
res <- process_task(row, sorting_data_raw)
res$diagnostics$status

start <- Sys.time()

warnings_collected <- character(0)
state <- new.env(parent = emptyenv())
state$cpr_elapsed <- NA_real_

result <- tryCatch(
  withCallingHandlers(
    {
      sorting_data <- sorting_data_raw
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

      sorting_data <- sorting_data |>
        select(
          permno,
          date,
          ret_excess,
          contains("sv_"),
          exchange,
          mktcap_lag
        ) |>
        drop_na(all_of(sorting_variables))

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

      min_portfolio_size <- 10

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
    },
    warning = function(w) {
      warnings_collected <<- c(warnings_collected, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  ),
  error = function(e) e
)

elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
