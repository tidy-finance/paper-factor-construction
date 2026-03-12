library(dplyr)
library(arrow)
library(furrr)

sv_directions <- read_parquet("data/sorting_variable_information.parquet") |>
  select(sorting_variable, direction)

grid <- read_parquet("data/portfolio_sort_grid.parquet") |>
  inner_join(sv_directions, join_by(sorting_variable))

grid_grouped <- grid |>
  group_by(sorting_variable, sorting_variable_lag)

grid_splits <- group_split(grid_grouped)
grid_keys <- group_keys(grid_grouped)

diagnostics_dir <- "data/task_diagnostics"
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

process_task <- function(row, sorting_data, output_dir, diag_dir) {
  start <- Sys.time()

  warnings_collected <- character(0)
  cpr_elapsed <- NA_real_

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

        dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
        arrow::write_parquet(
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

  status <- if (is.character(result)) result else paste("error:", as.character(result))

  diag <- tibble(
    id = row$id,
    status = status,
    elapsed_secs = elapsed,
    cpr_elapsed_secs = cpr_elapsed,
    n_warnings = length(warnings_collected),
    warnings = paste(warnings_collected, collapse = " | ")
  )

  dir.create(diag_dir, recursive = TRUE, showWarnings = FALSE)
  arrow::write_parquet(diag, file.path(diag_dir, paste0("id_", row$id, ".parquet")))
  invisible(NULL)
}

plan(multisession, workers = future::availableCores() - 1)

future_walk(
  seq_along(grid_splits),
  function(i) {
    key <- grid_keys[i, ]
    rows <- grid_splits[[i]]

    path <- file.path(
      "data",
      paste0("sorting_variables_lag_", key$sorting_variable_lag, ".parquet")
    )

    sv_lag_data <- arrow::open_dataset(path) |>
      select(
        permno,
        date,
        ret_excess,
        exchange,
        industry,
        filter_earnings,
        mktcap_lag,
        all_of(key$sorting_variable)
      ) |>
      collect()

    output_dir <- file.path(
      "data",
      "portfolio_returns",
      paste0("sorting_variable=", key$sorting_variable),
      paste0("sorting_variable_lag=", key$sorting_variable_lag)
    )

    diag_dir <- file.path(
      diagnostics_dir,
      paste0("sorting_variable=", key$sorting_variable),
      paste0("sorting_variable_lag=", key$sorting_variable_lag)
    )

    row_list <- split(rows, seq_len(nrow(rows)))
    for (row in row_list) {
      process_task(row, sv_lag_data, output_dir, diag_dir)
    }
    rm(sv_lag_data, row_list, rows, row, diag_dir)
    gc()
    invisible(NULL)
  },
  .options = furrr_options(packages = c("dplyr", "tidyfinance", "tidyr", "arrow"))
)

rm(grid, grid_splits, grid_keys, sv_directions)
gc()

diagnostics <- open_dataset(diagnostics_dir) |> collect()
write_parquet(diagnostics, "data/task_diagnostics.parquet")
unlink(diagnostics_dir, recursive = TRUE)

plan(sequential)
