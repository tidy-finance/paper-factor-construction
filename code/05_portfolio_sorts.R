library(dplyr)
library(lubridate)
library(arrow)
library(tidyr)
library(tidyfinance)
library(furrr)

full_grid <- read_parquet("data/portfolio_sort_grid.parquet")

set.seed(1234)
grid <- full_grid |>
  mutate(task_id = row_number()) |>
  slice_sample(n = 100)

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
  state <- new.env(parent = emptyenv())
  state$cpr_elapsed <- NA_real_

  result <- tryCatch(
    withCallingHandlers(
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
      },
      warning = function(w) {
        warnings_collected <<- c(warnings_collected, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )

  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  if (is.data.frame(result)) {
    list(
      returns = result,
      diagnostics = tibble(
        task_id = row$task_id,
        status = "success",
        elapsed_secs = elapsed,
        cpr_elapsed_secs = state$cpr_elapsed,
        n_warnings = length(warnings_collected),
        warnings = paste(warnings_collected, collapse = " | ")
      )
    )
  } else {
    list(
      returns = NULL,
      diagnostics = tibble(
        task_id = row$task_id,
        status = paste("error:", as.character(result)),
        elapsed_secs = elapsed,
        cpr_elapsed_secs = state$cpr_elapsed,
        n_warnings = length(warnings_collected),
        warnings = paste(warnings_collected, collapse = " | ")
      )
    )
  }
}

# Parallelization --------------------------------------------------------

# NOTE: multicore only works on UNIX-based systems and leverages the benefit of
# shared memory across tasks.
plan(multicore, workers = availableCores() - 1)

sorting_variable_groups <- split(grid, grid$sorting_variable)

total_start <- Sys.time()
diagnostics <- bind_rows(lapply(names(sorting_variable_groups), function(sv) {
  sv_grid <- sorting_variable_groups[[sv]]

  message("Processing sorting variable: ", sv, " (", nrow(sv_grid), " tasks)")

  required_lags <- unique(sv_grid$sorting_variable_lag)

  bind_rows(lapply(required_lags, function(lag_label) {
    lag_grid <- sv_grid |> filter(sorting_variable_lag == lag_label)

    message("  Lag: ", lag_label, " (", nrow(lag_grid), " tasks)")

    sv_cache <- setNames(
      list(read_sorting_data(
        lag_label,
        sorting_variables = unique(lag_grid$sorting_variable)
      )),
      lag_label
    )

    lag_rows <- split(lag_grid, seq_len(nrow(lag_grid)))

    results <- future_map(
      lag_rows,
      \(row) process_task(row, sv_cache),
      .progress = TRUE
    )

    all_returns <- bind_rows(lapply(results, \(r) r$returns))
    if (nrow(all_returns) > 0) {
      all_returns |>
        group_by(sorting_variable) |>
        write_dataset(
          path = "data/portfolio_returns",
          format = "parquet",
          existing_data_behavior = "delete_matching"
        )
    }

    diag <- bind_rows(lapply(results, \(r) r$diagnostics))

    rm(sv_cache, results, all_returns)
    gc()

    diag
  }))
}))
elapsed <- Sys.time() - total_start
message("Total: ", format(elapsed))

write_parquet(diagnostics, "data/task_diagnostics.parquet")
