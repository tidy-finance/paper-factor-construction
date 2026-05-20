library("dplyr")
library("arrow")
library("tidyr")
library("stringr")
library("tidyfinance")
library("future.apply")

n_workers <- max(1L, availableCores() - 1L)
options(future.globals.maxSize = Inf)
options(parallelly.fork.enable = TRUE)
plan(multicore, workers = n_workers)

sv_directions <- read_parquet("data/sorting_variable_information.parquet") |>
  transmute(sorting_variable = str_c("sv_", sorting_variable), direction)

grid <- read_parquet("data/portfolio_sort_grid.parquet") |>
  inner_join(sv_directions, join_by(sorting_variable)) |>
  mutate(
    parquet_path = file.path(
      "data",
      paste0("sorting_variables_lag_", sorting_variable_lag, ".parquet")
    )
  )

process_task <- function(row, sorting_data, output_dir) {
  warnings_collected <- character(0)

  result <- tryCatch(
    withCallingHandlers(
      {
        sorting_variables <- grep("sv_", names(sorting_data), value = TRUE)

        rebalancing_month <- if (row$rebalancing == "monthly") NULL else 7
        bp_exchanges <- strsplit(row$breakpoints_exchanges, split = "\\|")[[1]]
        breakpoints_min_size_threshold = if (
          !is.na(row$breakpoints_min_size_threshold)
        ) {
          row$breakpoints_min_size_threshold
        } else {
          NULL
        }

        options_main <- breakpoint_options(
          n_portfolios = row$n_portfolios_main,
          breakpoints_exchanges = bp_exchanges,
          breakpoints_min_size_threshold = breakpoints_min_size_threshold
        )

        options_secondary <- NULL

        if (row$sorting_method != "univariate") {
          sorting_variables <- c(sorting_variables, "mktcap_lag")
          options_secondary <- breakpoint_options(
            n_portfolios = row$n_portfolios_secondary,
            breakpoints_exchanges = bp_exchanges
          )
        }

        min_portfolio_size <- 1L

        portfolio_returns <- implement_portfolio_sort(
          sorting_data,
          sorting_variables = sorting_variables,
          sorting_method = row$sorting_method,
          rebalancing_month = rebalancing_month,
          portfolio_sort_options = portfolio_sort_options(
            filter_options = filter_options(
              exclude_financials = row$exclude_financials,
              exclude_utilities = row$exclude_utilities,
              exclude_negative_earnings = row$exclude_negative_earnings,
              min_size_quantile = if (!is.na(row$min_size_quantile)) {
                row$min_size_quantile
              } else {
                NULL
              },
              min_listing_age = 24
            ),
            breakpoint_options_main = options_main,
            breakpoint_options_secondary = options_secondary
          ),
          min_portfolio_size = min_portfolio_size,
          data_options = data_options(
            earnings = "filter_earnings"
          ),
          quiet = TRUE
        )

        long_short_return <- portfolio_returns |>
          compute_long_short_returns(direction = row$direction) |>
          pivot_longer(-date, names_to = "ret_type", values_to = "ret") |>
          mutate(
            ret_type = str_remove(ret_type, "ret_excess_"),
            id = row$id + match(ret_type, c("ew", "vw", "vw_capped")) - 1L,
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

  if (is.character(result)) {
    tibble(
      id = row$id,
      status = result,
      n_warnings = length(warnings_collected),
      warnings = paste(warnings_collected, collapse = " | ")
    )
  } else {
    tibble(
      id = row$id,
      status = paste("error:", as.character(result)),
      n_warnings = length(warnings_collected),
      warnings = paste(warnings_collected, collapse = " | ")
    )
  }
}

unique_paths <- unique(grid$parquet_path)
all_diagnostics <- vector("list", length(unique_paths))

for (p in seq_along(unique_paths)) {
  path <- unique_paths[p]
  group_grid <- grid[grid$parquet_path == path, ]
  group_grid <- group_grid |> filter(weighting_scheme == "EW") # Avoid redundant computations for VW and VW_CAPPED since they use the same breakpoints

  sv_cols_needed <- unique(group_grid$sorting_variable)

  message(
    sprintf(
      "[%s] Loading %s (%d tasks, %d sorting variables)...",
      Sys.time(),
      basename(path),
      nrow(group_grid),
      length(sv_cols_needed)
    )
  )

  sv_lag_data <- open_dataset(path) |>
    select(
      permno,
      date,
      ret_excess,
      exchange,
      siccd,
      filter_earnings,
      listing_age,
      mktcap_lag,
      all_of(sv_cols_needed)
    ) |>
    collect()

  output_dirs <- file.path(
    "data",
    "portfolio_returns",
    paste0("sorting_variable=", group_grid$sorting_variable),
    paste0("sorting_variable_lag=", group_grid$sorting_variable_lag)
  )

  results <- future_lapply(
    seq_len(nrow(group_grid)),
    function(i) {
      row <- group_grid[i, ]

      task_data <- sv_lag_data[,
        c(
          "permno",
          "date",
          "ret_excess",
          "exchange",
          "siccd",
          "filter_earnings",
          "listing_age",
          "mktcap_lag",
          row$sorting_variable
        ),
        drop = FALSE
      ]

      process_task(row, task_data, output_dirs[i])
    },
    future.seed = TRUE,
    future.chunk.size = max(1L, nrow(group_grid) %/% (n_workers * 4L))
  )

  all_diagnostics[[p]] <- bind_rows(results)

  message(
    sprintf(
      "[%s] Finished %s — %d tasks",
      Sys.time(),
      basename(path),
      nrow(group_grid)
    )
  )
}

plan(sequential)
diagnostics <- bind_rows(all_diagnostics)
write_parquet(diagnostics, "data/task_diagnostics.parquet")
message("All done! ", nrow(diagnostics), " tasks processed.")

# Clean up and finalize partition

temporary_folder <- "data/portfolio_returns_new"
open_dataset("data/portfolio_returns/") |>
  mutate(sorting_variable = str_remove(sorting_variable, "^sv_")) |>
  left_join(
    grid |> select(id, sorting_method, n_portfolios_main),
    join_by(id)
  ) |>
  write_dataset(
    path = temporary_folder,
    partitioning = c(
      "sorting_variable",
      "sorting_variable_lag",
      "sorting_method",
      "n_portfolios_main"
    )
  )


fs::dir_delete("data/portfolio_returns/")
fs::file_move(temporary_folder, "data/portfolio_returns/")
