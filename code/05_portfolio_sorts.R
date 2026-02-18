library(dplyr)
library(lubridate)
library(arrow)
library(tidyr)
library(tidyfinance)
library(furrr)
library(future)

full_grid <- read_parquet("data/portfolio_sort_grid.parquet")

set.seed(1234)
grid <- full_grid |>
  slice_sample(n = 25)

sv_directions <- read_parquet("data/sorting_variable_information.parquet") |>
  select(sorting_variable, direction)

grid <- grid |>
  inner_join(sv_directions, join_by(sorting_variable))

# Helper to read sorting data --------------------------------------------

read_sorting_data <- function(lag_label, sorting_variables) {
  path <- file.path(
    "data",
    paste0("sorting_variables_lag_", lag_label, ".parquet")
  )
  open_dataset(path) |>
    select(
      permno,
      date,
      ret_excess,
      exchange,
      industry,
      filter_earnings,
      mktcap_lag,
      all_of(sorting_variables)
    ) |>
    collect()
}

# Helper to process individual task --------------------------------------

process_task <- function(row, sorting_data_cache) {
  start <- Sys.time()

  warnings_collected <- character(0)
  result <- withCallingHandlers(
    {
      sorting_data <- sorting_data_cache[[row$sorting_variable_lag]]

      if (row$exclude_size != 0) {
        sorting_data <- sorting_data |>
          group_by(date) |>
          filter(
            mktcap_lag >=
              quantile(mktcap_lag[exchange == "NYSE"], row$exclude_size)
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
        drop_na(all_of(row$sorting_variable)) |>
        collect()

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
      cpr_elapsed <- as.numeric(difftime(Sys.time(), cpr_start, units = "secs"))

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

      long_short_return |>
        group_by(id) |>
        write_dataset(
          path = "data/portfolio_returns",
          format = "parquet",
          existing_data_behavior = "overwrite"
        )

      "success"
    },
    warning = function(w) {
      warnings_collected <<- c(warnings_collected, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  tibble(
    task_id = row$task_id,
    status = result,
    elapsed_secs = elapsed,
    cpr_elapsed_secs = cpr_elapsed,
    n_warnings = length(warnings_collected),
    warnings = paste(warnings_collected, collapse = " | ")
  )
}

# Parallelization --------------------------------------------------------

plan(multicore, workers = availableCores())

# Loop over each sorting variable, load relevant data once, then
# parallelize the tasks that share that variable.
sorting_variable_groups <- split(grid, grid$sorting_variable)

total_start <- Sys.time()
diagnostics <- bind_rows(lapply(names(sorting_variable_groups), function(sv) {
  sv_grid <- sorting_variable_groups[[sv]]

  message("Processing sorting variable: ", sv, " (", nrow(sv_grid), " tasks)")

  required_lags <- unique(sv_grid$sorting_variable_lag)
  required_svs <- unique(sv_grid$sorting_variable)

  sv_cache <- setNames(
    lapply(required_lags, read_sorting_data, sorting_variables = required_svs),
    required_lags
  )

  sv_rows <- split(sv_grid, seq_len(nrow(sv_grid)))

  future_map_dfr(
    sv_rows,
    \(row) process_task(row, sv_cache),
    .options = furrr_options(
      globals = c("process_task", "sv_cache"),
      packages = c("dplyr", "tidyr", "arrow", "tidyfinance")
    ),
    .progress = TRUE
  )
}))
elapsed <- Sys.time() - total_start
message("Total: ", format(elapsed))

write_parquet(diagnostics, "data/task_diagnostics.parquet")
