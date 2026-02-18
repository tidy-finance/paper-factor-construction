library(dplyr)
library(lubridate)
library(arrow)
library(tidyr)
library(tidyfinance)

library(mirai)
daemons(future::availableCores() - 1)

sv_directions <- read_parquet("data/sorting_variable_information.parquet") |>
  select(sorting_variable, direction)

full_grid <- read_parquet("data/portfolio_sort_grid.parquet") |>
  inner_join(sv_directions, join_by(sorting_variable))

set.seed(1234)
grid <- full_grid |>
  group_by(sorting_variable, sorting_variable_lag) |> # TODO: Parallel across sv and lag datasets to prevent multiple reading of the same data
  slice_sample(n = 5) |>
  mutate(task_id = row_number())

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

process_task <- function(row, sorting_data) {
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
            contains("sv_"),
            exchange,
            mktcap_lag
          ) |>
          drop_na(all_of(sorting_variables))

        rebalancing_month <- if (row$rebalancing == "monthly") NULL else 7

        options_main <- breakpoint_options(
          n_portfolios = row$breakpoints_main,
          breakpoint_exchanges = strsplit(
            row$breakpoints_exchanges,
            split = "\\|"
          )[[1]]
        )

        options_secondary <- NULL

        if (row$sorting_method != "univariate") {
          sorting_variables <- c(sorting_variables, "mktcap_lag")
          options_secondary <- breakpoint_options(
            n_portfolios = row$breakpoints_secondary,
            breakpoint_exchanges = strsplit(
              row$breakpoints_exchanges,
              split = "\\|"
            )[[1]]
          )
        }
        # TODO: I removed manual min_portfolio_size filter as we use it in compute_portfolio_returns
        min_portfolio_size <- 10

        cpr_start <- Sys.time()
        portfolio_returns <- compute_portfolio_returns(
          sorting_data,
          sorting_variables,
          sorting_method = row$sorting_method,
          rebalancing_month,
          options_main,
          options_secondary,
          min_portfolio_size = 10
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

groups <- group_split(grid)
keys <- group_keys(grid)

tasks <- lapply(seq_along(groups), \(i) {
  mirai(
    {
      library(dplyr)
      library(tidyr)
      library(tidyfinance)
      library(glue)
      library(arrow)

      .group_data <- groups[[i]]
      .group_key <- keys[i, ]

      message(glue(
        "Processing: {.group_key$sorting_variable} (lag: {.group_key$sorting_variable_lag}, {nrow(.group_data)} tasks)"
      ))

      sv_lag_data <- read_sorting_data(
        lag_label = .group_key$sorting_variable_lag,
        sorting_variables = .group_key$sorting_variable
      )

      rows <- split(.group_data, seq_len(nrow(.group_data)))
      results <- lapply(seq_along(rows), \(j) {
        process_task(rows[[j]], sv_lag_data)
      })

      all_returns <- bind_rows(lapply(results, \(r) r$returns))
      if (nrow(all_returns) > 0) {
        all_returns |>
          group_by(
            sorting_variable,
            sorting_variable_lag = .group_key$sorting_variable_lag
          ) |>
          write_dataset(
            path = "data/portfolio_returns",
            format = "parquet",
            existing_data_behavior = "overwrite"
          )
      }

      bind_rows(lapply(results, \(r) r$diagnostics))
    },
    groups = groups,
    keys = keys,
    i = i,
    read_sorting_data = read_sorting_data,
    process_task = process_task
  )
})

diagnostics <- bind_rows(lapply(tasks, \(t) collect_mirai(t)))
daemons(0)

write_parquet(diagnostics, "data/task_diagnostics.parquet")
