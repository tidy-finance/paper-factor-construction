library(dplyr)
library(lubridate)
library(arrow)
library(tidyr)
library(tidyfinance)
library(here)

source("factor-library-code/00_global_options.R")

# TODO: rewrite using local parallelization
# TODO: include option for SLURM parallelization via library(future.batchtools)

task_id <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID"))
tasks_per_worker <- 100

task_ids <- tibble(
  task_id = (task_id - 1) * tasks_per_worker + seq(tasks_per_worker)
)

full_grid <- read_parquet(
  here(data_folder, "portfolio_sort_grid.parquet")
)

grid <- full_grid |>
  mutate(task_id = row_number()) |>
  inner_join(task_ids, join_by(task_id))

required_sorting_variables <- grid |>
  distinct(sorting_variable) |>
  pull()

required_datasets <- grid |>
  distinct(sorting_variable_lag) |>
  pull()

sv_directions <- read_parquet(
  here(data_folder, "sorting_variable_information.parquet")
)

if ("3m" %in% required_datasets) {
  sorting_data_3m <- open_dataset(
    here(data_folder, "sorting_variables_lag_3m.parquet")
  ) |>
    select(
      permno,
      date,
      ret_excess,
      exchange,
      industry,
      filter_earnings,
      mktcap_lag,
      all_of(required_sorting_variables)
    ) |>
    collect()
}

# 6m lag
if ("6m" %in% required_datasets) {
  sorting_data_6m <- open_dataset(
    here(data_folder, "sorting_variables_lag_6m.parquet")
  ) |>
    select(
      permno,
      date,
      ret_excess,
      exchange,
      industry,
      filter_earnings,
      mktcap_lag,
      all_of(required_sorting_variables)
    ) |>
    collect()
}

# FF lag
if ("ff" %in% required_datasets) {
  sorting_data_ff <- open_dataset(
    here(data_folder, "sorting_variables_lag_ff.parquet")
  ) |>
    select(
      permno,
      date,
      ret_excess,
      exchange,
      industry,
      filter_earnings,
      mktcap_lag,
      all_of(required_sorting_variables)
    ) |>
    collect()
}

for (j in 1:nrow(grid)) {
  if (grid$sorting_variable_lag[j] == "3m") {
    sorting_data <- sorting_data_3m
  } else if (grid$sorting_variable_lag[j] == "6m") {
    sorting_data <- sorting_data_6m
  } else if (grid$sorting_variable_lag[j] == "ff") {
    sorting_data <- sorting_data_ff
  }

  # Size exclusion
  if (grid$exclude_size[j] != 0) {
    sorting_data <- sorting_data |>
      group_by(date) |>
      filter(
        mktcap_lag >=
          quantile(mktcap_lag[exchange == "NYSE"], grid$exclude_size[j])
      ) |>
      ungroup()
  }

  # Exclude financials
  if (grid$exclude_financials[j]) {
    sorting_data <- sorting_data |> filter(industry != "Finance")
  }

  # Exclude utilities
  if (grid$exclude_utilities[j]) {
    sorting_data <- sorting_data |> filter(industry != "Utilities")
  }

  # Exclude negative earnings
  if (grid$exclude_negative_earnings[j]) {
    sorting_data <- sorting_data |> filter(filter_earnings > 0)
  }

  sorting_data <- sorting_data |>
    select(
      permno,
      date, # identifiers
      ret_excess, # returns
      contains(grid$sorting_variable[j]), # sorting variable
      exchange,
      mktcap_lag
    ) |> # breakpoints + weighting
    drop_na(all_of(grid$sorting_variable[j]))

  # Portfolio characteristics
  min_portfolio_size <- 10

  rebalancing_month <- if (grid$rebalancing[j] == "monthly") {
    NULL
  } else {
    7
  }
  options_main <- breakpoint_options(
    n_portfolios = grid$breakpoints_main[j],
    breakpoint_exchanges = strsplit(
      grid$breakpoints_exchanges[j],
      split = "\\|"
    )[[1]]
  )

  sorting_variables <- grid$sorting_variable[j]
  options_secondary <- NULL

  if (grid$sorting_method[j] != "univariate") {
    sorting_variables <- c(grid$sorting_variable[j], "mktcap_lag")
    options_secondary <- breakpoint_options(
      n_portfolios = grid$breakpoints_secondary[j],
      breakpoint_exchanges = strsplit(
        grid$breakpoints_exchanges[j],
        split = "\\|"
      )[[1]]
    )
  }

  portfolio_returns <- compute_portfolio_returns(
    sorting_data,
    sorting_variables,
    sorting_method = grid$sorting_method[j],
    rebalancing_month,
    options_main,
    options_secondary,
    min_portfolio_size = min_portfolio_size
  )

  long_short_return <- portfolio_returns |>
    tidyfinance::compute_long_short_returns(
      direction = sv_directions |>
        filter(sorting_variable == grid$sorting_variable[j]) |>
        pull(direction)
    ) |>
    rename(
      "{grid$ID[j]}" := ret_excess_ew,
      "{grid$ID[j] + 1}" := ret_excess_vw
    ) |>
    pivot_longer(-date, names_to = "ID", values_to = "ret") |>
    mutate(
      ID = as.integer(ID),
      sorting_variable = grid$sorting_variable[j],
      ret = replace_na(ret, 0)
    ) |> # no trading for empty portfolios
    left_join(all_tasks |> select(ID, ID_sequence), join_by(ID)) |>
    select(ID, ID_sequence, sorting_variable, date, ret)

  # Store results
  dir.create(
    file.path(
      paste0(data_raw_folder, "portfolio_returns/"),
      grid$sorting_variable[j]
    ),
    showWarnings = FALSE
  )

  write_parquet(
    long_short_return,
    here(
      data_folder,
      "portfolio_returns/",
      grid$sorting_variable[j],
      "/",
      grid$ID[j]
    )
  )
}
