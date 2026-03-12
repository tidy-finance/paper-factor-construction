library(dplyr)
library(arrow)
library(tidyr)
library(tidyfinance)

sv_directions <- read_parquet("data/sorting_variable_information.parquet") |>
  select(sorting_variable, direction)

grid <- read_parquet("data/portfolio_sort_grid.parquet") |>
  inner_join(sv_directions, join_by(sorting_variable))

process_task <- function(row, sorting_data, output_dir) {
  start <- Sys.time()

  warnings_collected <- character(0)
  state <- new.env(parent = emptyenv())
  state$cpr_elapsed <- NA_real_

  result <- tryCatch(
    withCallingHandlers(
      {
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

        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
        write_parquet(
          long_short_return,
          file.path(output_dir, paste0("id_", row$id, ".parquet"))
        )

        "success"
      },
      warning = function(w) {
        warnings_collected <<- c(warnings_collected, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )

  elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))

  if (is.character(result)) {
    tibble(
      id = row$id,
      status = result,
      elapsed_secs = elapsed,
      cpr_elapsed_secs = state$cpr_elapsed,
      n_warnings = length(warnings_collected),
      warnings = paste(warnings_collected, collapse = " | ")
    )
  } else {
    tibble(
      id = row$id,
      status = paste("error:", as.character(result)),
      elapsed_secs = elapsed,
      cpr_elapsed_secs = state$cpr_elapsed,
      n_warnings = length(warnings_collected),
      warnings = paste(warnings_collected, collapse = " | ")
    )
  }
}

diagnostics_list <- list()
for (j in 1:nrow(grid)) {
  start_load <- Sys.time()
  row <- grid[j, ]

  path <- file.path(
    "data",
    paste0("sorting_variables_lag_", row$sorting_variable_lag, ".parquet")
  )

  sv_lag_data <- open_dataset(path) |>
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

  output_dir <- file.path(
    "data",
    "portfolio_returns",
    paste0("sorting_variable=", row$sorting_variable),
    paste0("sorting_variable_lag=", row$sorting_variable_lag)
  )

  diagnostics_list[[j]] <- process_task(row, sv_lag_data, output_dir) |>
    mutate(
      elpased_inc_load = as.numeric(difftime(
        Sys.time(),
        start_load,
        units = "secs"
      ))
    )

  message(j, " done!")
}

diagnostics <- bind_rows(diagnostics_list)

write_parquet(diagnostics, "data/task_diagnostics.parquet")
